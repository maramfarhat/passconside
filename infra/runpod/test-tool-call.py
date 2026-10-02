#!/usr/bin/env python3
import json
import os
import urllib.request

key = open("/workspace/pass-ai/config/api-key.env").read().split("=", 1)[1].strip()
body = {
    "model": "Qwen/Qwen2.5-Coder-32B-Instruct",
    "messages": [{"role": "user", "content": "Use editor tool only: path=a.html new_text=hi"}],
    "tools": [
        {
            "type": "function",
            "function": {
                "name": "editor",
                "description": "edit",
                "parameters": {
                    "type": "object",
                    "properties": {"path": {"type": "string"}, "new_text": {"type": "string"}},
                    "required": ["path", "new_text"],
                },
            },
        }
    ],
    "max_tokens": 200,
    "stream": False,
}
req = urllib.request.Request(
    "http://127.0.0.1:30000/v1/chat/completions",
    data=json.dumps(body).encode(),
    headers={"Authorization": f"Bearer {key}", "Content-Type": "application/json"},
)
with urllib.request.urlopen(req, timeout=180) as resp:
    data = json.load(resp)
msg = data["choices"][0]["message"]
tc = msg.get("tool_calls") or []
print("parser_env", os.environ.get("PASS_AI_TOOL_CALL_PARSER"))
print("tool_calls", len(tc))
if tc:
    print("name", tc[0]["function"]["name"])
else:
    print("content", (msg.get("content") or "")[:500])
