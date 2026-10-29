#!/usr/bin/env bash
# extension add/disable — delegates to the Control CLI (single source of account truth).
# The password comes from a credential FILE, never the command line (spec 13).
set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/lib/common.sh"

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
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

[ -n "$ext" ] || fail_input "extension required"
if [ "$action" = "add" ] && [ -z "$credential" ]; then
  fail_input "--credential-file is required (passwords never on the command line)"
fi

# site.env provides SMI_DOMAIN + paths for provisioning (non-secret config)
site="$ROOT/deploy/site.env"
[ -f "$site" ] || fail_blocked "deploy/site.env missing — run ./smi server init first"
# shellcheck disable=SC1090
source "$site"

# CLI execution mode: host dotnet when present, otherwise the SAME CLI inside the
# already-built control image (spec 11.2 — CLI is a mode of the Control program).
# On a deployed VPS there is no host .NET SDK by design.
cli_mode=""
if command -v docker >/dev/null 2>&1 && docker image inspect mini-voip-free/control:0.1.0 >/dev/null 2>&1; then
  cli_mode="docker"
elif command -v dotnet >/dev/null 2>&1; then
  cli_mode="dotnet"
else
  fail_blocked "no Control CLI available: host has neither dotnet nor the built image mini-voip-free/control:0.1.0 (run ./smi server up first)"
fi

if [ "$cli_mode" = "dotnet" ]; then
  cd "$ROOT/services/control"
  export SMI_DB_PATH="${SMI_CONTROL_DB_PATH:-$ROOT/deploy/data/control/smi.db}"
  export SMI_PBX_CFG_DIR="${SMI_CONTROL_PBX_CFG_DIR:-$ROOT/deploy/data/asterisk/config}"
  export SMI_DOMAIN="$SMI_DOMAIN"

  args=()
  [ -n "$credential" ] && args+=(--credential-file "$credential")
  dotnet run --project src/Smi.Control/Smi.Control.csproj -c Release -- $cli_verb "$ext" "${args[@]:-}"
else
  # Pass credentials through private stdin; never create a world-readable copy.
  cred_options=()
  credential_input=/dev/null
  if [ -n "$credential" ]; then
    [ -f "$credential" ] || fail_input "credential file not found"
    credential_input="$credential"
    cred_options=(--credential-file /dev/stdin)
  fi
  docker run --rm -i --network host \
    -e SMI_DB_PATH=/var/lib/smi/smi.db \
    -e SMI_PBX_CFG_DIR=/etc/asterisk \
    -e SMI_DOMAIN="$SMI_DOMAIN" \
    -v "$ROOT/deploy/data/control:/var/lib/smi" \
    -v "$ROOT/deploy/data/asterisk/config:/etc/asterisk" \
    mini-voip-free/control:0.1.0 $cli_verb "$ext" "${cred_options[@]}" < "$credential_input"
fi
