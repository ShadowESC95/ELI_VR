#!/usr/bin/env bash
set -Eeuo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
GODOT="${GODOT_BIN:-$(command -v godot || command -v godot4 || true)}"
[[ -n "$GODOT" ]] || { echo "Godot 4.7.2 not found. Set GODOT_BIN."; exit 1; }

# First word is the mode. Anything after it goes to Godot as it is, so
#   ./launch/run-linux.sh flat -- --eli-link=on
# switches the ELI link on for that run.
MODE="auto"
case "${1:-}" in
  auto|xr|flat|compat) MODE="$1"; shift ;;
esac
case "$MODE" in
  xr)
    cat >&2 <<'EOF'
ELI VR generic Linux XR uses the system default OpenXR runtime.
For Rift CV1 + native Monado use:
  ./launch/run-linux-cv1-headset-test.sh
EOF
    exec "$GODOT" --path "$ROOT" --xr-mode on "$@"
    ;;
  flat) exec "$GODOT" --path "$ROOT" --xr-mode off "$@" ;;
  compat) exec "$GODOT" --path "$ROOT" --rendering-method gl_compatibility "$@" ;;
  *) exec "$GODOT" --path "$ROOT" "$@" ;;
esac
