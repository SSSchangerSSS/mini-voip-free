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

# CLI execution mode: host dotnet when present, otherwise the SAME CLI inside the
# already-built control image (spec 11.2 — CLI is a mode of the Control program).
# On a deployed VPS there is no host .NET SDK by design.
cli_mode=""
if command -v dotnet >/dev/null 2>&1; then
  cli_mode="dotnet"
elif command -v docker >/dev/null 2>&1 && docker image inspect mini-voip-free/control:0.1.0 >/dev/null 2>&1; then
  cli_mode="docker"
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
  # container mode: uid 1001 inside the image must read the credential file, so a
  # short-lived world-readable copy in /tmp is used and deleted immediately after
  # (single-admin host; the file is gone before this script returns)
  cred_args=()
  tmpc=""
  if [ -n "$credential" ]; then
    tmpc="$(mktemp)"
    cp "$credential" "$tmpc" && chmod 644 "$tmpc"
    cred_args=(-v "$tmpc:/tmp/smi-cred:ro")
  fi
  rc=0
  docker run --rm --network host \
    -e SMI_DB_PATH=/var/lib/smi/smi.db \
    -e SMI_PBX_CFG_DIR=/etc/asterisk \
    -e SMI_DOMAIN="$SMI_DOMAIN" \
    -v "$ROOT/deploy/data/control:/var/lib/smi" \
    -v "$ROOT/deploy/data/asterisk/config:/etc/asterisk" \
    ${cred_args[@]:-} \
    mini-voip-free/control:0.1.0 $cli_verb "$ext" ${credential:+--credential-file /tmp/smi-cred} \
    || rc=$?
  [ -n "$tmpc" ] && rm -f "$tmpc"
  exit $rc
fi
