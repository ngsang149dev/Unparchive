#!/bin/zsh
set -euo pipefail

# Đóng gói dist/RarToZip.app thành dist/RarToZip.dmg CÓ background + icon sắp xếp.
# Cách dùng: ./make_dmg.sh
#   - Có `dmgbuild` trong PATH  -> dùng dmgbuild (không cần cấp quyền Finder).
#   - Không có                 -> hdiutil + AppleScript (macOS sẽ hỏi cho phép
#                                 Terminal điều khiển Finder ở lần đầu).
#   - AppleScript bị từ chối   -> vẫn tạo DMG thường (không có layout).

ROOT="$(cd "$(dirname "$0")" && pwd)"
APP="$ROOT/dist/RarToZip.app"
DMG="$ROOT/dist/RarToZip.dmg"
BG="$ROOT/Resources/dmg-background.png"

if [[ ! -d "$APP" ]]; then
  echo "Chưa có app. Chạy ./build.sh trước."
  exit 1
fi
rm -f "$DMG"

# ---------- 1) dmgbuild (nếu có) ----------
if command -v dmgbuild >/dev/null 2>&1; then
  echo "==> Tạo DMG (dmgbuild)"
  SETTINGS="$(mktemp)"
  cat > "$SETTINGS" <<EOF
files = ['$APP']
symlinks = {'Applications': '/Applications'}
icon_locations = {'RarToZip.app': (160, 180), 'Applications': (480, 180)}
background = '$BG'
window_rect = ((240, 240), (640, 428))
default_view = 'icon-view'
icon_size = 96
show_status_bar = False
show_tab_view = False
show_toolbar = False
show_sidebar = False
show_pathbar = False
EOF
  dmgbuild -s "$SETTINGS" "RarToZip" "$DMG"
  rm -f "$SETTINGS"
  echo "Đã tạo: $DMG"
  ls -lh "$DMG"
  exit 0
fi

# ---------- 2) hdiutil + AppleScript ----------
echo "==> Tạo DMG (hdiutil + Finder layout)"
WORK="$(mktemp -d)"
RW="$WORK/RarToZip-rw.dmg"
MNT="$WORK/mnt"
mkdir -p "$MNT"

hdiutil create -size 120m -fs HFS+ -volname "RarToZip" -ov "$RW" >/dev/null
hdiutil attach "$RW" -nobrowse -mountpoint "$MNT" >/dev/null

cp -R "$APP" "$MNT/RarToZip.app"
ln -s /Applications "$MNT/Applications"
mkdir -p "$MNT/.background"
cp "$BG" "$MNT/.background/background.png"

if ! osascript <<'APPLESCRIPT'
tell application "Finder"
  tell disk "RarToZip"
    open
    set current view of container window to icon view
    set toolbar visible of container window to false
    set statusbar visible of container window to false
    set the bounds of container window to {240, 240, 880, 668}
    set viewOptions to the icon view options of container window
    set arrangement of viewOptions to not arranged
    set icon size of viewOptions to 96
    set background picture of viewOptions to file ".background:background.png"
    set position of item "RarToZip.app" of container window to {160, 180}
    set position of item "Applications" of container window to {480, 180}
    close
    open
    update without registering applications
    delay 1
  end tell
end tell
APPLESCRIPT
then
  echo "CẢNH BÁO: không đặt được layout (cần cấp quyền điều khiển Finder). DMG vẫn được tạo."
fi

sync
hdiutil detach "$MNT" >/dev/null 2>&1 || hdiutil detach "$MNT" -force >/dev/null 2>&1 || true

hdiutil convert "$RW" -format UDZO -o "$DMG" >/dev/null
rm -rf "$WORK"

echo "Đã tạo: $DMG"
ls -lh "$DMG"
