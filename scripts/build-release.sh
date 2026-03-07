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

# Create DMG with Applications symlink
DMG_NAME="$APP_NAME-$VERSION.dmg"
DMG_PATH="build/release/$DMG_NAME"
DMG_STAGING="build/dmg-staging"

rm -rf "$DMG_STAGING"
mkdir -p "$DMG_STAGING"
cp -R "build/release/$APP_NAME.app" "$DMG_STAGING/"
ln -s /Applications "$DMG_STAGING/Applications"

hdiutil create \
  -volname "$APP_NAME" \
  -srcfolder "$DMG_STAGING" \
  -ov \
  -format UDZO \
  "$DMG_PATH"

rm -rf "$DMG_STAGING"

DMG_SIZE=$(stat -f%z "$DMG_PATH" 2>/dev/null || stat -c%s "$DMG_PATH")
REPO="${GITHUB_REPOSITORY:-adriandmitroca/messenger}"
PUB_DATE=$(date -u "+%a, %d %b %Y %H:%M:%S %z")
DOWNLOAD_URL="https://github.com/$REPO/releases/download/v$VERSION/$DMG_NAME"

# Sparkle signing
ED_SIG=""
if [ -n "${SPARKLE_PRIVATE_KEY:-}" ]; then
  SIGN_UPDATE=$(find ~/Library/Developer/Xcode/DerivedData -path "*/Sparkle/bin/sign_update" -print -quit 2>/dev/null || true)
  if [ -n "$SIGN_UPDATE" ]; then
    ED_SIG=$(echo "$SPARKLE_PRIVATE_KEY" | "$SIGN_UPDATE" "$DMG_PATH" --ed-key-file /dev/stdin | grep -o 'edSignature="[^"]*"' | cut -d'"' -f2)
  fi
fi

# Update appcast.xml
python3 - "$VERSION" "$DOWNLOAD_URL" "$ED_SIG" "$DMG_SIZE" "$PUB_DATE" "$APP_NAME" "$REPO" <<'PYEOF'
import sys, os

version, url, sig, length, pub_date, app_name, repo = sys.argv[1:8]

item = f"""    <item>
      <title>Version {version}</title>
      <sparkle:version>{version}</sparkle:version>
      <sparkle:shortVersionString>{version}</sparkle:shortVersionString>
      <sparkle:minimumSystemVersion>14.0</sparkle:minimumSystemVersion>
      <pubDate>{pub_date}</pubDate>
      <enclosure
        url="{url}"
        type="application/octet-stream"
        sparkle:edSignature="{sig}"
        length="{length}"
      />
    </item>"""

if os.path.exists("appcast.xml"):
    with open("appcast.xml") as f:
        content = f.read()
    content = content.replace("</channel>", item + "\n  </channel>")
    with open("appcast.xml", "w") as f:
        f.write(content)
else:
    with open("appcast.xml", "w") as f:
        f.write(f"""<?xml version="1.0" encoding="utf-8"?>
<rss version="2.0" xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle">
  <channel>
    <title>{app_name} Updates</title>
    <link>https://github.com/{repo}</link>
{item}
  </channel>
</rss>
""")
PYEOF

echo "Built and packaged $APP_NAME v$VERSION"
