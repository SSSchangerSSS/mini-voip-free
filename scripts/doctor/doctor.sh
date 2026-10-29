#!/usr/bin/env bash
# doctor — preflight for toolchain, config, ports, secrets (values never printed).
set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/lib/common.sh"

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
JSON_OUT=false
[ "${1:-}" = "--json" ] && JSON_OUT=true
declare -a LINES=()

pass() { LINES+=("PASS $*"); }
blocked() { LINES+=("BLOCKED $*"); }
warnln() { LINES+=("WARN $*"); }

# toolchain
if command -v dotnet >/dev/null 2>&1; then
  want="$(python3 -c "import json;print(json.load(open('$ROOT/global.json'))['sdk']['version'])" 2>/dev/null || echo '?')"
  have="$(dotnet --version 2>/dev/null || echo none)"
  case "$have" in "$want"*) pass "dotnet $have (global.json wants $want, rollForward latestFeature)";; *) warnln "dotnet $have != locked $want — install matching SDK";; esac
else
  blocked "dotnet SDK missing — Control build/test unavailable"
fi

if command -v flutter >/dev/null 2>&1; then
  fv="$(flutter --version --machine 2>/dev/null | python3 -c 'import json,sys;print(json.load(sys.stdin).get("flutterVersion","?"))' 2>/dev/null || echo '?')"
  pass "flutter $fv (locked: 3.47.8 — see toolchain.lock.json)"
else
  blocked "flutter missing — mobile build/test unavailable (CI covers unit tests)"
fi

command -v docker >/dev/null 2>&1 && pass "docker $(docker --version | cut -d' ' -f3 | tr -d ',')" || blocked "docker missing — server lifecycle commands unavailable"
command -v python3 >/dev/null 2>&1 && pass "python3" || blocked "python3 missing"

# lockfiles
for f in toolchain.lock.json global.json apps/mobile/pubspec.yaml services/control/src/Smi.Control/packages.lock.json; do
  [ -f "$ROOT/$f" ] && pass "lockfile present: $f" || warnln "lockfile missing: $f"
done

# secrets presence (NO values) + placeholder detection
if [ -f "$ROOT/deploy/secrets/ami" ]; then
  pass "deploy/secrets/ami present"
  if grep -qE '(CHANGEME|REPLACE_ME)' "$ROOT/deploy/secrets/ami" 2>/dev/null; then
    blocked "deploy/secrets/ami contains a placeholder"
  fi
else
  blocked "deploy/secrets/ami missing — control will run but calls fail closed"
fi
for s in apns.p8 fcm-service-account.json; do
  [ -s "$ROOT/deploy/secrets/$s" ] && pass "deploy/secrets/$s present (provider validation still required)" || blocked "deploy/secrets/$s missing or empty — push BLOCKED (PREFLIGHT B2/B3)"
done

# site config
if [ -f "$ROOT/deploy/site.env" ]; then
  assert_no_placeholder "$ROOT/deploy/site.env" && pass "deploy/site.env validated (no placeholders)"
  domain="$(grep -E '^SMI_DOMAIN=' "$ROOT/deploy/site.env" | cut -d= -f2 | tr -d '"' | head -1 || true)"
  if [ -n "${domain:-}" ] && command -v getent >/dev/null 2>&1; then
    if getent hosts "$domain" >/dev/null 2>&1; then pass "DNS resolves: $domain"; else warnln "DNS does not resolve: $domain"; fi
  fi
else
  warnln "deploy/site.env missing (copy from deploy/site.env.example)"
fi

# port conflicts (only meaningful on the server host)
if command -v ss >/dev/null 2>&1; then
  for p in 80 443 5038 5080 8088; do
    if ss -ltn 2>/dev/null | awk '{print $4}' | grep -qE "[:.]$p$"; then
      warnln "port $p already in use — resolve before ./smi server up"
    else
      pass "port $p free"
    fi
  done
fi

# clock sanity (NTP-corrected systems report ~0 offset; drift is informational here)
now_epoch="$(date -u +%s)"
date_utc="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
pass "clock: $date_utc (epoch $now_epoch)"

if $JSON_OUT; then
  json_out "{\"lines\":[$(printf '"%s",' "${LINES[@]}" | sed 's/,$//')]}"
else
  printf '%s\n' "${LINES[@]}"
fi

# exit non-zero when something is BLOCKED (informational tool — tests/doctor define gates)
if printf '%s\n' "${LINES[@]}" | grep -q '^BLOCKED'; then exit 1; fi
exit 0
