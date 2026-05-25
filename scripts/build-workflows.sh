#!/bin/bash
# build-workflows.sh — Injects JS files into workflow JSON templates using jq.
# Run this after modifying any file in workflows/js/ to rebuild the committed JSONs.
# Requires: jq >= 1.6
set -euo pipefail

REPO_DIR="$(cd "$(dirname "$0")/.." && pwd)"
JS="$REPO_DIR/workflows/js"
OUT="$REPO_DIR/workflows"

command -v jq &>/dev/null || { echo "jq is required (apt install jq)"; exit 1; }

echo "[build] Reading JS source files..."
INIT_JS=$(cat "$JS/init-security.js")
AUDIO_JS=$(cat "$JS/audio-handler.js")
GEMINI_RESULT_JS=$(cat "$JS/gemini-result.js")
TEXT_JS=$(cat "$JS/text-handler.js")
FLUX_CRUD_JS=$(cat "$JS/flux-crud.js")
GUARDIAN_JS=$(cat "$JS/guardian-logic.js")
PROCESS_RESULT_JS=$(cat "$JS/process-result.js")

EXTRACT_BASE64_JS='const audioBase64 = $input.first().binary.data.data; return [{ json: { audioBase64 } }];'

echo "[build] Building workflow-receiver.json..."
jq \
  --arg init        "$INIT_JS" \
  --arg audio       "$AUDIO_JS" \
  --arg extract     "$EXTRACT_BASE64_JS" \
  --arg gemini_res  "$GEMINI_RESULT_JS" \
  --arg text        "$TEXT_JS" \
  --arg flux_crud   "$FLUX_CRUD_JS" \
  '.nodes[] |= (
    if .name == "Init Security"     then .parameters.jsCode = $init       else . end |
    if .name == "Audio Handler"     then .parameters.jsCode = $audio      else . end |
    if .name == "Extract Base64"    then .parameters.jsCode = $extract    else . end |
    if .name == "Gemini Result"     then .parameters.jsCode = $gemini_res else . end |
    if .name == "Text Handler"      then .parameters.jsCode = $text       else . end |
    if .name == "Flux CRUD Handler" then .parameters.jsCode = $flux_crud  else . end
  )' \
  "$OUT/workflow-receiver.json" > /tmp/receiver-built.json
mv /tmp/receiver-built.json "$OUT/workflow-receiver.json"
echo "[build] workflow-receiver.json OK"

echo "[build] Building workflow-guardian.json..."
jq \
  --arg guardian    "$GUARDIAN_JS" \
  --arg proc_res    "$PROCESS_RESULT_JS" \
  '.nodes[] |= (
    if .name == "Guardian Logic" then .parameters.jsCode = $guardian  else . end |
    if .name == "Process Result" then .parameters.jsCode = $proc_res  else . end
  )' \
  "$OUT/workflow-guardian.json" > /tmp/guardian-built.json
mv /tmp/guardian-built.json "$OUT/workflow-guardian.json"
echo "[build] workflow-guardian.json OK"

echo "[build] Done. Commit workflows/*.json to persist changes."
