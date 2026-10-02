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

1. Open **[GitHub Releases](https://github.com/maramfarhat/passconside/releases)** (latest **PASS-AI-win32-x64-…zip**).
2. Download the `.zip` and the matching `.SHA256.txt` (optional integrity check).
3. Extract to a folder **without spaces in the path**, e.g. `C:\Tools\PASS-AI`.
4. Run **`PASS AI.exe`** from that folder.

**Important:** Keep the **entire extracted folder**. The exe needs `resources/`, DLLs, and bundled extensions next to it. Do not copy only the exe elsewhere.

### First run

- Windows 10/11 **64-bit**.
- Windows SmartScreen may warn on unsigned builds — choose “More info” → “Run anyway” if your team trusts the release.
- Agent settings and data: `%USERPROFILE%\.pass-ai\`
- Configure LLM keys in the agent panel (OpenRouter, etc.). **Do not commit API keys to Git.**

### What you get in the release zip

Portable PASS AI IDE with bundled **`pass-ai-agent`**, welcome/layout extensions, and PASS branding — same layout as `desktop/VSCode-win32-x64/` after a local build.

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
.\scripts\package-pass-ai-release.ps1 -Version "1.0.0"
# Artifact: desktop\out\releases\PASS-AI-win32-x64-1.0.0.zip
```

Upload that zip to GitHub Releases for Phase 1 users.

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
