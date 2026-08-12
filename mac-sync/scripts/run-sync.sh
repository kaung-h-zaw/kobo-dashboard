#!/bin/bash

set -u

FORCE_SYNC=false
if [[ "${1:-}" == "--force" ]]; then
    FORCE_SYNC=true
    shift
fi

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
ROOT_CONFIG="$PROJECT_DIR/../.env.example"
APP_PATH="$PROJECT_DIR/.build/KoboAppleSync.app"
USER_LOG_DIR="$HOME/Library/Logs"
OUTPUT_LOG="$USER_LOG_DIR/kobo-apple-sync-manual.log"
ERROR_LOG="$USER_LOG_DIR/kobo-apple-sync-manual-error.log"

if [[ ! -d "$APP_PATH" ]]; then
    echo "KoboAppleSync.app is not built. Run ./scripts/build-app.sh first." >&2
    exit 1
fi

mkdir -p "$USER_LOG_DIR"
: > "$OUTPUT_LOG"
: > "$ERROR_LOG"

OPEN_ARGUMENTS=(
    -n -W
    --stdout "$OUTPUT_LOG"
    --stderr "$ERROR_LOG"
    --env "KOBO_SERVER_URL=${KOBO_SERVER_URL:-https://kobo-dashboard-7ub6.onrender.com}"
    --env "TIMEZONE=${TIMEZONE:-Asia/Bangkok}"
)

# The scheduled job has a deliberately secret-free plist. Load the locally
# configured value at runtime instead of embedding it in LaunchAgent arguments.
if [[ -z "${APPLE_SYNC_SECRET:-}" && -f "$ROOT_CONFIG" ]]; then
    APPLE_SYNC_SECRET="$(/usr/bin/sed -n 's/^APPLE_SYNC_SECRET=//p' "$ROOT_CONFIG" | /usr/bin/head -n 1)"
fi

if [[ -n "${APPLE_SYNC_SECRET:-}" ]]; then
    OPEN_ARGUMENTS+=(--env "APPLE_SYNC_SECRET=$APPLE_SYNC_SECRET")
fi

# LaunchAgent checks quickly for a Kobo reload request, but performs the
# ordinary background upload only every five minutes.
LAST_RUN_FILE="/tmp/kaung-kobo-apple-sync-last-run"
NOW_EPOCH="$(date +%s)"
LAST_RUN_EPOCH="$(stat -f %m "$LAST_RUN_FILE" 2>/dev/null || echo 0)"
SYNC_DUE=false
if (( NOW_EPOCH - LAST_RUN_EPOCH >= 300 )); then SYNC_DUE=true; fi
REQUEST_WAITING=false
if [[ -n "${APPLE_SYNC_SECRET:-}" ]]; then
    REQUEST_STATUS="$(curl -fsS --max-time 5 \
        -H "Authorization: Bearer $APPLE_SYNC_SECRET" \
        "${KOBO_SERVER_URL:-https://kobo-dashboard-7ub6.onrender.com}/api/sync-request" 2>/dev/null || true)"
    if [[ "$REQUEST_STATUS" == *'"status":"waiting"'* ]]; then REQUEST_WAITING=true; fi
fi
if [[ "$FORCE_SYNC" != true && "$SYNC_DUE" != true && "$REQUEST_WAITING" != true ]]; then
    exit 0
fi

/usr/bin/open "${OPEN_ARGUMENTS[@]}" "$APP_PATH" --args "$@"
OPEN_STATUS=$?
if [[ "$OPEN_STATUS" -eq 0 ]]; then touch "$LAST_RUN_FILE"; fi

sed -n '1,1000p' "$OUTPUT_LOG"
sed -n '1,200p' "$ERROR_LOG" >&2
exit "$OPEN_STATUS"
