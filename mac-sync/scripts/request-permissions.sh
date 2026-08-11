#!/bin/bash

set -u

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
APP_PATH="$PROJECT_DIR/.build/KoboAppleSync.app"
USER_LOG_DIR="$HOME/Library/Logs"
OUTPUT_LOG="$USER_LOG_DIR/kobo-apple-sync-permissions.log"
ERROR_LOG="$USER_LOG_DIR/kobo-apple-sync-permissions-error.log"

if [[ ! -d "$APP_PATH" ]]; then
    echo "KoboAppleSync.app is not built. Run ./scripts/build-app.sh first." >&2
    exit 1
fi

mkdir -p "$USER_LOG_DIR"
: > "$OUTPUT_LOG"
: > "$ERROR_LOG"

# LaunchServices makes KoboAppleSync responsible for its own TCC request.
# Executing Contents/MacOS/KoboAppleSync directly from an IDE terminal makes
# the IDE responsible instead, and macOS refuses to show the consent sheets.
/usr/bin/open -n -W \
    --stdout "$OUTPUT_LOG" \
    --stderr "$ERROR_LOG" \
    "$APP_PATH" \
    --args --permissions-only
OPEN_STATUS=$?

sed -n '1,200p' "$OUTPUT_LOG"
sed -n '1,200p' "$ERROR_LOG" >&2
exit "$OPEN_STATUS"
