#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck source=launch/lib-session.sh
source "$ROOT/launch/lib-session.sh"
BIN="$ROOT/native/desktop_bridge/target/release/eli-vr-desktop-bridge"
# ELI_VR_DESKTOP_INPUT=0 shows the desktop and never moves the pointer or clicks.
NO_INPUT=()
[[ "${ELI_VR_DESKTOP_INPUT:-1}" == "0" ]] && NO_INPUT=(--no-input)


# Wayland: capture through the desktop portal + PipeWire. It asks once which
# screen to share and remembers the answer.
if [[ "${XDG_SESSION_TYPE:-}" == "wayland" && "${ELI_VR_ALLOW_LEGACY_WAYLAND_CAPTURE:-0}" != "1" ]]; then
  PORTAL="$ROOT/native/desktop_portal_bridge/eli_portal_bridge.py"
  if ! wayland_capture_ready; then
    echo "Wayland capture dependencies are missing. Run: ./tools/install-linux-wayland-capture-deps.sh" >&2
    exit 1
  fi
  exec python3 "$PORTAL" \
    --width "${ELI_VR_CAPTURE_WIDTH:-0}" \
    --fps "${ELI_VR_CAPTURE_FPS:-18}" \
    ${NO_INPUT[@]+"${NO_INPUT[@]}"}
fi

[[ -x "$BIN" ]] || {
  echo "Bridge not built. Run native/desktop_bridge/build-linux.sh"
  exit 1
}

exec "$BIN" \
  --fps "${ELI_VR_CAPTURE_FPS:-15}" \
  --width "${ELI_VR_CAPTURE_WIDTH:-0}" \
  ${NO_INPUT[@]+"${NO_INPUT[@]}"}
