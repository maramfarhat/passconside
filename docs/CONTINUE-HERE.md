# PASS AI — continue this project (handoff from previous chat)

**Workspace:** `C:\Users\maram\passconside` (copy of the original repo; use this folder only.)

## Goal

Build **PASS AI**, an open-source Cursor-like IDE:

- **Desktop:** VS Code OSS 1.93.1 (Electron), branded PASS Consulting (logo, `product.json`, `.pass-ai` data dir)
- **Frontend:** Node.js (`apps/web` — Vite)
- **Backend:** Spring Boot 3, Java 17 (`services/api`)
- **DB:** PostgreSQL (`infra/docker-compose.yml`)

## Done so far

- Monorepo scaffold: `desktop/`, `apps/web/`, `services/api/`, `infra/`, `assets/branding/`
- VS Code cloned under `desktop/vscode`, PASS branding applied (`setup-vscode.ps1`, `patch-product-json.ps1`, `apply-branding.ps1`)
- Logo fixed (was JPEG renamed `.png`); **`code.ico`** generated via Pillow
- Built-in extension: `desktop/extensions/pass-ai-welcome`
- Yarn 1.22.22 installed globally
- **`patch-native-spectre.ps1`** — patches native `binding.gyp` (Spectre → false) when VS Spectre libs are missing
- **`build-windows.ps1`** — `yarn --ignore-scripts` → patch → `postinstall` → `gulp vscode-win32-x64` → optional launch

## Blockers hit

1. **Disk full (ENOSPC)** during `node build/npm/postinstall.js` — free **40–60 GB** on `C:` before full build
2. **Path with spaces** broke scripts — resolved by working only in **`passconside`**
3. **MSB8040 Spectre** — use `patch-native-spectre.ps1` before native rebuilds

## Next steps (in order)

1. Ensure enough free disk space; optionally delete old `C:\Users\maram\Pass consulting ide` after verifying this copy
2. Build and launch:

   ```powershell
   cd C:\Users\maram\passconside\desktop
   .\scripts\build-windows.ps1 -Launch
   ```

3. After desktop works: Docker Postgres + `mvn spring-boot:run` in `services/api`
4. **Agent (Cline engine):** trimmed `vendor/cline` (source in git, not `node_modules`); `vendor/README.md`, `desktop/agent/README.md` — `build-pass-ai-agent.ps1`. Re-import full upstream → `trim-cline-vendor-for-pass-ai.ps1 -ReinstallDeps`. **Auto workspace:** new task with no folder open → `%USERPROFILE%\.pass-ai\workspaces\<prompt-slug>\` (rebuild agent after vendor changes).
5. Later: auth + model proxy in `services/api`, webviews in `apps/web`

## Key paths

| Item | Path |
|------|------|
| Build script | `desktop/scripts/build-windows.ps1` |
| VS Code source | `desktop/vscode` |
| Brand overrides | `desktop/product.overrides.json` |
| Logo | `assets/branding/pass-logo.png`, `code.ico` |
| Architecture | `docs/ARCHITECTURE.md` |

## Paste this in a new Agent chat (passconside workspace)

```
Read docs/CONTINUE-HERE.md and continue PASS AI: finish the Windows desktop build (build-windows.ps1 -Launch), then confirm Code.exe runs as PASS AI.
```
