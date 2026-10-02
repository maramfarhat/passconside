#!/usr/bin/env python3
"""Lightweight PASS AI inference admin (catalog + model switch). Port 30001."""
from __future__ import annotations

import json
import os
import subprocess
import urllib.parse
from http.server import BaseHTTPRequestHandler, HTTPServer
from pathlib import Path

PASS_AI_HOME = Path("/workspace/pass-ai")
CATALOG_PATH = PASS_AI_HOME / "config" / "models.catalog.json"
ACTIVE_PATH = PASS_AI_HOME / "config" / "active-model.txt"
SWITCH_SCRIPT = PASS_AI_HOME / "scripts" / "switch-model.sh"


def load_api_key() -> str:
    for line in (PASS_AI_HOME / "config" / "api-key.env").read_text(encoding="utf-8").splitlines():
        if line.startswith("PASS_AI_API_KEY="):
            return line.split("=", 1)[1].strip()
    return ""


def auth_ok(header: str | None) -> bool:
    expected = load_api_key()
    if not expected:
        return True
    if not header or not header.startswith("Bearer "):
        return False
    return header[7:].strip() == expected


def active_id() -> str:
    if ACTIVE_PATH.is_file():
        return ACTIVE_PATH.read_text(encoding="utf-8").strip()
    catalog = json.loads(CATALOG_PATH.read_text(encoding="utf-8"))
    return catalog["models"][0]["id"]


class Handler(BaseHTTPRequestHandler):
    def _json(self, code: int, payload: object) -> None:
        body = json.dumps(payload).encode("utf-8")
        self.send_response(code)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def do_GET(self) -> None:
        if not auth_ok(self.headers.get("Authorization")):
            return self._json(401, {"error": "Unauthorized"})
        path = urllib.parse.urlparse(self.path).path
        if path == "/v1/catalog":
            catalog = json.loads(CATALOG_PATH.read_text(encoding="utf-8"))
            return self._json(200, {"activeModelId": active_id(), "models": catalog["models"]})
        if path == "/v1/active":
            return self._json(200, {"modelId": active_id()})
        if path == "/health":
            return self._json(200, {"status": "ok"})
        self._json(404, {"error": "not found"})

    def do_POST(self) -> None:
        if not auth_ok(self.headers.get("Authorization")):
            return self._json(401, {"error": "Unauthorized"})
        path = urllib.parse.urlparse(self.path).path
        if path != "/v1/active":
            return self._json(404, {"error": "not found"})
        length = int(self.headers.get("Content-Length", "0"))
        raw = self.rfile.read(length) if length else b"{}"
        data = json.loads(raw.decode("utf-8") or "{}")
        model_id = data.get("modelId") or data.get("model")
        if not model_id:
            return self._json(400, {"error": "modelId required"})
        if model_id == active_id():
            return self._json(200, {"modelId": model_id, "switched": False})
        subprocess.run(["bash", str(SWITCH_SCRIPT), model_id], check=True)
        return self._json(200, {"modelId": model_id, "switched": True})

    def log_message(self, fmt: str, *args: object) -> None:
        return


def main() -> None:
    port = int(os.environ.get("PASS_AI_ADMIN_PORT", "30001"))
    HTTPServer(("0.0.0.0", port), Handler).serve_forever()


if __name__ == "__main__":
    main()
