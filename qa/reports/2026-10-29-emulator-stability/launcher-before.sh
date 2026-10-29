#!/usr/bin/env bash
set -euo pipefail
source /home/changer/.config/mini-voip-free/env.sh
api="${1:-26}"
case "$api" in 26) port=5554; label='Android 8 | 101'; pos=30; gpu=swiftshader; memory=1536 ;; 35) port=5556; label='Android 15 | 102'; pos=430; gpu=swiftshader_indirect; memory=2048 ;; *) echo 'Use 26 or 35'; exit 2 ;; esac
device="emulator-$port"
log="$SMI_TOOLS_DIR/logs/emulator-api$api.log"
if ! adb -s "$device" get-state >/dev/null 2>&1; then
  nohup env ANDROID_I_WANT_MY_TCG=yes "$ANDROID_HOME/emulator/emulator" \
    -avd "mini-voip-api$api" -port "$port" -accel off -gpu "$gpu" \
    -no-window -no-audio -no-snapshot -no-boot-anim -no-metrics -memory "$memory" \
    > "$log" 2>&1 < /dev/null &
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
    if pgrep -u "$(id -u)" -f "^$SMI_TOOLS_DIR/scrcpy-linux-x86_64-v5.0.1/scrcpy --serial=$device " >/dev/null; then
      echo "Display already running for $device"
      exit 0
    fi
    export ADB="$ANDROID_HOME/platform-tools/adb"
    exec "$SMI_TOOLS_DIR/scrcpy-linux-x86_64-v5.0.1/scrcpy" \
      --serial="$device" --no-audio --max-fps=2 --video-bit-rate=1M \
      --render-driver=software --no-clipboard-autosync \
      --window-title="Mini VoIP | $label" --window-width=360 --window-height=600 \
      --window-x="$pos" --window-y=60
  fi
  sleep 2
done
echo "BLOCKED emulator boot did not finish; inspect $log" >&2
exit 3
