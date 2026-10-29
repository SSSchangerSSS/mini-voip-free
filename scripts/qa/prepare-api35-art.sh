#!/usr/bin/env bash
# One-time ART preparation for the owned software-emulated Android15 QA AVD.
set -euo pipefail
source /home/changer/.config/mini-voip-free/env.sh
device="${1:-emulator-5556}"
[[ "$device" =~ ^emulator-[0-9]+$ ]] || { echo 'BLOCKED: emulator serial required' >&2; exit 3; }
[[ "$(adb -s "$device" shell getprop ro.build.version.sdk | tr -d '\r')" == 35 ]] || { echo 'BLOCKED: API35 required' >&2; exit 3; }
[[ "$(adb -s "$device" shell getprop ro.boot.qemu | tr -d '\r')" == 1 ]] || { echo 'BLOCKED: QEMU guest required' >&2; exit 3; }
if adb -s "$device" shell pidof dex2oat64 2>/dev/null | grep -q '[0-9]'; then
  echo 'BLOCKED: another ART compiler is active; wait for it before rerunning' >&2
  exit 3
fi
log_dir="$SMI_TOOLS_DIR/logs/api35-art-$(date -u +%Y%m%dT%H%M%SZ)"
mkdir -p "$log_dir"
for package in com.android.systemui com.android.launcher3; do
  echo "Compiling $package; evidence $log_dir"
  timeout 1200 adb -s "$device" shell cmd package compile -m speed "$package" > "$log_dir/$package-compile.txt" 2>&1
  # Some Android shell commands print Failure but return0. Validate artifacts too.
  if ! grep -qx 'Success' <(tr -d '\r' < "$log_dir/$package-compile.txt"); then
    echo "FAIL: compiler did not report Success for $package" >&2; exit 1
  fi
  adb -s "$device" shell pm art dump "$package" > "$log_dir/$package-art.txt"
  if ! grep -qF '[status=speed]' "$log_dir/$package-art.txt"; then
    echo "FAIL: speed artifact missing for $package" >&2; exit 1
  fi
  echo "PASS: $package has speed artifacts"
done
