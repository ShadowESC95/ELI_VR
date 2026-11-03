#!/bin/bash
set -e
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BIN="$ROOT/native/desktop_bridge/target/release/eli-vr-desktop-bridge"

if [ ! -x "$BIN" ]; then
  echo "Bridge not built. Run native/desktop_bridge/build-macos.sh"
  exit 1
fi

# macOS asks for Screen Recording permission the first time the bridge captures, and for
# Accessibility the first time ELI VR clicks on the desktop. ELI_VR_DESKTOP_INPUT=0 shows the
# desktop and never moves the pointer or clicks.
NO_INPUT=()
[ "${ELI_VR_DESKTOP_INPUT:-1}" = "0" ] && NO_INPUT=(--no-input)
exec "$BIN" \
  --fps "${ELI_VR_CAPTURE_FPS:-15}" \
  --width "${ELI_VR_CAPTURE_WIDTH:-0}" \
  "${NO_INPUT[@]}"
