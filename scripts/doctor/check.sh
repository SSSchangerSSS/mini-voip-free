#!/usr/bin/env bash
# check — static checks that run today (bash syntax, contracts, yaml sanity).
set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/lib/common.sh"

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
fail=0

# bash syntax over all scripts
while IFS= read -r f; do
  if bash -n "$f" 2>/dev/null; then
    ok "bash syntax: ${f#$ROOT/}"
  else
    fail=1; fail "bash syntax: ${f#$ROOT/}"
  fi
done < <(find "$ROOT/scripts" -name '*.sh' ! -path '*/node_modules/*')

# contracts
require_cmd python3
python3 "$ROOT/scripts/checks/validate-contracts.py" || fail=1

# yaml parse (compose + workflows) via python
python3 - <<'EOF' || fail=1
import glob, sys
try:
    import yaml
except ImportError:
    print("WARN pyyaml not installed — yaml validation skipped here (CI validates)")
    sys.exit(0)
files = glob.glob("deploy/*.yaml") + glob.glob(".github/workflows/*.yml")
bad = False
for f in files:
    try:
        with open(f) as fh:
            yaml.safe_load(fh)
        print(f"PASS yaml: {f}")
    except Exception as e:
        print(f"FAIL yaml: {f}: {e}")
        bad = True
sys.exit(1 if bad else 0)
EOF

exit $fail
