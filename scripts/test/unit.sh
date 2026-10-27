#!/usr/bin/env bash
# unit tests that exist TODAY — each one actually runs (no skipped/faked suites).
set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/lib/common.sh"

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
JSON_OUT=false
[ "${1:-}" = "--json" ] && JSON_OUT=true

results=()
fail=0

run_dotnet_tests() {
  require_cmd dotnet
  log "dotnet test (Control: state machine, slots, auth endpoints, crypto, normalization)"
  if (cd "$ROOT/services/control" && dotnet test tests/Smi.Control.Tests/Smi.Control.Tests.csproj -c Release --nologo); then
    results+=('{"suite":"control-api","status":"PASS"}')
  else
    results+=('{"suite":"control-api","status":"FAIL"}'); fail=1
  fi
}

run_flutter_tests() {
  if command -v flutter >/dev/null 2>&1; then
    log "flutter test (mobile: normalization, event queue, wire models)"
    if (cd "$ROOT/apps/mobile" && flutter test); then
      results+=('{"suite":"mobile-unit","status":"PASS"}')
    else
      results+=('{"suite":"mobile-unit","status":"FAIL"}'); fail=1
    fi
  else
    # BLOCKED is honest: flutter SDK missing on this machine
    results+=('{"suite":"mobile-unit","status":"BLOCKED","reason":"flutter SDK not in PATH"}')
    warn "flutter SDK not found — mobile unit tests NOT_RUN here (CI runs them)"
  fi
}

run_contract_validation() {
  require_cmd python3
  log "contract validation"
  if python3 "$ROOT/scripts/checks/validate-contracts.py"; then
    results+=('{"suite":"contracts","status":"PASS"}')
  else
    results+=('{"suite":"contracts","status":"FAIL"}'); fail=1
  fi
}

run_dotnet_tests
run_flutter_tests
run_contract_validation

if $JSON_OUT; then
  json_out "{\"suites\":[$(IFS=,; echo "${results[*]}")],\"exit\":$fail}"
fi
exit $fail
