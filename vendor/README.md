# Vendored third-party sources

## Cline agent engine (`vendor/cline`)

PASS AI ships a **trimmed** Cline monorepo (Apache-2.0) used only to build the in-IDE agent. Full upstream includes CLI, hub, examples, and evals; those are removed so the repo stays reviewable on GitHub.

| Piece | Path under `vendor/cline` |
|-------|---------------------------|
| VS Code extension + webview | `apps/vscode`, `apps/vscode/webview-ui` |
| Agent loop, tools, MCP | `sdk/packages/core` |
| Agents / LLMs / shared / UI | `sdk/packages/{agents,llms,shared,ui,sdk}` |
| Bun patches | `patches/` |

Details: `vendor/cline/PASS-AI-VENDOR.md`.

### First clone / after pulling vendor changes

```powershell
cd C:\Users\maram\passconside\desktop
.\scripts\build-pass-ai-agent.ps1
```

That runs `bun install` inside `vendor/cline` (several GB under `node_modules`, **not** committed) and copies the built extension to `desktop/vscode/extensions/pass-ai-agent`.

### Re-importing a full upstream Cline copy

If you replace `vendor/cline` with a full clone from upstream, run:

```powershell
.\scripts\trim-cline-vendor-for-pass-ai.ps1 -ReinstallDeps
.\scripts\build-pass-ai-agent.ps1
```

### External clone (optional)

```powershell
$env:PASS_CLINE_SOURCE = "D:\path\to\cline"
.\scripts\link-cline-vendor.ps1 -Source $env:PASS_CLINE_SOURCE -ForceJunction
```

Default layout is **no junction** — engine lives under `passconside/vendor/cline`.
