#!/bin/bash
# Builds build/EyeBreak.app. Pass --install to copy it to /Applications and launch it.
set -euo pipefail
cd "$(dirname "$0")"

APP=build/EyeBreak.app
ICON=build/AppIcon.icns

# Swift version an SDK's standard library was built with, e.g. "5.10" or "6.0".
sdk_swift_version() {
    local interface
    interface=$(ls "$1"/usr/lib/swift/Swift.swiftmodule/*.swiftinterface 2>/dev/null | head -1)
    [ -n "$interface" ] && sed -nE 's/^\/\/ swift-compiler-version: .*Swift version ([0-9]+\.[0-9]+).*/\1/p' "$interface" | head -1
}

# True if version $1 <= version $2.
version_le() {
    [ "$(printf '%s\n%s\n' "$1" "$2" | sort -t. -k1,1n -k2,2n | head -1)" = "$1" ]
}

# Some Command Line Tools installs end up with a default SDK built for a newer Swift than the
# installed compiler, which fails with "this SDK is not supported by the compiler". In that case,
# fall back to the newest installed SDK the compiler can read. Set SDKROOT to choose one yourself.
if [ -z "${SDKROOT:-}" ]; then
    COMPILER_VERSION=$(swiftc --version 2>&1 | sed -nE 's/.*Swift version ([0-9]+\.[0-9]+).*/\1/p' | head -1)
    DEFAULT_SDK=$(xcrun --sdk macosx --show-sdk-path)
    DEFAULT_SDK_VERSION=$(sdk_swift_version "$DEFAULT_SDK")
    if [ -n "$DEFAULT_SDK_VERSION" ] && ! version_le "$DEFAULT_SDK_VERSION" "$COMPILER_VERSION"; then
        BEST=""
        BEST_VERSION=""
        for sdk in "$(dirname "$DEFAULT_SDK")"/MacOSX[0-9]*.sdk; do
            [ -L "$sdk" ] && continue
            v=$(sdk_swift_version "$sdk")
            [ -z "$v" ] && continue
            if version_le "$v" "$COMPILER_VERSION" && { [ -z "$BEST_VERSION" ] || version_le "$BEST_VERSION" "$v"; }; then
                BEST=$sdk
                BEST_VERSION=$v
            fi
        done
        if [ -z "$BEST" ]; then
            echo "error: no installed macOS SDK matches Swift $COMPILER_VERSION. Reinstall the Command Line Tools:" >&2
            echo "  sudo rm -rf /Library/Developer/CommandLineTools && xcode-select --install" >&2
            exit 1
        fi
        echo "Default SDK needs Swift $DEFAULT_SDK_VERSION but the compiler is Swift $COMPILER_VERSION; using $(basename "$BEST")."
        export SDKROOT=$BEST
    fi
fi

# Compiled with swiftc directly: some Command Line Tools installs ship without a working SwiftPM.
# Builds a universal binary (Apple Silicon + Intel). Override with e.g. ARCHS=arm64 for a faster local build.
ARCHS="${ARCHS:-arm64 x86_64}"
mkdir -p build
BIN=build/EyeBreak
SLICES=()
for arch in $ARCHS; do
    swiftc -O -swift-version 5 -target "$arch-apple-macos12.0" -o "build/EyeBreak-$arch" Sources/EyeBreak/*.swift
    SLICES+=("build/EyeBreak-$arch")
done
lipo -create -output "$BIN" "${SLICES[@]}"

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
