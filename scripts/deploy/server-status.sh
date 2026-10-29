#!/usr/bin/env bash
# server status — control readiness + container states (no secrets printed).
set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/lib/common.sh"

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
DEPLOY="$ROOT/deploy"
require_cmd docker

config="$DEPLOY/site.env"
[ -f "$config" ] || fail_blocked "site configuration missing"
source "$config"
compose_args=(--env-file "$config" -f "$DEPLOY/compose.yaml")
[ "${SMI_TLS_MODE:-public}" != internal ] || compose_args+=(-f "$DEPLOY/compose.lan.yaml")
docker compose "${compose_args[@]}" ps --format '{{.Name}}\t{{.State}}\t{{.Status}}' || fail_blocked "cannot query Compose state"

require_cmd curl
for endpoint in live ready; do
  code="$(curl -s -o /dev/null -w '%{http_code}' --max-time 3 "http://127.0.0.1:5080/health/$endpoint" || true)"
  [ "$code" = 200 ] || fail_blocked "control /health/$endpoint -> ${code:-unreachable}"
  ok "control /health/$endpoint -> 200"
done
