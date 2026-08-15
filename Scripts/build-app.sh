#!/usr/bin/env bash
# Builds ClaudeBuddy.app from the SwiftPM executable.
#
#   ./Scripts/build-app.sh              # native architecture
#   UNIVERSAL=1 ./Scripts/build-app.sh  # arm64 + x86_64
set -euo pipefail

cd "$(dirname "$0")/.."

CONFIGURATION="${CONFIGURATION:-release}"
BUILD_ARGS=(-c "$CONFIGURATION")
if [[ "${UNIVERSAL:-0}" == "1" ]]; then
  BUILD_ARGS+=(--arch arm64 --arch x86_64)
fi

echo "==> swift build ${BUILD_ARGS[*]}"
swift build "${BUILD_ARGS[@]}"

BIN_PATH="$(swift build "${BUILD_ARGS[@]}" --show-bin-path)"
EXECUTABLE="$BIN_PATH/ClaudeBuddy"

if [[ ! -x "$EXECUTABLE" ]]; then
  echo "error: built executable not found at $EXECUTABLE" >&2
  exit 1
fi

APP="build/ClaudeBuddy.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$EXECUTABLE" "$APP/Contents/MacOS/ClaudeBuddy"

cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>en</string>
    <key>CFBundleExecutable</key>
    <string>ClaudeBuddy</string>
    <key>CFBundleIdentifier</key>
    <string>com.claudebuddy.app</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>Claude Buddy</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSSupportsAutomaticTermination</key>
    <false/>
    <key>NSSupportsSuddenTermination</key>
    <false/>
</dict>
</plist>
PLIST

# Ad-hoc signature: enough for local use and required for the login item API.
codesign --force --sign - "$APP" >/dev/null 2>&1 || \
  echo "warning: ad-hoc codesign failed; 'Launch At Login' may not work" >&2

echo "==> built $APP"
echo "    open $APP        # run it"
echo "    make install     # copy to /Applications"
