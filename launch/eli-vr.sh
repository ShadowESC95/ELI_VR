#!/usr/bin/env bash
set -Eeuo pipefail

# ELI VR, the whole thing, on Linux: the desktop helper, the app, and a clean
# stop of everything this session started once the app closes.
#
#   ./launch/eli-vr.sh               use the system's OpenXR runtime, flat if none
#   ./launch/eli-vr.sh --monado      start native Monado first (Rift CV1 on Wayland)
#   ./launch/eli-vr.sh --eli         with the link to ELI v3
#   ./launch/eli-vr.sh --flat        no headset     (--xr forces one, --compat is OpenGL)
#   ./launch/eli-vr.sh --no-desktop  do not start the desktop helper
#   ./launch/eli-vr.sh --register-eli    put this copy on ELI v3's list of bundles
#   ./launch/eli-vr.sh --unregister-eli  and take it off again
#
# Anything else is handed on to the app.
#
# Options you always want can live in ~/.config/eli-vr/launch.conf, one line,
# for example:  --monado --eli
# That is how a double-clicked AppImage is told what to start.

ROOT="$(cd "$(dirname "$(readlink -f "$0")")/.." && pwd)"
# shellcheck source=launch/lib-session.sh
source "$ROOT/launch/lib-session.sh"

case "${1:-}" in
  --register-eli|--unregister-eli)
    command -v python3 >/dev/null || { echo "python3 is needed for this." >&2; exit 1; }
    # an AppImage registers the file itself, not where it happens to be mounted
    [[ -z "${APPIMAGE:-}" ]] || export ELI_VR_APP="$APPIMAGE"
    FLAG=(); [[ "$1" == "--register-eli" ]] || FLAG=(--remove)
    PYTHONDONTWRITEBYTECODE=1 exec python3 "$ROOT/tools/register_eli_bundle.py" "${FLAG[@]}"
    ;;
esac

MONADO="${ELI_VR_MONADO:-0}"
DESKTOP=1
MODE="auto"
REST=()

DEFAULTS=()
CONF="${XDG_CONFIG_HOME:-$HOME/.config}/eli-vr/launch.conf"
if [[ -f "$CONF" ]]; then
  # Plain words only: the file is split on spaces, never run.
  read -r -a DEFAULTS < <(grep -v '^[[:space:]]*#' "$CONF" | head -n 1) || true
fi

for arg in "${DEFAULTS[@]}" "$@"; do
  case "$arg" in
    --monado) MONADO=1 ;;
    --eli) REST+=("--eli-link=on") ;;
    --flat) MODE="flat" ;;
    --xr) MODE="xr" ;;
    --compat) MODE="compat" ;;
    --no-desktop) DESKTOP=0 ;;
    *) REST+=("$arg") ;;
  esac
done

STATE="$(eli_state_dir)"
mkdir -p "$STATE"
# Started from a file manager there is no terminal: keep the output anyway.
[[ -t 1 ]] || exec >>"$STATE/session.log" 2>&1

# Monado has its own launcher: it has to start the runtime, wait for it, and
# take it down again.
if [[ "$MONADO" == "1" ]]; then
  [[ "$DESKTOP" == "1" ]] || export ELI_VR_DESKTOP_CAPTURE=0
  exec "$ROOT/launch/run-linux-monado-cv1-reference.sh" "${REST[@]}"
fi

eli_app_command || { echo "Godot 4.7.2 not found. Set GODOT_BIN." >&2; exit 1; }
eli_split_args "${REST[@]}"
case "$MODE" in
  xr) ENGINE_ARGS=(--xr-mode on "${ENGINE_ARGS[@]}") ;;
  flat) ENGINE_ARGS=(--xr-mode off "${ENGINE_ARGS[@]}") ;;
  compat) ENGINE_ARGS=(--rendering-method gl_compatibility "${ENGINE_ARGS[@]}") ;;
esac

APP_PID=""
cleanup(){
  local rc=$?
  trap - EXIT INT TERM HUP
  if [[ -n "$APP_PID" ]] && kill -0 "$APP_PID" 2>/dev/null; then
    kill -TERM "$APP_PID" 2>/dev/null || true
    wait "$APP_PID" 2>/dev/null || true
  fi
  desktop_helper_stop
  vr_stop_started
  session_report
  exit "$rc"
}
vr_snapshot
trap cleanup EXIT INT TERM HUP

[[ "$DESKTOP" == "1" ]] && desktop_helper_start

set +e
"${APP[@]}" "${ENGINE_ARGS[@]}" -- "${USER_ARGS[@]}" &
APP_PID=$!
wait "$APP_PID"
APP_RC=$?
APP_PID=""
set -e
exit "$APP_RC"
