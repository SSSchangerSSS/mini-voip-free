#!/usr/bin/env bash
# Configure the advertised server address; never changes the host NIC or starts services.
set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/lib/common.sh"
config="$SMI_ROOT/deploy/site.env"
host=""; tls="internal"
while [ "$#" -gt 0 ]; do
  case "$1" in
    --host|--tls|--config)
      [ "$#" -ge 2 ] || fail_input "$1 requires a value"
      case "$1" in --host) host="$2";; --tls) tls="$2";; --config) config="$2";; esac
      shift 2 ;;
    *) fail_input "unknown option $1" ;;
  esac
done
python3 - "$host" "$tls" "$config" <<'PY'
import sys,re,ipaddress,pathlib,os
host,tls,path=sys.argv[1:]
if tls not in ('internal','public'):raise SystemExit('Invalid TLS mode')
try:
 ip=ipaddress.ip_address(host)
 if ip.version!=4 or ip.is_unspecified or ip.is_multicast or ip.is_loopback:raise ValueError()
except ValueError:
 if not re.fullmatch(r'(?=.{1,253}$)(?:[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?\.)+[a-zA-Z]{2,63}',host):raise SystemExit('Invalid static IPv4 or DNS host')
p=pathlib.Path(path)
if not p.parent.exists():raise SystemExit('Configuration parent directory does not exist')
values={'SMI_DOMAIN':host.lower(),'SMI_TLS_MODE':tls}
lines=p.read_text().splitlines() if p.exists() else []
output=[]
for line in lines:
 key=line.split('=',1)[0]
 if key in values:
  output.append(key+'='+values.pop(key))
 else:output.append(line)
output.extend(k+'='+v for k,v in values.items())
tmp=p.with_name(p.name+'.new')
fd=os.open(tmp,os.O_CREAT|os.O_EXCL|os.O_WRONLY,0o600)
try:
 with os.fdopen(fd,'w') as f:f.write('\n'.join(output)+'\n')
 os.replace(tmp,p)
finally:tmp.unlink(missing_ok=True)
PY
ok "server address configured; host network unchanged. Run ./smi server up --config <same-file> to apply."
