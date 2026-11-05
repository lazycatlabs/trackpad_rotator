#!/bin/zsh
# Builds a notarized release: build/release/TrackpadRotator-<version>.dmg and .zip.
#
# One-time setup:
#   1. A "Developer ID Application" certificate for team 53KYGKG9B9 in the keychain
#      (Xcode → Settings → Accounts → Manage Certificates → + → Developer ID Application).
#   2. Notary credentials stored in the keychain:
#        xcrun notarytool store-credentials notary --apple-id <apple-id> --team-id 53KYGKG9B9
#      (it asks for an app-specific password from account.apple.com).
#
# NOTARY_PROFILE overrides the keychain profile name (default: notary).
set -euo pipefail
cd "$(dirname "$0")/.."

TEAM=53KYGKG9B9
PROFILE=${NOTARY_PROFILE:-notary}
VERSION=$(plutil -extract CFBundleShortVersionString raw Info.plist)
OUT=build/release
APP="$OUT/export/Trackpad Rotator.app"
NAME="TrackpadRotator-$VERSION"

rm -rf "$OUT"
mkdir -p "$OUT"

cat > "$OUT/ExportOptions.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>method</key><string>developer-id</string>
    <key>teamID</key><string>$TEAM</string>
    <key>signingStyle</key><string>automatic</string>
</dict>
</plist>
EOF

xcodebuild archive -project TrackpadRotator.xcodeproj -scheme TrackpadRotator -configuration Release \
    -destination "generic/platform=macOS" -archivePath "$OUT/TrackpadRotator.xcarchive" -quiet
xcodebuild -exportArchive -archivePath "$OUT/TrackpadRotator.xcarchive" \
    -exportOptionsPlist "$OUT/ExportOptions.plist" -exportPath "$OUT/export" -quiet

# Notarize the app itself and staple it, so the zip works offline too.
ditto -c -k --keepParent "$APP" "$OUT/notarize.zip"
xcrun notarytool submit "$OUT/notarize.zip" --keychain-profile "$PROFILE" --wait
xcrun stapler staple "$APP"
rm "$OUT/notarize.zip"

ditto -c -k --keepParent "$APP" "$OUT/$NAME.zip"

# DMG with an Applications shortcut, signed, notarized and stapled.
mkdir "$OUT/dmg"
cp -R "$APP" "$OUT/dmg/"
ln -s /Applications "$OUT/dmg/Applications"
hdiutil create -volname "Trackpad Rotator" -srcfolder "$OUT/dmg" -format UDZO -ov "$OUT/$NAME.dmg" -quiet
rm -rf "$OUT/dmg"
IDENTITY=$(security find-identity -v -p codesigning | grep -m1 "Developer ID Application:.*($TEAM)" | awk '{print $2}')
codesign --sign "$IDENTITY" --timestamp "$OUT/$NAME.dmg"
xcrun notarytool submit "$OUT/$NAME.dmg" --keychain-profile "$PROFILE" --wait
xcrun stapler staple "$OUT/$NAME.dmg"

spctl --assess --type execute -v "$APP"
spctl --assess --type open --context context:primary-signature -v "$OUT/$NAME.dmg"
shasum -a 256 "$OUT/$NAME.dmg" "$OUT/$NAME.zip"
echo "Release ready in $PWD/$OUT"
