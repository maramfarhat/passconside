# PASS AI IDE

Desktop IDE for **PASS Consulting Group**, based on **Visual Studio Code (Code-OSS)** with an integrated **PASS AI agent** (Cline engine, trimmed in `vendor/cline`).

| Layer | Technology |
|-------|------------|
| Desktop shell | VS Code OSS (Electron) |
| AI agent | `vendor/cline` → `pass-ai-agent` extension |
| Local API | Spring Boot 3, Java 17 (`services/api`) |
| GPU inference | RunPod + SGLang (OpenAI-compatible) |
| Database (optional) | PostgreSQL (`infra/docker-compose.yml`) |

---

## Phase 1 — Use PASS AI (no build)

For teammates who only need to **run** the app.

### Download

1. Open **[GitHub Releases](https://github.com/maramfarhat/passconside/releases)**.
2. Under **Assets**, download the latest **`PASS-AI-Setup-*.exe`** (Windows installer).
3. Run the installer and follow the wizard (optional desktop shortcut).
4. Launch **PASS AI** from the Start menu or desktop.

Optional: use the matching **`.SHA256.txt`** to verify the installer hash.

### First run

- Windows 10/11 **64-bit**.
- Windows SmartScreen may warn on unsigned builds — choose “More info” → “Run anyway” if your team trusts the release.
- Agent settings and data: `%USERPROFILE%\.pass-ai\`
- For **GPU-backed models**, complete [Connect PASS AI to the GPU server](#connect-pass-ai-to-the-gpu-server) below (tunnel + API + agent settings).

---

## Connect PASS AI to the GPU server

PASS AI can use **your team RunPod GPU** (SGLang) through a **local Spring Boot proxy**. The IDE talks to `http://127.0.0.1:18080/v1` — not directly to the public internet.

### Architecture

```
PASS AI (desktop)  →  Spring Boot API (:18080)  →  SSH tunnel  →  RunPod SGLang (:30000)
                              ↓
                        Admin API (:30001)  →  switch / catalog on GPU
```

### 1. One-time: repo root `.env`

```powershell
cd C:\dev\passconside   # or your clone path
copy .env.example .env
```

Edit `.env` (never commit this file):

| Variable | Example | Purpose |
|----------|---------|---------|
| `PASS_AI_INFERENCE_BASE_URL` | `http://127.0.0.1:30000/v1` | SGLang on the pod (via tunnel) |
| `PASS_AI_INFERENCE_ADMIN_URL` | `http://127.0.0.1:30001` | Model switch / catalog |
| `PASS_AI_INFERENCE_API_KEY` | (from pod `api-key.env`) | Bearer token for SGLang |
| `PASS_AI_API_KEY` | (optional, same or your own) | Protects local `/v1/*` |
| `PASS_AI_DEFAULT_MODEL` | `Qwen/Qwen3-Coder-30B-A3B-Instruct` | Default when switching models |
| `SERVER_PORT` | `18080` | Local API port (avoid 8080 if Oracle TNS uses it) |

Get the inference key from the pod: `/workspace/pass-ai/config/api-key.env` (ops only — do not commit).

Sync key for the agent (writes `%USERPROFILE%\.pass-ai\inference-api-key`):

```powershell
cd desktop
.\scripts\sync-pass-ai-inference-key.ps1
```

### 2. Start the SSH tunnel (every session)

Forwards **30000** (inference) and **30001** (admin) from RunPod to your PC:

```powershell
cd infra\runpod
.\tunnel.ps1
```

Leave this window open. Requires SSH key: `%USERPROFILE%\.ssh\pass_ai_runpod` (see `infra/runpod/README.md`).

### 3. Start the Spring Boot backend (every session)

**Java 17** and **Maven** required (e.g. `choco install maven`).

```powershell
cd C:\dev\passconside
# Load .env into the shell (PowerShell example):
Get-Content .env | ForEach-Object {
  if ($_ -match '^\s*([^#=]+)=(.*)$') { Set-Item -Path "env:$($matches[1].Trim())" -Value $matches[2].Trim() }
}
$env:SERVER_PORT = "18080"   # if not already in .env

cd services\api
mvn spring-boot:run
```

Wait until you see `Tomcat started on port 18080`.

**Quick checks:**

```powershell
Invoke-RestMethod http://127.0.0.1:18080/api/v1/health
Invoke-RestMethod http://127.0.0.1:18080/api/v1/inference/status
```

More detail: [`services/api/README.md`](services/api/README.md).

### 4. Configure PASS AI (agent panel)

1. Open **PASS AI** → agent **Settings** (gear).
2. **API Provider:** **OpenAI Compatible**
3. **Base URL:** `http://127.0.0.1:18080/v1`
4. **API key:** same as `PASS_AI_API_KEY` if set, else the inference key from the pod / `inference-api-key` file.
5. **Model ID:** pick from the list (refresh if empty), e.g.:
   - **`PASS AI Agent — Coder 30B MoE`** — recommended daily Cline / Act mode
   - **`PASS AI Agent — Coder Next FP8`** — hardest tasks (slower)
   - **`Fast Coder 32B`** — dense 32B fallback

Model catalog and GPU ops: [`desktop/agent/PASS-AI-MODELS.md`](desktop/agent/PASS-AI-MODELS.md), [`infra/runpod/README.md`](infra/runpod/README.md).

Bundled endpoints (after install/build): `desktop/agent/endpoints.json` → `http://127.0.0.1:18080/v1`.

### 5. RunPod server (maintainers)

SSH and scripts live on the pod under `/workspace/pass-ai/`. From your PC:

```powershell
cd infra\runpod
.\deploy-runpod-scripts.ps1
# Optional: download models + switch to recommended agent
.\setup-recommended-inference.ps1
```

Research (VRAM, which models fit): [`desktop/agent/PASS-AI-MODEL-RESEARCH.md`](desktop/agent/PASS-AI-MODEL-RESEARCH.md).

---

## Phase 1 + clone — installed the `.exe` and want to change the code

You can **keep using the installed app** for daily work and **use the cloned repo** to develop. They are separate copies on disk: editing files in Git does **not** change the app in `Program Files` until you **rebuild and reinstall** (or test via a dev build below).

### One-time setup after clone

Use a folder **without spaces**, e.g. `C:\dev\passconside`:

```powershell
git clone https://github.com/maramfarhat/passconside.git C:\dev\passconside
cd C:\dev\passconside\desktop
```

Install tools (minimum for **agent** changes):

| Tool | Install |
|------|---------|
| **Bun** | [bun.sh](https://bun.sh) |
| **Node.js 20** | [nodejs.org](https://nodejs.org) (for built-in extensions) |
| **Java 17 + Maven** | For `services/api` (backend proxy) |

First agent build (downloads `vendor/cline` dependencies; several GB in `node_modules`, not in Git):

```powershell
.\scripts\build-pass-ai-agent.ps1
```

Your API keys and agent data stay in **`%USERPROFILE%\.pass-ai\`** — the same folder the installed PASS AI uses, so settings usually carry over when you test a new build.

### What to do for each kind of change

| You changed… | What to run | How to test |
|--------------|-------------|-------------|
| **Agent** (chat, MCP, tools, prompts) under `vendor/cline/apps/vscode` | `.\scripts\build-pass-ai-agent.ps1` | **A)** Install the generated `.vsix` from `desktop\vscode\extensions\pass-ai-agent\*.vsix` in your **installed** PASS AI (Extensions → **Install from VSIX**), **or** **B)** build a dev app folder (next row) |
| **Built-in extensions** `desktop/extensions/pass-ai-*` | `.\scripts\install-builtin-extensions.ps1` then full desktop build | Full desktop build (below) |
| **Backend / inference proxy** `services/api` | `mvn spring-boot:run` (see above) | Health + chat via `:18080` |
| **PASS branding / product.json / workbench** | Full desktop build | Run `desktop\VSCode-win32-x64\PASS AI.exe` **or** create a new installer |

**Full desktop rebuild** (first time needs VS Code source + ~40–60 GB disk; see Phase 2 prerequisites):

```powershell
cd C:\dev\passconside\desktop
.\scripts\setup-vscode.ps1          # once
.\scripts\build-pass-ai-agent.ps1
.\scripts\build-windows.ps1 -Launch   # dev copy: desktop\VSCode-win32-x64\PASS AI.exe
```

Use that **`PASS AI.exe`** in the repo folder to verify changes without touching the installed copy.

### Ship changes to teammates (new `.exe` on Releases)

After your changes work locally:

```powershell
cd C:\dev\passconside\desktop
.\scripts\build-pass-ai-agent.ps1
.\scripts\package-pass-ai-release.ps1 -Version "0.1.1" -InstallInnoSetup
```

Upload `desktop\out\releases\PASS-AI-Setup-0.1.1.exe` to [GitHub Releases](https://github.com/maramfarhat/passconside/releases). Teammates run the new installer (they can install over the old version).

### Git workflow (short)

```powershell
cd C:\dev\passconside
git checkout -b my-feature
# edit, test with steps above
git add .
git commit -m "Describe your change"
git push -u origin my-feature
```

Open a Pull Request on GitHub for review.

---

## Phase 2 — Clone, change code, rebuild

For teammates who **modify** the project (agent, branding, desktop shell, API).

### Prerequisites

| Tool | Used for |
|------|----------|
| **Git** | Clone repo |
| **Bun** | Build agent (`vendor/cline`) |
| **Node.js 20.x** | Scripts, built-in extensions |
| **Yarn 1.22.x** | VS Code source build |
| **Python 3.11+** | VS Code build (Windows) |
| **Visual Studio 2022** + Desktop C++ | Native modules in VS Code build |
| **Java 17 + Maven** | Spring Boot API |
| **~40–60 GB free disk** | Full desktop compile |

Clone (use a path **without spaces**):

```powershell
git clone https://github.com/maramfarhat/passconside.git C:\dev\passconside
cd C:\dev\passconside
```

### What Git contains vs what you generate locally

| In Git | Not in Git (you create locally) |
|--------|----------------------------------|
| Source: `vendor/cline` (trimmed), `desktop/scripts`, `desktop/extensions`, `services/api`, `infra/runpod`, … | `vendor/cline/**/node_modules`, `**/dist` |
| Docs, branding assets | `desktop/vscode/` (VS Code upstream clone) |
| | `desktop/VSCode-win32-x64/` (portable app — use **Releases** or build) |
| `.env.example` | `.env` (secrets) |

After clone, **always** install agent dependencies once:

```powershell
cd desktop
.\scripts\build-pass-ai-agent.ps1
```

### Optional: PostgreSQL

```powershell
cd infra
docker compose up -d
```

The API can run without Postgres for inference-only workflows.

### Re-import full upstream Cline (rare)

```powershell
cd desktop
.\scripts\trim-cline-vendor-for-pass-ai.ps1 -ReinstallDeps
.\scripts\build-pass-ai-agent.ps1
```

See `vendor/README.md` and `vendor/cline/PASS-AI-VENDOR.md`.

---

## Repository layout

```
passconside/
├── assets/branding/       # Logos and icons
├── desktop/               # Build scripts, built-in extensions, agent docs
│   ├── agent/README.md
│   └── scripts/
├── vendor/cline/          # Trimmed Cline engine (source in Git)
├── apps/web/              # Future web UI
├── services/api/          # Spring Boot API (inference proxy)
├── infra/runpod/          # Tunnel, GPU catalog, deploy scripts
├── infra/docker-compose.yml
└── docs/                  # Architecture and handoff notes
```

---

## License

- PASS AI scaffolding: MIT (see repo license file if present).
- VS Code: [Microsoft VS Code License](https://github.com/microsoft/vscode/blob/main/LICENSE.txt) when building from source.
- Cline-derived agent code: Apache-2.0 (`vendor/cline/LICENSE`).
