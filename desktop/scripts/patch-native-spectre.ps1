#Requires -Version 5.1
param(
	[string]$VscodeDir = (Join-Path (Split-Path $PSScriptRoot -Parent) "vscode")
)

$ErrorActionPreference = "Stop"
$utf8NoBom = New-Object System.Text.UTF8Encoding $false

function Set-Utf8NoBom([string]$Path, [string]$Content) {
	[System.IO.File]::WriteAllText($Path, $Content, $utf8NoBom)
}

$gypCount = 0
Get-ChildItem -Path $VscodeDir -Recurse -Filter "*.gyp" -ErrorAction SilentlyContinue |
	Where-Object { $_.FullName -notmatch '\\(\.git|out|\.build)\\' } | ForEach-Object {
	$raw = [System.IO.File]::ReadAllText($_.FullName)
	$updated = $raw -replace "'SpectreMitigation':\s*'Spectre'", "'SpectreMitigation': 'false'"
	$updated = $updated -replace '"SpectreMitigation":\s*"Spectre"', '"SpectreMitigation": "false"'
	if ($updated -ne $raw) {
		Set-Utf8NoBom $_.FullName $updated
		$gypCount++
	}
}

$vcxCount = 0
Get-ChildItem -Path $VscodeDir -Recurse -Filter "*.vcxproj" -ErrorAction SilentlyContinue |
	Where-Object { $_.FullName -notmatch '\\(\.git|out|\.build)\\' } | ForEach-Object {
	$raw = [System.IO.File]::ReadAllText($_.FullName)
	if ($raw -match "SpectreMitigation") {
		$updated = $raw -replace "<SpectreMitigation>Spectre</SpectreMitigation>", "<SpectreMitigation>false</SpectreMitigation>"
		if ($updated -ne $raw) {
			Set-Utf8NoBom $_.FullName $updated
			$vcxCount++
		}
	}
}

Write-Host "Patched $gypCount binding.gyp and $vcxCount vcxproj file(s)." -ForegroundColor Green
