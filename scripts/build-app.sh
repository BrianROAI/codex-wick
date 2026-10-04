#!/bin/zsh
set -euo pipefail

ROOT="${0:A:h:h}"
cd "$ROOT"

swift build -c release --product CodexWick
BIN_DIR="$(swift build -c release --show-bin-path)"

APP="$ROOT/dist/Codex Wick.app"
CONTENTS="$APP/Contents"
ICON_TMP="$(mktemp -d)"
ICONSET="$ICON_TMP/AppIcon.iconset"

cleanup() {
  rm -rf "$ICON_TMP"
}
trap cleanup EXIT

rm -rf "$APP"
mkdir -p "$CONTENTS/MacOS" "$CONTENTS/Resources" "$ICONSET"

cp "$BIN_DIR/CodexWick" "$CONTENTS/MacOS/CodexWick"
cp "$ROOT/Resources/Info.plist" "$CONTENTS/Info.plist"
cp "$ROOT/Resources/favicon.svg" "$CONTENTS/Resources/favicon.svg"
chmod +x "$CONTENTS/MacOS/CodexWick"

qlmanage -t -s 1024 -o "$ICON_TMP" "$ROOT/Resources/AppIcon.svg" >/dev/null 2>&1
ICON_SOURCE="$ICON_TMP/AppIcon.svg.png"

if [[ ! -f "$ICON_SOURCE" ]]; then
  print -u2 "Failed to render Resources/AppIcon.svg"
  exit 1
fi

sips -z 16 16 "$ICON_SOURCE" --out "$ICONSET/icon_16x16.png" >/dev/null
sips -z 32 32 "$ICON_SOURCE" --out "$ICONSET/icon_16x16@2x.png" >/dev/null
sips -z 32 32 "$ICON_SOURCE" --out "$ICONSET/icon_32x32.png" >/dev/null
sips -z 64 64 "$ICON_SOURCE" --out "$ICONSET/icon_32x32@2x.png" >/dev/null
sips -z 128 128 "$ICON_SOURCE" --out "$ICONSET/icon_128x128.png" >/dev/null
sips -z 256 256 "$ICON_SOURCE" --out "$ICONSET/icon_128x128@2x.png" >/dev/null
sips -z 256 256 "$ICON_SOURCE" --out "$ICONSET/icon_256x256.png" >/dev/null
sips -z 512 512 "$ICON_SOURCE" --out "$ICONSET/icon_256x256@2x.png" >/dev/null
sips -z 512 512 "$ICON_SOURCE" --out "$ICONSET/icon_512x512.png" >/dev/null
cp "$ICON_SOURCE" "$ICONSET/icon_512x512@2x.png"

iconutil -c icns "$ICONSET" -o "$CONTENTS/Resources/AppIcon.icns"

if command -v codesign >/dev/null 2>&1; then
  codesign --force --deep --sign - "$APP" >/dev/null 2>&1 || true
fi

print "Built: $APP"
