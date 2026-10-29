#!/usr/bin/env bash
# device reset — rotate generation/tokens/SIP secret via the Control CLI.
set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/lib/common.sh"

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
ext="${1:-}"; shift || true

credential=""; force=false
while [[ $# -gt 0 ]]; do
  case "$1" in
    --credential-file) credential="$2"; shift 2 ;;
    --force) force=true; shift ;;
    *) shift ;;
  esac
done
[ -n "$ext" ] && [ -n "$credential" ] || fail_input "usage: ./smi device reset <ext> --credential-file <file> [--force]"

site="$ROOT/deploy/site.env"
[ -f "$site" ] || fail_blocked "deploy/site.env missing — run ./smi server init first"
# shellcheck disable=SC1090
source "$site"
require_cmd dotnet

cd "$ROOT/services/control"
export SMI_DB_PATH="${SMI_CONTROL_DB_PATH:-$ROOT/deploy/data/control/smi.db}"
export SMI_PBX_CFG_DIR="${SMI_CONTROL_PBX_CFG_DIR:-$ROOT/deploy/data/asterisk/config}"
export SMI_DOMAIN="$SMI_DOMAIN"

extra=()
$force && extra+=(--force)
dotnet run --project src/Smi.Control/Smi.Control.csproj -c Release -- device reset "$ext" --credential-file "$credential" "${extra[@]}"
