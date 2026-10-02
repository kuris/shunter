#!/bin/zsh
# Shorts Hunter Studio 를 macOS .app / .dmg 로 패키징한다.
# 사용법: Scripts/make_app.sh [debug|release]
#
# 참고: 프로젝트 루트의 .env 가 있으면 앱 번들 Resources/.env 로 포함된다.
#       (.env 는 .gitignore 로 커밋에서 제외됨)
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CONFIG="${1:-release}"
APP_NAME="ShortsHunterStudio"
DISPLAY_NAME="Shorts Hunter Studio"
DIST="$ROOT/dist"
BUNDLE="$DIST/$DISPLAY_NAME.app"
DMG="$DIST/ShortsHunterStudio.dmg"

echo "==> Building ($CONFIG)"
swift build -c "$CONFIG" --package-path "$ROOT"
BIN_DIR="$(swift build -c "$CONFIG" --show-bin-path --package-path "$ROOT")"
BIN="$BIN_DIR/$APP_NAME"
[[ -x "$BIN" ]] || { echo "binary not found: $BIN" >&2; exit 1; }

echo "==> Assembling $BUNDLE"
rm -rf "$BUNDLE"
mkdir -p "$BUNDLE/Contents/MacOS" "$BUNDLE/Contents/Resources"
cp "$BIN" "$BUNDLE/Contents/MacOS/$APP_NAME"

cat > "$BUNDLE/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key><string>$APP_NAME</string>
    <key>CFBundleDisplayName</key><string>$DISPLAY_NAME</string>
    <key>CFBundleIdentifier</key><string>com.shortshunter.studio</string>
    <key>CFBundleExecutable</key><string>$APP_NAME</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleShortVersionString</key><string>0.2.0</string>
    <key>CFBundleVersion</key><string>2</string>
    <key>LSMinimumSystemVersion</key><string>14.0</string>
    <key>NSHighResolutionCapable</key><true/>
    <key>NSPrincipalClass</key><string>NSApplication</string>
    <key>LSApplicationCategoryType</key><string>public.app-category.video</string>
    <key>NSSupportsAutomaticGraphicsSwitching</key><true/>
</dict>
</plist>
PLIST

if [[ -f "$ROOT/.env" ]]; then
  echo "==> Bundling .env (API keys)"
  cp "$ROOT/.env" "$BUNDLE/Contents/Resources/.env"
fi

echo "==> Ad-hoc signing"
codesign --force --deep --sign - "$BUNDLE" >/dev/null 2>&1 || echo "(codesign skipped)"

echo "==> Creating DMG"
STAGING="$(mktemp -d)"
cp -R "$BUNDLE" "$STAGING/"
ln -s /Applications "$STAGING/Applications"
rm -f "$DMG"
hdiutil create -volname "$DISPLAY_NAME" -srcfolder "$STAGING" -ov -format UDZO "$DMG" >/dev/null
rm -rf "$STAGING"

echo ""
echo "완료:"
echo "  APP: $BUNDLE"
echo "  DMG: $DMG"
