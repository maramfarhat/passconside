#Requires -Version 5.1
param(
	[string]$VscodeDir,
	[string]$BrandingDir
)

$ErrorActionPreference = "Stop"

$logo = Join-Path $BrandingDir "pass-logo.png"
if (-not (Test-Path $logo)) {
	Write-Warning "Logo not found at $logo - skipping icon copy."
	return
}

$targets = @(
	(Join-Path $VscodeDir "resources\win32\code_150x150.png"),
	(Join-Path $VscodeDir "resources\win32\code_70x70.png"),
	(Join-Path $VscodeDir "resources\linux\code.png"),
	(Join-Path $VscodeDir "resources\darwin\code.png")
)

foreach ($t in $targets) {
	$dir = Split-Path $t -Parent
	if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
	Copy-Item $logo $t -Force
	Write-Host "Branding: $t"
}

$icoSrc = Join-Path $BrandingDir "code.ico"
$icoDst = Join-Path $VscodeDir "resources\win32\code.ico"
if (Test-Path $icoSrc) {
	Copy-Item $icoSrc $icoDst -Force
	Write-Host "Branding: code.ico"
} else {
	Write-Warning "code.ico not found in branding folder - run: npx png-to-ico pass-logo.png > code.ico"
}

# Splash / welcome (optional override if file exists in branding)
$splashSrc = Join-Path $BrandingDir "splash.png"
$splashDst = Join-Path $VscodeDir "resources\win32\splash.png"
if (Test-Path $splashSrc) {
	Copy-Item $splashSrc $splashDst -Force
	Write-Host "Branding: splash.png"
} else {
	Copy-Item $logo $splashDst -Force -ErrorAction SilentlyContinue
}

Write-Host "PASS AI branding applied." -ForegroundColor Green
