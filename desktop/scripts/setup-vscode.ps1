#Requires -Version 5.1
<#
.SYNOPSIS
  Clones VS Code OSS at a pinned tag and applies PASS AI branding.
#>
param(
	[string]$VSCodeTag = "1.93.1",
	[switch]$SkipClone
)

$ErrorActionPreference = "Stop"
$DesktopRoot = Split-Path -Parent $PSScriptRoot
$RepoRoot = Split-Path -Parent $DesktopRoot
$VscodeDir = Join-Path $DesktopRoot "vscode"
$BrandingDir = Join-Path $RepoRoot "assets\branding"

if (-not $SkipClone) {
	if (Test-Path $VscodeDir) {
		Write-Host "VS Code directory already exists: $VscodeDir" -ForegroundColor Yellow
		Write-Host "Remove it or pass -SkipClone to only re-apply branding."
	} else {
		Write-Host "Cloning microsoft/vscode tag $VSCodeTag (shallow)..." -ForegroundColor Cyan
		git clone --depth 1 --branch $VSCodeTag https://github.com/microsoft/vscode.git $VscodeDir
	}
}

if (-not (Test-Path $VscodeDir)) {
	throw "VS Code source not found at $VscodeDir. Run without -SkipClone first."
}

& (Join-Path $PSScriptRoot "patch-product-json.ps1") -VscodeDir $VscodeDir

& (Join-Path $PSScriptRoot "apply-branding.ps1") -VscodeDir $VscodeDir -BrandingDir $BrandingDir

$welcomeSrc = Join-Path $DesktopRoot "extensions\pass-ai-welcome"
$welcomeDst = Join-Path $VscodeDir "extensions\pass-ai-welcome"
if (Test-Path $welcomeSrc) {
	if (Test-Path $welcomeDst) { Remove-Item $welcomeDst -Recurse -Force }
	Copy-Item $welcomeSrc $welcomeDst -Recurse -Force
	Write-Host "Bundled extension: pass-ai-welcome" -ForegroundColor Green
}

Write-Host @"

Next steps:
  cd `"$VscodeDir`"
  yarn
  yarn gulp vscode-win32-x64

First build can take 30-60+ minutes on Windows.

"@ -ForegroundColor Cyan
