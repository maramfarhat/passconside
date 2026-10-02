#Requires -Version 5.1
param(
	[string]$Version = "0.1.0",
	[string]$PackagedRoot = (Join-Path (Split-Path $PSScriptRoot -Parent) "VSCode-win32-x64"),
	[switch]$InstallInnoSetup
)

$ErrorActionPreference = "Stop"
$DesktopRoot = Split-Path $PSScriptRoot -Parent
$IssPath = Join-Path $DesktopRoot "installer\pass-ai-setup.iss"
$OutDir = Join-Path $DesktopRoot "out\releases"

if (-not (Test-Path (Join-Path $PackagedRoot "PASS AI.exe"))) {
	throw "Missing packaged app at $PackagedRoot. Run build-windows.ps1 first."
}

function Get-IsccPath {
	$candidates = @(
		"$env:LocalAppData\Programs\Inno Setup 6\ISCC.exe",
		"${env:ProgramFiles(x86)}\Inno Setup 6\ISCC.exe",
		"$env:ProgramFiles\Inno Setup 6\ISCC.exe",
		"$env:LocalAppData\Programs\Inno Setup 7\ISCC.exe",
		"${env:ProgramFiles(x86)}\Inno Setup 7\ISCC.exe",
		"$env:ProgramFiles\Inno Setup 7\ISCC.exe"
	)
	foreach ($c in $candidates) {
		if (Test-Path $c) { return $c }
	}
	return $null
}

$iscc = Get-IsccPath
if (-not $iscc -and $InstallInnoSetup) {
	Write-Host "Installing Inno Setup 6 via winget ..." -ForegroundColor Cyan
	winget install --id JRSoftware.InnoSetup -e --accept-package-agreements --accept-source-agreements
	$iscc = Get-IsccPath
}
if (-not $iscc) {
	throw "Inno Setup not found. Install from https://jrsoftware.org/isdl.php or run: build-pass-ai-setup.ps1 -InstallInnoSetup"
}

New-Item -ItemType Directory -Path $OutDir -Force | Out-Null
$sourceDir = (Resolve-Path $PackagedRoot).Path
Write-Host "Building PASS-AI-Setup-$Version.exe ..." -ForegroundColor Cyan

& $iscc "/DMyAppVersion=$Version" "/DSourceDir=$sourceDir" $IssPath
if ($LASTEXITCODE -ne 0) { throw "ISCC failed with exit $LASTEXITCODE" }

$setupExe = Join-Path $OutDir "PASS-AI-Setup-$Version.exe"
if (-not (Test-Path $setupExe)) {
	throw "Expected installer not found: $setupExe"
}

$hash = Get-FileHash -Path $setupExe -Algorithm SHA256
$manifest = @"
PASS AI Windows x64 installer
Version: $Version
Created: $(Get-Date -Format o)
SHA256: $($hash.Hash)

Install: run PASS-AI-Setup-$Version.exe and follow the wizard.
"@
$manifestPath = Join-Path $OutDir "PASS-AI-Setup-$Version.SHA256.txt"
$utf8 = New-Object System.Text.UTF8Encoding $false
[System.IO.File]::WriteAllText($manifestPath, $manifest, $utf8)

Write-Host "Installer: $setupExe ($([math]::Round((Get-Item $setupExe).Length/1MB, 1)) MB)" -ForegroundColor Green
Write-Host "Checksum:  $manifestPath" -ForegroundColor Green
