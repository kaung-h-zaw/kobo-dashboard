#!/bin/sh

APP_DIR="/mnt/onboard/.adds/kaungdashboard"
LOG_FILE="${APP_DIR}/debug.log"
INTERFACE="${INTERFACE:-eth0}"
export INTERFACE
export trmnl_loop_wpa_network_id="${trmnl_loop_wpa_network_id:--1}"
export debug_to_screen=0
export log_to_server=NONE

log() {
    printf '%s [WIFI] %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$1" >>"${LOG_FILE}"
}

has_address() {
    ifconfig "${INTERFACE}" 2>/dev/null | grep -Eq 'inet addr:|inet [0-9]'
}

is_connected() {
    wpa_cli -i "${INTERFACE}" status 2>/dev/null | grep -q 'wpa_state=COMPLETED' && has_address
}

cd "${APP_DIR}" || exit 1
if is_connected; then
    log "Already connected on ${INTERFACE}"
    exit 0
fi

if [ ! -x "${APP_DIR}/scripts/enable-wifi.sh" ]; then
    log "Automatic Wi-Fi support is missing; reinstall with a full trmnl-kobo source checkout"
    exit 1
fi

log "Enabling Wi-Fi on ${INTERFACE}"
"${APP_DIR}/scripts/enable-wifi.sh" >>"${LOG_FILE}" 2>&1 || true
wpa_cli -i "${INTERFACE}" enable_network all >>"${LOG_FILE}" 2>&1 || true
wpa_cli -i "${INTERFACE}" reconnect >>"${LOG_FILE}" 2>&1 || true

wait_count=0
while ! wpa_cli -i "${INTERFACE}" status 2>/dev/null | grep -q 'wpa_state=COMPLETED'; do
    if [ "${wait_count}" -ge 60 ]; then
        log "Timed out waiting for a saved Wi-Fi network"
        exit 1
    fi
    usleep 250000
    wait_count=$((wait_count + 1))
done

if ! has_address; then
    log "Obtaining an IP address"
    (cd "${APP_DIR}/scripts" && ./obtain-ip.sh) >>"${LOG_FILE}" 2>&1 || true
fi

if is_connected; then
    log "Wi-Fi connected"
    exit 0
fi

log "Wi-Fi association completed but no usable IP address was found"
exit 1
