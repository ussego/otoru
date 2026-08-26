#!/bin/bash
set -e

TITLE="${1:-Download complete}"
BODY="${2:-Saved}"
FOLDER="${3:-}"

if [ -n "$FOLDER" ]; then
  # The --exec string is run by a shell on click; single-quote-escape the
  # path so folder names with quotes or shell metacharacters pass through
  # literally instead of being interpreted.
  FOLDER="${FOLDER//\'/\'\\\'\'}"
  /usr/share/omarchy/bin/omarchy-notification-send \
    --exec "uwsm-app -- nautilus --new-window '$FOLDER'" \
    -a otoru \
    -i folder-download \
    -u normal \
    "$TITLE" "$BODY" >/dev/null 2>&1 || true
else
  /usr/share/omarchy/bin/omarchy-notification-send \
    -a otoru \
    -i folder-download \
    -u normal \
    "$TITLE" "$BODY" >/dev/null 2>&1 || true
fi
