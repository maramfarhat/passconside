#Requires -Version 5.1
<#
  Patches microsoft/vscode product.json with PASS AI branding (does not replace the full file).
#>
param(
	[string]$VscodeDir
)

$ErrorActionPreference = "Stop"
$productPath = Join-Path $VscodeDir "product.json"
if (-not (Test-Path $productPath)) {
	throw "Missing $productPath"
}

function New-GuidBraced {
	"{" + [guid]::NewGuid().ToString().ToUpper() + "}"
}

$DesktopRoot = Split-Path -Parent $PSScriptRoot
$overridesPath = Join-Path $DesktopRoot "product.overrides.json"
$overrideObj = Get-Content $overridesPath -Raw -Encoding UTF8 | ConvertFrom-Json

$json = Get-Content $productPath -Raw -Encoding UTF8 | ConvertFrom-Json

foreach ($prop in $overrideObj.PSObject.Properties) {
	$json | Add-Member -NotePropertyName $prop.Name -NotePropertyValue $prop.Value -Force
}

# Fresh Windows installer IDs (required when rebranding)
$json | Add-Member -NotePropertyName win32AppId -NotePropertyValue (New-GuidBraced) -Force
$json | Add-Member -NotePropertyName win32x64AppId -NotePropertyValue (New-GuidBraced) -Force
$json | Add-Member -NotePropertyName win32arm64AppId -NotePropertyValue (New-GuidBraced) -Force
$json | Add-Member -NotePropertyName win32UserAppId -NotePropertyValue (New-GuidBraced) -Force
$json | Add-Member -NotePropertyName win32x64UserAppId -NotePropertyValue (New-GuidBraced) -Force
$json | Add-Member -NotePropertyName win32arm64UserAppId -NotePropertyValue (New-GuidBraced) -Force

$utf8NoBom = New-Object System.Text.UTF8Encoding $false
$content = ($json | ConvertTo-Json -Depth 100)
[System.IO.File]::WriteAllText($productPath, $content, $utf8NoBom)
Write-Host "Patched product.json for PASS AI." -ForegroundColor Green
