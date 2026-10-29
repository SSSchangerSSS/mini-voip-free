#!/usr/bin/env bash
# server init — validate config, prepare dirs/secrets mounts, render AMI manager file.
# Idempotent; never overwrites existing data or secrets (spec 14.1).
set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/lib/common.sh"

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
DEPLOY="$ROOT/deploy"

config=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --config) config="$2"; shift 2 ;;
    *) fail_input "unknown argument $1" ;;
  esac
done
[ -n "$config" ] || fail_input "usage: ./smi server init --config deploy/site.env"
[ -f "$config" ] || fail_input "config file not found: $config"
assert_no_placeholder "$config"

# shellcheck disable=SC1090
source "$config"
: "${SMI_DOMAIN:?SMI_DOMAIN required in site.env}" || true
[ -n "${SMI_DOMAIN:-}" ] || fail_input "SMI_DOMAIN missing in $config"

require_cmd docker
case "${SMI_TLS_MODE:-public}" in
  public) caddyfile="$ROOT/infra/caddy/Caddyfile" ;;
  internal) caddyfile="$ROOT/infra/caddy/Caddyfile.lan" ;;
  *) fail_input "SMI_TLS_MODE must be public or internal" ;;
esac

# ports must be free — the installer never kills existing services (spec 14.1)
if command -v ss >/dev/null 2>&1; then
  for p in 80 443 5038 8088; do
    if ss -ltn | awk '{print $4}' | grep -qE "[:.]$p$"; then
      fail_blocked "port $p is in use — free it or stop the conflicting service (install script refuses to kill services)"
    fi
  done
fi

# data directories (host-path bind mounts; ownership stays with the admin user)
for d in data/caddy/data data/caddy/config data/control data/asterisk/config/pjsip data/asterisk/lib data/asterisk/spool data/asterisk/logs data/asterisk/config/manager.d; do
  mkdir -p "$DEPLOY/$d"
done

# copy base PBX configs into the (possibly fresh) config volume — never overwrite an
# existing file so admin edits survive re-init
for f in asterisk.conf pjsip.conf extensions.conf http.conf manager.conf rtp.conf modules.conf; do
  src="$ROOT/infra/asterisk/conf/$f"; dst="$DEPLOY/data/asterisk/config/$f"
  if [ -f "$dst" ]; then
    warn "keep existing $f (idempotent init)"
  else
    cp "$src" "$dst"; ok "installed $f"
  fi
done
[ -f "$DEPLOY/data/asterisk/config/pjsip/accounts.conf" ] || \
  printf '; Accounts are provisioned with ./smi extension add\n' > "$DEPLOY/data/asterisk/config/pjsip/accounts.conf"

# AMI manager account from the secret file (600). Missing secret = hard block.
AMI_SECRET_FILE="$DEPLOY/secrets/ami"
[ -f "$AMI_SECRET_FILE" ] || fail_blocked "deploy/secrets/ami missing — create it first (see deploy/secrets/README.md)"
assert_no_placeholder "$AMI_SECRET_FILE"
umask 077
cat > "$DEPLOY/data/asterisk/config/manager.d/smi-control.conf" <<EOF
[smi-control]
secret = $(tr -d '\r\n' < "$AMI_SECRET_FILE")
read = system,call,user
write = call,config,message
eventfilter = Event: UserEvent
eventfilter = Event: Hangup
eventfilter = Event: DialBegin
eventfilter = Event: DialEnd
eventfilter = Event: BridgeEnter
eventfilter = Event: BridgeLeave
eventfilter = Event: VarSet
eventfilter = Variable: SMI_
EOF
chmod 600 "$DEPLOY/data/asterisk/config/manager.d/smi-control.conf"
ok "manager.d/smi-control.conf rendered from secret (value never printed)"

# optional push secrets: create empty mount targets only if absent so `docker compose`
# secret mounts resolve; control treats missing content as BLOCKED push (no fake success)
for s in apns.p8 fcm-service-account.json; do
  [ -f "$DEPLOY/secrets/$s" ] || { : > "$DEPLOY/secrets/$s"; chmod 600 "$DEPLOY/secrets/$s"; warn "created EMPTY $s — push stays BLOCKED until the employer secret is provided"; }
done

# validate Caddyfile with the pinned caddy image (real validation, no placeholder TLS claims)
if ! SMI_DOMAIN="$SMI_DOMAIN" docker run --rm \
  -v "$caddyfile:/etc/caddy/Caddyfile:ro" \
  -e SMI_DOMAIN="$SMI_DOMAIN" -e SMI_ACME_EMAIL="${SMI_ACME_EMAIL:-}" \
  caddy:2.11.7 caddy validate --config /etc/caddy/Caddyfile --adapter caddyfile >/dev/null; then
  fail_blocked "Caddy validation failed; check Docker access, image availability and configuration"
fi
ok "Caddyfile validated with caddy:2.11.7"

ok "server init complete for domain $SMI_DOMAIN — next: ./smi server up"
