#!/usr/bin/env bash
set -euo pipefail
source /home/changer/.config/mini-voip-free/env.sh
api="${1:-26}"
case "$api" in 26) port=5554; label='Android 8 | 101'; pos=30; gpu=swiftshader; memory=1536; cores=2 ;; 35) port=5556; label='Android 15 | 102'; pos=430; gpu=swiftshader; memory=2560; cores=1 ;; *) echo 'Use 26 or 35'; exit 2 ;; esac
device="emulator-$port"
log="$SMI_TOOLS_DIR/logs/emulator-api$api.log"
state_dir="$SMI_TOOLS_DIR/run"
mkdir -p "$state_dir"
engine_state="$state_dir/emulator-api$api.pid"
# The native Qt display avoids MediaCodec encoding inside the slow TCG guest.
# Each engine owns a process group, so shutdown cleanup cannot touch another AVD.
if [ "${SMI_QA_ENGINE:-0}" = 1 ]; then
  printf '%s\n' "$$" > "$engine_state"
  set +e
  env QT_QPA_PLATFORM=xcb ANDROID_I_WANT_MY_TCG=yes "$ANDROID_HOME/emulator/emulator" \
    -avd "mini-voip-api$api" -port "$port" -accel off -gpu "$gpu" \
    -feature -Vulkan -no-audio -no-snapshot -no-boot-anim -no-metrics \
    -memory "$memory" -cores "$cores" -scale 0.75
  engine_exit=$?
  own_group="$(ps -o pgid= -p "$$" | tr -d ' ')"
  # A shutdown has left a one-thread QEMU helper consuming a CPU here before.
  # Only reap QEMU processes in THIS engine's now-finished process group.
  for signal in TERM KILL; do
    leftovers="$(pgrep -g "$own_group" -f '^/.*/qemu-system-' || true)"
    if [ -n "$leftovers" ]; then
      echo "QA_ENGINE cleanup owned leftover QEMU after exit=$engine_exit"
      kill -"$signal" $leftovers 2>/dev/null || true
      sleep 1
    fi
  done
  rm -f "$engine_state"
  exit "$engine_exit"
fi
# Avoid two expensive cold boots competing inside the same four-vCPU VM.
# The engine must not inherit this startup lock; resident AVDs run together.
exec 9> "$state_dir/emulator-startup.lock"
if ! flock -w 600 9; then echo 'BLOCKED: another emulator startup did not finish' >&2; exit 3; fi
if ! adb -s "$device" get-state >/dev/null 2>&1; then
  engine_alive=false
  if [ -f "$engine_state" ]; then
    read -r engine_pid < "$engine_state"
    if [[ "$engine_pid" =~ ^[0-9]+$ ]] && kill -0 "$engine_pid" 2>/dev/null; then engine_alive=true; fi
  fi
  if pgrep -u "$(id -u)" -f "^/.*/qemu-system-.* -avd mini-voip-api$api " >/dev/null; then engine_alive=true; fi
  if [ "$engine_alive" = false ]; then
    nohup setsid env SMI_QA_ENGINE=1 "$(realpath "$0")" "$api" > "$log" 2>&1 < /dev/null 9>&- &
  fi
fi
network_checked=false
for attempt in $(seq 1 180); do
  if [ "$(timeout 8 adb -s "$device" shell getprop sys.boot_completed 2>/dev/null | tr -d '\r')" = 1 ] && timeout 8 adb -s "$device" shell pm path app.minivoipfree 2>/dev/null | grep -q '^package:'; then
    if ! timeout 8 adb -s "$device" shell am get-started-user-state 0 2>/dev/null | grep -q RUNNING_UNLOCKED; then sleep 2; continue; fi
    # A connected virtual Wi-Fi can have DHCP addresses but no installed IPv4
    # default route after a guest reboot. Do not start the app into that fault.
    if [ "$network_checked" = false ]; then
      has_route() { timeout 8 adb -s "$device" shell ip -4 route show table all 2>/dev/null | grep -q '^default via '; }
      for route_wait in $(seq 1 10); do has_route && break; sleep 2; done
      if ! has_route; then
        echo "QA_NETWORK missing IPv4 default route; reconnecting emulator Wi-Fi once"
        timeout 20 adb -s "$device" shell svc wifi disable || exit 3
        sleep 2
        timeout 20 adb -s "$device" shell svc wifi enable || exit 3
        for route_wait in $(seq 1 30); do has_route && break; sleep 2; done
        if ! has_route; then
          echo "BLOCKED emulator IPv4 route unavailable after Wi-Fi reconnect" >&2
          exit 3
        fi
      fi
      echo "QA_NETWORK IPv4 default route ready"
      network_checked=true
    fi
    if ! launch_output=$(timeout 20 adb -s "$device" shell am start -n app.minivoipfree/.MainActivity 2>&1); then sleep 2; continue; fi
    if printf '%s' "$launch_output" | grep -qE 'Error|Exception'; then sleep 2; continue; fi
    printf '%s\n' "$launch_output"
    echo "PASS QA emulator/API$api booted with IPv4 route; app launch accepted; native display (no scrcpy encoder)"
    exit 0
  fi
  sleep 2
done
echo "BLOCKED emulator boot did not finish; inspect $log" >&2
exit 3
