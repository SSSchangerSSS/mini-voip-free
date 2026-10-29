#!/usr/bin/env bash
# verify-release — wrapper over verify_manifest.py (contract: ./smi verify-release)
set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/lib/common.sh"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
require_cmd python3
exec python3 "$ROOT/scripts/release/verify_manifest.py" "$@"
