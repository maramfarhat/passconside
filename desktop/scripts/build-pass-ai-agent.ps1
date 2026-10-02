#Requires -Version 5.1
param(
	[switch]$SkipPatch,
	[switch]$SkipBuild,
	[switch]$VsixOnly
)

$ErrorActionPreference = "Stop"
$DesktopRoot = Split-Path $PSScriptRoot -Parent
$RepoRoot = Split-Path $DesktopRoot -Parent
$VendorLink = Join-Path $RepoRoot "vendor\cline"
$ClineRoot = $VendorLink
if (Test-Path $VendorLink) {
	$item = Get-Item $VendorLink -Force
	if ($item.LinkType -eq "Junction" -and $item.Target) {
		$ClineRoot = $item.Target[0]
	}
}
$VscodeExtDir = Join-Path $DesktopRoot "vscode\extensions\pass-ai-agent"

if (-not (Test-Path (Join-Path $ClineRoot "package.json"))) {
	& (Join-Path $PSScriptRoot "link-cline-vendor.ps1")
	$item = Get-Item $VendorLink -Force
	if ($item.LinkType -eq "Junction" -and $item.Target) {
		$ClineRoot = $item.Target[0]
	}
}

if (-not $SkipPatch) {
	# Agent on right secondary side bar (Cursor-style). Do not use -UseActivityBar.
	& (Join-Path $PSScriptRoot "patch-cline-for-pass-ai.ps1") -ClineRoot $ClineRoot
	& (Join-Path $PSScriptRoot "apply-pass-agent-branding.ps1") -ClineRoot $ClineRoot
}

if (-not (Get-Command bun -ErrorAction SilentlyContinue)) {
	throw "Install Bun (https://bun.sh). Cline builds with bun workspaces."
}

if (-not $SkipBuild) {
	Push-Location $ClineRoot
	try {
		$prev = $ErrorActionPreference
		$ErrorActionPreference = "Continue"
		bun install --backend=copyfile 2>&1 | Out-Host
		if ($LASTEXITCODE -ne 0) { throw "bun install failed" }

		bun run build:sdk 2>&1 | Out-Host
		$sdkOk = ($LASTEXITCODE -eq 0)

		Push-Location (Join-Path $ClineRoot "apps\vscode")
		try {
			bun run build:production 2>&1 | Out-Host
			if ($LASTEXITCODE -ne 0) {
				if (-not $sdkOk) {
					Write-Warning "build:sdk failed (often @cline/llms types); build:production also failed. Restore sdk/dist from a good build or fix llms, then retry."
				}
				throw "apps/vscode build:production failed"
			}
			if (-not $sdkOk) {
				Write-Warning "build:sdk failed but apps/vscode build:production succeeded using existing sdk dist artifacts."
			}
		} finally {
			Pop-Location
		}
		$ErrorActionPreference = $prev
	} finally {
		Pop-Location
	}
}

$sourceExt = Join-Path $ClineRoot "apps\vscode"
$staging = Join-Path $DesktopRoot "out\pass-ai-agent-staging"
if (Test-Path $staging) {
	Remove-Item $staging -Recurse -Force
}
New-Item -ItemType Directory -Path $staging -Force | Out-Null

$endpointsPass = Join-Path (Split-Path $PSScriptRoot -Parent) "agent\endpoints.json"
Copy-Item -Path $endpointsPass -Destination (Join-Path $sourceExt "endpoints.json") -Force

$copyItems = @("dist", "assets", "walkthrough", "package.json", "LICENSE", "README.md", "endpoints.json")
foreach ($item in $copyItems) {
	$from = Join-Path $sourceExt $item
	if (Test-Path $from) {
		Copy-Item -Path $from -Destination (Join-Path $staging $item) -Recurse -Force
	}
}
$webviewBuild = Join-Path $sourceExt "webview-ui\build"
if (-not (Test-Path $webviewBuild)) {
	throw "Missing $webviewBuild; run build:production in apps/vscode first."
}
$webviewDest = Join-Path $staging "webview-ui\build"
New-Item -ItemType Directory -Path (Split-Path $webviewDest -Parent) -Force | Out-Null
Copy-Item -Path $webviewBuild -Destination $webviewDest -Recurse -Force

if (Test-Path $VscodeExtDir) {
	Remove-Item $VscodeExtDir -Recurse -Force
}
Copy-Item -Path $staging -Destination $VscodeExtDir -Recurse -Force
Write-Host "Installed extension -> $VscodeExtDir" -ForegroundColor Green

$pkgPath = Join-Path $VscodeExtDir "package.json"
$pkg = Get-Content $pkgPath -Raw -Encoding UTF8 | ConvertFrom-Json
if ($pkg.scripts.'vscode:prepublish') { $pkg.scripts.PSObject.Properties.Remove('vscode:prepublish') }
if ($pkg.scripts.prepublishOnly) { $pkg.scripts.PSObject.Properties.Remove('prepublishOnly') }
if ($pkg.devDependencies.'@types/vscode') { $pkg.devDependencies.'@types/vscode' = '1.93.0' }
$utf8NoBom = New-Object System.Text.UTF8Encoding $false
[System.IO.File]::WriteAllText($pkgPath, ($pkg | ConvertTo-Json -Depth 100), $utf8NoBom)

$userExt = Join-Path $env:USERPROFILE ".pass-ai\extensions\pass-ai-agent"
$userParent = Split-Path $userExt -Parent
if (-not (Test-Path $userParent)) { New-Item -ItemType Directory -Path $userParent -Force | Out-Null }
if (Test-Path $userExt) { Remove-Item $userExt -Recurse -Force }
Copy-Item -Path $VscodeExtDir -Destination $userExt -Recurse -Force
Write-Host "Installed for runtime -> $userExt" -ForegroundColor Green

Push-Location $VscodeExtDir
try {
	$prev = $ErrorActionPreference
	$ErrorActionPreference = "Continue"
	npx --yes @vscode/vsce@2.32.0 package --no-dependencies --no-yarn --allow-missing-repository 2>&1 | Out-Host
	$ErrorActionPreference = $prev
	$vsix = Get-ChildItem -Filter "*.vsix" | Sort-Object LastWriteTime -Descending | Select-Object -First 1
	if ($vsix) {
		Write-Host "VSIX: $($vsix.FullName)" -ForegroundColor Green
	}
} finally {
	Pop-Location
}

if (-not $VsixOnly) {
	& (Join-Path $PSScriptRoot "sync-bundled-pass-ai-agent.ps1") -AgentDir $VscodeExtDir
	Write-Host "Rebuild PASS AI desktop to refresh core bits, or run the packaged PASS AI.exe after sync above." -ForegroundColor Cyan
}
