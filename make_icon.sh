#!/bin/zsh
set -euo pipefail

# Sinh Resources/AppIcon.icns từ một file PNG (khuyến nghị 1024x1024).
# Cách dùng: ./make_icon.sh <đường-dẫn-icon.png>

ROOT="$(cd "$(dirname "$0")" && pwd)"
SRC="${1:-}"

if [[ -z "$SRC" ]]; then
  echo "Cách dùng: ./make_icon.sh <đường-dẫn-icon.png>"
  echo "Gợi ý xuất từ Figma: PNG, kích thước 1024 x 1024, không nén (lossless)."
  exit 1
fi

if [[ ! -f "$SRC" ]]; then
  echo "Không tìm thấy file: $SRC"
  exit 1
fi

# Đường dẫn tuyệt đối của ảnh gốc
SRC_ABS="$(cd "$(dirname "$SRC")" && pwd)/$(basename "$SRC")"

TMP="$(mktemp -d)"
ICONSET="$TMP/AppIcon.iconset"
mkdir -p "$ICONSET"

# Các kích thước macOS cần (iconutil)
sips -z 16   16   "$SRC_ABS" --out "$ICONSET/icon_16x16.png"       >/dev/null
sips -z 32   32   "$SRC_ABS" --out "$ICONSET/icon_16x16@2x.png"    >/dev/null
sips -z 32   32   "$SRC_ABS" --out "$ICONSET/icon_32x32.png"       >/dev/null
sips -z 64   64   "$SRC_ABS" --out "$ICONSET/icon_32x32@2x.png"    >/dev/null
sips -z 128  128  "$SRC_ABS" --out "$ICONSET/icon_128x128.png"     >/dev/null
sips -z 256  256  "$SRC_ABS" --out "$ICONSET/icon_128x128@2x.png"  >/dev/null
sips -z 256  256  "$SRC_ABS" --out "$ICONSET/icon_256x256.png"     >/dev/null
sips -z 512  512  "$SRC_ABS" --out "$ICONSET/icon_256x256@2x.png"  >/dev/null
sips -z 512  512  "$SRC_ABS" --out "$ICONSET/icon_512x512.png"     >/dev/null
sips -z 1024 1024 "$SRC_ABS" --out "$ICONSET/icon_512x512@2x.png"  >/dev/null

iconutil -c icns "$ICONSET" -o "$ROOT/Resources/AppIcon.icns"

rm -rf "$TMP"

echo "Đã tạo: $ROOT/Resources/AppIcon.icns"
echo "Build lại để nhúng icon: ./build.sh"
