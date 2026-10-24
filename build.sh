#!/bin/bash
# Builds build/EyeBreak.app. Pass --install to copy it to /Applications and launch it.
set -euo pipefail
cd "$(dirname "$0")"

APP=build/EyeBreak.app
ICON=build/AppIcon.icns

# Compiled with swiftc directly: the Command Line Tools here ship without a working SwiftPM.
mkdir -p build
BIN=build/EyeBreak
swiftc -O -target "$(uname -m)-apple-macos12.0" -o "$BIN" Sources/EyeBreak/*.swift

if [ ! -f "$ICON" ]; then
    ICONSET=build/AppIcon.iconset
    mkdir -p "$ICONSET"
    swift scripts/make-icon.swift build/icon-1024.png
    for s in 16 32 128 256 512; do
        sips -z $s $s build/icon-1024.png --out "$ICONSET/icon_${s}x${s}.png" >/dev/null
        sips -z $((s * 2)) $((s * 2)) build/icon-1024.png --out "$ICONSET/icon_${s}x${s}@2x.png" >/dev/null
    done
    iconutil -c icns "$ICONSET" -o "$ICON"
fi

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/EyeBreak"
cp Support/Info.plist "$APP/Contents/Info.plist"
cp "$ICON" "$APP/Contents/Resources/AppIcon.icns"
codesign --force --sign - "$APP"
echo "Built $APP"

if [ "${1:-}" = "--install" ]; then
    pkill -x EyeBreak || true
    rm -rf /Applications/EyeBreak.app
    cp -R "$APP" /Applications/
    open /Applications/EyeBreak.app
    echo "Installed and launched /Applications/EyeBreak.app"
fi
