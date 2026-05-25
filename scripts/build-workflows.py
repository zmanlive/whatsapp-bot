#!/usr/bin/env python3
"""build-workflows.py — Windows-compatible alternative to build-workflows.sh"""
import json, os, sys

BASE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
JS   = os.path.join(BASE, "workflows", "js")
OUT  = os.path.join(BASE, "workflows")

def read(f):
    with open(os.path.join(JS, f), encoding="utf-8") as fh:
        return fh.read()

EXTRACT_B64 = (
    "const audioBase64 = $input.first().binary.data.data; "
    "return [{ json: { audioBase64 } }];"
)

def build(filename, mapping):
    path = os.path.join(OUT, filename)
    with open(path, encoding="utf-8") as fh:
        wf = json.load(fh)
    for node in wf["nodes"]:
        if node["name"] in mapping:
            node["parameters"]["jsCode"] = mapping[node["name"]]
    with open(path, "w", encoding="utf-8") as fh:
        json.dump(wf, fh, ensure_ascii=False, indent=2)
    print(f"[build] {filename} OK")

build("workflow-receiver.json", {
    "Init Security":     read("init-security.js"),
    "Merge Context":     read("merge-context.js"),
    "Audio Handler":     read("audio-handler.js"),
    "Extract Base64":    EXTRACT_B64,
    "Gemini Result":     read("gemini-result.js"),
    "Text Handler":      read("text-handler.js"),
    "Flux CRUD Handler": read("flux-crud.js"),
    "Build Msg SQL":     read("build-msg-sql.js"),
})

build("workflow-guardian.json", {
    "Guardian Logic": read("guardian-logic.js"),
    "Process Result": read("process-result.js"),
})

print("[build] Done.")
