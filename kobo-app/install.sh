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
    SOURCE_BIN="${TRMNL_SOURCE}/src/TRMNL/bin"
elif [ -f "${TRMNL_SOURCE}/luajit" ] && [ -d "${TRMNL_SOURCE}/fbink" ]; then
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

for qr_asset in "${SCRIPT_DIR}/kaungdashboard/assets/wifi-24ghz.png" \
    "${SCRIPT_DIR}/kaungdashboard/assets/wifi-5ghz.png"; do
    if [ ! -f "${qr_asset}" ]; then
        echo "Missing private Wi-Fi QR asset: ${qr_asset}"
        exit 1
    fi
done

TARGET="${KOBO_MOUNT}/.adds/kaungdashboard"
mkdir -p "${TARGET}/bin" "${TARGET}/licenses" "${KOBO_MOUNT}/.adds/nm"
cp -R "${SCRIPT_DIR}/kaungdashboard/." "${TARGET}/"
cp "${SOURCE_BIN}/luajit" "${TARGET}/bin/luajit"
cp "${SOURCE_BIN}/fbink/fbink" "${TARGET}/bin/fbink"
cp "${SOURCE_BIN}/fbink/fbdepth" "${TARGET}/bin/fbdepth"
cp "${SOURCE_BIN}/fbink/input_scan" "${TARGET}/bin/input_scan"
for notice in LICENSE CREDITS README.md; do
    if [ -f "${SOURCE_BIN}/fbink/${notice}" ]; then
        cp "${SOURCE_BIN}/fbink/${notice}" "${TARGET}/licenses/FBInk-${notice}"
    fi
done
if [ -f "${TRMNL_SOURCE}/LICENSE" ]; then
    cp "${TRMNL_SOURCE}/LICENSE" "${TARGET}/licenses/trmnl-kobo-LICENSE"
fi
cp "${SCRIPT_DIR}/KaungDashboard.nm" "${KOBO_MOUNT}/.adds/nm/KaungDashboard"
chmod +x "${TARGET}/start.sh" "${TARGET}/stop.sh" "${TARGET}/nickel.sh" "${TARGET}/bin/"*
sync

echo "Kaung Dashboard files prepared successfully. Safely eject the Kobo before unplugging it."
