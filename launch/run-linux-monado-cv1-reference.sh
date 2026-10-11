#!/usr/bin/env bash
set -Eeuo pipefail

# ELI VR reference launcher for Ubuntu/Wayland + native Monado + Rift CV1.
#
# Portable ELI VR core remains OpenXR-based. This script is only the adapter
# for one specific stack (Wayland + native Monado + Rift CV1). Other headsets
# and runtimes should use ./launch/run-linux.sh xr.
#
# IMPORTANT:
# - WayVR is NOT used.
# - SteamVR is NOT used.
# - Legacy Wayland desktop capture is disabled by default.
# - Desktop surface UI remains available; live capture requires a safe provider.
# - Monado receives the known-good stdin FIFO workaround.
# - Godot is run as a child so Monado is cleaned up on exit.

ROOT="$(cd "$(dirname "$(readlink -f "$0")")/.." && pwd)"
# shellcheck source=launch/lib-session.sh
source "$ROOT/launch/lib-session.sh"
STATE="${XDG_STATE_HOME:-$HOME/.local/state}/eli-vr-standalone"
FIFO="$STATE/monado.stdin.fifo"
MONADO_LOG="$STATE/monado.log"
GODOT_LOG="$STATE/godot-xr.log"
BRIDGE_LOG="$STATE/desktop-bridge.log"
IPC="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/monado_comp_ipc"

mkdir -p "$STATE"

say(){ printf '\n==> %s\n' "$*"; }
warn(){ printf '\nWARNING: %s\n' "$*" >&2; }
die(){ printf '\nERROR: %s\n' "$*" >&2; exit 1; }

[[ "${XDG_SESSION_TYPE:-}" == "wayland" ]] || \
  warn "Reference CV1 launcher was validated for a Wayland session; current session is ${XDG_SESSION_TYPE:-unknown}."

# Running SteamVR and native Monado against the same CV1 is unsafe/unreliable.
if pgrep -x vrserver >/dev/null 2>&1 || pgrep -x vrcompositor >/dev/null 2>&1; then
  die "SteamVR is running. Stop SteamVR before starting native Monado."
fi

eli_app_command || die "Godot 4.7.2 not found. Set GODOT_BIN=/path/to/Godot."
eli_split_args "$@"

MONADO="$(command -v monado-service || true)"
if [[ -z "$MONADO" ]]; then
  for candidate in \
    "$HOME/.local/bin/monado-service" \
    /usr/local/bin/monado-service \
    /usr/bin/monado-service; do
    [[ -x "$candidate" ]] && MONADO="$candidate" && break
  done
fi
[[ -n "$MONADO" ]] || die "monado-service not found."

MANIFEST="${XR_RUNTIME_JSON:-}"
if [[ -z "$MANIFEST" || ! -f "$MANIFEST" ]]; then
  for candidate in \
    /usr/local/share/openxr/1/openxr_monado.json \
    /usr/share/openxr/1/openxr_monado.json \
    "$HOME/.local/share/openxr/1/openxr_monado.json"; do
    if [[ -f "$candidate" ]]; then
      MANIFEST="$candidate"
      break
    fi
  done
fi
[[ -n "$MANIFEST" && -f "$MANIFEST" ]] || \
  die "Monado OpenXR runtime JSON not found. Set XR_RUNTIME_JSON=/path/to/openxr_monado.json."

GODOT_PID=""
MONADO_PID=""
BRIDGE_PID=""

cleanup(){
  local rc=$?
  trap - EXIT INT TERM HUP

  if [[ -n "$GODOT_PID" ]] && kill -0 "$GODOT_PID" 2>/dev/null; then
    kill -TERM "$GODOT_PID" 2>/dev/null || true
    wait "$GODOT_PID" 2>/dev/null || true
  fi

  if [[ -n "$BRIDGE_PID" ]] && kill -0 "$BRIDGE_PID" 2>/dev/null; then
    kill -TERM "$BRIDGE_PID" 2>/dev/null || true
    wait "$BRIDGE_PID" 2>/dev/null || true
  fi

  if [[ -n "$MONADO_PID" ]] && kill -0 "$MONADO_PID" 2>/dev/null; then
    kill -TERM "$MONADO_PID" 2>/dev/null || true
    for _ in $(seq 1 15); do
      kill -0 "$MONADO_PID" 2>/dev/null || break
      sleep 0.2
    done
    if kill -0 "$MONADO_PID" 2>/dev/null; then
      kill -KILL "$MONADO_PID" 2>/dev/null || true
    fi
    wait "$MONADO_PID" 2>/dev/null || true
  fi

  # Nothing this session started may be left holding the GPU.
  vr_stop_started
  rm -f "$IPC" "$FIFO" 2>/dev/null || true
  session_report
  exit "$rc"
}
trap cleanup EXIT INT TERM HUP

# Stop only stale ELI VR capture and Monado processes.
# The capture process is deliberately stopped because the current Wayland
# backend is not suitable for headset validation.
pkill -TERM -f "$ROOT/native/desktop_bridge/target/release/eli-vr-desktop-bridge" 2>/dev/null || true
pkill -TERM -f "$ROOT/native/desktop_portal_bridge/eli_portal_bridge.py" 2>/dev/null || true
pkill -TERM -x monado-service 2>/dev/null || true
sleep 1
if pgrep -x monado-service >/dev/null 2>&1; then
  pkill -KILL -x monado-service 2>/dev/null || true
fi

rm -f "$IPC" "$FIFO" 2>/dev/null || true
vr_snapshot

# The pinned native Monado build epolls stdin when not socket-activated.
# A FIFO avoids the /dev/null -> epoll_ctl failure seen on this CV1 stack.
mkfifo "$FIFO"
exec 9<>"$FIFO"

say "Starting native Monado Rift CV1 runtime"
say "OpenXR manifest: $MANIFEST"

: > "$MONADO_LOG"
env \
  XRT_COMPOSITOR_FORCE_WAYLAND_DIRECT=1 \
  XRT_COMPOSITOR_LOG=info \
  RIFT_LOG=info \
  RIFT_EYE_HEIGHT="${RIFT_EYE_HEIGHT:-1.6}" \
  "$MONADO" <&9 9>&- >"$MONADO_LOG" 2>&1 &
MONADO_PID=$!
exec 9>&-

ready=0
for _ in $(seq 1 45); do
  if ! kill -0 "$MONADO_PID" 2>/dev/null; then
    tail -n 180 "$MONADO_LOG" || true
    die "Monado exited during startup."
  fi

  if [[ -S "$IPC" ]] || grep -q 'Started vblank event thread' "$MONADO_LOG" 2>/dev/null; then
    ready=1
    break
  fi
  sleep 1
done

if [[ "$ready" -ne 1 ]]; then
  tail -n 180 "$MONADO_LOG" || true
  die "Monado did not become ready."
fi

say "Monado ready"
grep -E 'Opened [0-9]+ Rift Sensor cameras|Opened Rift Sensor|HMD|vblank|ERROR|WARN' \
  "$MONADO_LOG" 2>/dev/null | tail -n 40 || true

# Desktop capture adapter. Wayland uses the XDG ScreenCast portal + PipeWire
# provider so permission is session-oriented instead of screenshot polling.
if [[ "${XDG_SESSION_TYPE:-}" == "wayland" && "${ELI_VR_DESKTOP_CAPTURE:-1}" != "0" ]]; then
  PORTAL_BRIDGE="$ROOT/native/desktop_portal_bridge/eli_portal_bridge.py"
  if python3 -c 'import dbus, gi; gi.require_version("Gst","1.0"); from gi.repository import Gst; Gst.init(None); assert Gst.ElementFactory.find("pipewiresrc")' >/dev/null 2>&1; then
    say "Starting XDG Portal + PipeWire desktop capture"
    PYTHONUNBUFFERED=1 python3 "$PORTAL_BRIDGE" \
      --width "${ELI_VR_CAPTURE_WIDTH:-1280}" \
      --fps "${ELI_VR_CAPTURE_FPS:-18}" \
      >"$BRIDGE_LOG" 2>&1 &
    BRIDGE_PID=$!

    bridge_ready=0
    for _ in $(seq 1 40); do
      if ! kill -0 "$BRIDGE_PID" 2>/dev/null; then
        break
      fi
      if command -v ss >/dev/null 2>&1 && ss -H -ltn 2>/dev/null | grep -q '127.0.0.1:47831'; then
        bridge_ready=1
        break
      fi
      sleep 0.1
    done
    if [[ "$bridge_ready" -eq 1 ]]; then
      say "Desktop capture adapter listening; choose a screen/window if GNOME asks"
      tail -n 8 "$BRIDGE_LOG" 2>/dev/null || true
    else
      warn "Desktop capture adapter did not open 127.0.0.1:47831."
      tail -n 40 "$BRIDGE_LOG" 2>/dev/null || true
    fi
  else
    warn "Wayland desktop capture dependencies are missing."
    warn "Run: ./tools/install-linux-wayland-capture-deps.sh"
  fi
elif [[ "${ELI_VR_START_DESKTOP_BRIDGE:-0}" == "1" ]]; then
  BRIDGE="$ROOT/native/desktop_bridge/target/release/eli-vr-desktop-bridge"
  if [[ -x "$BRIDGE" ]]; then
    say "Starting legacy/X11 desktop bridge"
    "$BRIDGE" --fps "${ELI_VR_CAPTURE_FPS:-15}" --width "${ELI_VR_CAPTURE_WIDTH:-1280}" --quality "${ELI_VR_CAPTURE_QUALITY:-72}" >"$BRIDGE_LOG" 2>&1 &
    BRIDGE_PID=$!
  else
    warn "Legacy desktop bridge requested but binary is not built."
  fi
else
  say "Desktop capture provider not started; XR desktop surface remains available"
fi

say "Starting ELI VR on native Monado OpenXR"
say "Godot log: $GODOT_LOG"

: > "$GODOT_LOG"
set +e
env XR_RUNTIME_JSON="$MANIFEST" \
  "${APP[@]}" \
    --xr-mode on \
    --log-file "$GODOT_LOG" \
    "${ENGINE_ARGS[@]}" \
    -- \
    --eli-xr=on "${USER_ARGS[@]}" &
GODOT_PID=$!

wait "$GODOT_PID"
GODOT_RC=$?
GODOT_PID=""
set -e

if [[ "$GODOT_RC" -ne 0 ]]; then
  warn "Godot exited with status $GODOT_RC"
  echo
  echo "----- Godot XR log (tail) -----"
  tail -n 160 "$GODOT_LOG" 2>/dev/null || true
  echo
  echo "----- Monado log (tail) -----"
  tail -n 160 "$MONADO_LOG" 2>/dev/null || true
fi

exit "$GODOT_RC"
