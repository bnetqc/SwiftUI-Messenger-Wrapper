#!/bin/bash
#
# Builds, signs, notarizes and packages Messenger for distribution.
#
# Requirements (one-time):
#   - Xcode installed
#   - A "Developer ID Application" certificate in your login keychain
#   - Notarization credentials stored in the keychain:
#       xcrun notarytool store-credentials "messenger-notary" \
#           --apple-id "<apple id email>" --team-id "<TEAM ID>" \
#           --password "<app-specific password>"
#
# Optional environment overrides: TEAM_ID, NOTARY_PROFILE, SIGN_IDENTITY.

set -euo pipefail
cd "$(dirname "$0")"

SIGN_IDENTITY="${SIGN_IDENTITY-$(security find-identity -v -p codesigning | sed -n 's/.*"\(Developer ID Application: [^"]*\)".*/\1/p' | head -n 1)}"
if [ -z "$SIGN_IDENTITY" ]; then
    echo "❌ No 'Developer ID Application' certificate found in the keychain."
    exit 1
fi
TEAM_ID="${TEAM_ID-$(echo "$SIGN_IDENTITY" | sed -n 's/.*(\([A-Z0-9]*\))$/\1/p')}"
NOTARY_PROFILE="${NOTARY_PROFILE:-messenger-notary}"

# Use the full Xcode even if the command line tools are the active developer dir.
if ! xcodebuild -version > /dev/null 2>&1; then
    export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
fi

VERSION=$(xcodebuild -project Messenger.xcodeproj -scheme Messenger -showBuildSettings 2>/dev/null | sed -n 's/.*MARKETING_VERSION = //p' | head -n 1)
BUILD_DIR="build"
ARCHIVE="$BUILD_DIR/Messenger.xcarchive"
EXPORT_DIR="$BUILD_DIR/export"
APP="$EXPORT_DIR/Messenger.app"
RELEASES="releases"
ZIP="$RELEASES/Messenger-v${VERSION}-macOS.zip"

echo "🚀 Building Messenger v${VERSION} (team ${TEAM_ID})"
rm -rf "$ARCHIVE" "$EXPORT_DIR"
mkdir -p "$BUILD_DIR" "$RELEASES"

echo "📦 Archiving..."
xcodebuild -project Messenger.xcodeproj -scheme Messenger -configuration Release \
    -archivePath "$ARCHIVE" archive \
    DEVELOPMENT_TEAM="$TEAM_ID" CODE_SIGN_STYLE=Manual \
    CODE_SIGN_IDENTITY="$SIGN_IDENTITY" | grep -E "error:|warning:|ARCHIVE" || true
[ -d "$ARCHIVE" ] || { echo "❌ Archive failed"; exit 1; }

echo "✍️  Exporting with Developer ID signature..."
xcodebuild -exportArchive -archivePath "$ARCHIVE" -exportOptionsPlist ExportOptions.plist \
    -exportPath "$EXPORT_DIR" DEVELOPMENT_TEAM="$TEAM_ID" | grep -E "error:|EXPORT" || true
[ -d "$APP" ] || { echo "❌ Export failed"; exit 1; }
codesign --verify --deep --strict --verbose=2 "$APP"

echo "🔏 Notarizing (this can take a few minutes)..."
rm -f "$ZIP"
ditto -c -k --keepParent "$APP" "$ZIP"
xcrun notarytool submit "$ZIP" --keychain-profile "$NOTARY_PROFILE" --wait
xcrun stapler staple "$APP"

# Re-zip so the archive contains the stapled app.
rm -f "$ZIP"
ditto -c -k --keepParent "$APP" "$ZIP"
spctl --assess --type execute -v "$APP"

echo "✅ Done: $ZIP"
echo "   Upload it to GitHub Releases as v${VERSION}."
