#!/usr/bin/env bash
# extension add/disable — delegates to the Control CLI (single source of account truth).
# The password comes from a credential FILE, never the command line (spec 13).
set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh")"

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
action="${1:-}"; ext="${2:-}"; shift 2 2>/dev/null || true

case "$action" in
  add) cli_verb="extensions add" ;;
  disable) cli_verb="extensions disable" ;;
  *) fail_input "usage: ./smi extension add|disable <ext> --credential-file <file>" ;;
esac

credential=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --credential-file) credential="$2"; shift 2 ;;
    *) shift ;;
  esac
done

require_cmd dotnet
[ -n "$ext" ] || fail_input "extension required"
if [ "$action" = "add" ] && [ -z "$credential" ]; then
  fail_input "--credential-file is required (passwords never on the command line)"
fi

# site.env provides SMI_DOMAIN + paths for provisioning (non-secret config)
site="$ROOT/deploy/site.env"
[ -f "$site" ] || fail_blocked "deploy/site.env missing — run ./smi server init first"
# shellcheck disable=SC1090
source "$site"

cd "$ROOT/services/control"
export SMI_DB_PATH="${SMI_CONTROL_DB_PATH:-$ROOT/deploy/data/control/smi.db}"
export SMI_PBX_CFG_DIR="${SMI_CONTROL_PBX_CFG_DIR:-$ROOT/deploy/data/asterisk/config}"
export SMI_DOMAIN="$SMI_DOMAIN"

args=()
[ -n "$credential" ] && args+=(--credential-file "$credential")
dotnet run --project src/Smi.Control/Smi.Control.csproj -c Release -- $cli_verb "$ext" "${args[@]:-}"
