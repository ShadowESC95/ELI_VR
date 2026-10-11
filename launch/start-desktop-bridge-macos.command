#!/bin/bash
set -e
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BIN="$ROOT/native/desktop_bridge/target/release/eli-vr-desktop-bridge"

if [ ! -x "$BIN" ]; then
  echo "Bridge not built. Run native/desktop_bridge/build-macos.sh"
  exit 1
fi

# macOS asks for Screen Recording permission the first time the bridge captures.
exec "$BIN" \
  --fps "${ELI_VR_CAPTURE_FPS:-15}" \
  --width "${ELI_VR_CAPTURE_WIDTH:-1600}" \
  --quality "${ELI_VR_CAPTURE_QUALITY:-72}"
