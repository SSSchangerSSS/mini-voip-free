#!/usr/bin/env bash
# server up — idempotent stack start; never rewrites data or keys (spec 14.1).
set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/lib/common.sh"

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
DEPLOY="$ROOT/deploy"
config=""
[ "${1:-}" = "--config" ] && config="${2:-}"
[ -f "$config" ] || config="$DEPLOY/site.env"
[ -f "$config" ] || fail_input "site env not found: deploy/site.env (run ./smi server init first)"
require_cmd docker
config="$(realpath "$config")"
source "$config"
compose_args=(--env-file "$config" -f "$DEPLOY/compose.yaml")
case "${SMI_TLS_MODE:-public}" in
  public) ;;
  internal) compose_args+=(-f "$DEPLOY/compose.lan.yaml") ;;
  *) fail_input "SMI_TLS_MODE must be public or internal" ;;
esac
docker compose "${compose_args[@]}" build
# Bind mounts hide packaged Asterisk documentation and keys on a fresh host.
# Seed missing files only; preserve runtime DB, keys and administrator changes.
docker run --rm --user 0:0 \
  -v "$DEPLOY/data/asterisk/lib:/seed" \
  --entrypoint sh mini-voip-free/pbx:22.11.0 \
  -c 'cp -an /var/lib/asterisk/. /seed/ && chown -R 1001:1001 /seed'
( cd "$DEPLOY" && docker compose "${compose_args[@]}" up -d --no-build )
ok "compose stack started (edge/pbx/control)"
log "readiness: curl http://127.0.0.1:5080/health/ready — 200 only after AMI reconcile"
