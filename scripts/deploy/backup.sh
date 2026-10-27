#!/usr/bin/env bash
# backup — SQLite via the online backup API (WAL-safe) + config snapshot, then
# encrypted with age/openssl using a key INDEPENDENT of the data (spec 14.3).
set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh")"

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
DEPLOY="$ROOT/deploy"
out=""
[ "${1:-}" = "--output" ] && out="${2:-}"
[ -n "$out" ] || fail_input "usage: ./smi backup --output <secure-path>"
case "$out" in /*) ;; *) out="$PWD/$out" ;; esac

db="$DEPLOY/data/control/smi.db"
[ -f "$db" ] || fail_blocked "control database not found at $db — is the stack initialized?"

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

# SQLite .backup (consistent under WAL) — a plain file copy of a live WAL db is NOT safe
python3 - "$db" "$work/smi.db" <<'EOF'
import sqlite3, sys
src, dst = sys.argv[1], sys.argv[2]
s = sqlite3.connect(f"file:{src}?mode=ro", uri=True)
d = sqlite3.connect(dst)
s.backup(d)
d.close(); s.close()
print(f"PASS sqlite backup: {dst}")
EOF

# config snapshot (non-secret) + secret manifest (names only, never values)
mkdir -p "$work/config"
cp -r "$DEPLOY/data/asterisk/config" "$work/config/asterisk" 2>/dev/null || true
[ -f "$DEPLOY/site.env" ] && cp "$DEPLOY/site.env" "$work/config/site.env"
: > "$work/config/secrets.manifest"
for s in ami apns.p8 fcm-service-account.json; do
  [ -f "$DEPLOY/secrets/$s" ] && echo "$s present" >> "$work/config/secrets.manifest"
done
db_version="$(python3 -c "import sqlite3;print(sqlite3.connect('$work/smi.db').execute('SELECT MAX(Version) FROM SchemaMigrations').fetchone()[0])")"
echo "schema_version=$db_version" > "$work/config/db-state.txt"

tar -czf "$work/backup.tar.gz" -C "$work" smi.db config

# encryption with an operator-supplied key (AGE_RECIPIENT or BACKUP_PASSPHRASE env)
if [ -n "${AGE_RECIPIENT:-}" ] && command -v age >/dev/null 2>&1; then
  age -r "$AGE_RECIPIENT" -o "$out" "$work/backup.tar.gz"
  ok "backup written (age-encrypted): $out"
elif [ -n "${BACKUP_PASSPHRASE:-}" ]; then
  BACKUP_PASSPHRASE="$BACKUP_PASSPHRASE" openssl enc -aes-256-cbc -pbkdf2 -salt \
    -in "$work/backup.tar.gz" -out "$out" -pass env:BACKUP_PASSPHRASE
  ok "backup written (openssl-encrypted): $out"
else
  fail_blocked "set AGE_RECIPIENT or BACKUP_PASSPHRASE — unencrypted backups of sensitive data are forbidden (spec 14.3)"
fi
sha256sum "$out" | tee "$out.sha256"
ok "IMPORTANT: keep the encryption key OUTSIDE this server (spec 14.3)"
