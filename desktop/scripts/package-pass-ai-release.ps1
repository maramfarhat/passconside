#Requires -Version 5.1
param(
	[string]$Version = "",
	[string]$PackagedRoot = (Join-Path (Split-Path $PSScriptRoot -Parent) "VSCode-win32-x64"),
	[string]$OutDir = (Join-Path (Split-Path $PSScriptRoot -Parent) "out\releases"),
	[switch]$IncludeZip,
	[switch]$InstallInnoSetup
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
	$Version = "0.1.0"
	if ($product.version) { $Version = $product.version }
}

New-Item -ItemType Directory -Path $OutDir -Force | Out-Null

$setupParams = @{
	Version       = $Version
	PackagedRoot  = $PackagedRoot
}
if ($InstallInnoSetup) { $setupParams.InstallInnoSetup = $true }
& (Join-Path $PSScriptRoot "build-pass-ai-setup.ps1") @setupParams

if ($IncludeZip) {
	$zipName = "PASS-AI-win32-x64-$Version.zip"
	$zipPath = Join-Path $OutDir $zipName
	if (Test-Path $zipPath) { Remove-Item $zipPath -Force }

	Write-Host "Creating $zipPath ..." -ForegroundColor Cyan
	Compress-Archive -Path $PackagedRoot -DestinationPath $zipPath -CompressionLevel Optimal
	Write-Host "Optional zip: $zipPath" -ForegroundColor Green
}

$setupExe = Join-Path $OutDir "PASS-AI-Setup-$Version.exe"
if (Test-Path $setupExe) {
	Write-Host "Upload to GitHub Releases: $setupExe" -ForegroundColor Green
}
