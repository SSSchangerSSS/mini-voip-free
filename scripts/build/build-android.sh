#!/usr/bin/env bash
# build android — universal Release APK via Flutter with locked toolchain.
set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/lib/common.sh"

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
MOBILE="$ROOT/apps/mobile"
release=false
[[ "${1:-}" == android ]] && shift
server_host="${SMI_SERVER_HOST:-}"
server_port="${SMI_SERVER_PORT:-443}"
flutter_flags=()
trusted_ca=""
developer_password_file=""
while [ "$#" -gt 0 ]; do
  case "$1" in
    --release) release=true; shift ;;
    --verbose) flutter_flags+=(--verbose); shift ;;
    --developer-password-file)
      [ "$#" -ge 2 ] || fail_input "--developer-password-file requires a path"
      developer_password_file="$2"; shift 2 ;;
    --trusted-ca-file)
      [ "$#" -ge 2 ] || fail_input "--trusted-ca-file requires a path"
      trusted_ca="$2"; shift 2 ;;
    --server-host|--server-port)
      [ "$#" -ge 2 ] || fail_input "$1 requires a value"
      case "$1" in --server-host) server_host="$2" ;; --server-port) server_port="$2" ;; esac
      shift 2 ;;
    *) fail_input "unknown Android build option: $1" ;;
  esac
done
[[ -z "$server_host" || "$server_host" =~ ^[A-Za-z0-9.-]+$ ]] || fail_input "server host must be an IP or hostname without scheme/path"
[[ "$server_port" =~ ^[0-9]{1,5}$ ]] || fail_input "server port must be 1..65535"
(( 10#$server_port >= 1 && 10#$server_port <= 65535 )) || fail_input "server port must be 1..65535"
build_config=()
if [ -n "$server_host" ]; then
  build_config+=("--dart-define=SMI_SERVER_HOST=$server_host" "--dart-define=SMI_SERVER_PORT=$server_port")
fi

if [ -n "$trusted_ca" ]; then
  [ -f "$trusted_ca" ] || fail_input "trusted CA file not found"
  ca_defines="$(mktemp)"
  trap 'rm -f "$ca_defines"' EXIT
  python3 - "$trusted_ca" "$ca_defines" <<'PYCA'
import base64, json, sys
pem = open(sys.argv[1]).read()
if '-----BEGIN CERTIFICATE-----' not in pem:
    raise SystemExit('Invalid CA PEM')
with open(sys.argv[2], 'w') as output:
    json.dump({'SMI_TRUSTED_CA_BASE64': base64.b64encode(pem.encode()).decode()}, output)
PYCA
  build_config+=("--dart-define-from-file=$ca_defines")
fi
# The verifier is build data; plaintext remains exclusively in the private input file.
python3 - "$developer_password_file" "$MOBILE/android/app/developer-gate.properties" <<'PYGATE'
import sys,pathlib,hashlib,secrets,base64,os
source,target=sys.argv[1:]
p=pathlib.Path(target)
if not source:
    p.unlink(missing_ok=True)
else:
    f=pathlib.Path(source)
    if f.stat().st_mode & 0o077:raise SystemExit('Developer password file must be private (mode600)')
    password=f.read_bytes().strip()
    if not 12<=len(password)<=256:raise SystemExit('Developer password must contain12..256bytes')
    salt=secrets.token_bytes(16)
    derived=hashlib.pbkdf2_hmac('sha256',password,salt,120000)
    fd=os.open(p,os.O_WRONLY|os.O_CREAT|os.O_TRUNC,0o600)
    with os.fdopen(fd,'w') as out:out.write('salt='+base64.b64encode(salt).decode()+'\nhash='+base64.b64encode(derived).decode()+'\n')
PYGATE
require_cmd flutter
if [ ! -d "$MOBILE/android" ]; then
  fail_blocked "apps/mobile/android missing — run: flutter create --org app --project-name smi_phone apps/mobile && ./scripts/build/apply-platform-overlay.sh"
fi

( cd "$MOBILE" && flutter pub get )
if $release; then
  ( cd "$MOBILE" && flutter build apk --release "${build_config[@]}" "${flutter_flags[@]}" )
  apk="$MOBILE/build/app/outputs/flutter-apk/app-release.apk"
  [ -f "$apk" ] || fail "Flutter exited without the expected APK: $apk"
  ok "APK: $apk"
  sha256sum "$apk"
  warn "signing: verify the APK signer; production signing remains BLOCKED without the employer keystore (PREFLIGHT B6)"
else
  ( cd "$MOBILE" && flutter build apk --debug "${build_config[@]}" "${flutter_flags[@]}" )
fi
