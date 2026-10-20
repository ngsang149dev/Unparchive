#!/bin/zsh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
cd "$ROOT"

APP_NAME="Unparchive"
DIST="$ROOT/dist"
APP="$DIST/$APP_NAME.app"
CONTENTS="$APP/Contents"
MACOS="$CONTENTS/MacOS"
HELPERS="$CONTENTS/Helpers"
RESOURCES="$CONTENTS/Resources"

echo "==> Building $APP_NAME"
swift build -c release --product "$APP_NAME"

BIN="$(swift build -c release --product "$APP_NAME" --show-bin-path)/$APP_NAME"

rm -rf "$APP"
mkdir -p "$MACOS" "$HELPERS" "$RESOURCES"

cp "$BIN" "$MACOS/$APP_NAME"
cp "$ROOT/Resources/Info.plist" "$CONTENTS/Info.plist"
cp "$ROOT/Vendor/unrar/unrar" "$HELPERS/unrar"
cp "$ROOT/Vendor/unar/unar" "$HELPERS/unar"
cp "$ROOT/Vendor/unar/lsar" "$HELPERS/lsar"
cp "$ROOT/Vendor/unrar/unrar" "$MACOS/unrar"
cp "$ROOT/Vendor/unar/unar" "$MACOS/unar"
cp "$ROOT/Vendor/unar/lsar" "$MACOS/lsar"
chmod 755 "$MACOS/$APP_NAME" "$MACOS/unar" "$MACOS/lsar" "$MACOS/unrar" "$HELPERS/unrar" "$HELPERS/unar" "$HELPERS/lsar"

if [[ -f "$ROOT/Resources/AppIcon.icns" ]]; then
  cp "$ROOT/Resources/AppIcon.icns" "$RESOURCES/AppIcon.icns"
  /usr/libexec/PlistBuddy -c 'Add :CFBundleIconFile string AppIcon' "$CONTENTS/Info.plist" 2>/dev/null || true
fi

cat > "$CONTENTS/PkgInfo" <<'EOF'
APPLRTZP
EOF

xattr -cr "$APP"
codesign --force --deep --sign - "$APP"

echo "==> Built $APP"
echo "Cài đặt: cp -R \"$APP\" /Applications/"
echo "Dùng: double-click file .rar = giải nén tại chỗ; mở app Unparchive = cửa sổ chọn Convert/Extract"
echo "Gắn double-click: chuột phải file .rar → Open With → Unparchive → Change All"
