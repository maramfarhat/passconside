#Requires -Version 5.1
<#
  Copies PASS_AI_INFERENCE_API_KEY from repo .env to ~/.pass-ai/inference-api-key
  so the PASS AI agent can authenticate to the local Spring Boot proxy.
#>
param(
	[string]$EnvFile = (Join-Path (Split-Path (Split-Path $PSScriptRoot -Parent) -Parent) ".env")
)

$ErrorActionPreference = "Stop"
if (-not (Test-Path $EnvFile)) {
	throw "Missing $EnvFile — copy .env.example and set PASS_AI_INFERENCE_API_KEY"
}

$key = $null
Get-Content $EnvFile | ForEach-Object {
	if ($_ -match '^\s*PASS_AI_INFERENCE_API_KEY=(.+)$') {
		$key = $matches[1].Trim()
	}
}
if (-not $key) {
	throw "PASS_AI_INFERENCE_API_KEY not set in $EnvFile"
}

$destDir = Join-Path $env:USERPROFILE ".pass-ai"
New-Item -ItemType Directory -Path $destDir -Force | Out-Null
$dest = Join-Path $destDir "inference-api-key"
$utf8 = New-Object System.Text.UTF8Encoding $false
[System.IO.File]::WriteAllText($dest, $key, $utf8)
Write-Host "Updated $dest (restart PASS AI after rebuild)" -ForegroundColor Green
