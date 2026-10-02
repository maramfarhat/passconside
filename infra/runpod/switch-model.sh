#!/usr/bin/env bash
set -euo pipefail
MODEL_ID="${1:?Usage: switch-model.sh <model-id>}"

PASS_AI_HOME=/workspace/pass-ai
CATALOG="$PASS_AI_HOME/config/models.catalog.json"
ENV_FILE="$PASS_AI_HOME/config/env.sh"
ACTIVE_FILE="$PASS_AI_HOME/config/active-model.txt"

python3 - <<'PY' "$MODEL_ID" "$CATALOG" "$ENV_FILE" "$ACTIVE_FILE"
import json, re, sys
model_id, catalog_path, env_path, active_path = sys.argv[1:5]
catalog = json.load(open(catalog_path, encoding="utf-8"))
match = next((m for m in catalog["models"] if m["id"] == model_id), None)
if not match:
    raise SystemExit(f"Unknown model id: {model_id}")
model_path = match["modelPath"]
parser = match.get("toolCallParser", "qwen3_coder")
ctx = str(match.get("contextLength", 65536))
open(active_path, "w", encoding="utf-8").write(model_id)
text = open(env_path, encoding="utf-8").read()
text = re.sub(r'^export PASS_AI_MODEL=.*$', f'export PASS_AI_MODEL={model_path}', text, flags=re.M)
text = re.sub(r'^export PASS_AI_CONTEXT_LENGTH=.*$', f'export PASS_AI_CONTEXT_LENGTH={ctx}', text, flags=re.M)
text = re.sub(r'^export PASS_AI_TOOL_CALL_PARSER=.*$', f'export PASS_AI_TOOL_CALL_PARSER={parser}', text, flags=re.M)
if "PASS_AI_TOOL_CALL_PARSER" not in text:
    text += f'\nexport PASS_AI_TOOL_CALL_PARSER={parser}\n'
open(env_path, "w", encoding="utf-8").write(text)
print(f"Active model: {model_id} -> {model_path}")
PY

bash "$PASS_AI_HOME/scripts/stop.sh" || true
bash "$PASS_AI_HOME/scripts/start.sh"
python3 "$PASS_AI_HOME/scripts/_wait_ready.py"
