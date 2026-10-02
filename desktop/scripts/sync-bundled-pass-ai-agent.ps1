#Requires -Version 5.1
<#
  Copies the built pass-ai-agent extension into a packaged PASS AI folder (if present)
  and into desktop/vscode/extensions for the next full desktop build.
#>
param(
	[string]$AgentDir = (Join-Path (Split-Path $PSScriptRoot -Parent) "vscode\extensions\pass-ai-agent"),
	[string]$PackagedAppRoot = (Join-Path (Split-Path $PSScriptRoot -Parent) "VSCode-win32-x64\resources\app")
)

$ErrorActionPreference = "Stop"
if (-not (Test-Path (Join-Path $AgentDir "package.json"))) {
	throw "Missing agent at $AgentDir. Run build-pass-ai-agent.ps1 first."
}
if (-not (Test-Path (Join-Path $AgentDir "dist\extension.js"))) {
	throw "Agent not built (no dist\extension.js). Run build-pass-ai-agent.ps1 first."
}

$bundled = Join-Path $PackagedAppRoot "extensions\pass-ai-agent"
if (Test-Path $PackagedAppRoot) {
	if (Test-Path $bundled) { Remove-Item $bundled -Recurse -Force }
	Copy-Item -Path $AgentDir -Destination $bundled -Recurse -Force
	Write-Host "Bundled agent -> $bundled" -ForegroundColor Green
} else {
	Write-Host "No packaged app at $PackagedAppRoot (skip bundle; full rebuild uses vscode\extensions)." -ForegroundColor Yellow
}
