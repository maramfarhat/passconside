#Requires -Version 5.1
param(
	[string]$ClineRoot = (Join-Path (Split-Path (Split-Path $PSScriptRoot -Parent) -Parent) "vendor\cline"),
	[switch]$UseActivityBar
)

$ErrorActionPreference = "Stop"
$manifestPath = Join-Path $ClineRoot "apps\vscode\package.json"
$overridesPath = Join-Path (Split-Path $PSScriptRoot -Parent) "agent\manifest.overrides.json"

if (-not (Test-Path $manifestPath)) {
	throw "Missing $manifestPath. Run link-cline-vendor.ps1 first."
}

$manifest = Get-Content $manifestPath -Raw -Encoding UTF8 | ConvertFrom-Json
$overrides = Get-Content $overridesPath -Raw -Encoding UTF8 | ConvertFrom-Json

	foreach ($prop in $overrides.PSObject.Properties) {
	if ($prop.Name -eq "viewsContainers") {
		$containers = @{}
		if ($UseActivityBar) {
			$containers.activitybar = @($prop.Value.auxiliarybar)
		} else {
			$containers.auxiliarybar = @($prop.Value.auxiliarybar)
		}
		$manifest.contributes.viewsContainers = $containers
		continue
	}
	$manifest | Add-Member -NotePropertyName $prop.Name -NotePropertyValue $prop.Value -Force
}

if ($manifest.contributes.walkthroughs) {
	$manifest.contributes.walkthroughs = @()
}
if ($manifest.contributes.configuration) {
	$manifest.contributes.configuration.title = "PASS AI Agent"
}
foreach ($cmd in $manifest.contributes.commands) {
	if ($cmd.title -match "Cline") {
		$cmd.title = ($cmd.title -replace "Cline", "PASS AI")
	}
	if ($cmd.category -eq "Cline") {
		$cmd.category = "PASS AI"
	}
}
$manifest.homepage = "https://passconsulting.com"
$manifest.repository = @{ type = "git"; url = "https://github.com/passconsulting/pass-ai" }
$manifest | Add-Member -NotePropertyName "passAiStandalone" -NotePropertyValue $true -Force

if ($manifest.devDependencies.'@types/vscode') {
	$manifest.devDependencies.'@types/vscode' = "1.93.0"
}

# Restore stock Cline bar/view icons (no PASS activity PNG/SVG overrides).
$manifest.icon = "assets/icons/icon.png"
if ($manifest.contributes.views) {
	foreach ($viewList in $manifest.contributes.views.PSObject.Properties) {
		foreach ($view in @($viewList.Value)) {
			if ($view.id -eq "claude-dev.SidebarProvider") {
				$view | Add-Member -MemberType NoteProperty -Name name -Value "PASS AI" -Force
				$view | Add-Member -MemberType NoteProperty -Name icon -Value "assets/icons/pass-ai-view.svg" -Force
			} elseif ($view.PSObject.Properties.Name -contains "icon") {
				$icon = $view.icon
				if ($icon -is [string] -and ($icon -match "pass-ai|icon\.svg")) {
					$view | Add-Member -MemberType NoteProperty -Name icon -Value "assets/icons/pass-ai-view.svg" -Force
				} elseif ($icon -is [pscustomobject] -or $icon -is [hashtable]) {
					$view | Add-Member -MemberType NoteProperty -Name icon -Value "assets/icons/pass-ai-view.svg" -Force
				}
			}
		}
	}
}
if ($manifest.contributes.viewsContainers) {
	foreach ($containerList in $manifest.contributes.viewsContainers.PSObject.Properties) {
		foreach ($container in @($containerList.Value)) {
			$container | Add-Member -MemberType NoteProperty -Name icon -Value "assets/icons/pass-ai-view.svg" -Force
		}
	}
}

$utf8NoBom = New-Object System.Text.UTF8Encoding $false
$json = $manifest | ConvertTo-Json -Depth 100
[System.IO.File]::WriteAllText($manifestPath, $json, $utf8NoBom)
Write-Host "Patched Cline manifest for PASS AI (auxiliary bar, branding)." -ForegroundColor Green
