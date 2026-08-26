# Otoru vs. omarchyplugins.com Security Policy — Analysis & Readiness Plan

## Context

The omarchyplugins.com marketplace runs an **Automated Security Baseline** on every plugin commit: a deterministic static scan producing either findings (blocking patterns), review capabilities (require maintainer review), or `passed`. This plan analyzes otoru (ussego.otoru, an Omarchy bar-widget fronting `yt-dlp`) against that policy and applies the minimal hardening so the listing passes cleanly. **Purpose: real marketplace submission, soon.**

## What otoru is (scan-relevant inventory)

- 11 tracked files (clean tree — `.agents/`, `.claude/`, `skills-lock.json` are gitignored and never committed).
- Runtime files: `BarWidget.qml` (manifest entry point, forced into scan), `Panel.qml` (2338 lines, loaded via Loader), `OtoruModel.js` (pure functions), `notify-done.sh` (notification helper), `manifest.json`, `README.md`.
- Binary content: only `preview.png` — recognized asset extension, excluded by path classification.
- External processes: `yt-dlp` (ships with Omarchy), `ffmpeg`, `wl-paste`, `curl` (thumbnail page scrape only), `mkdir`, `omarchy-notification-send`. All spawned via Quickshell `Process`/`execDetached` with **argv-style command arrays — no shell**.

## Policy mapping

### Findings (blocking patterns) — none present

| Pattern | Otoru status |
|---|---|
| curl-pipe-shell | No. `curl -sL` is used once (Panel.qml:647) to fetch page HTML for og:image scraping; stdout goes to a `StdioCollector`, parsed by regex, never piped to a shell or written to a later-executed file. |
| cargo-git-unpinned | N/A — no Rust/cargo. |
| remote-git-execution-unpinned | N/A — yt-dlp is a system binary; otoru never pulls or executes external git repos. |
| sudoers-dangerous-passwordless-command | N/A — no sudoers, no NOPASSWD anywhere. |
| privileged-process-control-from-shared-temp | N/A — no /tmp PID files, no sudo/pkexec. |

### Review capabilities — none present

| Capability | Otoru status |
|---|---|
| installer | No install scripts. `notify-done.sh` is a notification helper, not an installer. |
| package-manager | No apt/pacman/dnf/etc. README install is `omarchy plugin add` (platform mechanism). |
| privilege | Zero sudo/pkexec references. |
| remote-build | N/A — nothing builds or executes external repos. |
| bundled-executable-binary | No ELF/PE/Mach-O. No install/setup-named paths. |
| service-management | No systemd units, no systemctl/systemd-run. |
| sudoers-modification | N/A — no sudoers policy handling. |

### Expected baseline outcome: **`passed`**

No findings, no review capabilities → `passed`, eligible for exact-commit evidence and verified publication. Scan-limit checks (1,000 files / 8 MiB / 512 KiB per file) are trivially satisfied: ~8 small text files, largest is Panel.qml ~90 KB.

## Near-miss patterns (not findings, but reviewers may ask)

1. **`sh -c` wrappers** (OtoruModel.js:394 and Panel.qml:826). Both pass all dynamic data via `"$@"`/`"$1"` — no shell interpolation of user input. They exist because Quickshell `Process` doesn't set `env`/stdin. Safe — documented in SECURITY.md.
2. **notify-done.sh `--exec` interpolation** — `--exec "uwsm-app -- nautilus --new-window \"$FOLDER\""` embeds `$FOLDER` in a command string. Verified against `/usr/bin/omarchy-notification-send`: `--exec` becomes a `omarchy-exec:` hint string that the Omarchy shell itself runs (no argv alternative exists), so escaping in the script is the right fix. `FOLDER` = the user's own `downloadDir` setting (never remote-controlled — yt-dlp output filenames don't enter it), worst case is self-inflicted, but a `"` or `$(…)` in downloadDir would be interpreted by the shell. → **Fix with single-quote escaping.**
3. **`customArgs` advanced setting** — user settings can pass arbitrary yt-dlp flags, including `--exec`, which yt-dlp runs in its own shell with the filename substituted. Opt-in power-user config, not a static finding, but the trust boundary belongs in docs → SECURITY.md.
4. **README direct-install line** — `omarchy plugin add https://github.com/ussego/otoru.git` installs mutable branch HEAD, which the marketplace explicitly does *not* verification-bind. → Add one README line.

## Approved changes (user decision: apply all three, keep features working)

### 1. Harden `notify-done.sh` (feature-preserving)

Single-quote wrap `$FOLDER` and escape any embedded single quotes with the standard `'\''` idiom. Every normal path (including spaces, `$`, `"`, backticks) round-trips unchanged; only a literal `'` in the folder name needs escaping, and that is handled. The "open folder" notification button keeps working for any valid download dir.

```diff
-if [ -n "$FOLDER" ]; then
+if [ -n "$FOLDER" ]; then
+  FOLDER="${FOLDER//\'/\'\\\'\'}"   # shell-escape for the --exec string
   /usr/share/omarchy/bin/omarchy-notification-send \
-    --exec "uwsm-app -- nautilus --new-window \"$FOLDER\"" \
+    --exec "uwsm-app -- nautilus --new-window '$FOLDER'" \
```

Note: FOLDER reaches this script already expanded and absolute (Panel.qml passes `Otoru.expandHome(downloadDir, home)`); it is never a yt-dlp-derived filename.

### 2. Add `SECURITY.md` — **dropped per user decision** (plan feedback). No security doc will be added.

### 3. README install note (1 line)

Under Install: marketplace installs are snapshot-verified against the reviewed commit; direct `omarchy plugin add` tracks the repo's default branch and is not verification-bound.

## Files to modify

- `notify-done.sh` — escape FOLDER (change 1) ✅
- `README.md` — verification note (change 3) ✅
- ~~`SECURITY.md` — dropped~~

## Reuse

- `tests/normalize.test.js` exists for OtoruModel.js helpers — unaffected (no JS/QML logic changes). No new test needed; the change is a one-line shell escape with no branches (ponytail: YAGNI on test for a quoting tweak).
- No new dependencies, no new tooling.

## Steps

- [x] Edit `notify-done.sh`: single-quote-escape `$FOLDER` before the `--exec` string
- [x] ~~Add `SECURITY.md`~~ — dropped per user decision
- [x] Add one-line verification note to `README.md` Install section
- [ ] Verify (below), then commit — the submission will scan this exact commit SHA

## Verification

- `bash -n notify-done.sh` → syntax OK
- `shellcheck notify-done.sh` if available
- Manual: `./notify-done.sh "test" "body" "/home/usse/Downloads"` → notification fires, button opens folder
- Manual edge: folder with a single quote (`/tmp/ot'ru`) → button still opens the folder
- `grep -rnE "sudo|pkexec|systemctl|systemd-run|curl .*\| *sh|/tmp/.*pid" .` → empty outside expected hits
- `node tests/normalize.test.js` → all pass (regression guard for OtoruModel.js)
- `git ls-files` → clean, deterministic tree for exact-SHA binding
