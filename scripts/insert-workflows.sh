#!/bin/bash
# insert-workflows.sh — Imports pre-built workflow JSONs into n8n.
set -euo pipefail

N8N_KEY="${1:-}"
[[ -z "$N8N_KEY" ]] && { echo "Usage: $0 N8N_API_KEY"; exit 1; }

BASE="http://localhost:5678"
WORKFLOWS_DIR="/opt/waha-bot/workflows"

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
  local EX WF_ID RESP

  EX=$(curl -sf "$BASE/api/v1/workflows?limit=100" \
    -H "X-N8N-API-KEY: $N8N_KEY" 2>/dev/null \
    | python3 -c "
import sys, json
d = json.load(sys.stdin)
m = [str(w['id']) for w in d.get('data', []) if w.get('name') == '$NAME']
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
      "import sys, json; print(json.load(sys.stdin).get('id', ''))" 2>/dev/null || echo "")
    [[ -z "$WF_ID" ]] && { echo "Import failed: $(echo "$RESP" | head -c 200)"; exit 1; }
  fi

  curl -sf -o/dev/null \
    -X POST "$BASE/api/v1/workflows/$WF_ID/activate" \
    -H "X-N8N-API-KEY: $N8N_KEY" 2>/dev/null || true

  echo "[wf] OK: $NAME (id $WF_ID)"
}

upsert_wf "WA Bot - Receiver" "$WORKFLOWS_DIR/workflow-receiver.json"
upsert_wf "WA Bot - Guardian" "$WORKFLOWS_DIR/workflow-guardian.json"
echo "[wf] Finished — verify activation in n8n"
