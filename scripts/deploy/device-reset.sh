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
if command -v docker >/dev/null 2>&1 && docker image inspect mini-voip-free/control:0.1.0 >/dev/null 2>&1; then
  [ -f "$credential" ] || fail_input "credential file not found"
  extra=()
  $force && extra+=(--force)
  exec docker run --rm -i --network host \
    -e SMI_DB_PATH=/var/lib/smi/smi.db \
    -e SMI_PBX_CFG_DIR=/etc/asterisk \
    -e SMI_DOMAIN="$SMI_DOMAIN" \
    -v "$ROOT/deploy/data/control:/var/lib/smi" \
    -v "$ROOT/deploy/data/asterisk/config:/etc/asterisk" \
    mini-voip-free/control:0.1.0 device reset "$ext" \
    --credential-file /dev/stdin "${extra[@]}" < "$credential"
fi
require_cmd dotnet

cd "$ROOT/services/control"
export SMI_DB_PATH="${SMI_CONTROL_DB_PATH:-$ROOT/deploy/data/control/smi.db}"
export SMI_PBX_CFG_DIR="${SMI_CONTROL_PBX_CFG_DIR:-$ROOT/deploy/data/asterisk/config}"
export SMI_DOMAIN="$SMI_DOMAIN"

extra=()
$force && extra+=(--force)
dotnet run --project src/Smi.Control/Smi.Control.csproj -c Release -- device reset "$ext" --credential-file "$credential" "${extra[@]}"
