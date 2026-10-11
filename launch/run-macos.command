#!/bin/bash
set -e
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
GODOT="${GODOT_BIN:-/Applications/Godot.app/Contents/MacOS/Godot}"
if [ ! -x "$GODOT" ]; then
  GODOT="$(command -v godot || command -v godot4 || true)"
fi
if [ -z "$GODOT" ] || [ ! -x "$GODOT" ]; then
  echo "Godot 4.7.2 not found. Set GODOT_BIN to the Godot executable."
  exit 1
fi

# Same modes as the Linux and Windows launchers. Anything after the mode goes
# to Godot as it is:  ./launch/run-macos.command flat -- --eli-link=on
MODE="auto"
case "${1:-}" in
  auto|xr|flat|compat) MODE="$1"; shift ;;
esac
case "$MODE" in
  xr)     exec "$GODOT" --path "$ROOT" --xr-mode on "$@" ;;
  flat)   exec "$GODOT" --path "$ROOT" --xr-mode off "$@" ;;
  compat) exec "$GODOT" --path "$ROOT" --rendering-method gl_compatibility "$@" ;;
  *)      exec "$GODOT" --path "$ROOT" "$@" ;;
esac
