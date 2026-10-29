#!/usr/bin/env bash
# build ios — requires macOS + Xcode; on other OSes fail LOUDLY (spec 13: no fake success).
set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/lib/common.sh"

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
MOBILE="$ROOT/apps/mobile"

if [ "$(uname -s)" != "Darwin" ]; then
  fail_blocked "iOS build requires macOS/Xcode (PROJECT_SPEC 16.3). Use a macOS machine/runner."
fi

require_cmd flutter
if [ ! -d "$MOBILE/ios" ]; then
  fail_blocked "apps/mobile/ios missing — run flutter create + overlay first (platform-overlay/README.md)"
fi

( cd "$MOBILE" && flutter pub get )
if [ "${1:-}" = "--release" ]; then
  ( cd "$MOBILE" && flutter build ipa --release )
  ok "IPA: $MOBILE/build/ios/archive — upload path per docs/IOS-RELEASE.fa.md"
else
  ( cd "$MOBILE" && flutter build ios --debug --no-codesign )
fi
