#!/bin/bash
# install.sh — WhatsApp Bot v5.0
# n8n 1.70.0 + WAHA 2024.12 + Gemini AI + Caddy 2.8 + PostgreSQL 16
set -euo pipefail

RED='\033[0;31m'; GRN='\033[0;32m'; YEL='\033[1;33m'; CYA='\033[0;36m'; NC='\033[0m'
log(){ echo -e "${CYA}[*]${NC} $1"; }
ok(){ echo -e "${GRN}[+]${NC} $1"; }
err(){ echo -e "${RED}[-]${NC} $1"; exit 1; }
warn(){ echo -e "${YEL}[!]${NC} $1"; }

[ "$EUID" -ne 0 ] && err "Run as root: sudo ./install.sh"

REPO_DIR="$(cd "$(dirname "$0")" && pwd)"
DIR="/opt/waha-bot"

clear
echo -e "${CYA}"
echo "  ██╗    ██╗██╗  ██╗ █████╗ ████████╗███████╗ █████╗ ██████╗ ██████╗      ██████╗  ██████╗ ████████╗"
echo "  ██║    ██║██║  ██║██╔══██╗╚══██╔══╝██╔════╝██╔══██╗██╔══██╗██╔══██╗     ██╔══██╗██╔═══██╗╚══██╔══╝"
echo "  ██║ █╗ ██║███████║███████║   ██║   ███████╗███████║██████╔╝██████╔╝      ██████╔╝██║   ██║   ██║   "
echo "  ╚████╔╝ ██╔══██║██╔══██║   ██║   ╚════██║██╔══██║██╔═══╝ ██╔═══╝       ██╔══██╗██║   ██║   ██║   "
echo "   ╚═══╝  ██║  ██║██║  ██║   ██║   ███████║██║  ██║██║     ██║    ██╗     ██████╔╝╚██████╔╝   ██║   "
echo ""
echo -e "                           v5.0 — Ubuntu — n8n + WAHA + Gemini + PostgreSQL${NC}"
echo ""

# ════════════════════════════════════════════════════════════
# SECTION 1 — QUESTIONS
# ════════════════════════════════════════════════════════════
echo -e "${CYA}━━━ Setup ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

read -p "[1/9] WAHA API key (min 16 chars) : " WAHA_KEY
[[ ${#WAHA_KEY} -lt 16 ]] && err "Too short (min 16)"

read -p "[2/9] WAHA dashboard username : " WAHA_USER
[[ -z "$WAHA_USER" ]] && err "Username required"

read -s -p "[3/9] WAHA dashboard password (min 12) : " WAHA_PASS; echo
[[ ${#WAHA_PASS} -lt 12 ]] && err "Too short (min 12)"

echo ""
echo -e "${CYA}  ── Gemini API Key ─────────────────────────────────────────${NC}"
echo "  1. Go to: https://aistudio.google.com"
echo "  2. Click 'Get API key' in the left sidebar"
echo "  3. Click 'Create API key' and copy it"
echo "  4. IMPORTANT: click the dollar icon (\$) next to your key"
echo "     to set a spending limit and avoid unexpected charges"
echo -e "${CYA}  ───────────────────────────────────────────────────────────${NC}"
echo ""
read -p "[4/9] Paste your Gemini API key : " GEMINI_KEY
[[ -z "$GEMINI_KEY" ]] && err "Gemini API key required"

read -p "[5/9] Authorized phone number (ex: 33612345678) : " WA_NUM
[[ ! "$WA_NUM" =~ ^[0-9]{8,15}$ ]] && err "Invalid format — digits only, 8-15 digits"

read -p "[6/9] Bot name for pre-message (ex: Rafaeline) : " BOT_NAME
[[ -z "$BOT_NAME" ]] && BOT_NAME="Bot"

read -p "[7/9] Default pre-message text (Enter = auto) : " PREMSG
[[ -z "$PREMSG" ]] && PREMSG="Bot by $BOT_NAME. Scheduled message:"

read -p "[8/9] Timezone (ex: Europe/Paris, Asia/Jerusalem) : " TZ_VAL
[[ -z "$TZ_VAL" ]] && TZ_VAL="UTC"

read -p "[9/9] HTTPS domain (leave empty for direct IP access) : " DOMAIN

IP=$(hostname -I | awk '{print $1}')
POSTGRES_PASSWORD=$(openssl rand -base64 24 | tr -d '/+=')

echo ""
echo -e "${CYA}━━━ Summary ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo "  Server IP     : $IP"
echo "  Bot number    : $WA_NUM"
echo "  Timezone      : $TZ_VAL"
[[ -n "$DOMAIN" ]] && echo "  Domain        : $DOMAIN" || echo "  Access        : direct IP (no domain)"
echo "  Database      : PostgreSQL 16 (auto-configured)"
echo ""
read -p "Confirm installation? (yes/no) : " CONFIRM
[[ "$CONFIRM" != "yes" ]] && err "Installation cancelled"

# ════════════════════════════════════════════════════════════
# SECTION 2 — DOCKER
# ════════════════════════════════════════════════════════════
echo ""
log "Verifying Docker..."

if ! command -v docker &>/dev/null; then
  log "Installing Docker..."
  apt-get update -qq
  apt-get install -y -qq ca-certificates curl gnupg lsb-release python3
  install -m 0755 -d /etc/apt/keyrings
  curl -fsSL https://download.docker.com/linux/ubuntu/gpg \
    | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
  chmod a+r /etc/apt/keyrings/docker.gpg
  echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
    https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" \
    > /etc/apt/sources.list.d/docker.list
  apt-get update -qq
  apt-get install -y -qq docker-ce docker-ce-cli containerd.io docker-compose-plugin
  systemctl enable --now docker
  ok "Docker installed"
else
  ok "Docker $(docker --version | cut -d' ' -f3 | tr -d ',') already installed"
fi

# ════════════════════════════════════════════════════════════
# SECTION 3 — UFW
# ════════════════════════════════════════════════════════════
if command -v ufw &>/dev/null; then
  log "Configuring UFW firewall..."
  ufw --force reset > /dev/null 2>&1
  ufw default deny incoming > /dev/null 2>&1
  ufw default allow outgoing > /dev/null 2>&1
  ufw allow 22/tcp > /dev/null 2>&1
  ufw allow 80/tcp > /dev/null 2>&1
  ufw allow 443/tcp > /dev/null 2>&1
  ufw --force enable > /dev/null 2>&1
  ok "UFW: ports 22, 80, 443 open"
fi

# ════════════════════════════════════════════════════════════
# SECTION 4 — DIRECTORIES + .env
# ════════════════════════════════════════════════════════════
log "Creating directories..."
mkdir -p "$DIR"/{n8n_data,sessions,media,backups,postgres_data,workflows}
cd "$DIR"

cat > .env <<EOF
WAHA_API_KEY=${WAHA_KEY}
WAHA_DASHBOARD_USERNAME=${WAHA_USER}
WAHA_DASHBOARD_PASSWORD=${WAHA_PASS}
GEMINI_API_KEY=${GEMINI_KEY}
AUTHORIZED_NUMBER=${WA_NUM}
BOT_NAME=${BOT_NAME}
DEFAULT_PREMESSAGE=${PREMSG}
TZ=${TZ_VAL}
DOMAIN=${DOMAIN:-$IP}
POSTGRES_PASSWORD=${POSTGRES_PASSWORD}
EOF
chmod 600 .env
ok "Directories and .env created"

# ════════════════════════════════════════════════════════════
# SECTION 5 — docker-compose.yml
# ════════════════════════════════════════════════════════════
log "Generating docker-compose.yml..."

if [[ -n "$DOMAIN" ]]; then
  WEBHOOK_URL="https://${DOMAIN}"
  N8N_PORTS=""
  WAHA_PORTS=""
else
  WEBHOOK_URL="http://${IP}:5678"
  N8N_PORTS=$'\n    ports:\n      - "5678:5678"'
  WAHA_PORTS=$'\n    ports:\n      - "3000:3000"'
fi

cat > docker-compose.yml <<EOF
services:

  postgres:
    image: postgres:16-alpine
    container_name: postgres
    environment:
      - POSTGRES_DB=n8n
      - POSTGRES_USER=n8n
      - POSTGRES_PASSWORD=\${POSTGRES_PASSWORD}
    volumes:
      - ./postgres_data:/var/lib/postgresql/data
    restart: unless-stopped
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U n8n"]
      interval: 5s
      timeout: 5s
      retries: 10

  waha:
    image: devlikeapro/waha:noweb
    container_name: waha${WAHA_PORTS}
    environment:
      - WHATSAPP_API_KEY=\${WAHA_API_KEY}
      - WHATSAPP_DASHBOARD_USERNAME=\${WAHA_DASHBOARD_USERNAME}
      - WHATSAPP_DASHBOARD_PASSWORD=\${WAHA_DASHBOARD_PASSWORD}
      - WHATSAPP_HOOK_URL=http://n8n:5678/webhook/waha
      - WHATSAPP_HOOK_EVENTS=message
      - TZ=\${TZ}
    volumes:
      - ./sessions:/app/.sessions
      - ./media:/app/.media
    restart: unless-stopped

  n8n:
    image: n8nio/n8n:1.70.0
    container_name: n8n${N8N_PORTS}
    environment:
      - N8N_USER_MANAGEMENT_DISABLED=false
      - WEBHOOK_URL=${WEBHOOK_URL}
      - GENERIC_TIMEZONE=\${TZ}
      - TZ=\${TZ}
      - AUTHORIZED_NUMBER=\${AUTHORIZED_NUMBER}
      - BOT_NAME=\${BOT_NAME}
      - DEFAULT_PREMESSAGE=\${DEFAULT_PREMESSAGE}
      - GEMINI_API_KEY=\${GEMINI_API_KEY}
      - WAHA_API_KEY=\${WAHA_API_KEY}
      - DB_TYPE=postgresdb
      - DB_POSTGRESDB_HOST=postgres
      - DB_POSTGRESDB_DATABASE=n8n
      - DB_POSTGRESDB_USER=n8n
      - DB_POSTGRESDB_PASSWORD=\${POSTGRES_PASSWORD}
    volumes:
      - ./n8n_data:/home/node/.n8n
    restart: unless-stopped
    depends_on:
      postgres:
        condition: service_healthy
      waha:
        condition: service_started
EOF

if [[ -n "$DOMAIN" ]]; then
  cat >> docker-compose.yml <<EOF

  caddy:
    image: caddy:2.8
    container_name: caddy
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - ./Caddyfile:/etc/caddy/Caddyfile
      - caddy_data:/data
      - caddy_config:/config
    restart: unless-stopped
    depends_on:
      - n8n
      - waha

volumes:
  caddy_data:
  caddy_config:
EOF

  cat > Caddyfile <<EOF
${DOMAIN} {
  handle /waha* {
    reverse_proxy waha:3000
  }
  handle {
    reverse_proxy n8n:5678
  }
}
EOF
  ok "Caddy configured for ${DOMAIN}"
fi
ok "docker-compose.yml generated"

# ════════════════════════════════════════════════════════════
# SECTION 6 — COPY WORKFLOWS + SCRIPTS
# ════════════════════════════════════════════════════════════
log "Copying workflow files..."
cp "$REPO_DIR/workflows/workflow-receiver.json" "$DIR/workflows/"
cp "$REPO_DIR/workflows/workflow-guardian.json" "$DIR/workflows/"
cp "$REPO_DIR/scripts/insert-workflows.sh"      "$DIR/"
chmod +x "$DIR/insert-workflows.sh"
ok "Workflow JSONs and scripts copied"

# ════════════════════════════════════════════════════════════
# SECTION 7 — CONTAINER STARTUP
# ════════════════════════════════════════════════════════════
log "Starting containers..."
docker compose up -d
ok "Containers started"

# ════════════════════════════════════════════════════════════
# SECTION 8 — WAITING FOR WAHA
# ════════════════════════════════════════════════════════════
log "Waiting for WAHA (up to 60s)..."
for i in $(seq 1 20); do
  CODE=$(curl -sf -o/dev/null -w"%{http_code}" \
    -H "X-Api-Key: ${WAHA_KEY}" \
    http://localhost:3000/api/sessions/default 2>/dev/null || echo "000")
  if [[ "$CODE" == "200" || "$CODE" == "404" ]]; then
    ok "WAHA ready"
    break
  fi
  [[ $i -eq 20 ]] && warn "WAHA slow — continuing anyway"
  sleep 3
done

# ════════════════════════════════════════════════════════════
# SECTION 9 — WAITING FOR n8n + API KEY
# ════════════════════════════════════════════════════════════
log "Waiting for n8n (up to 90s)..."
for i in $(seq 1 30); do
  CODE=$(curl -sf -o/dev/null -w"%{http_code}" \
    http://localhost:5678/healthz 2>/dev/null || echo "000")
  [[ "$CODE" == "200" ]] && break
  [[ $i -eq 30 ]] && err "n8n unreachable after 90s — check: docker logs n8n"
  sleep 3
done
ok "n8n is ready"

if [[ -n "$DOMAIN" ]]; then
  N8N_URL="https://${DOMAIN}"
else
  N8N_URL="http://${IP}:5678"
fi

echo ""
echo -e "${CYA}━━━ n8n Setup ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo "  n8n is running. Follow these steps in your browser:"
echo ""
echo "  1. Open n8n:"
echo -e "     ${YEL}${N8N_URL}${NC}"
echo ""
echo "  2. Create your owner account (email + password of your choice)"
echo ""
echo "  3. Once logged in:"
echo "     Settings (bottom-left gear) > API > Create an API Key"
echo ""
echo "  4. Give it a name (e.g. 'bot'), click Create"
echo ""
echo "  5. Copy the key — it will not be shown again"
echo ""
echo -e "${CYA}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
read -p "  Paste your n8n API key here : " N8N_API_KEY
[[ -z "$N8N_API_KEY" ]] && err "n8n API key required"
echo "N8N_API_KEY=${N8N_API_KEY}" >> .env
ok "n8n API key saved"

# ════════════════════════════════════════════════════════════
# SECTION 10 — IMPORTING WORKFLOWS
# ════════════════════════════════════════════════════════════
log "Importing n8n workflows..."
bash "$DIR/insert-workflows.sh" "$N8N_API_KEY"
ok "Workflows imported and activated"

# ════════════════════════════════════════════════════════════
# SECTION 11 — FINAL SUMMARY
# ════════════════════════════════════════════════════════════
echo ""
echo -e "${GRN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GRN}  INSTALLATION COMPLETED — v5.0${NC}"
echo -e "${GRN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

if [[ -n "$DOMAIN" ]]; then
  echo -e "  ${CYA}n8n${NC}            → https://${DOMAIN}"
  echo -e "  ${CYA}WAHA dashboard${NC} → https://${DOMAIN}/waha/dashboard"
  echo -e "  ${CYA}WAHA API${NC}       → https://${DOMAIN}/waha"
else
  echo -e "  ${CYA}n8n${NC}            → http://${IP}:5678"
  echo -e "  ${CYA}WAHA dashboard${NC} → http://${IP}:3000/dashboard"
  echo -e "  ${CYA}WAHA API${NC}       → http://${IP}:3000"
  echo ""
  echo -e "  ${YEL}Or via SSH tunnel:${NC}"
  echo -e "  ${YEL}  ssh -L 5678:127.0.0.1:5678 -L 3000:127.0.0.1:3000 root@${IP}${NC}"
fi

echo ""
echo -e "  ${CYA}PostgreSQL${NC}     → internal (n8n data persisted across restarts)"
echo ""
echo -e "  ${YEL}NEXT STEP:${NC}"
echo -e "  ${YEL}  1. Open the WAHA dashboard${NC}"
echo -e "  ${YEL}  2. Go to Sessions > default > Start${NC}"
echo -e "  ${YEL}  3. Scan the QR code with WhatsApp${NC}"
echo -e "  ${YEL}  4. Status must switch to WORKING${NC}"
echo ""

cat > "$DIR/INSTALL_INFO.txt" <<INFO
WhatsApp Bot v5.0 Installation
Date: $(date)
IP  : ${IP}
$([ -n "$DOMAIN" ] && echo "Domain: ${DOMAIN}" || echo "Direct access: http://${IP}:3000")

n8n URL      : ${N8N_URL}
WAHA user    : ${WAHA_USER}
N8N API KEY  : ${N8N_API_KEY}
Database     : PostgreSQL 16 (internal, auto-managed)

WAHA dashboard: $([ -n "$DOMAIN" ] && echo "https://${DOMAIN}/waha/dashboard" || echo "http://${IP}:3000/dashboard")
n8n           : $([ -n "$DOMAIN" ] && echo "https://${DOMAIN}" || echo "http://${IP}:5678")
INFO
chmod 600 "$DIR/INSTALL_INFO.txt"
ok "Summary saved in /opt/waha-bot/INSTALL_INFO.txt"
