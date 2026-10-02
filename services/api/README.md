# PASS AI API

Spring Boot gateway for **health**, **inference status**, and **OpenAI-compatible** proxy to RunPod SGLang.

## Run locally

```powershell
cd services\api
copy ..\..\.env.example ..\..\.env
# Edit .env — inference URL + keys (see infra/runpod/README.md)

# With tunnel to RunPod:
# ..\..\infra\runpod\tunnel.ps1

.\mvnw spring-boot:run
```

## Endpoints

| Method | Path | Description |
|--------|------|-------------|
| GET | `/api/v1/health` | API alive |
| GET | `/api/v1/inference/status` | Upstream SGLang reachable |
| GET | `/v1/models` | Proxy to GPU server |
| POST | `/v1/chat/completions` | Proxy (JSON + SSE stream) |

If `PASS_AI_API_KEY` is set, `/v1/*` requires `Authorization: Bearer <PASS_AI_API_KEY>`.

Upstream auth uses `PASS_AI_INFERENCE_API_KEY` → SGLang on the pod.
