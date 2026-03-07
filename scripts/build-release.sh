#!/usr/bin/env bash
set -euo pipefail

VERSION="$1"
APP_NAME="Messenger"
PROJECT="Messenger.xcodeproj"
SCHEME="Messenger"

xcodegen generate

xcodebuild build \
  -project "$PROJECT" \
  -scheme "$SCHEME" \
  -configuration Release \
  -derivedDataPath build/derived \
  CODE_SIGN_IDENTITY="-" \
  CODE_SIGNING_REQUIRED=NO \
  -quiet

mkdir -p build/release
cp -R "build/derived/Build/Products/Release/$APP_NAME.app" build/release/

cd build/release
ditto -c -k --sequesterRsrc --keepParent "$APP_NAME.app" "$APP_NAME-$VERSION.zip"
cd - > /dev/null

ZIP_PATH="build/release/$APP_NAME-$VERSION.zip"
ZIP_SIZE=$(stat -f%z "$ZIP_PATH" 2>/dev/null || stat -c%s "$ZIP_PATH")
REPO="${GITHUB_REPOSITORY:-adriandmitroca/messenger}"
PUB_DATE=$(date -u "+%a, %d %b %Y %H:%M:%S %z")
DOWNLOAD_URL="https://github.com/$REPO/releases/download/v$VERSION/$APP_NAME-$VERSION.zip"

# Sparkle signing
ED_SIG=""
if [ -n "${SPARKLE_PRIVATE_KEY:-}" ]; then
  SIGN_UPDATE=$(find ~/Library/Developer/Xcode/DerivedData -path "*/Sparkle/bin/sign_update" -print -quit 2>/dev/null || true)
  if [ -n "$SIGN_UPDATE" ]; then
    ED_SIG=$(echo "$SPARKLE_PRIVATE_KEY" | "$SIGN_UPDATE" "$ZIP_PATH" --ed-key-file /dev/stdin | grep -o 'edSignature="[^"]*"' | cut -d'"' -f2)
  fi
fi

NEW_ITEM="    <item>
      <title>Version $VERSION</title>
      <sparkle:version>$VERSION</sparkle:version>
      <sparkle:shortVersionString>$VERSION</sparkle:shortVersionString>
      <sparkle:minimumSystemVersion>14.0</sparkle:minimumSystemVersion>
      <pubDate>$PUB_DATE</pubDate>
      <enclosure
        url=\"$DOWNLOAD_URL\"
        type=\"application/octet-stream\"
        sparkle:edSignature=\"$ED_SIG\"
        length=\"$ZIP_SIZE\"
      />
    </item>"

if [ -f appcast.xml ]; then
  awk -v item="$NEW_ITEM" '/<\/channel>/ { print item } { print }' appcast.xml > appcast.tmp && mv appcast.tmp appcast.xml
else
  cat > appcast.xml <<APPCAST
<?xml version="1.0" encoding="utf-8"?>
<rss version="2.0" xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle">
  <channel>
    <title>$APP_NAME Updates</title>
    <link>https://github.com/$REPO</link>
$NEW_ITEM
  </channel>
</rss>
APPCAST
fi

echo "Built and packaged $APP_NAME v$VERSION"
