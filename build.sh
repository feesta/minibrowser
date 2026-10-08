#!/bin/sh
# Builds build/mini.app (universal, macOS 12+) and build/mini.zip. Needs the Xcode Command Line Tools.
#
#   ./build.sh             build, and sign with your Developer ID if the keychain has one
#   ./build.sh notarize    build, sign, send to Apple's notary service and staple the ticket
#
# Notarizing needs a one-time credential in the keychain:
#   xcrun notarytool store-credentials mini-notary --apple-id you@example.com --team-id XXXXXXXXXX
# (it asks for an app-specific password from https://account.apple.com). Override the profile name
# with PROFILE=..., the signing identity with IDENTITY=..., and the version (default: latest git tag) with VERSION=...
#
# For hacking on it, a bare binary next to home.html also works:  swiftc -O mini.swift -o mini && ./mini
set -e
cd "$(dirname "$0")"

VERSION=${VERSION:-$(git describe --tags --abbrev=0 2>/dev/null | sed 's/^v//')}
VERSION=${VERSION:-0.0.0}
IDENTITY=${IDENTITY:-$(security find-identity -v -p codesigning 2>/dev/null | grep -o '"Developer ID Application: [^"]*"' | head -1 | tr -d '"')}
PROFILE=${PROFILE:-mini-notary}
APP=build/mini.app
C=$APP/Contents

rm -rf "$APP" build/mini.zip build/mini.iconset build/arm64 build/x86_64
mkdir -p "$C/MacOS" "$C/Resources"

swiftc -O -target arm64-apple-macosx12.0  mini.swift -o build/arm64
swiftc -O -target x86_64-apple-macosx12.0 mini.swift -o build/x86_64
lipo -create build/arm64 build/x86_64 -output "$C/MacOS/mini"
rm -f build/arm64 build/x86_64

cp home.html putty-ink.css icon.png "$C/Resources/"
swift mkicon.swift icon.png build/mini.iconset
iconutil -c icns build/mini.iconset -o "$C/Resources/mini.icns"
rm -rf build/mini.iconset
sed "s/@VERSION@/$VERSION/g" Info.plist > "$C/Info.plist"

if [ -n "$IDENTITY" ]; then
    codesign --force --options runtime --timestamp --sign "$IDENTITY" "$APP"
    codesign --verify --strict --verbose=2 "$APP"
    echo "signed as $IDENTITY"
else
    codesign --force --sign - "$APP"
    echo "no Developer ID Application certificate in the keychain: ad-hoc signed, Gatekeeper will refuse this on other Macs"
fi

ditto -c -k --keepParent "$APP" build/mini.zip

if [ "$1" = notarize ]; then
    xcrun notarytool submit build/mini.zip --keychain-profile "$PROFILE" --wait
    xcrun stapler staple "$APP"
    rm -f build/mini.zip
    ditto -c -k --keepParent "$APP" build/mini.zip
    echo "notarized and stapled"
fi

echo "built $APP ($VERSION) and build/mini.zip"
