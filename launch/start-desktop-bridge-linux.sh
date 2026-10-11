#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BIN="$ROOT/native/desktop_bridge/target/release/eli-vr-desktop-bridge"


# Wayland: capture through the desktop portal + PipeWire. It asks once which
# screen to share and remembers the answer.
if [[ "${XDG_SESSION_TYPE:-}" == "wayland" && "${ELI_VR_ALLOW_LEGACY_WAYLAND_CAPTURE:-0}" != "1" ]]; then
  PORTAL="$ROOT/native/desktop_portal_bridge/eli_portal_bridge.py"
  if ! python3 -c 'import dbus, gi; gi.require_version("Gst","1.0"); from gi.repository import Gst; Gst.init(None); assert Gst.ElementFactory.find("pipewiresrc")' >/dev/null 2>&1; then
    echo "Wayland capture dependencies are missing. Run: ./tools/install-linux-wayland-capture-deps.sh" >&2
    exit 1
  fi
  exec python3 "$PORTAL" \
    --width "${ELI_VR_CAPTURE_WIDTH:-1280}" \
    --fps "${ELI_VR_CAPTURE_FPS:-18}"
fi

[[ -x "$BIN" ]] || {
  echo "Bridge not built. Run native/desktop_bridge/build-linux.sh"
  exit 1
}

exec "$BIN" \
  --fps "${ELI_VR_CAPTURE_FPS:-15}" \
  --width "${ELI_VR_CAPTURE_WIDTH:-1600}" \
  --quality "${ELI_VR_CAPTURE_QUALITY:-72}"
