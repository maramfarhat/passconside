#Requires -Version 5.1
<#
.SYNOPSIS
  Removes upstream Cline monorepo folders not needed to build the PASS AI VS Code agent.

.DESCRIPTION
  Keeps: sdk/packages/*, apps/vscode (+ webview-ui), patches/, bun.lock, minimal root config.
  Drops: CLI, hub, examples, evals, docs, CI, and local dev tooling trees.
  Replaces vendor/cline/package.json with desktop/scripts/vendor-cline-minimal.package.json.

  Run from passconside after copying vendor/cline. Use -ReinstallDeps to delete node_modules
  and dist under the trimmed tree (recommended before first git commit of vendor source).

.PARAMETER ClineRoot
  Path to vendor/cline (default: repo vendor/cline).

.PARAMETER DryRun
  List actions only; do not delete or overwrite files.

.PARAMETER ReinstallDeps
  After trim, remove node_modules and dist workspaces-wide (slow; run bun install yourself or use -VerifyBuild).
#>
param(
	[string]$ClineRoot = "",
	[switch]$DryRun,
	[switch]$ReinstallDeps,
	[switch]$VerifyBuild
)

$ErrorActionPreference = "Stop"
$DesktopRoot = Split-Path $PSScriptRoot -Parent
$RepoRoot = Split-Path $DesktopRoot -Parent
if (-not $ClineRoot) {
	$ClineRoot = Join-Path $RepoRoot "vendor\cline"
}
$ClineRoot = (Resolve-Path $ClineRoot).Path

$minimalPkg = Join-Path $PSScriptRoot "vendor-cline-minimal.package.json"
if (-not (Test-Path $minimalPkg)) {
	throw "Missing $minimalPkg"
}
if (-not (Test-Path (Join-Path $ClineRoot "apps\vscode\package.json"))) {
	throw "Not a Cline tree: $ClineRoot"
}

$removeRelative = @(
	"apps\cli",
	"apps\cline-hub",
	"apps\examples",
	"apps\vscode-rollout",
	"apps\vscode\testing-platform",
	"sdk\examples",
	"docs",
	"evals",
	"assets",
	".github",
	".greptile",
	".agents",
	".claude",
	".codex",
	".kanban",
	".husky",
	".vscode",
	".clinerules",
	".gitmodules",
	"AGENTS.md",
	"CHANGELOG.md",
	"CODE_OF_CONDUCT.md",
	"CONTRIBUTING.md",
	"SECURITY.md",
	"vitest.config.ts",
	".gitleaks.toml",
	".worktreeinclude"
)

function Remove-TreeIfExists {
	param([string]$Path)
	if (-not (Test-Path $Path)) { return }
	if ($DryRun) {
		Write-Host "[dry-run] Remove $Path" -ForegroundColor Yellow
		return
	}
	Write-Host "Remove $Path" -ForegroundColor DarkYellow
	Remove-Item -LiteralPath $Path -Recurse -Force
}

Write-Host "Trimming Cline vendor for PASS AI -> $ClineRoot" -ForegroundColor Cyan

foreach ($rel in $removeRelative) {
	Remove-TreeIfExists (Join-Path $ClineRoot $rel)
}

$destPkg = Join-Path $ClineRoot "package.json"
if ($DryRun) {
	Write-Host "[dry-run] Copy minimal package.json -> $destPkg" -ForegroundColor Yellow
} else {
	Copy-Item -Path $minimalPkg -Destination $destPkg -Force
	Write-Host "Applied minimal package.json" -ForegroundColor Green
}

$passNote = Join-Path $ClineRoot "PASS-AI-VENDOR.md"
$noteText = @"
# PASS AI trimmed Cline vendor

This tree is a **subset** of the [Cline](https://github.com/cline/cline) monorepo, kept only to build the PASS AI agent extension.

## Included (required for ``build-pass-ai-agent.ps1``)

| Path | Role |
|------|------|
| ``apps/vscode`` | VS Code extension host (bundled as ``pass-ai-agent``) |
| ``apps/vscode/webview-ui`` | Agent chat UI |
| ``sdk/packages/core`` | Agent loop, tools, MCP |
| ``sdk/packages/agents`` | Agent definitions |
| ``sdk/packages/llms`` | Model providers |
| ``sdk/packages/shared`` | Shared types and prompts |
| ``sdk/packages/ui`` | Webview components |
| ``sdk/packages/sdk`` | SDK package (built with ``build:sdk``) |
| ``patches/`` | Bun patched dependencies (``ollama-ai-provider-v2``) |
| ``bun.lock`` | Lockfile for reproducible installs |

## Removed upstream (not needed for PASS AI desktop agent)

CLI, Cline Hub, examples, evals, docs, GitHub Actions, and other release/CI trees.

## After clone

``````powershell
cd passconside\desktop
.\scripts\trim-cline-vendor-for-pass-ai.ps1   # only if you imported a full upstream copy again
.\scripts\build-pass-ai-agent.ps1             # bun install + build inside vendor/cline
``````

Do **not** commit ``node_modules`` or ``dist`` folders (see repo ``.gitignore``).

License: upstream ``LICENSE`` (Apache-2.0). PASS-specific branding patches live under ``apps/vscode`` and ``desktop/scripts/apply-pass-agent-branding.ps1``.
"@
if (-not $DryRun) {
	$utf8NoBom = New-Object System.Text.UTF8Encoding $false
	[System.IO.File]::WriteAllText($passNote, $noteText, $utf8NoBom)
}

if ($ReinstallDeps -and -not $DryRun) {
	Write-Host "Removing node_modules and dist under vendor/cline ..." -ForegroundColor Cyan
	Get-ChildItem -Path $ClineRoot -Recurse -Directory -Force -ErrorAction SilentlyContinue |
		Where-Object { $_.Name -eq "node_modules" -or $_.Name -eq "dist" } |
		ForEach-Object {
			Write-Host "  $($_.FullName)"
			Remove-Item -LiteralPath $_.FullName -Recurse -Force -ErrorAction SilentlyContinue
		}
	if (Test-Path (Join-Path $ClineRoot "node_modules")) {
		Remove-Item (Join-Path $ClineRoot "node_modules") -Recurse -Force
	}
}

if ($VerifyBuild -and -not $DryRun) {
	& (Join-Path $PSScriptRoot "build-pass-ai-agent.ps1")
}

Write-Host "Done. See vendor/cline/PASS-AI-VENDOR.md and vendor/README.md." -ForegroundColor Green
