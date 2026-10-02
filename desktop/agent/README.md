# PASS AI agent (Cline engine)

## Layout (Cursor-like)

- Agent UI opens in the **secondary side bar (right)** via `auxiliarybar` in `manifest.overrides.json`.
- `pass-ai-layout` extension sets default visibility and toggle behavior.
- Toggle: **View → Secondary Side Bar** or `workbench.action.toggleAuxiliaryBar`.

## Where the engine lives

| Piece | Cline path |
|-------|------------|
| Agent loop, tools, context | `sdk/packages/core` |
| Agent definitions | `sdk/packages/agents` |
| Model providers | `sdk/packages/llms` |
| Shared utilities | `sdk/packages/shared` |
| VS Code host + webview | `apps/vscode` + `apps/vscode/webview-ui` |

Engine lives at `vendor/cline` inside the passconside repo (trimmed source tracked; `node_modules` not committed). See `vendor/README.md`.

## Build & install into PASS AI

```powershell
cd C:\Users\maram\passconside\desktop
.\scripts\link-cline-vendor.ps1
.\scripts\patch-cline-for-pass-ai.ps1
.\scripts\build-pass-ai-agent.ps1
```

Output is copied to `desktop/vscode/extensions/pass-ai-agent` for bundled desktop builds.

Dev without rebuilding PASS AI: **Extensions → Install from VSIX** using the `.vsix` from the build script, or run PASS AI with that folder under `extensions/`.

## MCP server configuration (unchanged)

In the agent panel:

1. **MCP Servers** toolbar button (plug icon) → **Remote Servers** / **Configure** tabs, **Edit Configuration** opens `cline_mcp_settings.json`.
2. **Marketplace** toolbar button → **MCP** section → **Add Remote Server**, **Edit Configuration**, **Advanced MCP Settings** (Settings → Features).

Branding only removes **Cline documentation hyperlinks** in Rules/About/etc.; MCP UI and settings files are not stripped.

## Ollama and tools (Act mode)

The agent only runs **editor**, **terminal**, and **MCP** tools when the model returns real **tool calls** from the API. Many coder models (including **`qwen2.5-coder`**) often **print JSON in chat** instead — you see `{"name":"editor",...}` as text and the task shows **COMPLETED** with no file created.

For local Ollama, prefer models with reliable tool calling, for example:

- `llama3.1:8b` (good default for tools)
- `llama3.2:3b` / `llama3.2` (if installed)
- `mistral` / `qwen2.5` **non-coder** variants with tool support (verify with `ollama run <model>` and a tool-capable prompt)

Use **Act** mode (not Plan), enable **Use MCP servers** if needed, and pull the model: `ollama pull llama3.1:8b`.

## Auto workspace (no folder open)

When you start a **new task** without a project folder open (or with only the legacy shared `chat` fallback), PASS AI:

1. Creates `%USERPROFILE%\.pass-ai\workspaces\<short-name>\` (e.g. `shop` from `shop/index.html`, not the whole sentence)
2. Adds that folder to the VS Code workspace so file tools and terminals use it as `cwd`

If you already opened a real repo (e.g. `passconside`), behavior is unchanged. Agent data and chat fallback paths use **`~/.pass-ai`** via `setClineDirIfUnset` at extension activation.

## PASS-only product (no Cline cloud)

Build runs `apply-pass-agent-branding.ps1`:

- Bundled `endpoints.json` → **standalone / self-hosted** mode (no ClinePass, no cline.bot telemetry defaults)
- Account UI → **PASS sign-in (coming soon)**, not Cline OAuth
- Command labels → **PASS AI** (internal extension id unchanged for stability)

Optional: `desktop/scripts/clear-cline-cloud-session.ps1` to remove old Cline login from `%USERPROFILE%\.pass-ai\data\globalState.json`.

Copy `%USERPROFILE%\.pass-ai\endpoints.json` from `desktop/agent/endpoints.json` (points at future PASS API on `:8080`).

## Backend (Spring Boot)

**Not required for first agent testing.** The agent talks to LLMs via **API keys / Ollama** in Settings.

Use `services/api` later for:

- PASS SSO / team auth
- Central model routing and billing
- Audit and policy

See `docs/ARCHITECTURE.md`.

## Version note

Upstream Cline targets VS Code **1.101+**. PASS AI ships **1.93.1**; `manifest.overrides.json` lowers the engine constraint for install. If you hit API gaps, plan a VS Code OSS bump in `desktop/vscode`.
