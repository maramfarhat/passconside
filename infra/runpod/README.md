# RunPod GPU inference (PASS AI)

## What runs on the pod

| Item | Value |
|------|--------|
| Model (primary) | `Qwen/Qwen3-Coder-Next-FP8` (~76 GB on `/workspace/huggingface`) |
| Engine | SGLang on port **30000** (OpenAI API `/v1/*`) |
| Persistent data | `/workspace` (models, logs, venv) |
| Ops scripts | `/workspace/pass-ai/scripts/` (`start.sh`, `stop.sh`, `status.sh`) |

## SSH (ops)

```powershell
ssh root@198.13.252.107 -p 23008 -i $env:USERPROFILE\.ssh\pass_ai_runpod
```

Start / check inference:

```bash
bash /workspace/pass-ai/scripts/start.sh
bash /workspace/pass-ai/scripts/status.sh
```

API key for SGLang lives on the pod only: `/workspace/pass-ai/config/api-key.env` — **do not commit**.

## Connect PASS AI desktop → backend → GPU

1. **SSH tunnel** (simplest for dev):

   ```powershell
   ssh -N -L 30000:127.0.0.1:30000 -p 23008 -i $env:USERPROFILE\.ssh\pass_ai_runpod root@198.13.252.107
   ```

2. **Spring Boot proxy** (repo `services/api`):

   ```powershell
   copy .env.example .env
   # set PASS_AI_INFERENCE_BASE_URL=http://127.0.0.1:30000/v1
   # set PASS_AI_INFERENCE_API_KEY from pod api-key.env
   cd services\api
   .\mvnw spring-boot:run
   ```

3. **PASS AI agent** — provider **OpenAI Compatible**:
   - Base URL: `http://127.0.0.1:8080/v1`
   - API key: `PASS_AI_API_KEY` if you set one, else same as inference key
   - Model: `Qwen/Qwen3-Coder-Next-FP8`

Or point the agent directly at RunPod HTTPS proxy (port 30000 exposed in RunPod dashboard) with the SGLang Bearer key.

## Download extra models (on pod)

Primary agent model is already cached. Optional fast coder:

```bash
source /workspace/pass-ai/venv/bin/activate
export HF_HOME=/workspace/huggingface
huggingface-cli download Qwen/Qwen2.5-Coder-32B-Instruct --local-dir /workspace/models/Qwen2.5-Coder-32B-Instruct
```

Only **one** large model loads in VRAM at a time; switch `PASS_AI_MODEL` in `/workspace/pass-ai/config/env.sh` and restart SGLang.

## RunPod HTTP URL

In RunPod → Pod → **Connect** → expose port **30000**. Use:

`https://<pod-id>-30000.proxy.runpod.net/v1`

as `PASS_AI_INFERENCE_BASE_URL` (with Bearer auth).
