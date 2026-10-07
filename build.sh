#!/bin/bash
# ./build.sh           app in build/, ad-hoc signed (runs on this Mac only)
# ./build.sh install   ...then replaces /Applications/YouFixIt.app and opens it
# ./build.sh dmg       ...plus dist/YouFixIt.dmg (signed if CODESIGN_IDENTITY is set)
# ./build.sh release   Developer ID signed, notarized + stapled DMG.
#                      Needs a notarytool keychain profile (NOTARY_PROFILE, default claude-meter).
set -euo pipefail
cd "$(dirname "$0")"

MODE="${1:-}"
if [ "$MODE" = "release" ]; then
    CODESIGN_IDENTITY="${CODESIGN_IDENTITY:-Developer ID Application: Yiftach Freeman (6QWCS23UJ3)}"
fi
IDENTITY="${CODESIGN_IDENTITY:--}"

# CLT lacks the SwiftUI macros plugin on this SDK; borrow it from Xcode if present.
FLAGS=()
for XC in /Applications/Xcode.app /Applications/Xcode-beta.app; do
    PLUGINS="$XC/Contents/Developer/Platforms/MacOSX.platform/Developer/usr/lib/swift/host/plugins"
    if [ -d "$PLUGINS" ]; then FLAGS=(-Xswiftc -plugin-path -Xswiftc "$PLUGINS"); break; fi
done
swift build -c release --arch arm64 --arch x86_64 ${FLAGS[@]+"${FLAGS[@]}"}

APP="build/YouFixIt.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
# SwiftPM puts multi-arch products under out/ (Xcode 27) or apple/ (older).
BIN=.build/out/Products/Release/YouFixIt
[ -f "$BIN" ] || BIN=.build/apple/Products/Release/YouFixIt
cp "$BIN" "$APP/Contents/MacOS/"
cp Info.plist "$APP/Contents/"
# Liquid Glass icon (Assets.car) plus a flattened AppIcon.icns for macOS 14/15.
xcrun actool AppIcon.icon --compile "$APP/Contents/Resources" --platform macosx \
    --minimum-deployment-target 14.4 --app-icon AppIcon --standalone-icon-behavior all \
    --output-partial-info-plist "$(mktemp -d)/icon.plist" --errors --warnings >/dev/null

TIMESTAMP=()
if [ "$IDENTITY" != "-" ]; then TIMESTAMP=(--timestamp); fi
codesign --force --options runtime ${TIMESTAMP[@]+"${TIMESTAMP[@]}"} --sign "$IDENTITY" "$APP"
echo "Built $APP"

if [ "$MODE" = "install" ]; then
    pkill -f "/Applications/YouFixIt.app/Contents/MacOS/YouFixIt" 2>/dev/null || true   # the installed copy only, never a CLI scan
    sleep 0.5
    rm -rf /Applications/YouFixIt.app
    cp -R "$APP" /Applications/
    open /Applications/YouFixIt.app
    echo "Installed and opened /Applications/YouFixIt.app"
    exit 0
fi

if [ "$MODE" = "release" ]; then
    ZIP="$(mktemp -d)/YouFixIt.zip"
    ditto -c -k --keepParent "$APP" "$ZIP"
    xcrun notarytool submit "$ZIP" --keychain-profile "${NOTARY_PROFILE:-claude-meter}" --wait
    xcrun stapler staple "$APP"
fi

[ "$MODE" = "dmg" ] || [ "$MODE" = "release" ] || exit 0

DMG="dist/YouFixIt.dmg"
STAGE=$(mktemp -d)
cp -R "$APP" "$STAGE/"
ln -s /Applications "$STAGE/Applications"
mkdir -p dist
hdiutil create -volname "YouFixIt" -srcfolder "$STAGE" -ov -format UDZO "$DMG" >/dev/null
rm -rf "$STAGE"
if [ "$IDENTITY" != "-" ]; then codesign --force --timestamp --sign "$IDENTITY" "$DMG"; fi
echo "Built $DMG"

[ "$MODE" = "release" ] || exit 0
xcrun notarytool submit "$DMG" --keychain-profile "${NOTARY_PROFILE:-claude-meter}" --wait
xcrun stapler staple "$DMG"
xcrun stapler validate "$DMG"
echo "Notarized $DMG"
