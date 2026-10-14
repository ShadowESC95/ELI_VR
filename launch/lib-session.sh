# Shared by the Linux launchers. Sourced, never run on its own.
# Expects ROOT to be the folder that holds launch/.

# Every process a VR runtime leaves holding the GPU.
VR_PROCESS_NAMES=(monado-service vrserver vrcompositor vrmonitor vrwebhelper vrdashboard vrstartup)

APP=()
ENGINE_ARGS=()
USER_ARGS=()
VR_BEFORE=" "
VR_SNAPSHOT_TAKEN=0
GPU_BEFORE=""
HELPER_PID=""

eli_state_dir(){ printf '%s' "${XDG_STATE_HOME:-$HOME/.local/state}/eli-vr-standalone"; }

# An exported build beside launch/ runs by itself. A source checkout runs
# through Godot.
eli_app_command(){
  if [[ -x "$ROOT/ELI-VR.x86_64" ]]; then
    APP=("$ROOT/ELI-VR.x86_64")
    return 0
  fi
  local godot="${GODOT_BIN:-$(command -v godot || command -v godot4 || true)}"
  [[ -n "$godot" ]] || return 1
  APP=("$godot" --path "$ROOT")
}

# --eli-... options are for the app. Everything else is for the engine.
eli_split_args(){
  local arg
  for arg in "$@"; do
    case "$arg" in
      --) ;;
      --eli-*) USER_ARGS+=("$arg") ;;
      *) ENGINE_ARGS+=("$arg") ;;
    esac
  done
}

vr_pids(){
  local name
  for name in "${VR_PROCESS_NAMES[@]}"; do
    pgrep -x "$name" 2>/dev/null || true
  done
}

# Remember which VR runtime processes were already there. They are not ours.
vr_snapshot(){
  VR_BEFORE=" $(vr_pids | tr '\n' ' ')"
  GPU_BEFORE="$(gpu_used_mib)"
  VR_SNAPSHOT_TAKEN=1
}

# Stop every VR runtime process that appeared since the snapshot, so nothing
# this session started is left holding GPU memory.
vr_stop_started(){
  # Without a snapshot there is no telling what is ours, so touch nothing.
  [[ "$VR_SNAPSHOT_TAKEN" == "1" ]] || return 0
  local pid alive started=()
  for pid in $(vr_pids); do
    [[ "$VR_BEFORE" == *" $pid "* ]] || started+=("$pid")
  done
  ((${#started[@]})) || return 0

  printf '\n==> Stopping the VR runtime this session started: %s\n' \
    "$(ps -o comm= -p "${started[@]}" 2>/dev/null | sort -u | tr '\n' ' ')"
  kill -TERM "${started[@]}" 2>/dev/null || true
  for _ in $(seq 1 25); do
    alive=0
    for pid in "${started[@]}"; do
      kill -0 "$pid" 2>/dev/null && alive=1
    done
    ((alive)) || break
    sleep 0.2
  done
  for pid in "${started[@]}"; do
    kill -0 "$pid" 2>/dev/null && kill -KILL "$pid" 2>/dev/null
  done

  # A killed Monado leaves its socket behind and the next start trips on it.
  if ! pgrep -x monado-service >/dev/null 2>&1; then
    rm -f "${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/monado_comp_ipc" 2>/dev/null || true
  fi
}

gpu_used_mib(){
  command -v nvidia-smi >/dev/null 2>&1 || return 0
  nvidia-smi --query-gpu=memory.used --format=csv,noheader,nounits 2>/dev/null | head -n1 | tr -d ' '
}

# Say what is left, so a held GPU is seen and not assumed.
session_report(){
  [[ "$VR_SNAPSHOT_TAKEN" == "1" ]] || return 0
  local left now
  left="$(for pid in $(vr_pids); do [[ "$VR_BEFORE" == *" $pid "* ]] || ps -o comm= -p "$pid"; done 2>/dev/null | tr '\n' ' ')"
  if [[ -n "$left" ]]; then
    printf '\nWARNING: still running after shutdown: %s\n' "$left" >&2
  else
    printf '\n==> VR runtime stopped. Nothing from this session is left running.\n'
  fi
  now="$(gpu_used_mib)"
  if [[ -n "$GPU_BEFORE" && -n "$now" ]]; then
    printf '==> GPU memory in use: %s MiB before, %s MiB now\n' "$GPU_BEFORE" "$now"
  fi
}

# The helper that feeds the desktop screen. Wayland goes through the desktop
# portal, X11 uses the native helper.
desktop_helper_start(){
  local log
  log="$(eli_state_dir)/desktop-bridge.log"
  if [[ "${XDG_SESSION_TYPE:-}" == "wayland" ]]; then
    if ! python3 -c 'import dbus, gi; gi.require_version("Gst","1.0"); from gi.repository import Gst; Gst.init(None); assert Gst.ElementFactory.find("pipewiresrc")' >/dev/null 2>&1; then
      printf '\nWARNING: desktop screen off: Wayland capture pieces are missing. See docs/INSTALL.md.\n' >&2
      return 0
    fi
    PYTHONUNBUFFERED=1 python3 "$ROOT/native/desktop_portal_bridge/eli_portal_bridge.py" \
      --width "${ELI_VR_CAPTURE_WIDTH:-1280}" --fps "${ELI_VR_CAPTURE_FPS:-18}" \
      --token-file "$(eli_state_dir)/portal-restore-token" >"$log" 2>&1 &
    HELPER_PID=$!
    desktop_share_wait "$log" "$HELPER_PID"
  else
    local bin="$ROOT/native/desktop_bridge/target/release/eli-vr-desktop-bridge"
    if [[ ! -x "$bin" ]]; then
      printf '\nWARNING: desktop screen off: the desktop helper is not built.\n' >&2
      return 0
    fi
    "$bin" --fps "${ELI_VR_CAPTURE_FPS:-15}" --width "${ELI_VR_CAPTURE_WIDTH:-1600}" \
      --quality "${ELI_VR_CAPTURE_QUALITY:-72}" >"$log" 2>&1 &
    HELPER_PID=$!
  fi
}

# The first time, the desktop asks which screen to share. Wait for that answer
# before the headset starts, so the question is not left unseen on the monitor.
# The choice is remembered, and later sessions start sharing without asking.
desktop_share_wait(){
  local log="$1" pid="$2" limit=8
  if [[ ! -s "$(eli_state_dir)/portal-restore-token" ]]; then
    limit="${ELI_VR_SHARE_WAIT:-120}"
    printf '\n==> Choose the screen to show in VR in the dialog on your monitor (asked once).\n'
  fi
  for _ in $(seq 1 "$((limit * 5))"); do
    kill -0 "$pid" 2>/dev/null || return 0
    grep -qE 'capture streaming|rejected|cancelled|no PipeWire|fatal|GStreamer error' "$log" 2>/dev/null && return 0
    sleep 0.2
  done
}

desktop_helper_stop(){
  if [[ -n "$HELPER_PID" ]] && kill -0 "$HELPER_PID" 2>/dev/null; then
    kill -TERM "$HELPER_PID" 2>/dev/null || true
    wait "$HELPER_PID" 2>/dev/null || true
  fi
  HELPER_PID=""
}
