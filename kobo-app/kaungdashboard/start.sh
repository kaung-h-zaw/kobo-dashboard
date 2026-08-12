#!/bin/sh

APP_DIR="/mnt/onboard/.adds/kaungdashboard"
PID_FILE="/tmp/kaungdashboard.pid"
LOCK_DIR="/tmp/kaungdashboard.lock"
STOP_FILE="/tmp/kaungdashboard.stop"
LOG_FILE="${APP_DIR}/debug.log"
FBINK="${APP_DIR}/bin/fbink"
FBDEPTH="${APP_DIR}/bin/fbdepth"
LUAJIT="${APP_DIR}/bin/luajit"
APP_PID=""
VIA_NICKEL="false"
ORIG_FB_BPP=""
ORIG_FB_ROTA=""

log() {
    printf '%s [LAUNCHER] %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$1" >>"${LOG_FILE}"
}

# shellcheck disable=SC2329 # Called from the EXIT trap through cleanup.
restart_nickel() {
    if [ "${VIA_NICKEL}" = "true" ]; then
        log "Restarting Nickel"
        # Clear the dashboard while its own framebuffer orientation is still active.
        # Nickel will issue the first refresh after it has restored portrait mode.
        "${FBINK}" -q -f -B WHITE --cls >>"${LOG_FILE}" 2>&1 || true
        "${APP_DIR}/nickel.sh" >>"${LOG_FILE}" 2>&1 &
    fi
}

# shellcheck disable=SC2329 # Called by trap.
cleanup() {
    trap - EXIT INT TERM
    if [ -n "${APP_PID}" ] && kill -0 "${APP_PID}" 2>/dev/null; then
        kill -TERM "${APP_PID}" 2>/dev/null || true
    fi
    rm -f "${PID_FILE}" "${STOP_FILE}"
    rmdir "${LOCK_DIR}" 2>/dev/null || true
    if [ -n "${ORIG_FB_BPP}" ] && [ -n "${ORIG_FB_ROTA}" ]; then
        "${FBDEPTH}" -q -d "${ORIG_FB_BPP}" -r "${ORIG_FB_ROTA}" >>"${LOG_FILE}" 2>&1 || true
    elif [ -n "${ORIG_FB_ROTA}" ]; then
        "${FBDEPTH}" -q -r "${ORIG_FB_ROTA}" >>"${LOG_FILE}" 2>&1 || true
    fi
    restart_nickel
    log "Launcher stopped"
}

trap cleanup EXIT INT TERM

if ! mkdir "${LOCK_DIR}" 2>/dev/null; then
    old_pid="$(cat "${PID_FILE}" 2>/dev/null)"
    if [ -n "${old_pid}" ] && kill -0 "${old_pid}" 2>/dev/null; then
        log "Launch ignored: process ${old_pid} is already running"
        trap - EXIT INT TERM
        exit 0
    fi
    rm -f "${PID_FILE}"
    rmdir "${LOCK_DIR}" 2>/dev/null || true
    if ! mkdir "${LOCK_DIR}" 2>/dev/null; then
        log "Launch ignored: unable to acquire lock"
        trap - EXIT INT TERM
        exit 0
    fi
fi
printf '%s\n' "$$" >"${PID_FILE}"

for required in "${FBINK}" "${FBDEPTH}" "${LUAJIT}" "${APP_DIR}/bin/input_scan"; do
    if [ ! -x "${required}" ]; then
        log "Missing executable: ${required}"
        exit 1
    fi
done
if ! command -v curl >/dev/null 2>&1; then
    log "curl is unavailable; remote data will use the last local cache or samples"
fi

rm -f "${STOP_FILE}"
cd "${APP_DIR}" || exit 1
ORIG_FB_BPP="$(cat /sys/class/graphics/fb0/bits_per_pixel 2>/dev/null)"
ORIG_FB_ROTA="$(cat /sys/class/graphics/fb0/rotate 2>/dev/null)"
log "Original framebuffer: ${ORIG_FB_BPP}bpp rotation=${ORIG_FB_ROTA}"

if pkill -0 nickel 2>/dev/null; then
    VIA_NICKEL="true"
    nickel_pid="$(pidof -s nickel)"
    if [ -n "${nickel_pid}" ]; then
        # Preserve the late environment required by the Kobo Nickel restart scripts.
        # Intentional splitting: each NUL-delimited NAME=value entry becomes one export argument.
        # shellcheck disable=SC2046
        export $(tr '\000' '\n' <"/proc/${nickel_pid}/environ" | grep -E '^(DBUS_SESSION_BUS_ADDRESS|NICKEL_HOME|WIFI_MODULE|LANG|INTERFACE|PLATFORM|PRODUCT)=')
    fi
    sync
    killall -q -TERM nickel hindenburg sickel fickel strickel fontickel adobehost foxitpdf iink fmon nanoclock.lua
    wait_count=0
    while pkill -0 nickel 2>/dev/null && [ "${wait_count}" -lt 16 ]; do
        usleep 250000
        wait_count=$((wait_count + 1))
    done
    rm -f /tmp/nickel-hardware-status
fi

log "Ensuring Wi-Fi is connected"
"${APP_DIR}/connect-wifi.sh" >>"${LOG_FILE}" 2>&1 || log "Wi-Fi connection failed; cached data will remain available"

log "Starting dashboard"
"${LUAJIT}" "${APP_DIR}/app.lua" >>"${LOG_FILE}" 2>&1 &
APP_PID=$!
printf '%s\n' "${APP_PID}" >"${PID_FILE}"
wait "${APP_PID}"
APP_STATUS=$?
APP_PID=""
exit "${APP_STATUS}"
