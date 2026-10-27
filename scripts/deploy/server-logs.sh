#!/usr/bin/env bash
# server logs — container logs; optional call-id correlation grep (spec 14.2).
set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh")"

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
DEPLOY="$ROOT/deploy"
service="${1:-}"
call_id=""

shift 2>/dev/null || true
while [[ $# -gt 0 ]]; do
  case "$1" in
    --call-id) call_id="$2"; shift 2 ;;
    *) shift ;;
  esac
done
[ -n "$service" ] || fail_input "usage: ./smi server logs <edge|pbx|control> [--call-id UUID]"

if [ -n "$call_id" ]; then
  docker compose -f "$DEPLOY/compose.yaml" logs --since 1h --no-log-prefix "$service" | grep -F "$call_id" || warn "no log lines matched callId $call_id"
else
  exec docker compose -f "$DEPLOY/compose.yaml" logs -f --tail 200 "$service"
fi
