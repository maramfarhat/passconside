#Requires -Version 5.1
param(
	[string]$VscodeDir = (Join-Path (Split-Path $PSScriptRoot -Parent) "vscode")
)

$ErrorActionPreference = "Stop"

function Invoke-YarnIgnoreScripts([string]$Dir) {
	$cwd = if ($Dir) { Join-Path $VscodeDir $Dir } else { $VscodeDir }
	if (-not (Test-Path (Join-Path $cwd "package.json"))) { return }
	Push-Location $cwd
	try {
		$prev = $ErrorActionPreference
		$ErrorActionPreference = "Continue"
		yarn --ignore-scripts 2>&1 | Out-Host
		$ErrorActionPreference = $prev
		if ($LASTEXITCODE -ne 0) { throw "yarn --ignore-scripts failed in $Dir" }
	} finally {
		Pop-Location
	}
}

function Invoke-RootNativeRebuild() {
	$nodeGyp = Join-Path $VscodeDir "build\npm\gyp\node_modules\.bin\node-gyp.cmd"
	if (-not (Test-Path $nodeGyp)) {
		throw "Missing $nodeGyp; run yarn in build/npm/gyp first."
	}
	Push-Location $VscodeDir
	try {
		$yarnJs = (Get-Command yarn -ErrorAction Stop).Source
		if ($yarnJs -match "yarn\.ps1$") {
			$yarnJs = Join-Path (Split-Path $yarnJs -Parent) "node_modules\yarn\bin\yarn.js"
		}
		$env:npm_execpath = $yarnJs
		$prev = $ErrorActionPreference
		$ErrorActionPreference = "Continue"
		node build/npm/preinstall.js 2>&1 | Out-Host
		if ($LASTEXITCODE -ne 0) { throw "vscode preinstall failed" }

		Get-ChildItem -Path (Join-Path $VscodeDir "node_modules") -Recurse -Filter "binding.gyp" -ErrorAction SilentlyContinue |
			ForEach-Object {
				$pkgDir = $_.Directory.FullName
				Write-Host "node-gyp rebuild: $pkgDir" -ForegroundColor DarkCyan
				Push-Location $pkgDir
				try {
					& $nodeGyp rebuild 2>&1 | Out-Host
					if ($LASTEXITCODE -ne 0) { throw "node-gyp rebuild failed in $pkgDir" }
				} finally {
					Pop-Location
				}
			}
		$ErrorActionPreference = $prev
	} finally {
		Pop-Location
	}
}

function Invoke-NpmRebuild([string]$Dir) {
	if (-not $Dir) {
		Invoke-RootNativeRebuild
		return
	}
	$cwd = Join-Path $VscodeDir $Dir
	if (-not (Test-Path (Join-Path $cwd "package.json"))) { return }
	Push-Location $cwd
	try {
		$prev = $ErrorActionPreference
		$ErrorActionPreference = "Continue"
		npm rebuild 2>&1 | Out-Host
		$ErrorActionPreference = $prev
		if ($LASTEXITCODE -ne 0) { throw "npm rebuild failed in $Dir" }
	} finally {
		Pop-Location
	}
}

Push-Location $VscodeDir
try {
	$dirsJson = node -e "console.log(JSON.stringify(require('./build/npm/dirs').dirs))" 2>&1
	if ($LASTEXITCODE -ne 0) { throw "Failed to read build/npm/dirs.js: $dirsJson" }
	$dirs = $dirsJson | ConvertFrom-Json
	foreach ($dir in $dirs) {
		$label = if ($dir) { $dir } else { "(root)" }
		Write-Host "yarn --ignore-scripts: $label" -ForegroundColor Cyan
		if ($dir -eq "build") {
			node (Join-Path $VscodeDir "build\npm\setupBuildYarnrc.js") 2>&1 | Out-Host
		}
		Invoke-YarnIgnoreScripts $dir
		if ($dir -eq "extensions") {
			Push-Location (Join-Path $VscodeDir "extensions")
			try {
				node ./postinstall.mjs 2>&1 | Out-Host
				if ($LASTEXITCODE -ne 0) { throw "extensions postinstall.mjs failed" }
			} finally {
				Pop-Location
			}
		}
	}

	& (Join-Path $PSScriptRoot "patch-native-spectre.ps1") -VscodeDir $VscodeDir | Out-Host

	foreach ($dir in $dirs) {
		$label = if ($dir) { $dir } else { "(root)" }
		Write-Host "npm rebuild: $label" -ForegroundColor Cyan
		Invoke-NpmRebuild $dir
	}

	$prev = $ErrorActionPreference
	$ErrorActionPreference = "Continue"
	git config pull.rebase merges 2>&1 | Out-Null
	git config blame.ignoreRevsFile .git-blame-ignore-revs 2>&1 | Out-Null
	$ErrorActionPreference = $prev
} finally {
	Pop-Location
}

Write-Host "postinstall-windows completed." -ForegroundColor Green
