#!/usr/bin/env bash
set -euo pipefail
STATE="${XDG_STATE_HOME:-$HOME/.local/state}/eli-vr-standalone"
LOG="$STATE/desktop-bridge.log"
echo "==> ELI VR Wayland desktop capture check"
if pgrep -f 'native/desktop_portal_bridge/eli_portal_bridge.py' >/dev/null 2>&1; then
  echo "portal bridge process: running"
else
  echo "portal bridge process: NOT RUNNING"
fi
if command -v ss >/dev/null 2>&1 && ss -H -ltn 2>/dev/null | grep -q '127.0.0.1:47831'; then
  echo "loopback frame server: listening on 127.0.0.1:47831"
else
  echo "loopback frame server: NOT LISTENING"
fi
echo
echo "----- desktop bridge log -----"
tail -n 80 "$LOG" 2>/dev/null || echo "No log yet: $LOG"
