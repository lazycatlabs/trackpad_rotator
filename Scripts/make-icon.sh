#!/bin/zsh
# Renders Resources/AppIcon.icns (plus Resources/AppIcon-1024.png) from make-icon.swift.
set -euo pipefail
cd "$(dirname "$0")/.."

WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT
mkdir -p Resources "$WORK/AppIcon.iconset"

xcrun swift Scripts/make-icon.swift "$WORK/icon-1024.png"

for s in 16 32 128 256 512; do
    sips -z $s $s "$WORK/icon-1024.png" --out "$WORK/AppIcon.iconset/icon_${s}x${s}.png" >/dev/null
    sips -z $((s * 2)) $((s * 2)) "$WORK/icon-1024.png" --out "$WORK/AppIcon.iconset/icon_${s}x${s}@2x.png" >/dev/null
done

iconutil -c icns "$WORK/AppIcon.iconset" -o Resources/AppIcon.icns
cp "$WORK/icon-1024.png" Resources/AppIcon-1024.png
echo "Wrote Resources/AppIcon.icns"
