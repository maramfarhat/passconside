#Requires -Version 5.1
# Removes Cline cloud OAuth session from PASS AI storage (optional before PASS-only agent).
$ErrorActionPreference = "Stop"
$statePath = Join-Path $env:USERPROFILE ".pass-ai\data\globalState.json"
if (-not (Test-Path $statePath)) {
	Write-Host "No globalState.json at $statePath"
	exit 0
}
$raw = Get-Content $statePath -Raw -Encoding UTF8
$state = $raw | ConvertFrom-Json
$keys = @($state.PSObject.Properties.Name) | Where-Object { $_ -match 'cline|Cline|auth|token|refresh|account' }
foreach ($k in $keys) {
	$state.PSObject.Properties.Remove($k)
}
$utf8 = New-Object System.Text.UTF8Encoding $false
[System.IO.File]::WriteAllText($statePath, ($state | ConvertTo-Json -Depth 20), $utf8)
Write-Host "Cleared $($keys.Count) Cline-related keys from globalState. Reload PASS AI." -ForegroundColor Green
