#Requires -Version 5.1
# Updates product.json checksums after patching packaged PASS AI (e.g. workbench.desktop.main.js).
param(
	[string]$AppRoot = (Join-Path (Split-Path $PSScriptRoot -Parent) "VSCode-win32-x64\resources\app")
)

$ErrorActionPreference = "Stop"
$productPath = Join-Path $AppRoot "product.json"
if (-not (Test-Path $productPath)) {
	throw "Missing $productPath"
}

$files = @(
	"out\vs\base\parts\sandbox\electron-sandbox\preload.js",
	"out\vs\workbench\workbench.desktop.main.js",
	"out\vs\workbench\workbench.desktop.main.css",
	"out\vs\workbench\api\node\extensionHostProcess.js",
	"out\vs\code\electron-sandbox\workbench\workbench.html",
	"out\vs\code\electron-sandbox\workbench\workbench.js"
)

$checksums = @{}
foreach ($rel in $files) {
	$full = Join-Path $AppRoot $rel
	if (-not (Test-Path $full)) {
		Write-Warning "Skip missing $rel"
		continue
	}
	$key = ($rel -replace '^out\\', '') -replace '\\', '/'
	$bytes = [IO.File]::ReadAllBytes($full)
	$sha = [System.Security.Cryptography.SHA256]::Create()
	$hash = $sha.ComputeHash($bytes)
	$b64 = [Convert]::ToBase64String($hash).TrimEnd('=')
	$checksums[$key] = $b64
}

$product = Get-Content $productPath -Raw -Encoding UTF8 | ConvertFrom-Json
$product.checksums = $checksums
$utf8 = New-Object System.Text.UTF8Encoding $false
[System.IO.File]::WriteAllText($productPath, ($product | ConvertTo-Json -Depth 20), $utf8)
Write-Host "Updated checksums in $productPath" -ForegroundColor Green
