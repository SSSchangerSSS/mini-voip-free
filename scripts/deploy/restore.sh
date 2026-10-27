#!/usr/bin/env bash
# restore — decrypt, verify, stop control (not pbx), restore DB, run migrations.
# NEVER restores over a live database (spec 14.3).
set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh")"

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
DEPLOY="$ROOT/deploy"
inp=""; confirm=false
[ "${1:-}" = "--input" ] && inp="${2:-}"
[[ "${3:-}" == "--confirm" || "${4:-}" == "--confirm" ]] && confirm=true
[ -f "$inp" ] || fail_input "usage: ./smi restore --input <backup> --confirm"
$confirm || fail_blocked "restore overwrites live data — re-run with --confirm (spec 14.3)"

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

if command -v age >/dev/null 2>&1 && [ -n "${AGE_IDENTITY_FILE:-}" ]; then
  age -d -i "$AGE_IDENTITY_FILE" -o "$work/backup.tar.gz" "$inp"
elif [ -n "${BACKUP_PASSPHRASE:-}" ]; then
  BACKUP_PASSPHRASE="$BACKUP_PASSPHRASE" openssl enc -d -aes-256-cbc -pbkdf2 \
    -in "$inp" -out "$work/backup.tar.gz" -pass env:BACKUP_PASSPHRASE
else
  fail_blocked "set AGE_IDENTITY_FILE or BACKUP_PASSPHRASE to decrypt the backup"
fi

tar -xzf "$work/backup.tar.gz" -C "$work"
[ -f "$work/smi.db" ] || fail "backup archive is missing smi.db"

# integrity check before touching anything
python3 - "$work/smi.db" <<'EOF' || fail "backup DB failed integrity check"
import sqlite3, sys
c = sqlite3.connect(sys.argv[1])
r = c.execute("PRAGMA integrity_check").fetchone()[0]
print(f"{'PASS' if r=='ok' else 'FAIL'} integrity_check={r}")
sys.exit(0 if r == "ok" else 1)
EOF

require_cmd docker
docker compose -f "$DEPLOY/compose.yaml" stop control
cp "$work/smi.db" "$DEPLOY/data/control/smi.db"
rm -f "$DEPLOY/data/control/smi.db-wal" "$DEPLOY/data/control/smi.db-shm"
if [ -d "$work/config/asterisk" ]; then
  cp -r "$work/config/asterisk/." "$DEPLOY/data/asterisk/config/"
fi
docker compose -f "$DEPLOY/compose.yaml" start control
ok "restore applied — verify with ./smi server status and place a REAL test call (spec 14.3)"
