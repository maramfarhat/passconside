# PASS AI — pick a model from the GPU server

## One-time setup

1. **Tunnel** (two ports — inference + admin):

   ```powershell
   cd passconside\infra\runpod
   .\tunnel.ps1
   ```

2. **`.env`** at repo root (inference + admin keys from the pod `api-key.env`).

3. **Start API**:

   ```powershell
   cd services\api
   mvn spring-boot:run
   ```

4. **PASS AI** → Settings → **OpenAI Compatible**:
   - Base URL: `http://127.0.0.1:8080/v1`
   - API key: same Bearer as the GPU server (or your `PASS_AI_API_KEY` if set)
   - Click refresh on models → pick **PASS AI Agent** or **Fast Coder 32B**

Switching models **restarts SGLang on the pod** (~2–5 minutes). Wait until the switch finishes before sending a long task.

## Models on the server

| Model ID | Label | Use |
|----------|--------|-----|
| `Qwen/Qwen3-Coder-Next-FP8` | PASS AI Agent — Coder Next FP8 | Best quality agent (slower) |
| `Qwen/Qwen3-Coder-30B-A3B-Instruct` | PASS AI Agent — Coder 30B MoE | **Recommended** — fast + native tools (download on pod first) |
| `Qwen/Qwen2.5-Coder-32B-Instruct` | Fast Coder 32B | Dense 32B agent; PASS API rewrites loose tool JSON for Cline |

Run `infra/runpod/deploy-runpod-scripts.ps1` once after pulling (fixes SGLang parser selection). See `PASS-AI-MODEL-RESEARCH.md`.

Only **one** is loaded in VRAM at a time.
