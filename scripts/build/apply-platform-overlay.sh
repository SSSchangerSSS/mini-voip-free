#!/usr/bin/env bash
# apply-platform-overlay.sh — copies native adapters over the flutter-create output.
# Run AFTER `flutter create` (first time only). Idempotent.
#
# Android uses direct private-PBX reception; no Firebase SDK/config is required.
# --android-no-push remains accepted for older build workflows.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
OVERLAY="$ROOT/apps/mobile/platform-overlay"
ANDROID_APP="$ROOT/apps/mobile/android/app"
IOS_RUNNER="$ROOT/apps/mobile/ios/Runner"
NO_PUSH=0
[ "${1:-}" = "--android-no-push" ] && NO_PUSH=1

[ -d "$ROOT/apps/mobile/android" ] || { echo "ERROR apps/mobile/android missing — run flutter create first (see platform-overlay/README.md)"; exit 2; }

echo "Applying Android overlay… (no-push mode: $NO_PUSH)"
mkdir -p "$ANDROID_APP/src/main/kotlin/app/minivoipfree"
cp -v "$OVERLAY/android/app/src/main/AndroidManifest.xml" "$ANDROID_APP/src/main/AndroidManifest.xml"
cp -v "$OVERLAY"/android/app/src/main/kotlin/app/minivoipfree/*.kt "$ANDROID_APP/src/main/kotlin/app/minivoipfree/"
rm -f "$ANDROID_APP/src/main/kotlin/app/minivoipfree/SmiFirebaseMessagingService.kt" "$ANDROID_APP/src/main/kotlin/app/minivoipfree/SmiPush.kt" "$ANDROID_APP/smi-push-disabled"

if [ -d "$IOS_RUNNER" ]; then
  echo "Applying iOS overlay…"
  cp -v "$OVERLAY/ios/Runner/AppDelegate.swift" "$IOS_RUNNER/AppDelegate.swift"
  cp -v "$OVERLAY/ios/Runner/SmiCallProvider.swift" "$IOS_RUNNER/SmiCallProvider.swift"
  cp -v "$OVERLAY/ios/Runner/Info.plist" "$IOS_RUNNER/Info.plist"
  cp -v "$OVERLAY/ios/Runner/Runner.entitlements" "$IOS_RUNNER/Runner.entitlements"
else
  echo "NOT_RUN iOS overlay: iOS platform has not been generated (Android build is independent)"
fi

echo "Overlay applied. Next: flutter pub get && flutter analyze"
echo "Android direct incoming standby installed; no Google account or Firebase configuration required."
