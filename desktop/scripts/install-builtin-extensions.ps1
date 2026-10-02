#Requires -Version 5.1
param(
	[string]$VscodeDir = (Join-Path (Split-Path $PSScriptRoot -Parent) "vscode")
)

$ErrorActionPreference = "Stop"
$DesktopRoot = Split-Path $PSScriptRoot -Parent
$builtIns = @("pass-ai-welcome", "pass-ai-layout")

foreach ($name in $builtIns) {
	$src = Join-Path $DesktopRoot "extensions\$name"
	$dest = Join-Path $VscodeDir "extensions\$name"
	if (-not (Test-Path $src)) {
		Write-Warning "Skip missing $src"
		continue
	}
	if (Test-Path (Join-Path $src "tsconfig.json")) {
		Push-Location $src
		try {
			if (-not (Test-Path "node_modules")) {
				npm install --silent 2>&1 | Out-Null
			}
			npm run compile 2>&1 | Out-Host
		} finally {
			Pop-Location
		}
	}
	if (Test-Path $dest) {
		Remove-Item $dest -Recurse -Force
	}
	Copy-Item -Path $src -Destination $dest -Recurse -Force
	Write-Host "Installed $name -> extensions\$name" -ForegroundColor Green
}

if (Test-Path (Join-Path $VscodeDir "extensions\pass-ai-agent\package.json")) {
	Write-Host "pass-ai-agent already present (run build-pass-ai-agent.ps1 to refresh)." -ForegroundColor Cyan
}
