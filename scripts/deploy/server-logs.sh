#!/usr/bin/env bash
# server logs — container logs; optional call-id correlation grep (spec 14.2).
set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/lib/common.sh"

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
DEPLOY="$ROOT/deploy"
service="${1:-}"
call_id=""

shift 2>/dev/null || true
while [[ $# -gt 0 ]]; do
  case "$1" in
    --call-id) [ "$#" -ge 2 ] || fail_input "--call-id requires UUID"; call_id="$2"; shift 2 ;;
    *) shift ;;
  esac
done
case "$service" in edge|pbx|control) ;; *) fail_input "service must be edge, pbx or control" ;; esac
[ -n "$service" ] || fail_input "usage: ./smi server logs <edge|pbx|control> [--call-id UUID]"

config="$DEPLOY/site.env"
[ -f "$config" ] || fail_blocked "deploy/site.env missing"
source "$config"
compose_args=(--env-file "$config" -f "$DEPLOY/compose.yaml")
case "${SMI_TLS_MODE:-public}" in public) ;; internal) compose_args+=(-f "$DEPLOY/compose.lan.yaml") ;; *) fail_input "SMI_TLS_MODE must be public or internal" ;; esac

if [ -n "$call_id" ]; then
  set +e
  docker compose "${compose_args[@]}" logs --since 1h --no-log-prefix "$service" | grep -F -- "$call_id"
  statuses=("${PIPESTATUS[@]}")
  set -e
  [ "${statuses[0]}" -eq 0 ] || exit "${statuses[0]}"
  case "${statuses[1]}" in 0) ;; 1) warn "no log lines matched callId $call_id" ;; *) exit "${statuses[1]}" ;; esac
else
  exec docker compose "${compose_args[@]}" logs -f --tail 200 "$service"
fi
