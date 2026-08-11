#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
APP_PATH="$PROJECT_DIR/.build/KoboAppleSync.app"

cd "$PROJECT_DIR"
swift build -c release
BIN_PATH="$(swift build -c release --show-bin-path)/KoboAppleSync"

# Create the standard macOS app-bundle structure used by LaunchServices and TCC.
rm -rf "$APP_PATH"
mkdir -p "$APP_PATH/Contents/MacOS"
cp "$BIN_PATH" "$APP_PATH/Contents/MacOS/KoboAppleSync"
cp "$PROJECT_DIR/Sources/KoboAppleSync/Info.plist" "$APP_PATH/Contents/Info.plist"

# Ad-hoc signing gives the local helper a stable code identity. Hardened Runtime
# is enabled because Apple requires it (or App Sandbox) for this entitlement.
codesign --force \
    --sign - \
    --options runtime \
    --entitlements "$PROJECT_DIR/KoboAppleSync.entitlements" \
    --requirements '=designated => identifier "com.kaung.KoboAppleSync"' \
    "$APP_PATH"

codesign --verify --strict --verbose=2 "$APP_PATH"
echo "Built $APP_PATH"
