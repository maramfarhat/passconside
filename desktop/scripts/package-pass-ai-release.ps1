#Requires -Version 5.1
param(
	[string]$Version = "",
	[string]$PackagedRoot = (Join-Path (Split-Path $PSScriptRoot -Parent) "VSCode-win32-x64"),
	[string]$OutDir = (Join-Path (Split-Path $PSScriptRoot -Parent) "out\releases")
)

$ErrorActionPreference = "Stop"
$exe = Join-Path $PackagedRoot "PASS AI.exe"
if (-not (Test-Path $exe)) {
	$exe = Join-Path $PackagedRoot "Code.exe"
}
if (-not (Test-Path $exe)) {
	throw "Missing PASS AI.exe under $PackagedRoot. Run build-windows.ps1 first."
}

$agentPkg = Join-Path $PackagedRoot "resources\app\extensions\pass-ai-agent\package.json"
if (-not (Test-Path $agentPkg)) {
	Write-Warning "pass-ai-agent not bundled. Run sync-bundled-pass-ai-agent.ps1 or rebuild desktop after build-pass-ai-agent.ps1."
}

$productPath = Join-Path $PackagedRoot "resources\app\product.json"
if (-not (Test-Path $productPath)) {
	throw "Incomplete app (missing product.json)."
}
$product = Get-Content $productPath -Raw -Encoding UTF8 | ConvertFrom-Json
if ($product.nameShort -ne "PASS AI") {
	Write-Warning "product.json nameShort is '$($product.nameShort)' (expected PASS AI)."
}

if (-not $Version) {
	$Version = (Get-Date -Format "yyyy.MM.dd")
	if ($product.version) { $Version = "$Version+$($product.version)" }
}

New-Item -ItemType Directory -Path $OutDir -Force | Out-Null
$zipName = "PASS-AI-win32-x64-$Version.zip"
$zipPath = Join-Path $OutDir $zipName
if (Test-Path $zipPath) { Remove-Item $zipPath -Force }

Write-Host "Creating $zipPath ..." -ForegroundColor Cyan
Compress-Archive -Path $PackagedRoot -DestinationPath $zipPath -CompressionLevel Optimal

$hash = Get-FileHash -Path $zipPath -Algorithm SHA256
$manifest = @"
PASS AI Windows x64 portable build
Version label: $Version
Created: $(Get-Date -Format o)
SHA256: $($hash.Hash)

Install:
1. Download and extract the zip to a folder (e.g. C:\Tools\PASS-AI).
2. Run ``PASS AI.exe`` (keep the whole folder; do not move only the exe).

Requirements: Windows 10/11 x64. No installer; portable layout.
"@
$manifestPath = Join-Path $OutDir "PASS-AI-win32-x64-$Version.SHA256.txt"
$utf8 = New-Object System.Text.UTF8Encoding $false
[System.IO.File]::WriteAllText($manifestPath, $manifest, $utf8)

Write-Host "Release zip: $zipPath ($([math]::Round((Get-Item $zipPath).Length/1MB, 1)) MB)" -ForegroundColor Green
Write-Host "Checksum:    $manifestPath" -ForegroundColor Green
