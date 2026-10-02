# PASS AI trimmed Cline vendor

This tree is a **subset** of the [Cline](https://github.com/cline/cline) monorepo, kept only to build the PASS AI agent extension.

## Included (required for `build-pass-ai-agent.ps1`)

| Path | Role |
|------|------|
| `apps/vscode` | VS Code extension host (bundled as `pass-ai-agent`) |
| `apps/vscode/webview-ui` | Agent chat UI |
| `sdk/packages/core` | Agent loop, tools, MCP |
| `sdk/packages/agents` | Agent definitions |
| `sdk/packages/llms` | Model providers |
| `sdk/packages/shared` | Shared types and prompts |
| `sdk/packages/ui` | Webview components |
| `sdk/packages/sdk` | SDK package (built with `build:sdk`) |
| `patches/` | Bun patched dependencies (`ollama-ai-provider-v2`) |
| `bun.lock` | Lockfile for reproducible installs |

## Removed upstream (not needed for PASS AI desktop agent)

CLI, Cline Hub, examples, evals, docs, GitHub Actions, and other release/CI trees.

## After clone

```powershell
cd passconside\desktop
.\scripts\trim-cline-vendor-for-pass-ai.ps1   # only if you imported a full upstream copy again
.\scripts\build-pass-ai-agent.ps1             # bun install + build inside vendor/cline
```

Do **not** commit `node_modules` or `dist` folders (see repo `.gitignore`).

License: upstream `LICENSE` (Apache-2.0). PASS-specific branding patches live under `apps/vscode` and `desktop/scripts/apply-pass-agent-branding.ps1`.