#!/usr/bin/env bash
# Explicit local QA launch; no privileged service is installed at system boot.
set -euo pipefail
source /home/changer/.config/mini-voip-free/env.sh
root=/home/changer/Desktop/flash/mini-voip-free
device=127.0.0.1:5565
if [ ! -d /sys/module/binder_linux ]; then
  # A desktop click after host reboot may need local OS authentication once.
  # Password entry belongs to PolicyKit; this script never reads the password.
  if [ -n "${DISPLAY:-}" ] && command -v pkexec >/dev/null 2>&1; then
    pkexec --disable-internal-agent /usr/bin/sh "$root/scripts/qa/enable-qa-binder.sh" || true
  fi
  if [ ! -d /sys/module/binder_linux ]; then
    echo "BLOCKED: load the existing Binder driver first: sudo sh $root/scripts/qa/enable-qa-binder.sh" >&2
    exit 3
  fi
fi
mkdir -p "$SMI_TOOLS_DIR/run"
exec 9> "$SMI_TOOLS_DIR/run/emulator-startup.lock"
flock -w 600 9 || { echo 'BLOCKED: another QA emulator is still starting' >&2; exit 3; }
sg docker -c "docker compose -f $root/qa/redroid-compose.yaml up -d android15"
ready=false
stable_pid=
stable_samples=0
for attempt in $(seq 1 90); do
  adb connect "$device" >/dev/null 2>&1 || true
  current_pid="$(timeout 5 adb -s "$device" shell pidof system_server 2>/dev/null | tr -d '\r' || true)"
  if [ -n "$current_pid" ] && [ "$(timeout 5 adb -s "$device" shell getprop sys.boot_completed 2>/dev/null | tr -d '\r')" = 1 ] && \
      timeout 5 adb -s "$device" shell am get-started-user-state 0 2>/dev/null | grep -q RUNNING_UNLOCKED && \
      timeout 5 adb -s "$device" shell pm path android 2>/dev/null | grep -q '^package:'; then
    if [ "$current_pid" = "$stable_pid" ]; then stable_samples=$((stable_samples + 1)); else stable_samples=1; stable_pid="$current_pid"; fi
    if [ "$stable_samples" -ge 3 ]; then ready=true; break; fi
  else
    stable_samples=0
  fi
  sleep 2
done
[ "$ready" = true ] || { echo 'BLOCKED: Android15 container boot did not complete' >&2; exit 3; }
[ "$(adb -s "$device" shell getprop ro.build.version.sdk | tr -d '\r')" = 35 ] || { echo 'FAIL: expected Android API35' >&2; exit 1; }
apk="$root/artifacts/android/mini-voip-free-192.168.1.151-startup-fix.apk"
[ -f "$apk" ] || { echo 'BLOCKED: local QA APK missing' >&2; exit 3; }
remote_apk="$(adb -s "$device" shell pm path app.minivoipfree 2>/dev/null | tr -d '\r' | sed -n 's/^package://p' | head -1)"
if [ -n "$remote_apk" ]; then
  local_hash="$(sha256sum "$apk" | cut -d ' ' -f1)"
  remote_hash="$(adb -s "$device" shell sha256sum "$remote_apk" | tr -d '\r' | cut -d ' ' -f1)"
  if [ "$local_hash" != "$remote_hash" ]; then
    echo 'BLOCKED: an APK update is pending; update explicitly while no call is active' >&2; exit 3
  fi
  echo 'Installed APK matches; preserving the running app and account'
else
  adb -s "$device" install -r -g "$apk"
fi
adb -s "$device" shell am start -n app.minivoipfree/.MainActivity
flock -u 9
exec 9>&-
echo 'QA Android15 boot/API/install/launch completed; account/UI/call validation is separate'
if pgrep -u "$(id -u)" -f "^$SMI_TOOLS_DIR/scrcpy-linux-x86_64-v5.0.1/scrcpy --serial=$device " >/dev/null; then exit 0; fi
export ADB="$ANDROID_HOME/platform-tools/adb"
exec "$SMI_TOOLS_DIR/scrcpy-linux-x86_64-v5.0.1/scrcpy" \
  --serial="$device" --no-audio --max-fps=10 --max-size=800 --video-bit-rate=1M \
  --render-driver=software --no-clipboard-autosync \
  --window-title='Mini VoIP | Android15 native QA' --window-width=360 --window-height=600 \
  --window-x=430 --window-y=60
