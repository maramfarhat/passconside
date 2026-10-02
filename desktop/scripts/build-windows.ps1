#Requires -Version 5.1
param(
	[switch]$Launch,
	[switch]$SkipGulp,
	[switch]$SkipPostinstall
)

$ErrorActionPreference = "Stop"
$DesktopRoot = Split-Path $PSScriptRoot -Parent
$BuildRoot = Join-Path $DesktopRoot "vscode"

if (-not (Test-Path (Join-Path $BuildRoot "package.json"))) {
	throw "Run desktop\scripts\setup-vscode.ps1 first."
}

function Invoke-BuildStep {
	param([scriptblock]$Step)
	$prev = $ErrorActionPreference
	$ErrorActionPreference = "Continue"
	try {
		& $Step
	} finally {
		$ErrorActionPreference = $prev
	}
}

Push-Location $BuildRoot
try {
	if (-not (Get-Command yarn -ErrorAction SilentlyContinue)) {
		throw "Install Yarn 1.x: npm install -g yarn@1.22.22"
	}

	Invoke-BuildStep { yarn --ignore-scripts 2>&1 | Out-Host }
	if ($LASTEXITCODE -ne 0) { throw "yarn failed" }

	Invoke-BuildStep { & (Join-Path $PSScriptRoot "patch-native-spectre.ps1") -VscodeDir $BuildRoot 2>&1 | Out-Host }

	if (-not $SkipPostinstall) {
		Invoke-BuildStep { & (Join-Path $PSScriptRoot "postinstall-windows.ps1") -VscodeDir $BuildRoot 2>&1 | Out-Host }
		if ($LASTEXITCODE -ne 0) { throw "postinstall failed (often ENOSPC: free disk space or native build)" }
	}

	if (-not $SkipGulp) {
		Invoke-BuildStep { yarn gulp vscode-win32-x64 2>&1 | Out-Host }
		if ($LASTEXITCODE -ne 0) { throw "gulp failed" }
	}

	$packagedRoot = Join-Path $DesktopRoot "VSCode-win32-x64"
	$exeNames = @("Code.exe", "PASS AI.exe")
	$exe = $null
	foreach ($name in $exeNames) {
		$candidate = Join-Path $packagedRoot $name
		if (Test-Path $candidate) {
			$exe = Get-Item $candidate
			break
		}
	}
	if (-not $exe) {
		$exe = Get-ChildItem -Path $packagedRoot -Filter "*.exe" -ErrorAction SilentlyContinue |
			Where-Object { $_.Name -notmatch 'inno|setup|unins' } |
			Select-Object -First 1
	}
	if ($exe) {
		Write-Host "PASS AI: $($exe.FullName)" -ForegroundColor Green
		if ($Launch) { Start-Process -FilePath $exe.FullName }
	} else {
		Write-Warning "Code.exe not found yet."
	}
} finally {
	Pop-Location
}
