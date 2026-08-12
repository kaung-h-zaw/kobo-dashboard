#!/bin/sh

set -eu

SCRIPT_DIR="$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)"
KOBO_MOUNT="${1:-}"
TRMNL_SOURCE="${2:-}"

if [ -z "${KOBO_MOUNT}" ] || [ -z "${TRMNL_SOURCE}" ]; then
    echo "Usage: $0 /path/to/KOBOeReader /path/to/trmnl-kobo"
    exit 2
fi
if [ ! -d "${KOBO_MOUNT}/.adds" ]; then
    echo "Refusing to install: ${KOBO_MOUNT}/.adds was not found."
    exit 1
fi

if [ -d "${TRMNL_SOURCE}/src/TRMNL/bin" ]; then
    SOURCE_APP="${TRMNL_SOURCE}/src/TRMNL"
    SOURCE_BIN="${TRMNL_SOURCE}/src/TRMNL/bin"
elif [ -f "${TRMNL_SOURCE}/luajit" ] && [ -d "${TRMNL_SOURCE}/fbink" ]; then
    SOURCE_APP="${TRMNL_SOURCE}"
    SOURCE_BIN="${TRMNL_SOURCE}"
else
    echo "Could not find src/TRMNL/bin in the supplied trmnl-kobo checkout."
    exit 1
fi

for required in "${SOURCE_BIN}/luajit" "${SOURCE_BIN}/fbink/fbink" \
    "${SOURCE_BIN}/fbink/fbdepth" "${SOURCE_BIN}/fbink/input_scan"; do
    if [ ! -f "${required}" ]; then
        echo "Missing required upstream binary: ${required}"
        exit 1
    fi
done

for required in "${SOURCE_APP}/scripts/enable-wifi.sh" \
    "${SOURCE_APP}/scripts/obtain-ip.sh" \
    "${SOURCE_APP}/scripts/release-ip.sh" \
    "${SOURCE_APP}/scripts/log.sh" \
    "${SOURCE_APP}/lua/ntx_io.lua" \
    "${SOURCE_APP}/ffi/posix_h.lua"; do
    if [ ! -f "${required}" ]; then
        echo "Missing required upstream Wi-Fi support file: ${required}"
        exit 1
    fi
done

for qr_asset in "${SCRIPT_DIR}/kaungdashboard/assets/wifi-24ghz.png" \
    "${SCRIPT_DIR}/kaungdashboard/assets/wifi-5ghz.png"; do
    if [ ! -f "${qr_asset}" ]; then
        echo "Missing private Wi-Fi QR asset: ${qr_asset}"
        exit 1
    fi
done

TARGET="${KOBO_MOUNT}/.adds/kaungdashboard"
mkdir -p "${TARGET}/bin" "${TARGET}/ffi" "${TARGET}/lua" "${TARGET}/scripts" \
    "${TARGET}/licenses" "${KOBO_MOUNT}/.adds/nm"
cp -R "${SCRIPT_DIR}/kaungdashboard/." "${TARGET}/"
cp "${SOURCE_BIN}/luajit" "${TARGET}/bin/luajit"
cp "${SOURCE_BIN}/fbink/fbink" "${TARGET}/bin/fbink"
cp "${SOURCE_BIN}/fbink/fbdepth" "${TARGET}/bin/fbdepth"
cp "${SOURCE_BIN}/fbink/input_scan" "${TARGET}/bin/input_scan"
for wifi_script in enable-wifi.sh obtain-ip.sh release-ip.sh log.sh; do
    cp "${SOURCE_APP}/scripts/${wifi_script}" "${TARGET}/scripts/${wifi_script}"
done
# Upstream renamed its optional reconnect helper between releases. Copy whichever
# helpers are present; enable-wifi.sh from each release uses its matching version.
for wifi_helper in force-wifi-connection.sh restore-wifi-async.sh; do
    if [ -f "${SOURCE_APP}/scripts/${wifi_helper}" ]; then
        cp "${SOURCE_APP}/scripts/${wifi_helper}" "${TARGET}/scripts/${wifi_helper}"
    fi
done
cp "${SOURCE_APP}/lua/ntx_io.lua" "${TARGET}/lua/ntx_io.lua"
cp -R "${SOURCE_APP}/ffi/." "${TARGET}/ffi/"
for notice in LICENSE CREDITS README.md; do
    if [ -f "${SOURCE_BIN}/fbink/${notice}" ]; then
        cp "${SOURCE_BIN}/fbink/${notice}" "${TARGET}/licenses/FBInk-${notice}"
    fi
done
if [ -f "${TRMNL_SOURCE}/LICENSE" ]; then
    cp "${TRMNL_SOURCE}/LICENSE" "${TARGET}/licenses/trmnl-kobo-LICENSE"
fi
cp "${SCRIPT_DIR}/KaungDashboard.nm" "${KOBO_MOUNT}/.adds/nm/KaungDashboard"
chmod +x "${TARGET}/start.sh" "${TARGET}/stop.sh" "${TARGET}/nickel.sh" \
    "${TARGET}/connect-wifi.sh" "${TARGET}/bin/"* "${TARGET}/scripts/"*.sh
sync

echo "Kaung Dashboard files prepared successfully. Safely eject the Kobo before unplugging it."
