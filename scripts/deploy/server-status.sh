#!/usr/bin/env bash
# server status — control readiness + container states (no secrets printed).
set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh")"

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
DEPLOY="$ROOT/deploy"
require_cmd docker

docker compose -f "$DEPLOY/compose.yaml" ps --format '{{.Name}}\t{{.State}}\t{{.Status}}' 2>/dev/null || true

if command -v curl >/dev/null 2>&1; then
  live="$(curl -s -o /dev/null -w '%{http_code}' --max-time 3 http://127.0.0.1:5080/health/live || true)"
  ready="$(curl -s --max-time 3 http://127.0.0.1:5080/health/ready || true)"
  ok "control /health/live -> ${live:-unreachable}"
  ok "control /health/ready -> ${ready:-unreachable}"
fi
