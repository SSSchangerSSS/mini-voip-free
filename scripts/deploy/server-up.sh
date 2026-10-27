#!/usr/bin/env bash
# server up — idempotent stack start; never rewrites data or keys (spec 14.1).
set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh")"

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
DEPLOY="$ROOT/deploy"
config=""
[ "${1:-}" = "--config" ] && config="${2:-}"
[ -f "$config" ] || config="$DEPLOY/site.env"
[ -f "$config" ] || fail_input "site env not found: deploy/site.env (run ./smi server init first)"
require_cmd docker

( cd "$DEPLOY" && docker compose --env-file "$(basename "$config")" -f compose.yaml up -d )
ok "compose stack started (edge/pbx/control)"
log "readiness: curl http://127.0.0.1:5080/health/ready — 200 only after AMI reconcile"
