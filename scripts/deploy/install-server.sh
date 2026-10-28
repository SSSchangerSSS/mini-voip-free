#!/usr/bin/env bash
# install-server.sh — one-shot installer for a fresh Ubuntu VPS (22.04/24.04).
#
# What it does, in order (idempotent — safe to re-run):
#   1. preflight: docker + openssl present, ports 80/443/5038/5080/8088 free
#   2. deploy/site.env  ← prompts for the public DOMAIN and ACME email (once)
#   3. deploy/secrets/ami ← generated once with openssl (600, never printed to logs)
#   4. ./smi server init --config deploy/site.env   (dirs, asterisk conf, Caddy validate)
#   5. chown 1001:1001 for the volumes the control container (uid 1001) writes
#   6. ./smi server up                              (first run BUILDS asterisk ~15-30 min)
#   7. waits for https://<domain>/health/ready
#   8. optionally creates extensions 101..N with generated passwords saved under
#      ./credentials/ (chmod 600) and shown ONCE in this terminal only
#
# NEVER puts secrets in git/chat/logs; refuses placeholder values (fail-closed,
# AGENTS.md rule 3/6). Run it INSIDE the extracted server bundle root:
#     sudo bash install-server.sh
set -euo pipefail

# never accumulate shell history of pasted secrets
export HISTFILE=/dev/null

say()  { printf '\n\033[1;34m==> %s\033[0m\n' "$*"; }
warn() { printf '\033[1;33m[warn]\033[0m %s\n' "$*"; }
die()  { printf '\033[1;31m[BLOCKED]\033[0m %s\n' "$*" >&2; exit 3; }

[ "$(id -u)" = 0 ] || die "run with sudo: sudo bash install-server.sh"

ROOT="$(pwd)"
[ -f "$ROOT/smi" ] && [ -f "$ROOT/deploy/compose.yaml" ] \
  || die "run this script from the extracted bundle root (install-server.sh not found next to smi/compose.yaml)"

# fail-closed: on Windows-mounted filesystems (NTFS via WSL /mnt/c, drvfs/9p) chmod 600
# does NOT actually restrict access — secrets would sit unprotected. Refuse and say why.
fstype="$(df --output=fstype "$ROOT" 2>/dev/null | tail -1 | tr -d ' ')"
case "$fstype" in
  drvfs|9p|ntfs|ntfs-3g|fuseblk)
    die "bundle is on a Windows-mounted filesystem ($fstype) — extract it INSIDE the Linux filesystem (e.g. ~/mini-voip-free in WSL2) so chmod 600 on secrets really protects them" ;;
esac

command -v docker >/dev/null 2>&1 || die "docker is not installed. Install first:  curl -fsSL https://get.docker.com | sh  — then re-run."
command -v openssl >/dev/null 2>&1 || die "openssl not found (apt-get install -y openssl)"
docker compose version >/dev/null 2>&1 || die "docker compose plugin missing (usually bundled with get.docker.com install)"

say "1/8 checking ports (never kills existing services)"
if command -v ss >/dev/null 2>&1; then
  for p in 80 443 5038 5080 8088; do
    if ss -ltn | awk '{print $4}' | grep -qE "[:.]$p$"; then
      die "port $p is already in use — free it or stop the conflicting service, then re-run"
    fi
  done
fi

# ── site.env ─────────────────────────────────────────────────────────────────
SITE="$ROOT/deploy/site.env"
if [ ! -f "$SITE" ]; then
  say "2/8 creating deploy/site.env"
  read -r -p "Public domain pointed to THIS server (A record), e.g. phone.example.com: " DOMAIN
  DOMAIN="$(echo "$DOMAIN" | tr -d ' \r' | tr '[:upper:]' '[:lower:]')"
  echo "$DOMAIN" | grep -qE '^[a-z0-9.-]+\.[a-z]{2,}$' \
    || die "not a valid domain: '$DOMAIN' (TLS needs a real domain; a bare IP cannot get a Let's Encrypt cert)"
  read -r -p "Email for Let's Encrypt notices: " ACME_EMAIL
  ACME_EMAIL="$(echo "$ACME_EMAIL" | tr -d ' \r')"
  echo "$ACME_EMAIL" | grep -qE '^[^@]+@[^@]+\.[^@]+$' || die "not a valid email: '$ACME_EMAIL'"
  umask 022
  sed -e "s|^SMI_DOMAIN=.*|SMI_DOMAIN=$DOMAIN|" \
      -e "s|^SMI_ACME_EMAIL=.*|SMI_ACME_EMAIL=$ACME_EMAIL|" \
      "$ROOT/deploy/site.env.example" > "$SITE"
  echo "wrote $SITE (SMI_DOMAIN=$DOMAIN)"
else
  DOMAIN="$(sed -n 's/^SMI_DOMAIN=//p' "$SITE" | head -1)"
  warn "existing $SITE kept (SMI_DOMAIN=$DOMAIN)"
  [ -n "$DOMAIN" ] || die "SMI_DOMAIN empty in $SITE"
fi

# ── AMI secret ───────────────────────────────────────────────────────────────
AMI="$ROOT/deploy/secrets/ami"
umask 077
mkdir -p "$ROOT/deploy/secrets"
if [ ! -s "$AMI" ]; then
  say "3/8 generating AMI secret (deploy/secrets/ami, mode 600, never printed)"
  openssl rand -base64 32 | tr -d '\n' > "$AMI"
  chmod 600 "$AMI"
else
  warn "existing AMI secret kept"
fi
umask 022

say "4/8 server init (dirs + asterisk conf + Caddyfile validation)"
bash "$ROOT/smi" server init --config deploy/site.env

say "5/8 fixing volume ownership for the control container (uid 1001)"
chown -R 1001:1001 "$ROOT/deploy/data/control" "$ROOT/deploy/data/asterisk/config"

say "6/8 starting the stack (FIRST RUN BUILDS ASTERISK FROM SOURCE — 15-30 min, needs ~2GB free RAM)"
bash "$ROOT/smi" server up

say "7/8 waiting for /health/ready (this can take a while on first run)"
READY=""
for i in $(seq 1 60); do
  code="$(curl -s -o /dev/null -w '%{http_code}' "https://$DOMAIN/health/ready" || true)"
  if [ "$code" = "200" ]; then READY=1; break; fi
  echo "  attempt $i/60 → HTTP ${code:-none} (retrying in 30s; docker compose logs if stuck: ./smi server logs)"
  sleep 30
done
[ -n "$READY" ] || die "server did not become ready in 30 min — check: ./smi server logs   (TLS needs ports 80+443 reachable from the internet)"

say "READY — control plane answers at https://$DOMAIN/health/ready"

# ── extensions ───────────────────────────────────────────────────────────────
say "8/8 creating extensions (each gets a random 16-char password)"
mkdir -p "$ROOT/credentials"; chmod 700 "$ROOT/credentials"
read -r -p "How many extensions? (101..N, default 2): " COUNT
case "${COUNT:-2}" in ''|*[!0-9]*) COUNT=2 ;; esac
[ "$COUNT" -ge 1 ] && [ "$COUNT" -le 99 ] || COUNT=2

CREATED=""
i=0
while [ "$i" -lt "$COUNT" ]; do
  EXT=$((101 + i))
  i=$((i + 1))
  PW="$(openssl rand -base64 24 | tr -dc 'A-Za-z0-9' | head -c 16)"
  CF="$ROOT/credentials/ext-$EXT.txt"
  umask 077
  printf '%s\n' "$PW" > "$CF"
  umask 022
  if ! bash "$ROOT/smi" extension add "$EXT" --credential-file "$CF"; then
    warn "extension $EXT failed — see the message above (it stays fail-closed)"
    continue
  fi
  CREATED="$CREATED $EXT"
  echo "  extension $EXT  password: $PW   (also saved: $CF, mode 600)"
done

# control CLI runs inside the same image on the host network — no host dotnet needed
cat > "$ROOT/credentials/README.txt" <<EOF
Each ext-<N>.txt holds that extension's password (created $(date -u +%Y-%m-%dT%H:%MZ)).
These are the ONLY copy besides the PBKDF2 hash in the database — treat as secret.
Add more later:
  ./smi extension add 103 --credential-file /path/to/secure-file
EOF
chmod 600 "$ROOT/credentials/README.txt" 2>/dev/null || true

say "DONE"
echo "  Server:        https://$DOMAIN  (health: /health/ready)"
echo "  Extensions:    $CREATED  (passwords in ./credentials/, mode 600)"
echo "  Next step:     GitHub → Actions → android-build → Run workflow →"
echo "                 enter server_ip = $DOMAIN  → download the APK artifact"
echo "  Ops commands:  ./smi server status | logs | backup | restore | extension add | device reset"
echo "  Reminder:      firewall = TCP 80/443 + UDP 10000-10199 public; SSH restricted."
