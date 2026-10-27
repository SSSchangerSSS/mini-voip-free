#!/usr/bin/env bash
# build android — Release APK (arm64-v8a) via Flutter with locked toolchain.
set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh")"

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
MOBILE="$ROOT/apps/mobile"
release=false
[[ "${1:-}" == android ]] && shift
[ "${1:-}" = "--release" ] && release=true

require_cmd flutter
if [ ! -d "$MOBILE/android" ]; then
  fail_blocked "apps/mobile/android missing — run: flutter create --org app --project-name smi_phone apps/mobile && ./scripts/build/apply-platform-overlay.sh"
fi

( cd "$MOBILE" && flutter pub get )
if $release; then
  ( cd "$MOBILE" && flutter build apk --release --split-per-abi --target-platform android-arm64 )
  ok "APK: $MOBILE/build/app/outputs/flutter-apk/app-arm64-v8a-release.apk"
  [ -f "$MOBILE/build/app/outputs/flutter-apk/app-arm64-v8a-release.apk" ] && \
    sha256sum "$MOBILE/build/app/outputs/flutter-apk/app-arm64-v8a-release.apk"
  warn "signing: release keystore must come from the employer (PREFLIGHT B6); unsigned release will not install"
else
  ( cd "$MOBILE" && flutter build apk --debug )
fi
