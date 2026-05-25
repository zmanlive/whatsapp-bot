# WhatsApp Bot v6.0

WhatsApp message scheduler + audio transcription.
Stack: n8n · WAHA · Gemini AI · PostgreSQL · Caddy · Docker · Ubuntu

---

## Installation

### Prerequisites
- Ubuntu 22.04 or 24.04 VPS (min. 2 GB RAM)
- SSH root access
- Gemini API key — [aistudio.google.com](https://aistudio.google.com)
- A dedicated WhatsApp number for the bot

### Single Command

```bash
curl -fsSL https://rafaeline.com/bot -o install.sh && sudo bash install.sh
```

### What the script asks for (≈ 2 minutes)

| # | Prompt | Example |
|---|--------|---------|
| 1/9 | WAHA API key (min. 16 chars) | `my_secret_waha_key_2024` |
| 2/9 | WAHA dashboard username | `admin` |
| 3/9 | WAHA dashboard password (min. 12 chars) | `MySecretPassword!` |
| 4/9 | Gemini API Key | `AIzaSy...` |
| 5/9 | Authorized number (digits only) | `33612345678` |
| 6/9 | Bot pre-message name | `Rafaeline` |
| 7/9 | Pre-message text (Enter = default) | `Scheduled message:` |
| 8/9 | Timezone | `Europe/Paris` |
| 9/9 | HTTPS Domain (empty = direct IP access) | `bot.mydomain.com` |

Then confirmation, followed by ~3 minutes of automatic installation.

### After Installation — 2 Manual Steps

**Step 1 — Configure n8n**

The script stops and displays the n8n URL. In your browser:
1. Open the displayed URL (e.g. `http://IP:5678`)
2. Create your owner account (email + password of your choice)
3. Go to **Settings > API > Create an API Key**
4. Give it a name, click Create, and **copy the key**
5. Paste it in the terminal when prompted by the script

**Step 2 — Scan the WhatsApp QR code**

1. Open the WAHA dashboard (e.g. `http://IP:3000/dashboard`)
2. Go to **Sessions > default > Start**
3. Scan the QR code using the WhatsApp app on the phone linked to the bot number
4. Status must switch to **WORKING**

---

## Usage

Send WhatsApp messages to the bot number from your authorized number.

### Schedule a Message

Send the recipient number — the bot will guide you step by step:

```
33698765432          ← recipient number
→ 25/05/2026         ← date
→ 14:30              ← time
→ Hello, see you tomorrow ← message (text or audio)
→ 1                  ← pre-message (1=default 2=none 3=custom)
→ yes                ← confirmation
```

Or in a single multi-line message:
```
33698765432
25/05/2026
14:30
Hello, see you tomorrow
```

### Commands

| Command | Action |
|----------|--------|
| `/list` | View all pending messages |
| `/view 1` | Details of message #1 |
| `/edit 1` | Edit number / date+time / message / pre-message |
| `/cancel 1` | Cancel message #1 |
| `/cancel all` | Cancel all messages |
| `/help` | Help |

### Audio

Send a voice note → instant transcription by Gemini.
If you are scheduling a message, the bot will ask if you want to use the transcription as the message text.

---

## Architecture

```
[WhatsApp] ──webhook──► [WAHA] ──► [n8n Receiver]
                                        ├─ audio → Gemini → PG Save User → response
                                        └─ text  → PG Read User+Messages → CRUD/flow
                                                   → PG Save User + PG Msg Op → response

[n8n Guardian] (every minute)
  └─ PG: recover stalled + select pending → mark sending → [WAHA] ──► [WhatsApp recipient]
       └─ PG: update message status (sent / retry / failed)

[PostgreSQL]
  ├─ n8n internal tables  (workflows, credentials, executions)
  ├─ bot_messages          (scheduled messages — status, retry, timestamps)
  └─ bot_user_state        (conversation state per user — step, draft, flags)
```

### n8n Workflows

| Workflow | Role | Trigger |
|----------|------|-------------|
| WA Bot - Receiver | Receives messages, transcribes audio, handles scheduling | WAHA Webhook |
| WA Bot - Guardian | Sends scheduled messages at the correct time, handles retries | Every minute |

### PostgreSQL Tables (v6.0)

| Table | Purpose |
|-------|---------|
| `bot_messages` | One row per scheduled message — full lifecycle tracking |
| `bot_user_state` | Conversation state per authorized user (`step`, `draft`, `flags`) |

---

## Stack

| Service | Version | Role |
|---------|---------|------|
| [n8n](https://n8n.io) | 1.70.0 | Workflow orchestration |
| [WAHA](https://waha.devlike.pro) | 2024.12 (NOWEB) | WhatsApp API |
| [Gemini](https://aistudio.google.com) | 2.0 Flash | Audio transcription |
| [PostgreSQL](https://www.postgresql.org) | 16 | n8n internals + bot data (messages, user state) |
| [Caddy](https://caddyserver.com) | 2.8 | HTTPS Reverse proxy (optional) |

---

## Server Directories

```
/opt/waha-bot/
├── scripts/
│   ├── build-workflows.py     ← injects JS into workflow JSONs (Windows/Linux)
│   ├── build-workflows.sh     ← same, Linux/jq version
│   └── insert-workflows.sh    ← creates PG credential + imports into n8n via API
├── workflows/
│   ├── js/                    ← source JS files (one per n8n Code node)
│   ├── workflow-receiver.json
│   └── workflow-guardian.json
├── sql/
│   └── schema.sql             ← bot_messages + bot_user_state table definitions
├── n8n_data/                  ← persistent n8n data
├── postgres_data/             ← PostgreSQL data volume
├── sessions/                  ← WAHA WhatsApp sessions
├── media/                     ← temporary audio files
├── .env                       ← API keys and secrets (chmod 600)
├── docker-compose.yml
└── INSTALL_INFO.txt           ← post-install summary (chmod 600)
```
