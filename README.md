# PASS AI IDE

Desktop IDE for **PASS Consulting Group**, based on **Visual Studio Code (Code-OSS)** with an integrated **PASS AI agent** (Cline engine, trimmed in `vendor/cline`).

| Layer | Technology |
|-------|------------|
| Desktop shell | VS Code OSS (Electron) |
| AI agent | `vendor/cline` → `pass-ai-agent` extension |
| API (planned) | Spring Boot 3, Java 17 |
| Database (planned) | PostgreSQL |

---

## Phase 1 — Use PASS AI (no build)

For teammates who only need to **run** the app.

### Download

1. Open **[GitHub Releases](https://github.com/maramfarhat/passconside/releases)**.
2. Under **Assets**, download **`PASS-AI-Setup-0.1.0.exe`** (Windows installer, ~170 MB).
3. Run the installer and follow the wizard (optional desktop shortcut).
4. Launch **PASS AI** from the Start menu or desktop.

Optional: use **`PASS-AI-Setup-….SHA256.txt`** to verify the installer hash.

### First run

- Windows 10/11 **64-bit**.
- Windows SmartScreen may warn on unsigned builds — choose “More info” → “Run anyway” if your team trusts the release.
- Agent settings and data: `%USERPROFILE%\.pass-ai\`
- Configure LLM keys in the agent panel (OpenRouter, etc.). **Do not commit API keys to Git.**

### What the installer includes

Full PASS AI IDE with bundled **`pass-ai-agent`**, welcome/layout extensions, and PASS branding (same files as `desktop/VSCode-win32-x64/` after a local build).

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
.\scripts\package-pass-ai-release.ps1 -Version "0.1.1"
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
| **~40–60 GB free disk** | Full desktop compile |

Clone (use a path **without spaces**):

```powershell
git clone https://github.com/maramfarhat/passconside.git C:\dev\passconside
cd C:\dev\passconside
```

### What Git contains vs what you generate locally

| In Git | Not in Git (you create locally) |
|--------|----------------------------------|
| Source: `vendor/cline` (trimmed), `desktop/scripts`, `desktop/extensions`, `services/api`, … | `vendor/cline/**/node_modules`, `**/dist` |
| Docs, branding assets | `desktop/vscode/` (VS Code upstream clone) |
| | `desktop/VSCode-win32-x64/` (portable app — use **Releases** or build) |

After clone, **always** install agent dependencies once:

```powershell
cd desktop
.\scripts\build-pass-ai-agent.ps1
```

That runs `bun install` in `vendor/cline` and installs the agent into `desktop/vscode/extensions/pass-ai-agent` (when the VS Code tree exists) and syncs into `desktop/VSCode-win32-x64` if that folder exists.

### Apply your changes

**Agent / MCP / PASS branding (most common)**

```powershell
cd C:\dev\passconside\desktop
# edit files under vendor\cline\apps\vscode or run patches:
.\scripts\patch-cline-for-pass-ai.ps1
.\scripts\apply-pass-agent-branding.ps1
.\scripts\build-pass-ai-agent.ps1
```

If you already have a portable build folder, the build script syncs the agent into it. Otherwise run a full desktop build (below).

**Built-in PASS extensions** (`pass-ai-welcome`, `pass-ai-layout`)

```powershell
cd desktop
.\scripts\install-builtin-extensions.ps1
```

**Full desktop IDE rebuild** (required for core VS Code / product.json / workbench changes)

```powershell
cd desktop
.\scripts\setup-vscode.ps1          # first time only
.\scripts\build-pass-ai-agent.ps1   # before or after; keeps agent bundled
.\scripts\build-windows.ps1 -Launch
```

Output: `desktop\VSCode-win32-x64\PASS AI.exe`

**Create a new release zip locally** (maintainers)

```powershell
cd desktop
.\scripts\package-pass-ai-release.ps1 -Version "0.1.0" -InstallInnoSetup
# Artifact: desktop\out\releases\PASS-AI-Setup-0.1.0.exe
```

Upload **`PASS-AI-Setup-….exe`** (+ `.SHA256.txt`) to GitHub Releases for Phase 1 users.

**Backend (optional today)**

```powershell
cd infra
docker compose up -d
cd ..\services\api
.\mvnw spring-boot:run
```

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
├── services/api/          # Spring Boot API
├── infra/                 # Docker Compose (PostgreSQL)
└── docs/                  # Architecture and handoff notes
```

---

## License

- PASS AI scaffolding: MIT (see repo license file if present).
- VS Code: [Microsoft VS Code License](https://github.com/microsoft/vscode/blob/main/LICENSE.txt) when building from source.
- Cline-derived agent code: Apache-2.0 (`vendor/cline/LICENSE`).
