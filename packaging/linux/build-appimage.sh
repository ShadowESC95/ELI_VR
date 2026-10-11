#!/usr/bin/env bash
set -Eeuo pipefail

# Wrap an unpacked Linux package in an AppImage.
#
#   packaging/linux/build-appimage.sh <linux package folder> <output.AppImage>
#
# The package folder is what the release workflow assembles: the exported
# build with launch/, native/ and tools/ beside it.

[[ $# -eq 2 ]] || { echo "usage: $0 <linux package folder> <output.AppImage>" >&2; exit 2; }
HERE="$(cd "$(dirname "$0")" && pwd)"
PKG="$(readlink -f "$1")"
OUT="$(readlink -f "$(dirname "$2")")/$(basename "$2")"
[[ -x "$PKG/ELI-VR.x86_64" && -f "$PKG/launch/eli-vr.sh" ]] || {
  echo "not a Linux package folder: $PKG" >&2; exit 1; }

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
APPDIR="$WORK/ELI_VR.AppDir"
mkdir -p "$APPDIR/usr/share"
cp -a "$PKG" "$APPDIR/usr/share/eli-vr"
install -m 755 "$HERE/AppRun" "$APPDIR/AppRun"
cp "$HERE/eli-vr.desktop" "$APPDIR/eli-vr.desktop"
cp "$PKG/icon.svg" "$APPDIR/eli-vr.svg"
ln -s eli-vr.svg "$APPDIR/.DirIcon"

# appimagetool: one on PATH, else download it.
TOOL="$(command -v appimagetool || true)"
if [[ -z "$TOOL" ]]; then
  TOOL="$WORK/appimagetool-x86_64.AppImage"
  echo "[appimage] downloading appimagetool"
  curl -fL --retry 5 --retry-all-errors -o "$TOOL" \
    "https://github.com/AppImage/appimagetool/releases/download/continuous/appimagetool-x86_64.AppImage" \
  || curl -fL --retry 5 -o "$TOOL" \
    "https://github.com/AppImage/AppImageKit/releases/download/13/appimagetool-x86_64.AppImage"
  chmod +x "$TOOL"
fi

# The tool is itself an AppImage; unpack-and-run needs no FUSE on a build box.
ARCH=x86_64 APPIMAGE_EXTRACT_AND_RUN=1 "$TOOL" --no-appstream "$APPDIR" "$OUT"
chmod +x "$OUT"
ls -la "$OUT"
