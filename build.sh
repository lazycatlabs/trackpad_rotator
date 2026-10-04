#!/bin/zsh
# Builds build/Trackpad Rotator.app (no Xcode project needed).
set -euo pipefail
cd "$(dirname "$0")"

ARCH=$(uname -m)
APP="build/Trackpad Rotator.app"
rm -rf build
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

xcrun clang -c Sources/MTBridge.c -o build/MTBridge.o -O2 \
    -target "$ARCH-apple-macos13.0" -fobjc-arc

xcrun swiftc -O -swift-version 5 \
    -target "$ARCH-apple-macos13.0" \
    -import-objc-header Sources/MTBridge.h \
    Sources/*.swift build/MTBridge.o \
    -o "$APP/Contents/MacOS/TrackpadRotator"

cp Info.plist "$APP/Contents/Info.plist"
[[ -f Resources/AppIcon.icns ]] || ./Scripts/make-icon.sh
cp Resources/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"
# A stable signing identity keeps macOS privacy permissions across rebuilds;
# ad-hoc signatures change every build and macOS forgets the grants.
IDENTITY=${SIGN_IDENTITY:-$(security find-identity -v -p codesigning | grep -m1 "Apple Development: Mudassir" | awk '{print $2}')}
codesign --force --sign "${IDENTITY:--}" "$APP"
echo "Built: $PWD/$APP"
