#!/usr/bin/env bash
# apply-platform-overlay.sh — copies native adapters over the flutter-create output.
# Run AFTER `flutter create` (first time only). Idempotent.
#
# Modes:
#   (default)                 full overlay incl. the FCM receiver. Requires the
#                             firebase_messaging dependency + google-services.json
#                             (PREFLIGHT B3) or the Kotlin build fails.
#   --android-no-push         same overlay WITHOUT the FCM receiver: the file
#                             SmiFirebaseMessagingService.kt is skipped and the
#                             MESSAGING_EVENT <service> block is stripped from the
#                             manifest. This is the mode the android-build workflow
#                             uses while B3 (Firebase project) is BLOCKED — the
#                             APK then honestly runs foreground-only incoming calls.
#                             Everything else (CallStyle FGS, Keystore store,
#                             event backlog) is identical.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
OVERLAY="$ROOT/apps/mobile/platform-overlay"
ANDROID_APP="$ROOT/apps/mobile/android/app"
IOS_RUNNER="$ROOT/apps/mobile/ios/Runner"
NO_PUSH=0
[ "${1:-}" = "--android-no-push" ] && NO_PUSH=1

[ -d "$ROOT/apps/mobile/android" ] || { echo "ERROR apps/mobile/android missing — run flutter create first (see platform-overlay/README.md)"; exit 2; }
[ -d "$ROOT/apps/mobile/ios" ] || { echo "ERROR apps/mobile/ios missing — run flutter create first"; exit 2; }

echo "Applying Android overlay… (no-push mode: $NO_PUSH)"
mkdir -p "$ANDROID_APP/src/main/kotlin/app/minivoipfree"
if [ "$NO_PUSH" = 1 ]; then
  for f in "$OVERLAY"/android/app/src/main/kotlin/app/minivoipfree/*.kt; do
    base="$(basename "$f")"
    [ "$base" = "SmiFirebaseMessagingService.kt" ] && continue
    cp -v "$f" "$ANDROID_APP/src/main/kotlin/app/minivoipfree/"
  done
  python3 - "$OVERLAY/android/app/src/main/AndroidManifest.xml" \
            "$ANDROID_APP/src/main/AndroidManifest.xml" <<'PY'
import re, sys
src, dst = sys.argv[1], sys.argv[2]
s = open(src).read()
s2 = re.sub(r'\n\s*<!-- Single FCM receiver.*?</service>', '', s, flags=re.S)
assert s2 != s, 'FCM service block not found in overlay manifest — manifest changed?'
open(dst, 'w').write(s2)
print('manifest written with FCM receiver stripped:', dst)
PY
else
  cp -v "$OVERLAY/android/app/src/main/AndroidManifest.xml" "$ANDROID_APP/src/main/AndroidManifest.xml"
  cp -v "$OVERLAY"/android/app/src/main/kotlin/app/minivoipfree/*.kt "$ANDROID_APP/src/main/kotlin/app/minivoipfree/"
fi

echo "Applying iOS overlay…"
cp -v "$OVERLAY/ios/Runner/AppDelegate.swift" "$IOS_RUNNER/AppDelegate.swift"
cp -v "$OVERLAY/ios/Runner/SmiCallProvider.swift" "$IOS_RUNNER/SmiCallProvider.swift"
cp -v "$OVERLAY/ios/Runner/Info.plist" "$IOS_RUNNER/Info.plist"
cp -v "$OVERLAY/ios/Runner/Runner.entitlements" "$IOS_RUNNER/Runner.entitlements"

echo "Overlay applied. Next: flutter pub get && flutter analyze"
echo "NOTE: android/app/build.gradle.kts needs google-services applied ONLY when"
echo "google-services.json exists (employer input B3) — see PREFLIGHT.md."
