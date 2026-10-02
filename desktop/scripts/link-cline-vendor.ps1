#Requires -Version 5.1
param(
	[string]$Source,
	[switch]$ForceJunction
)

$ErrorActionPreference = "Stop"
$RepoRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
$VendorDir = Join-Path $RepoRoot "vendor\cline"

if (-not $Source) {
	$Source = $env:PASS_CLINE_SOURCE
}
if (-not $Source) {
	$Source = $VendorDir
}

function Test-ClineRoot([string]$Path) {
	return Test-Path (Join-Path $Path "apps\vscode\package.json")
}

if (-not (Test-ClineRoot $Source)) {
	throw "Cline engine not found at: $Source (expected apps/vscode/package.json). Copy the tree into vendor/cline or set -Source / PASS_CLINE_SOURCE."
}

$Source = (Resolve-Path $Source).Path

# In-repo copy (default): no junction.
$vendorResolved = $null
if (Test-Path $VendorDir) {
	$vendorResolved = (Resolve-Path $VendorDir).Path
}
if ($vendorResolved -and $Source -eq $vendorResolved -and (Test-ClineRoot $VendorDir)) {
	Write-Host "Cline engine OK at $VendorDir" -ForegroundColor Green
	exit 0
}

if (-not $ForceJunction) {
	throw "External source $Source is not vendor/cline. To link an external clone: link-cline-vendor.ps1 -Source <path> -ForceJunction"
}

$vendorParent = Split-Path $VendorDir -Parent
if (-not (Test-Path $vendorParent)) {
	New-Item -ItemType Directory -Path $vendorParent -Force | Out-Null
}

if (Test-Path $VendorDir) {
	$item = Get-Item $VendorDir -Force
	if ($item.LinkType -eq "Junction") {
		if ($item.Target[0] -eq $Source) {
			Write-Host "Already linked: $VendorDir -> $Source" -ForegroundColor Green
			exit 0
		}
		cmd /c rmdir "$VendorDir" | Out-Null
	} else {
		throw "$VendorDir exists as a real folder. Remove or rename it before creating a junction."
	}
}

cmd /c mklink /J "$VendorDir" "$Source" | Out-Host
Write-Host "Linked vendor/cline -> $Source" -ForegroundColor Green
