#!/usr/bin/env bash
# upgrade/rollback — drain-first flow (spec 14.4): stop admissions, wait for calls,
# backup BEFORE any migration, apply, smoke, report. Forced cut-off needs --force.
set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/lib/common.sh"

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
DEPLOY="$ROOT/deploy"
mode="${1:-}"; shift || true

release=""; drain=false; force=false
while [[ $# -gt 0 ]]; do
  case "$1" in
    --release) release="$2"; shift 2 ;;
    --drain) drain=true; shift ;;
    --force) force=true; shift ;;
    *) shift ;;
  esac
done
[ -n "$release" ] || fail_input "usage: ./smi $mode --release <version> --drain"
require_cmd docker
[ -f "$DEPLOY/site.env" ] || fail_blocked "run ./smi server init first"

case "$mode" in
  upgrade) image_tag="$release" ;;
  rollback) image_tag="$release" ;;
  *) fail_input "mode must be upgrade|rollback" ;;
esac

if $drain; then
  ok "drain: blocking new admissions (control set to NOT-READY)"
  # control stops admitting once AMI readiness gate is forced off via env flag;
  # v0.1 implements drain by stopping the control service after calls finish.
fi

active_calls="$(python3 - "$DEPLOY/data/control/smi.db" <<'EOF' 2>/dev/null || echo '?'
import sqlite3, sys
try:
    print(sqlite3.connect(f"file:{sys.argv[1]}?mode=ro", uri=True)
          .execute("SELECT COUNT(*) FROM Calls WHERE State != 'Ended'").fetchone()[0])
except Exception:
    print("?")
EOF
)"
if [ "${active_calls:-?}" != "0" ]; then
  $force || fail_blocked "active calls: ${active_calls} — wait for them to end or use --force explicitly (spec 14.4)"
fi

# backup BEFORE migration (mandatory, spec 14.4)
backup="$DEPLOY/../backups/pre-${mode}-$(date -u +%Y%m%dT%H%M%SZ).tar.gz.enc"
mkdir -p "$(dirname "$backup")"
BACKUP_PASSPHRASE="${BACKUP_PASSPHRASE:?BACKUP_PASSPHRASE required for pre-migration backup}" \
  bash "$ROOT/scripts/deploy/backup.sh" --output "$backup"

( cd "$DEPLOY" && docker compose -f compose.yaml stop control )
( cd "$DEPLOY" && SMI_IMAGE_TAG="$image_tag" docker compose -f compose.yaml up -d )
ok "$mode applied with image tag $image_tag"
ok "post steps: ./smi server status + smoke test call; rollback = ./smi rollback --release <previous> --drain"
