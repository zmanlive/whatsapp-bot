#!/bin/bash
# install.sh — WhatsApp Bot v4.2 — COMPLET
# n8n 1.70.0 + WAHA 2024.12 + Gemini AI + Caddy 2.8
set -euo pipefail

RED='\033[0;31m'; GRN='\033[0;32m'; YEL='\033[1;33m'; CYA='\033[0;36m'; NC='\033[0m'
log(){ echo -e "${CYA}[*]${NC} $1"; }
ok(){ echo -e "${GRN}[+]${NC} $1"; }
err(){ echo -e "${RED}[-]${NC} $1"; exit 1; }
warn(){ echo -e "${YEL}[!]${NC} $1"; }

[ "$EUID" -ne 0 ] && err "Run as root: sudo ./install.sh"

DIR="/opt/waha-bot"
clear
echo -e "${CYA}"
echo "  ██╗    ██╗██╗  ██╗ █████╗ ████████╗███████╗ █████╗ ██████╗ ██████╗      ██████╗  ██████╗ ████████╗"
echo "  ██║    ██║██║  ██║██╔══██╗╚══██╔══╝██╔════╝██╔══██╗██╔══██╗██╔══██╗     ██╔══██╗██╔═══██╗╚══██╔══╝"
echo "  ██║ █╗ ██║███████║███████║   ██║   ███████╗███████║██████╔╝██████╔╝      ██████╔╝██║   ██║   ██║   "
echo "  ╚████╔╝ ██╔══██║██╔══██║   ██║   ╚════██║██╔══██║██╔═══╝ ██╔═══╝       ██╔══██╗██║   ██║   ██║   "
echo "   ╚═══╝  ██║  ██║██║  ██║   ██║   ███████║██║  ██║██║     ██║    ██╗     ██████╔╝╚██████╔╝   ██║   "
echo ""
echo -e "                           v4.2 — Ubuntu — n8n + WAHA + Gemini${NC}"
echo ""

# ════════════════════════════════════════════════════════════
# SECTION 1 — QUESTIONS
# ════════════════════════════════════════════════════════════
echo -e "${CYA}━━━ Setup ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
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

echo ""
echo -e "${CYA}━━━ Summary ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo "  Server IP     : $IP"
echo "  Bot number    : $WA_NUM"
echo "  Timezone      : $TZ_VAL"
[[ -n "$DOMAIN" ]] && echo "  Domain        : $DOMAIN" || echo "  Access        : direct IP (no domain)"
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
mkdir -p "$DIR"/{scripts,n8n_data,sessions,media,backups,workflows}
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
    volumes:
      - ./n8n_data:/home/node/.n8n
    restart: unless-stopped
    depends_on:
      - waha
EOF

# Add Caddy if domain provided
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

  # ── Caddyfile ────────────────────────────────────────────
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
# SECTION 6 — WRITING SCRIPTS TO DISK
# ════════════════════════════════════════════════════════════
log "Writing scripts to disk..."

# ── insert-workflows.sh ──────────────────────────────────────
cat > "$DIR/scripts/insert-workflows.sh" <<'INSERT_EOF'
#!/bin/bash
set -euo pipefail
N8N_KEY="${1:-}"
[[ -z "$N8N_KEY" ]] && { echo "Usage: $0 N8N_API_KEY"; exit 1; }
BASE="http://localhost:5678"
DIR="/opt/waha-bot"

echo "[wf] Waiting for n8n API..."
for i in $(seq 1 15); do
  CODE=$(curl -sf -o/dev/null -w"%{http_code}" \
    "$BASE/api/v1/workflows" -H "X-N8N-API-KEY: $N8N_KEY" 2>/dev/null || echo "000")
  [[ "$CODE" == "200" ]] && break
  [[ $i -eq 15 ]] && { echo "n8n API unreachable (HTTP $CODE)"; exit 1; }
  sleep 3
done

upsert_wf() {
  local NAME="$1" FILE="$2"
  EX=$(curl -sf "$BASE/api/v1/workflows?limit=100" \
    -H "X-N8N-API-KEY: $N8N_KEY" 2>/dev/null \
    | python3 -c "
import sys,json
d=json.load(sys.stdin)
m=[str(w['id']) for w in d.get('data',[]) if w.get('name')=='$NAME']
print(m[0] if m else '')" 2>/dev/null || echo "")

  if [[ -n "$EX" ]]; then
    curl -sf -X PUT "$BASE/api/v1/workflows/$EX" \
      -H "X-N8N-API-KEY: $N8N_KEY" -H "Content-Type: application/json" \
      -d "@$FILE" -o/dev/null
    WF_ID="$EX"
  else
    RESP=$(curl -sf -X POST "$BASE/api/v1/workflows" \
      -H "X-N8N-API-KEY: $N8N_KEY" -H "Content-Type: application/json" \
      -d "@$FILE" 2>/dev/null)
    WF_ID=$(echo "$RESP" | python3 -c \
      "import sys,json; print(json.load(sys.stdin).get('id',''))" 2>/dev/null || echo "")
    [[ -z "$WF_ID" ]] && { echo "Import failed: $(echo $RESP | head -c 200)"; exit 1; }
  fi

  curl -sf -o/dev/null \
    -X POST "$BASE/api/v1/workflows/$WF_ID/activate" \
    -H "X-N8N-API-KEY: $N8N_KEY" 2>/dev/null || true
  echo "[wf] OK: $NAME (id $WF_ID)"
}

python3 "$DIR/scripts/gen_workflows.py"
upsert_wf "WA Bot - Receiver" "$DIR/workflows/workflow-receiver.json"
upsert_wf "WA Bot - Guardian"   "$DIR/workflows/workflow-guardian.json"
echo "[wf] Finished — verify activation in n8n"
INSERT_EOF
chmod +x "$DIR/scripts/insert-workflows.sh"
ok "insert-workflows.sh written"

# ── gen_workflows.py ─────────────────────────────────────────
cat > "$DIR/scripts/gen_workflows.py" <<'GEN_EOF'
#!/usr/bin/env python3
# gen_workflows.py — generates workflow-receiver.json and workflow-guardian.json
import json, os
DIR = "/opt/waha-bot"
os.makedirs(f"{DIR}/workflows", exist_ok=True)

# ── NODE : Init Security ──────────────────────────────────────────────────────
INIT_JS = (
  "const body=($input.first().json?.body??$input.first().json)??{};"
  "const msgId=body.id??body.key?.id??('_'+Date.now());"
  "const from=(body.from??body.key?.remoteJid??'').replace('@s.whatsapp.net','');"
  "const isAudio=['audio','ptt','voice'].includes(body.type??'');"
  "const msgType=isAudio?'audio':'text';"
  "const rawText=(body.body??body.message?.conversation??'').trim();"
  "const msgText=rawText.toLowerCase();"
  "const sd=$getWorkflowStaticData('global');"
  "sd.processedIds=sd.processedIds??{};"
  "sd.utilisateurs=sd.utilisateurs??{};"
  "sd.messages=sd.messages??[];"
  "sd.config={"
  " numeroAutorise:sd.config?.numeroAutorise??process.env.AUTHORIZED_NUMBER??'',"
  " nomDefaut:sd.config?.nomDefaut??process.env.BOT_NAME??'',"
  " premessageDefaut:sd.config?.premessageDefaut??process.env.DEFAULT_PREMESSAGE??'',"
  " timezone:sd.config?.timezone??process.env.TZ??'UTC'"
  "};"
  "const now=Date.now();"
  "Object.keys(sd.processedIds).forEach(k=>{"
  " if(now-sd.processedIds[k]>3600000)delete sd.processedIds[k];"
  "});"
  "if(sd.processedIds[msgId])return[];"
  "sd.processedIds[msgId]=now;"
  "if(!from||from!==sd.config.numeroAutorise)return[];"
  "sd.utilisateurs[from]??={"
  " langue:'en',etape:0,previousEtape:null,pendingCmd:null,lastActivity:now,flux:{}"
  "};"
  "const user=sd.utilisateurs[from];"
  "if(user.etape>0&&(now-(user.lastActivity??0))>30*60*1000){"
  " user.etape=0;user.flux={};user.previousEtape=null;user.pendingCmd=null;"
  " user.lastActivity=now;sd.utilisateurs[from]=user;"
  " return[{json:{action:'send',to:from,text:'Flow cancelled (30 min inactive).'}}];"
  "}"
  "user.lastActivity=now;"
  "sd.utilisateurs[from]=user;"
  "return[{json:{from,msgType,msgText,rawText,msgId,rawBody:body,user,sd}}];"
)

AUDIO_JS = (
  "const{from,user,sd,rawBody}=$json;"
  "const fs=rawBody?.message?.audioMessage?.fileLength??0;"
  "const dur=rawBody?.message?.audioMessage?.seconds??0;"
  "const mUrl=$('Webhook WAHA').first().json?.payload?.media?.url??'';"
  "const mId=rawBody?.id??'';"
  "if(fs>25*1024*1024)return[{json:{action:'send',to:from,text:'Audio too large (max 25MB).'}}];"
  "if(dur>300)return[{json:{action:'send',to:from,text:'Audio too long (max 5 min).'}}];"
  "if(!mUrl)return[{json:{action:'send',to:from,text:'Audio unavailable. Try again.'}}];"
  "return[{json:{action:'transcribe',from,user,sd,mediaUrl:mUrl,mediaId:mId,etape:user.etape}}];"
)

GEMINI_RESULT_JS = (
  "const resp=$('Gemini Transcribe').first().json??{};"
  "const{from,user,sd,etape}=$('Audio Handler').first().json;"
  "const err=resp?.error?.code;"
  "if(err){"
  " let m='Transcription failed.';"
  " if(err===429)m='Gemini quota exceeded. Try again in a few minutes.';"
  " else if(err===400)m='Audio unreadable by Gemini.';"
  " else if(err===403)m='Invalid Gemini key.';"
  " return[{json:{action:'send',to:from,text:m}}];"
  "}"
  "const t=resp?.candidates?.[0]?.content?.parts?.[0]?.text?.trim()??'';"
  "if(!t)return[{json:{action:'send',to:from,text:'Empty transcription.'}}];"
  "if(etape===0)return[{json:{action:'send',to:from,text:'\u{1F3A4} '+t}}];"
  "user.flux.pendingTranscription=t;"
  "sd.utilisateurs[from]=user;"
  "const fl=user.flux;"
  "return[{json:{action:'send',to:from,"
  " text:'\u{1F3A4} '+t+'\n\nUse as message?\n\u{1F4CD} '+fl.destinataire"
  " +'  '+fl.scheduledLocal+'\nyes / no'}}];"
)

TEXT_JS = (
  "let{from,msgText,rawText,user,sd}=$json;"
  "const isSlash=msgText.startsWith('/');"
  "const cmd=isSlash?msgText.split(' ')[0]:null;"
  "const cmdArg=isSlash?(parseInt(msgText.split(' ')[1])||null):null;"
  "const mc=(t)=>isSlash&&cmd===t;"
  "if(user.etape>0&&user.etape!==99&&isSlash){"
  " user.previousEtape=user.etape;user.etape=99;user.pendingCmd=msgText;"
  " sd.utilisateurs[from]=user;"
  " return[{json:{action:'send',to:from,text:'Flow in progress. Abandon?\nyes / no'}}];"
  "}"
  "if(user.etape===99){"
  " const ok=msgText==='yes';"
  " if(ok){msgText=user.pendingCmd;"
  " user.etape=0;user.flux={};user.pendingCmd=null;user.previousEtape=null;"
  " sd.utilisateurs[from]=user;"
  " }else{"
  " user.etape=user.previousEtape??0;user.previousEtape=null;user.pendingCmd=null;"
  " sd.utilisateurs[from]=user;"
  " return[{json:{action:'send',to:from,text:'OK, continuing.'}}];"
  " }"
  "}"
  "if(mc('/list'))return[{json:{action:'crud_liste',from,sd}}];"
  "if(mc('/view'))return[{json:{action:'crud_voir',from,sd,n:cmdArg}}];"
  "if(mc('/edit'))return[{json:{action:'crud_edit',from,sd,n:cmdArg}}];"
  "if(mc('/help'))return[{json:{action:'aide',from}}];"
  "if(mc('/cancel')&&msgText.includes('all'))"
  " return[{json:{action:'crud_cancel_all',from,sd}}];"
  "if(mc('/cancel'))return[{json:{action:'crud_cancel',from,sd,n:cmdArg}}];"
  "return[{json:{action:'flux',from,rawText,msgText,user,sd}}];"
)

FLUX_CRUD_JS = (
  "const{action,from,rawText,msgText,user,sd,n}=$json;"
  "const fl=user?.flux??{};"
  "const TZ=sd.config?.timezone??'UTC';"
  "const cfg=sd.config??{};"
  "const{DateTime}=require('luxon');"
  "const M={"
  " askDate:'Number ok. Send date (ex: 20/05/2026)',"
  " askTime:'Date ok. Send time (ex: 14:30)',"
  " askMsg:'Time ok. Send your message (text or voice note)',"
  " askPre:'Message received.\n1=Default pre-message\n2=None\n3=Custom',"
  " askCustom:'Write your pre-message:',"
  " confirm:(f)=>'Confirm?\\n\u{1F4CD} '+f.destinataire+'\\n\u{1F552} '+f.scheduledLocal+'\\n\u{1F4AC} \"'+f.message+'\"\\n\\nyes / no',"
  " saved:(id)=>'Scheduled! Ref: '+id+'\\n/list to view',"
  " badNum:'Invalid number. Ex: 33612345678',"
  " badDate:'Invalid or past date. Ex: 20/05/2026',"
  " badTime:'Invalid or past time. Ex: 14:30',"
  " badPre:'Reply 1, 2 or 3',"
  " warnNone:'Recipient will receive the message without any context.',"
  " cancelled:'Flow cancelled.',"
  " noMsgs:'No scheduled messages.',"
  " notFound:'Message not found.',"
  " notCancel:'Message already sent.',"
  " deleted:'Message deleted.',"
  " deletedAll:'All messages deleted.',"
  " confirmDel:(id)=>'Delete '+id+'?\\nyes / no',"
  " confirmDelAll:'Delete ALL messages?\\nyes / no',"
  " editMenu:'What to edit?\\n1=Number 2=Date 3=Time 4=Message 5=Pre-message',"
  " help:'Commands: /list  /view [n]  /edit [n]  /cancel [n]  /help\\n\\n"
  "Schedule a message:\\n"
  "  Send the recipient number, then follow the prompts:\\n"
  "  → date (ex: 25/05/2026)\\n"
  "  → time (ex: 14:30)\\n"
  "  → your message (text or voice note)\\n"
  "  → pre-message (1=default  2=none  3=custom)\\n"
  "  → confirm with yes\\n\\n"
  "  Shortcut — send all at once:\\n"
  "  33612345678\\n"
  "  25/05/2026\\n"
  "  14:30\\n"
  "  Your message here\\n\\n"
  "Voice notes → instant transcription by Gemini.\\n"
  "Timeout: 30 min of inactivity resets the flow.'"
  "};"
  "function pd(s){"
  " if(/^\\d{2}\\/\\d{2}\\/\\d{4}$/.test(s))return DateTime.fromFormat(s,'dd/MM/yyyy',{zone:TZ});"
  " if(/^\\d{4}-\\d{2}-\\d{2}$/.test(s))return DateTime.fromFormat(s,'yyyy-MM-dd',{zone:TZ});"
  " return null;"
  "}"
  "function vd(s){const d=pd(s);return d?.isValid&&d>=DateTime.now().setZone(TZ).startOf('day');}"
  "function vdt(ds,ts){"
  " const d=pd(ds);if(!d?.isValid)return false;"
  " const[h,m]=ts.split(':').map(Number);"
  " if(isNaN(h)||isNaN(m)||h>23||m>59)return false;"
  " return d.set({hour:h,minute:m})>DateTime.now().setZone(TZ);"
  "}"
  "function toSched(ds,ts){"
  " const d=pd(ds);const[h,m]=ts.split(':').map(Number);"
  " const full=d.set({hour:h,minute:m,second:0});"
  " return{utc:full.toUTC().toISO(),local:full.toFormat('dd/MM/yyyy')+' at '+ts+' ('+TZ+')'};"
  "}"
  "const isOui=msgText==='yes';"
  "const isNon=msgText==='no';"
  "if(action==='aide')return[{json:{action:'send',to:from,text:M.help}}];"
  "if(action==='crud_liste'){"
  " const ms=(sd.messages??[]).filter(m=>['pending','sending'].includes(m.status));"
  " if(!ms.length)return[{json:{action:'send',to:from,text:M.noMsgs}}];"
  " const list=ms.map((m,i)=>'#'+(i+1)+' '+m.id.substring(0,18)+'\\n '"
  "  +m.destinataire+' | \u{1F552} '+m.scheduledLocal+' | '+m.status).join('\\n\\n');"
  " return[{json:{action:'send',to:from,text:'\u{1F4CB} '+list+'\\n\\n/view /edit /cancel'}}];"
  "}"
  "if(action==='crud_voir'){"
  " const msg=(sd.messages??[]).find(m=>n?m.id.includes(String(n)):false);"
  " if(!msg)return[{json:{action:'send',to:from,text:M.notFound}}];"
  " return[{json:{action:'send',to:from,"
  "  text:'\u{1F4CB} '+msg.id+'\\n\u{1F4CD} '+msg.destinataire+'\\n\u{1F552} '+msg.scheduledLocal"
  "  +'\\n\u{1F4AC} \"'+msg.message+'\"\\nStatus: '+msg.status}}];"
  "}"
  "if(action==='crud_cancel'){"
  " const msg=(sd.messages??[]).find(m=>n?m.id.includes(String(n)):false);"
  " if(!msg)return[{json:{action:'send',to:from,text:M.notFound}}];"
  " if(msg.status==='sent')return[{json:{action:'send',to:from,text:M.notCancel}}];"
  " user.pendingCancelId=msg.id;sd.utilisateurs[from]=user;"
  " return[{json:{action:'send',to:from,text:M.confirmDel(msg.id.substring(0,18))}}];"
  "}"
  "if(action==='crud_cancel_all'){"
  " user.pendingCancelAll=true;sd.utilisateurs[from]=user;"
  " return[{json:{action:'send',to:from,text:M.confirmDelAll}}];"
  "}"
  "if(action==='crud_edit'){"
  " const msg=(sd.messages??[]).find(m=>n?m.id.includes(String(n)):false);"
  " if(!msg)return[{json:{action:'send',to:from,text:M.notFound}}];"
  " user.editingMsgId=msg.id;user.editingField=null;"
  " sd.utilisateurs[from]=user;"
  " return[{json:{action:'send',to:from,text:M.editMenu}}];"
  "}"
  "if(user.pendingCancelId&&(isOui||isNon)){"
  " const cid=user.pendingCancelId;user.pendingCancelId=null;"
  " sd.utilisateurs[from]=user;"
  " if(isOui){"
  "  const msg=(sd.messages??[]).find(m=>m.id===cid);"
  "  if(msg){msg.status='cancelled';msg.updatedAt=new Date().toISOString();}"
  "  return[{json:{action:'send',to:from,text:M.deleted}}];"
  " }return[{json:{action:'send',to:from,text:'OK.'}}];"
  "}"
  "if(user.pendingCancelAll&&(isOui||isNon)){"
  " user.pendingCancelAll=false;sd.utilisateurs[from]=user;"
  " if(isOui){"
  "  (sd.messages??[]).forEach(m=>{"
  "   if(['pending','sending'].includes(m.status)){"
  "    m.status='cancelled';m.updatedAt=new Date().toISOString();"
  "   }});"
  "  return[{json:{action:'send',to:from,text:M.deletedAll}}];"
  " }return[{json:{action:'send',to:from,text:'OK.'}}];"
  "}"
  "if(user.editingMsgId&&!user.editingField){"
  " const choice=parseInt(msgText);"
  " if([1,2,3,4,5].includes(choice)){"
  "  user.editingField=['destinataire','date','heure','message','premessageType'][choice-1];"
  "  sd.utilisateurs[from]=user;"
  "  const ask=['New number:','New date (ex: 20/05/2026):','New time (ex: 14:30):','New message:','Pre-message (1=default 2=none 3=custom):'][choice-1];"
  "  return[{json:{action:'send',to:from,text:ask}}];"
  " }user.editingMsgId=null;sd.utilisateurs[from]=user;"
  " return[{json:{action:'send',to:from,text:'Cancelled.'}}];"
  "}"
  "if(user.editingMsgId&&user.editingField){"
  " const msg=(sd.messages??[]).find(m=>m.id===user.editingMsgId);"
  " if(msg){"
  "  const f=user.editingField;"
  "  if(f==='destinataire'){"
  "   if(!/^[0-9]{8,15}$/.test(rawText))return[{json:{action:'send',to:from,text:M.badNum}}];"
  "   msg.destinataire=rawText;"
  "  }else if(f==='date'){"
  "   if(!vd(rawText))return[{json:{action:'send',to:from,text:M.badDate}}];"
  "   msg.date=rawText;"
  "  }else if(f==='heure'){"
  "   if(!vdt(msg.date??msg.scheduledLocal,rawText))return[{json:{action:'send',to:from,text:M.badTime}}];"
  "   const sc=toSched(msg.date??msg.scheduledLocal.split(' ')[0],rawText);"
  "   msg.scheduledAtUtc=sc.utc;msg.scheduledLocal=sc.local;msg.heure=rawText;"
  "  }else if(f==='message'){msg.message=rawText;"
  "  }else if(f==='premessageType'){"
  "   if(msgText==='1')msg.premessageType='default';"
  "   else if(msgText==='2')msg.premessageType='none';"
  "   else if(msgText==='3')msg.premessageType='custom';"
  "  }"
  "  msg.updatedAt=new Date().toISOString();"
  " }"
  " user.editingMsgId=null;user.editingField=null;sd.utilisateurs[from]=user;"
  " return[{json:{action:'send',to:from,text:'Modified!'}}];"
  "}"
  "if(user.etape===0){"
  " const lines=rawText.split('\\n').map(s=>s.trim()).filter(Boolean);"
  " if(lines.length>=4){"
  "  const[num,ds,ts,...mp]=lines;"
  "  if(!/^[0-9]{8,15}$/.test(num))return[{json:{action:'send',to:from,text:M.badNum}}];"
  "  if(!vd(ds))return[{json:{action:'send',to:from,text:M.badDate}}];"
  "  if(!vdt(ds,ts))return[{json:{action:'send',to:from,text:M.badTime}}];"
  "  const sc=toSched(ds,ts);"
  "  fl.destinataire=num;fl.date=ds;fl.heure=ts;fl.message=mp.join(' ');"
  "  fl.scheduledAtUtc=sc.utc;fl.scheduledLocal=sc.local;"
  "  user.etape=4;user.flux=fl;sd.utilisateurs[from]=user;"
  "  return[{json:{action:'send',to:from,text:M.askPre}}];"
  " }"
  " if(/^[0-9]{8,15}$/.test(rawText)){"
  "  fl.destinataire=rawText;user.etape=1;user.flux=fl;sd.utilisateurs[from]=user;"
  "  return[{json:{action:'send',to:from,text:M.askDate}}];"
  " }return[{json:{action:'send',to:from,text:M.badNum}}];"
  "}"
  "if(user.etape===1){"
  " if(!vd(rawText))return[{json:{action:'send',to:from,text:M.badDate}}];"
  " fl.date=rawText;user.etape=2;user.flux=fl;sd.utilisateurs[from]=user;"
  " return[{json:{action:'send',to:from,text:M.askTime}}];"
  "}"
  "if(user.etape===2){"
  " if(!vdt(fl.date,rawText))return[{json:{action:'send',to:from,text:M.badTime}}];"
  " const sc=toSched(fl.date,rawText);"
  " fl.heure=rawText;fl.scheduledAtUtc=sc.utc;fl.scheduledLocal=sc.local;"
  " user.etape=3;user.flux=fl;sd.utilisateurs[from]=user;"
  " return[{json:{action:'send',to:from,text:M.askMsg}}];"
  "}"
  "if(user.etape===3){"
  " if(fl.pendingTranscription){"
  "  if(isOui){fl.message=fl.pendingTranscription;fl.pendingTranscription=null;}"
  "  else if(isNon){fl.pendingTranscription=null;user.flux=fl;sd.utilisateurs[from]=user;"
  "   return[{json:{action:'send',to:from,text:'Send a message or voice note.'}}];}"
  "  else{fl.message=rawText;fl.pendingTranscription=null;}"
  " }else{fl.message=rawText;}"
  " user.etape=4;user.flux=fl;sd.utilisateurs[from]=user;"
  " return[{json:{action:'send',to:from,text:M.askPre}}];"
  "}"
  "if(user.etape===4){"
  " if(msgText==='1'){fl.premessageType='default';user.etape=6;}"
  " else if(msgText==='2'){fl.premessageType='none';user.etape=6;}"
  " else if(msgText==='3'){user.etape=5;user.flux=fl;sd.utilisateurs[from]=user;"
  "  return[{json:{action:'send',to:from,text:M.askCustom}}];}"
  " else return[{json:{action:'send',to:from,text:M.badPre}}];"
  " user.flux=fl;sd.utilisateurs[from]=user;"
  " const pre=fl.premessageType==='none'?M.warnNone+'\\n\\n':'';"
  " return[{json:{action:'send',to:from,text:pre+M.confirm(fl)}}];"
  "}"
  "if(user.etape===5){"
  " fl.premessageType='custom';fl.customPremessage=rawText;"
  " user.etape=6;user.flux=fl;sd.utilisateurs[from]=user;"
  " return[{json:{action:'send',to:from,text:M.confirm(fl)}}];"
  "}"
  "if(user.etape===6){"
  " if(!isOui){"
  "  user.etape=0;user.flux={};sd.utilisateurs[from]=user;"
  "  return[{json:{action:'send',to:from,text:M.cancelled}}];"
  " }"
  " const id='msg_'+Date.now()+'_'+Math.random().toString(36).substr(2,4);"
  " const nm={id,destinataire:fl.destinataire,timezone:TZ,"
  "  scheduledAtUtc:fl.scheduledAtUtc,scheduledLocal:fl.scheduledLocal,"
  "  message:fl.message,premessageType:fl.premessageType,"
  "  customPremessage:fl.customPremessage??null,"
  "  status:'pending',retryCount:0,nextRetryAtUtc:null,"
  "  sendingStartedAt:null,sendAttemptId:null,wahaMessageId:null,"
  "  lastError:null,createdAt:new Date().toISOString(),"
  "  updatedAt:new Date().toISOString(),sentAt:null};"
  " sd.messages.push(nm);"
  " user.etape=0;user.flux={};sd.utilisateurs[from]=user;"
  " return[{json:{action:'send',to:from,text:M.saved(id)}}];"
  "}"
  "return[{json:{action:'send',to:from,text:'Type /help for help.'}}];"
)

GUARDIAN_JS = (
  "const sd=$getWorkflowStaticData('global');"
  "sd.messages=sd.messages??[];"
  "const now=Date.now();"
  "const cfg=sd.config??{};"
  "sd.messages.forEach(msg=>{"
  " if(msg.status==='sending'&&msg.sendingStartedAt&&"
  "  now-new Date(msg.sendingStartedAt).getTime()>5*60*1000){"
  "  msg.status='pending';msg.sendingStartedAt=null;"
  "  msg.nextRetryAtUtc=new Date(now+2*60*1000).toISOString();"
  "  msg.lastError=(msg.lastError??'')+' [recovery]';"
  "  msg.updatedAt=new Date(now).toISOString();"
  " }"
  "});"
  "const toSend=sd.messages.filter(msg=>"
  " msg.status==='pending'&&"
  " new Date(msg.scheduledAtUtc).getTime()<=now&&"
  " (!msg.nextRetryAtUtc||new Date(msg.nextRetryAtUtc).getTime()<=now));"
  "if(!toSend.length)return[];"
  "const att='att_'+now;"
  "toSend.forEach(msg=>{"
  " msg.status='sending';msg.sendingStartedAt=new Date(now).toISOString();"
  " msg.sendAttemptId=att+'_'+msg.id;msg.updatedAt=new Date(now).toISOString();"
  "});"
  "const PREMSG=cfg.premessageDefaut??process.env.DEFAULT_PREMESSAGE??'';"
  "const AUTH=cfg.numeroAutorise??process.env.AUTHORIZED_NUMBER??'';"
  "return toSend.map(msg=>{"
  " let t;"
  " if(msg.premessageType==='default')t=PREMSG+'\\n\"'+msg.message+'\"';"
  " else if(msg.premessageType==='custom')t=(msg.customPremessage??'')+'\\n\"'+msg.message+'\"';"
  " else t=msg.message;"
  " return{json:{msgId:msg.id,to:msg.destinataire,text:t,authNum:AUTH}};"
  "});"
)

PROCESS_RESULT_JS = (
  "const sd=$getWorkflowStaticData('global');"
  "const guardianItems=$('Guardian Logic').all();"
  "const wahaResp=$input.first().json??{};"
  "const src=guardianItems[$itemIndex]?.json??{};"
  "const msgId=src.msgId;const authNum=src.authNum;"
  "const now=new Date().toISOString();"
  "const msg=(sd.messages??[]).find(m=>m.id===msgId);"
  "if(!msg)return[{json:{action:'notify',to:authNum,text:'[log] not found: '+msgId}}];"
  "const wahaId=wahaResp?.id??wahaResp?.key?.id??null;"
  "if(wahaId){"
  " msg.status='sent';msg.wahaMessageId=wahaId;msg.sentAt=now;"
  " msg.updatedAt=now;msg.sendingStartedAt=null;"
  " return[{json:{action:'notify',to:authNum,"
  "  text:'✅ Message sent!\n\u{1F4CD} '+msg.destinataire+'\n\u{1F552} '+msg.scheduledLocal}}];"
  "}"
  "msg.retryCount=(msg.retryCount??0)+1;"
  "msg.lastError=JSON.stringify(wahaResp).substring(0,300);"
  "msg.updatedAt=now;msg.sendingStartedAt=null;"
  "if(msg.retryCount>=3){"
  " msg.status='failed';"
  " return[{json:{action:'notify',to:authNum,"
  "  text:'❌ Failed (3 attempts)\\n\u{1F4CD} '+msg.destinataire+'\\nError: '+msg.lastError.substring(0,80)}}];"
  "}"
  "msg.status='pending';msg.nextRetryAtUtc=new Date(Date.now()+2*60*1000).toISOString();"
  "return[{json:{action:'notify',to:authNum,"
  " text:'[log] Retry #'+msg.retryCount+' for '+msgId}}];"
)

# ── Construction Workflow Receiver ─────────────────────────────────────────────
WF_RECV = {
  "name": "WA Bot - Receiver",
  "active": True,
  "settings": {"executionOrder": "v1"},
  "nodes": [
    {"id":"n_wh","name":"Webhook WAHA","type":"n8n-nodes-base.webhook",
     "typeVersion":1.1,"position":[100,300],
     "parameters":{"path":"waha","responseMode":"onReceived","options":{}}},
    {"id":"n_init","name":"Init Security","type":"n8n-nodes-base.code",
     "typeVersion":2,"position":[300,300],"parameters":{"jsCode":INIT_JS}},
    {"id":"n_sw","name":"Switch Type","type":"n8n-nodes-base.switch",
     "typeVersion":3,"position":[500,300],
     "parameters":{"mode":"expression",
       "output":"={{ ['audio','ptt','voice'].includes($json.msgType) ? 0 : 1 }}"}},
    {"id":"n_ah","name":"Audio Handler","type":"n8n-nodes-base.code",
     "typeVersion":2,"position":[700,160],"parameters":{"jsCode":AUDIO_JS}},
    {"id":"n_dl","name":"Download Audio","type":"n8n-nodes-base.httpRequest",
     "typeVersion":4.4,"position":[900,160],
     "parameters":{"method":"GET",
       "url":"={{ $('Audio Handler').first().json.mediaUrl }}",
       "sendHeaders":True,"headerParameters":{"parameters":[
         {"name":"X-Api-Key","value":"={{$env.WAHA_API_KEY}}"}]},
       "options":{"response":{"response":{"responseFormat":"file"}},"timeout":15000}}},
    {"id":"n_eb","name":"Extract Base64","type":"n8n-nodes-base.code",
     "typeVersion":2,"position":[1100,160],
     "parameters":{"jsCode":"const audioBase64=$input.first().binary.data.data;return[{json:{audioBase64}}];"}},
    {"id":"n_gm","name":"Gemini Transcribe","type":"n8n-nodes-base.httpRequest",
     "typeVersion":4.2,"position":[1300,160],
     "parameters":{"method":"POST",
       "url":"=https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent?key={{$env.GEMINI_API_KEY}}",
       "sendBody":True,"specifyBody":"json",
       "jsonBody":"={{ JSON.stringify({contents:[{parts:[{inline_data:{mime_type:'audio/ogg',data:$json.audioBase64}},{text:'Transcribe this audio to text. Return only the transcribed text.'}]}]}) }}",
       "options":{"timeout":30000}}},
    {"id":"n_del","name":"Delete Audio","type":"n8n-nodes-base.httpRequest",
     "typeVersion":4,"position":[1500,160],
     "parameters":{"method":"DELETE",
       "url":"=http://waha:3000/api/default/media/{{$('Audio Handler').first().json.mediaId}}",
       "sendHeaders":True,"headerParameters":{"parameters":[
         {"name":"X-Api-Key","value":"={{$env.WAHA_API_KEY}}"}]},
       "options":{"timeout":5000},"continueOnFail":True}},
    {"id":"n_gr","name":"Gemini Result","type":"n8n-nodes-base.code",
     "typeVersion":2,"position":[1700,160],"parameters":{"jsCode":GEMINI_RESULT_JS}},
    {"id":"n_th","name":"Text Handler","type":"n8n-nodes-base.code",
     "typeVersion":2,"position":[700,420],"parameters":{"jsCode":TEXT_JS}},
    {"id":"n_fc","name":"Flux CRUD Handler","type":"n8n-nodes-base.code",
     "typeVersion":2,"position":[1000,420],"parameters":{"jsCode":FLUX_CRUD_JS}},
    {"id":"n_sr","name":"Send Response","type":"n8n-nodes-base.httpRequest",
     "typeVersion":4,"position":[1900,300],
     "parameters":{"method":"POST",
       "url":"http://waha:3000/api/default/sendText",
       "sendHeaders":True,"headerParameters":{"parameters":[
         {"name":"X-Api-Key","value":"={{$env.WAHA_API_KEY}}"}]},
       "sendBody":True,"contentType":"json",
       "body":"={\"chatId\":\"{{$json.to}}@s.whatsapp.net\",\"text\":\"{{$json.text}}\"}",
       "options":{"timeout":15000},"continueOnFail":True}},
  ],
  "connections": {
    "Webhook WAHA":      {"main":[[{"node":"Init Security",     "type":"main","index":0}]]},
    "Init Security":     {"main":[[{"node":"Switch Type",       "type":"main","index":0}]]},
    "Switch Type":       {"main":[
      [{"node":"Audio Handler",    "type":"main","index":0}],
      [{"node":"Text Handler",     "type":"main","index":0}],
    ]},
    "Audio Handler":     {"main":[[{"node":"Download Audio",    "type":"main","index":0}]]},
    "Download Audio":    {"main":[[{"node":"Extract Base64",    "type":"main","index":0}]]},
    "Extract Base64":    {"main":[[{"node":"Gemini Transcribe", "type":"main","index":0}]]},
    "Gemini Transcribe": {"main":[[{"node":"Delete Audio",      "type":"main","index":0}]]},
    "Delete Audio":      {"main":[[{"node":"Gemini Result",     "type":"main","index":0}]]},
    "Gemini Result":     {"main":[[{"node":"Send Response",     "type":"main","index":0}]]},
    "Text Handler":      {"main":[[{"node":"Flux CRUD Handler", "type":"main","index":0}]]},
    "Flux CRUD Handler": {"main":[[{"node":"Send Response",     "type":"main","index":0}]]},
  }
}

# ── Construction Workflow Guardian ─────────────────────────────────────────────
WF_GARD = {
  "name": "WA Bot - Guardian",
  "active": True,
  "settings": {"executionOrder": "v1"},
  "nodes": [
    {"id":"g_sc","name":"Schedule","type":"n8n-nodes-base.scheduleTrigger",
     "typeVersion":1.1,"position":[100,300],
     "parameters":{"rule":{"interval":[{"field":"minutes","minutesInterval":1}]}}},
    {"id":"g_gl","name":"Guardian Logic","type":"n8n-nodes-base.code",
     "typeVersion":2,"position":[300,300],"parameters":{"jsCode":GUARDIAN_JS}},
    {"id":"g_hs","name":"HTTP Send WAHA","type":"n8n-nodes-base.httpRequest",
     "typeVersion":4,"position":[500,300],
     "parameters":{"method":"POST",
       "url":"http://waha:3000/api/default/sendText",
       "sendHeaders":True,"headerParameters":{"parameters":[
         {"name":"X-Api-Key","value":"={{$env.WAHA_API_KEY}}"}]},
       "sendBody":True,"contentType":"json",
       "body":"={\"chatId\":\"{{$json.to}}@s.whatsapp.net\",\"text\":\"{{$json.text}}\"}",
       "options":{"timeout":15000}}},
    {"id":"g_pr","name":"Process Result","type":"n8n-nodes-base.code",
     "typeVersion":2,"position":[700,300],"parameters":{"jsCode":PROCESS_RESULT_JS}},
    {"id":"g_nt","name":"Send Notification","type":"n8n-nodes-base.httpRequest",
     "typeVersion":4,"position":[900,300],
     "parameters":{"method":"POST",
       "url":"http://waha:3000/api/default/sendText",
       "sendHeaders":True,"headerParameters":{"parameters":[
         {"name":"X-Api-Key","value":"={{$env.WAHA_API_KEY}}"}]},
       "sendBody":True,"contentType":"json",
       "body":"={\"chatId\":\"{{$json.to}}@s.whatsapp.net\",\"text\":\"{{$json.text}}\"}",
       "options":{"timeout":10000},"continueOnFail":True}},
  ],
  "connections": {
    "Schedule":       {"main":[[{"node":"Guardian Logic",    "type":"main","index":0}]]},
    "Guardian Logic": {"main":[[{"node":"HTTP Send WAHA",    "type":"main","index":0}]]},
    "HTTP Send WAHA": {"main":[[{"node":"Process Result",    "type":"main","index":0}]]},
    "Process Result": {"main":[[{"node":"Send Notification", "type":"main","index":0}]]},
  }
}

with open(f"{DIR}/workflows/workflow-receiver.json","w") as f:
  json.dump(WF_RECV, f, ensure_ascii=False, indent=2)
print(f"OK workflow-receiver.json ({len(WF_RECV['nodes'])} nodes)")

with open(f"{DIR}/workflows/workflow-guardian.json","w") as f:
  json.dump(WF_GARD, f, ensure_ascii=False, indent=2)
print(f"OK workflow-guardian.json ({len(WF_GARD['nodes'])} nodes)")
GEN_EOF
chmod +x "$DIR/scripts/gen_workflows.py"
ok "gen_workflows.py written"

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
# SECTION 9 — WAITING FOR n8n + API KEY (manual entry)
# ════════════════════════════════════════════════════════════
log "Waiting for n8n (up to 90s)..."
for i in $(seq 1 30); do
  CODE=$(curl -sf -o/dev/null -w"%{http_code}" \
    http://localhost:5678/healthz 2>/dev/null || echo "000")
  [[ "$CODE" == "200" ]] && break
  [[ $i -eq 30 ]] && err "n8n unreachable after 90s — check docker logs n8n"
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
bash "$DIR/scripts/insert-workflows.sh" "$N8N_API_KEY"
ok "Workflows imported and activated"

# ════════════════════════════════════════════════════════════
# SECTION 11 — FINAL SUMMARY
# ════════════════════════════════════════════════════════════
echo ""
echo -e "${GRN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GRN}  INSTALLATION COMPLETED${NC}"
echo -e "${GRN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

if [[ -n "$DOMAIN" ]]; then
  echo -e "  ${CYA}n8n${NC}           → https://${DOMAIN}"
  echo -e "  ${CYA}WAHA dashboard${NC} → https://${DOMAIN}/waha/dashboard"
  echo -e "  ${CYA}WAHA API${NC}       → https://${DOMAIN}/waha"
else
  echo -e "  ${CYA}n8n${NC}           → http://${IP}:5678"
  echo -e "  ${CYA}WAHA dashboard${NC} → http://${IP}:3000/dashboard"
  echo -e "  ${CYA}WAHA API${NC}       → http://${IP}:3000"
  echo ""
  echo -e "  ${YEL}Or via SSH tunnel:${NC}"
  echo -e "  ${YEL}  ssh -L 5678:127.0.0.1:5678 -L 3000:127.0.0.1:3000 root@${IP}${NC}"
  echo -e "  ${YEL}  Then open: http://localhost:3000/dashboard${NC}"
fi

echo ""
echo -e "  ${CYA}n8n${NC}            → ${N8N_URL}"
echo -e "  ${CYA}WAHA user${NC}      → ${WAHA_USER}"
echo ""
echo -e "  ${YEL}NEXT STEP:${NC}"
echo -e "  ${YEL}  1. Open the WAHA dashboard${NC}"
echo -e "  ${YEL}  2. Go to Sessions > default > Start${NC}"
echo -e "  ${YEL}  3. Scan the QR code with WhatsApp${NC}"
echo -e "  ${YEL}  4. Status must switch to WORKING${NC}"
echo ""

# Save the summary
cat > "$DIR/INSTALL_INFO.txt" <<INFO
WhatsApp Bot v4.2 Installation
Date: $(date)
IP  : ${IP}
$([ -n "$DOMAIN" ] && echo "Domain: ${DOMAIN}" || echo "Direct access: http://${IP}:3000")

n8n URL      : ${N8N_URL}
WAHA user    : ${WAHA_USER}
N8N API KEY  : ${N8N_API_KEY}

WAHA dashboard: $([ -n "$DOMAIN" ] && echo "https://${DOMAIN}/waha/dashboard" || echo "http://${IP}:3000/dashboard")
n8n           : $([ -n "$DOMAIN" ] && echo "https://${DOMAIN}" || echo "http://${IP}:5678")
INFO
chmod 600 "$DIR/INSTALL_INFO.txt"
ok "Summary saved in /opt/waha-bot/INSTALL_INFO.txt"
