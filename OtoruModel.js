.pragma library

function fmtSize(f) {
  if (!f) return 0
  return Number(f.filesize) || Number(f.filesize_approx) || 0
}

function formatSize(bytes) {
  var b = Number(bytes)
  if (!b || isNaN(b) || b <= 0) return ""
  var units = ["B", "KB", "MB", "GB"]
  var i = 0
  while (b >= 1024 && i < units.length - 1) { b /= 1024; i++ }
  return (i === 0 ? Math.round(b) : b.toFixed(1)) + " " + units[i]
}

// Strip prose debris off the tail of a URL: punctuation, quotes, and
// closing brackets ("see https://x.com/a," / "(https://x.com/a)" pastes).
function stripUrlJunk(u) {
  return String(u).replace(/[.,;:!?)\]}"'\u2019\u201d]+$/, "")
}

// Normalize whatever the user pastes into a usable URL, or "" if it can't
// be one: trim, take the first http(s) URL (even inside prose), strip
// trailing junk, and auto-prefix https:// for bare hosts (youtube.com/...).
// ponytail: single-token-with-dot heuristic also catches file names
// (notes.md) -> https://notes.md; in a URL field that's the right guess.
function cleanUrlText(text) {
  var t = String(text || "").trim()
  if (!t) return ""
  // Explicit ytsearch: prefixes are already valid yt-dlp input.
  if (/^ytsearch/i.test(t)) return stripUrlJunk(t)
  var m = /https?:\/\/\S+/i.exec(t)
  if (m) return stripUrlJunk(m[0])
  if (!/\s/.test(t) && t.indexOf(".") >= 0) {
    return "https://" + stripUrlJunk(t)
  }
  return ""
}

function looksLikeUrl(text) {
  return cleanUrlText(text) !== ""
}

// Non-empty text that isn't a URL and isn't an explicit ytsearch: prefix —
// the candidate for "search YouTube for this".
function isSearchQuery(text) {
  var t = String(text || "").trim()
  return t !== "" && cleanUrlText(t) === "" && !/^ytsearch/i.test(t)
}

function expandHome(path, home) {
  var p = String(path || "")
  if (p.indexOf("~") === 0) {
    return (home || "") + p.substring(1)
  }
  return p
}

function cookiesFromBrowserArg(settings) {
  var browser = String(settings.cookiesFromBrowser || "").trim().toLowerCase()
  if (!browser) return null
  var profile = String(settings.cookiesProfile || "").trim()
  if (profile) return browser + ":" + profile
  return browser
}

function formatDuration(totalSeconds) {
  var s = Math.max(0, Math.floor(Number(totalSeconds) || 0))
  var h = Math.floor(s / 3600)
  var m = Math.floor((s % 3600) / 60)
  var r = s % 60
  var parts = []
  if (h > 0) parts.push(String(h))
  parts.push(String(m).padStart(h > 0 ? 2 : 1, "0"))
  parts.push(String(r).padStart(2, "0"))
  return parts.join(":")
}

function parseVideoInfo(info) {
  var formats = Array.isArray(info.formats) ? info.formats : []
  var heights = []
  var hasAudio = false
  var audioLanguages = []
  for (var i = 0; i < formats.length; i++) {
    var f = formats[i]
    if (f && f.height && Number(f.height) > 0) heights.push(Number(f.height))
    if (f && f.acodec && String(f.acodec).toLowerCase() !== "none") {
      hasAudio = true
      if (f.language) {
        var lang = String(f.language).toLowerCase().split(/[-_]/)[0]
        if (lang && lang !== "" && audioLanguages.indexOf(lang) < 0) audioLanguages.push(lang)
      }
    }
  }

  var hasSubs = false
  var hasAutoSubs = false
  var subLanguages = []
  try {
    hasSubs = info.subtitles && Object.keys(info.subtitles).length > 0
    hasAutoSubs = info.automatic_captions && Object.keys(info.automatic_captions).length > 0
    // Every language yt-dlp reported, manual + auto, deduped and sorted.
    var subSets = [info.subtitles, info.automatic_captions]
    for (var si = 0; si < subSets.length; si++) {
      var langs = subSets[si] ? Object.keys(subSets[si]) : []
      for (var li = 0; li < langs.length; li++) {
        var code = String(langs[li]).toLowerCase()
        if (code && subLanguages.indexOf(code) < 0) subLanguages.push(code)
      }
    }
    subLanguages.sort()
  } catch (e2) { }

  // Qt here has no WebP image plugin, so prefer non-webp URLs and rewrite
  // YouTube's vi_webp/*.webp to their jpg equivalents when webp is all we get.
  var thumbnail = ""
  var thumbs = Array.isArray(info.thumbnails) ? info.thumbnails : []
  for (var ti = 0; ti < thumbs.length; ti++) {
    var tu = thumbs[ti] && thumbs[ti].url ? String(thumbs[ti].url) : ""
    if (tu && !/\.webp($|\?)/i.test(tu)) thumbnail = tu
  }
  if (!thumbnail && info.thumbnail) thumbnail = String(info.thumbnail)
  if (/\.webp($|\?)/i.test(thumbnail)) {
    thumbnail = thumbnail.replace("/vi_webp/", "/vi/").replace(/\.webp/i, ".jpg")
  }

  return {
    title: String(info.title || "Unknown title"),
    thumbnail: thumbnail,
    duration: Number(info.duration) || 0,
    uploader: String(info.uploader || info.channel || info.artist || ""),
    formats: formats,
    hasAudio: hasAudio,
    maxHeight: heights.length > 0 ? Math.max.apply(null, heights) : 0,
    extractor: String(info.extractor || ""),
    audioLanguages: audioLanguages,
    hasSubs: hasSubs,
    hasAutoSubs: hasAutoSubs,
    subLanguages: subLanguages,
    webpage_url: String(info.webpage_url || "")
  }
}

function parseInfo(raw) {
  try {
    var info = JSON.parse(String(raw || "{}"))
    if (!info || typeof info !== "object") return null

    // Playlists arrive as {_type:"playlist", entries:[…]}. For plain URLs
    // this is flat extraction (entry stubs only — the download re-extracts
    // each item itself); for ytsearchN it's a wrapper around fully-extracted
    // entries. A single fully-extracted result (ytsearch1) is unwrapped to
    // its video card — title/thumbnail/duration should be the song, not the
    // query.
    if (info._type === "playlist" || Array.isArray(info.entries)) {
      var entries = info.entries || []
      if (entries.length === 1 && Array.isArray(entries[0].formats) && entries[0].formats.length > 0) {
        return parseVideoInfo(entries[0])
      }
      return {
        isPlaylist: true,
        title: String(info.title || "Playlist"),
        thumbnail: "",
        duration: 0,
        uploader: String(info.uploader || info.channel || ""),
        formats: [],
        hasAudio: true,
        maxHeight: 0,
        extractor: String(info.extractor || ""),
        audioLanguages: [],
        hasSubs: false,
        hasAutoSubs: false,
        subLanguages: [],
        count: Number(info.playlist_count) || entries.length,
        webpage_url: String(info.webpage_url || "")
      }
    }

    return parseVideoInfo(info)
  } catch (e) {
    return null
  }
}

var VIDEO_QUALITIES = [2160, 1440, 1080, 720, 480, 360, 240]

function availableVideoQualities(maxHeight) {
  var out = []
  for (var i = 0; i < VIDEO_QUALITIES.length; i++) {
    if (maxHeight >= VIDEO_QUALITIES[i]) out.push(String(VIDEO_QUALITIES[i]))
  }
  return out
}

// Flat playlist extraction carries no formats, so the real max height is
// unknown — offer every rung and let yt-dlp cap each entry on its own
// (`height<=` selectors degrade to the entry's best when it can't be met).
function allVideoQualities() {
  return VIDEO_QUALITIES.map(String)
}

function bestAudioFormat(formats, lang) {
  var best = null
  var bestScore = -1
  for (var i = 0; i < formats.length; i++) {
    var f = formats[i]
    if (!f.acodec || String(f.acodec).toLowerCase() === "none") continue
    if (lang && String(f.language || "").toLowerCase().split(/[-_]/)[0] !== lang) continue
    var score = fmtSize(f) || Number(f.abr) || 0
    if (score > bestScore) { bestScore = score; best = f }
  }
  return best
}

function bestVideoFormat(formats, maxHeight) {
  var best = null
  var bestScore = -1
  for (var i = 0; i < formats.length; i++) {
    var f = formats[i]
    if (!f.vcodec || String(f.vcodec).toLowerCase() === "none") continue
    var h = Number(f.height) || 0
    if (maxHeight > 0 && h > maxHeight) continue
    var score = fmtSize(f) || Number(f.tbr) * 125 || h
    if (score > bestScore) { bestScore = score; best = f }
  }
  return best
}

function estimateQualitySize(info, height) {
  if (!info || !Array.isArray(info.formats)) return 0
  return fmtSize(bestVideoFormat(info.formats, Number(height) || 0))
    + fmtSize(bestAudioFormat(info.formats, ""))
}

function estimateSize(info, job) {
  if (!info || !Array.isArray(info.formats)) return 0
  var j = job || {}
  var mode = j.mode || "best"
  if (mode === "custom") return 0
  if (mode === "audio") return fmtSize(bestAudioFormat(info.formats, j.audioLanguage || ""))
  var maxH = (mode === "video" && j.quality && j.quality !== "best") ? Number(j.quality) || 0 : 0
  var total = fmtSize(bestVideoFormat(info.formats, maxH)) + fmtSize(bestAudioFormat(info.formats, ""))
  return total > 0 ? total : 0
}

function progressTemplate() {
  return "progress:%(progress._percent_str)s|%(progress._speed_str)s|%(progress._eta_str)s|%(progress._downloaded_bytes_str)s|%(progress._total_bytes_str)s|%(progress._total_bytes_estimate_str)s|%(playlist_index)s|%(n_entries)s"
}

function stripAnsi(s) {
  return String(s || "").replace(/\x1b\[[0-9;]*m/g, "")
}

function parseProgressLine(line) {
  var prefix = "progress:"
  var s = stripAnsi(line || "")
  if (!s.startsWith(prefix)) return null
  var parts = s.substring(prefix.length).split("|")

  function field(i) {
    var v = parts[i] ? parts[i].trim() : ""
    if (!v || v === "NA" || v.indexOf("Unknown") >= 0) return ""
    return v
  }

  var percentText = field(0)
  var percent = 0
  if (percentText) {
    var n = parseFloat(percentText.replace("%", ""))
    if (!isNaN(n)) percent = Math.max(0, Math.min(100, n))
  }

  var downloaded = field(3)
  var total = field(4) || field(5)
  var idx = field(6)
  var count = field(7)
  var itemPrefix = idx && count ? "[" + idx + "/" + count + "] " : ""

  return {
    percent: percent,
    percentText: percentText,
    speed: field(1),
    eta: field(2),
    downloaded: downloaded,
    total: total,
    sizeText: itemPrefix + (downloaded && total ? downloaded + " / " + total : downloaded)
  }
}

function infoCommand(url, proxy, useWebClient, settings, home) {
  var args = ["yt-dlp", "--no-warnings", "--dump-single-json", "--skip-download"]
  // Search queries need real (non-flat) extraction to return the resolved
  // video instead of a playlist stub.
  if (!/^ytsearch/i.test(String(url))) args.push("--flat-playlist")
  if (useWebClient) args.push("--extractor-args", "youtube:player_client=web")
  if (proxy && String(proxy).trim()) args.push("--proxy", String(proxy).trim())
  var browserCookies = cookiesFromBrowserArg(settings)
  if (browserCookies) {
    args.push("--cookies-from-browser", browserCookies)
  } else if (settings && settings.cookies && String(settings.cookies).trim()) {
    args.push("--cookies", expandHome(String(settings.cookies).trim(), home))
  }
  args.push(String(url))
  // Cap the producer-side output at 1MB so a large playlist JSON can't
  // exhaust the long-lived shell process. "$@" passes each arg as a
  // separate parameter — no shell interpolation of the URL.
  return ["sh", "-c", "exec \"$@\" 2>&1 | head -c 1048576", "otoru-info"].concat(args)
}

function versionCommand() {
  return ["yt-dlp", "--version"]
}

function ffmpegVersionCommand() {
  return ["ffmpeg", "-version"]
}

function clipCommand() {
  return ["wl-paste", "--no-newline"]
}

function mkdirCommand(dir, home) {
  return ["mkdir", "-p", expandHome(dir, home)]
}

function splitCustomArgs(argString) {
  var s = String(argString || "").trim()
  if (!s) return []
  return s.split(/\s+/).filter(function(t) { return t !== "" })
}

function buildDownloadArgs(job, settings, home, useWebClient) {
  var args = ["yt-dlp", "--newline", "--no-warnings", "--no-colors", "--progress", "--progress-delta", "0.3", "--progress-template", progressTemplate(), "--print", "after_move:filepath"]
  if (useWebClient) args.push("--extractor-args", "youtube:player_client=web")

  var outDir = expandHome(settings.downloadDir, home)
  args.push("-P", outDir)

  if (settings.outputTemplate && String(settings.outputTemplate).trim()) {
    args.push("-o", String(settings.outputTemplate).trim())
  }
  if (settings.proxy && String(settings.proxy).trim()) {
    args.push("--proxy", String(settings.proxy).trim())
  }
  var browserCookies = cookiesFromBrowserArg(settings)
  if (browserCookies) {
    args.push("--cookies-from-browser", browserCookies)
  } else if (settings.cookies && String(settings.cookies).trim()) {
    args.push("--cookies", expandHome(String(settings.cookies).trim(), home))
  }
  if (settings.rateLimit && String(settings.rateLimit).trim()) {
    args.push("--limit-rate", String(settings.rateLimit).trim())
  }
  if (settings.concurrentFragments && String(settings.concurrentFragments).trim()) {
    args.push("--concurrent-fragments", String(settings.concurrentFragments).trim())
  }
  if (settings.customArgs && String(settings.customArgs).trim()) {
    args = args.concat(splitCustomArgs(settings.customArgs))
  }
  if (settings.sponsorBlock === true) {
    var cats = Array.isArray(settings.sponsorBlockCategories) ? settings.sponsorBlockCategories.join(",") : ""
    if (cats) args.push("--sponsorblock-remove", cats)
  }
  if (settings.useArchive === true) {
    args.push("--download-archive", outDir + "/.otoru-archive.txt")
  }

  if (settings.downloadThumbnail === true) {
    args.push("--write-thumbnail", "--convert-thumbnails", "jpg")
  }
  if (settings.embedThumbnail === true) {
    args.push("--embed-thumbnail")
  }
  if (settings.embedSubs === true || settings.includeAutoSubs === true) {
    var subLang = String(settings.subLanguage || "all").trim()
    args.push("--sub-langs", subLang || "all")
    if (settings.embedSubs === true) args.push("--embed-subs")
    // Embedding manual subs is a no-op on auto-caption-only videos
    // (--embed-subs fetches only manually uploaded ones); pull in the auto
    // captions instead. Videos with manual subs stay manual-only unless the
    // user also opts into auto captions.
    if (settings.includeAutoSubs === true ||
        (settings.embedSubs === true && job.info && !job.info.hasSubs && job.info.hasAutoSubs)) {
      args.push("--write-auto-subs")
    }
  }

  // ponytail: DRC preference relies on YouTube's "-drc" format-id suffix;
  // other sites fall through the alternate selectors unchanged.
  var preferDrc = settings.preferDrc === true
  var mode = job.mode || "best"
  if (mode === "audio") {
    args.push("-x")
    var af = job.audioFormat || settings.audioFormat || "best"
    if (af && String(af) !== "best") args.push("--audio-format", String(af))
    var langFilter = ""
    if (job.audioLanguage && String(job.audioLanguage) !== "") {
      langFilter = "[language=" + String(job.audioLanguage) + "]"
    }
    if (preferDrc || langFilter !== "") {
      var base = "bestaudio" + langFilter
      var sel = preferDrc ? base + "[format_id$='-drc']/" + base : base
      args.push("-f", sel + "/bestaudio")
    }
  } else if (mode === "custom") {
    var sel2 = settings.customFormatSelector ? String(settings.customFormatSelector).trim() : ""
    if (sel2) args.push("-f", sel2)
  } else if (mode === "video") {
    var q = job.quality || "best"
    if (q !== "best") {
      var vf = "bestvideo[height<=" + q + "]+bestaudio"
      if (preferDrc) vf += "[format_id$='-drc']/bestvideo[height<=" + q + "]+bestaudio"
      vf += "/best[height<=" + q + "]"
      args.push("-f", vf)
    } else if (preferDrc) {
      args.push("-f", "bestvideo*+bestaudio[format_id$='-drc']/bestvideo*+bestaudio/best")
    }
  }

  args.push(String(job.url))

  return ["sh", "-c", "exec env PYTHONUNBUFFERED=1 \"$@\" 2>&1", "otoru-dl"].concat(args)
}

function friendlyError(stderr, exitCode, exitStatus) {
  var s = String(stderr || "")
  if (exitStatus !== 0) return "Download cancelled."
  if (exitCode === 127 || s.toLowerCase().indexOf("command not found") >= 0 || s.indexOf("yt-dlp: not found") >= 0) {
    return "yt-dlp is not installed or not on PATH."
  }
  if (s.toLowerCase().indexOf("ffmpeg") >= 0) {
    return "ffmpeg is required for this download. Please install ffmpeg."
  }
  if (s.indexOf("Unsupported URL") >= 0) {
    return "Unsupported website or URL."
  }
  if (/sign in|login|authentication|auth required|authenticate/i.test(s)) {
    return "Authentication required."
  }
  if (/private|removed|unavailable|not available|blocked|copyright|age restricted/i.test(s)) {
    return "Media unavailable."
  }
  if (/requested format|format not available/i.test(s)) {
    return "Selected format unavailable."
  }
  if (/403|forbidden|access denied/i.test(s)) {
    return "Access denied (HTTP 403). Try updating yt-dlp, using cookies, or retry as web client."
  }
  if (/not available in your country|geo.*restrict|this content is not available/i.test(s)) {
    return "Geo-blocked in your region."
  }
  if (/certificate verify failed|ssl/i.test(s)) {
    return "SSL/TLS certificate error."
  }
  if (/http error|timed out|temporary failure|network|could not send|connection/i.test(s)) {
    return "Network error."
  }
  var first = s.split("\n")[0] || ""
  return "Download failed" + (first ? ": " + first : "")
}

function guessOutputPath(settings, job, info, home) {
  var dir = expandHome(settings.downloadDir, home)
  var title = info && info.title ? String(info.title).replace(/[\/\\?%*:|"<>]/g, "_") : "download"
  var ext = ""
  if (job.mode === "audio") {
    var af = job.audioFormat || settings.audioFormat || "best"
    ext = af === "best" ? ".%(ext)s" : "." + af
  } else {
    ext = ".%(ext)s"
  }
  return dir + "/" + title + ext
}
