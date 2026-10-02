#Requires -Version 5.1
param(
	[string]$ClineRoot = (Join-Path (Split-Path (Split-Path $PSScriptRoot -Parent) -Parent) "vendor\cline")
)

$ErrorActionPreference = "Stop"
$vscode = Join-Path $ClineRoot "apps\vscode"
if (-not (Test-Path $vscode)) {
	$item = Get-Item (Join-Path (Split-Path (Split-Path $PSScriptRoot -Parent) -Parent) "vendor\cline") -Force -ErrorAction SilentlyContinue
	if ($item -and $item.Target) { $ClineRoot = $item.Target[0]; $vscode = Join-Path $ClineRoot "apps\vscode" }
}
if (-not (Test-Path $vscode)) { throw "Cline apps/vscode not found. Run link-cline-vendor.ps1 first." }

function Set-Utf8([string]$Path, [string]$Content) {
	$utf8 = New-Object System.Text.UTF8Encoding $false
	[System.IO.File]::WriteAllText($Path, $Content, $utf8)
}

function Replace-InFile([string]$Path, [string]$Old, [string]$New) {
	if (-not (Test-Path $Path)) { return }
	$raw = [System.IO.File]::ReadAllText($Path)
	if ($raw -notlike "*$Old*") { return }
	Set-Utf8 $Path ($raw.Replace($Old, $New))
}

$configTs = Join-Path $vscode "src\config.ts"
Replace-InFile $configTs ".cline/endpoints.json" ".pass-ai/endpoints.json"
Replace-InFile $configTs 'path.join(os.homedir(), ".cline"' 'path.join(os.homedir(), ".pass-ai"'
Replace-InFile $configTs "Cline running in self-hosted mode" "PASS AI agent running in standalone mode"

# Keep VS Code command IDs as cline.* (package.json menus); user-facing strings use PASS AI via manifest patch.

$welcome = Join-Path $vscode "webview-ui\src\components\account\AccountWelcomeView.tsx"
if (Test-Path $welcome) {
	$content = @'
import { VSCodeButton } from "@vscode/webview-ui-toolkit/react"
import { useExtensionState } from "@/context/ExtensionStateContext"

export const AccountWelcomeView = () => {
	const { environment } = useExtensionState()

	return (
		<div className="flex flex-col items-center gap-3 text-center px-2">
			<h2 className="text-lg font-semibold m-0">PASS AI account</h2>
			<p className="m-0 text-sm">
				Organization sign-in for PASS AI will connect to the PASS backend (Spring Boot). It is not linked to Cline
				accounts or ClinePass.
			</p>
			<p className="m-0 text-xs text-(--vscode-descriptionForeground)">
				For now, use <strong>Settings</strong> to configure Ollama, OpenRouter, or other API keys. Environment:{" "}
				{environment ?? "standalone"}
			</p>
			<VSCodeButton className="w-full" disabled>
				PASS sign-in (coming soon)
			</VSCodeButton>
		</div>
	)
}
'@
	Set-Utf8 $welcome $content
}

$accountView = Join-Path $vscode "webview-ui\src\components\account\AccountView.tsx"
Replace-InFile $accountView '<ViewHeader environment={environment} onDone={onDone} showEnvironmentSuffix title="Account" />' '<ViewHeader environment={environment} onDone={onDone} showEnvironmentSuffix title="PASS account" />'
# Never show Cline cloud account (credits, ClinePass, OAuth profile) in PASS AI standalone.
if (Test-Path $accountView) {
	$av = [System.IO.File]::ReadAllText($accountView)
	if ($av -match 'clineUser\?\.uid') {
		$av = [regex]::Replace(
			$av,
			'\{clineUser\?\.uid \? \([\s\S]*?\) : \(\s*<AccountWelcomeView />\s*\)\}',
			'<AccountWelcomeView />',
			1
		)
		Set-Utf8 $accountView $av
	}
}

$passHint = Join-Path $vscode "webview-ui\src\components\settings\ClinePassHint.tsx"
if (Test-Path $passHint) {
	Set-Utf8 $passHint @'
/** PASS AI: no ClinePass promos in standalone product. */
import type { ApiProvider } from "@shared/api"

interface ClinePassHintProps {
	selectedProvider: ApiProvider
	currentMode: string
}

export const ClinePassHint = (_props: ClinePassHintProps) => null
'@
}

$passCard = Join-Path $vscode "webview-ui\src\components\account\ClinePassCard.tsx"
if (Test-Path $passCard) {
	Set-Utf8 $passCard @'
/** PASS AI: ClinePass UI disabled — standalone product, no Cline billing. */
export const ClinePassCard = () => null
export const ClinePassWelcomeCallout = () => null
'@
}

$viewHeader = Join-Path $vscode "webview-ui\src\components\common\ViewHeader.tsx"
Replace-InFile $viewHeader 'title="Account"' 'title="PASS account"'

# Remove Cline marketing/doc links only in selected UI (never touch MCP/marketplace trees).
$webviewSrc = Join-Path $vscode "webview-ui\src"
$clineLinkPattern = '<VSCodeLink[\s\S]*?href="https?://[^"]*cline[^"]*"[\s\S]*?>([\s\S]*?)</VSCodeLink>'
$passLinkStripTargets = @(
	"components\cline-rules\ClineRulesToggleModal.tsx",
	"components\settings\sections\GeneralSettingsSection.tsx",
	"components\settings\sections\TerminalSettingsSection.tsx",
	"components\settings\sections\RemoteConfigSection.tsx",
	"components\settings\sections\AboutSection.tsx",
	"components\worktrees\WorktreesView.tsx",
	"components\worktrees\CreateWorktreeModal.tsx",
	"components\chat\auto-approve-menu\AutoApproveModal.tsx",
	"components\chat\ErrorRow.tsx",
	"components\chat\ChatRow.tsx",
	"components\common\WhatsNewModal.tsx",
	"components\onboarding\data-steps.ts"
)
foreach ($rel in $passLinkStripTargets) {
	$filePath = Join-Path $webviewSrc $rel
	if (-not (Test-Path $filePath)) { continue }
	$raw = [System.IO.File]::ReadAllText($filePath)
	if ($raw -notmatch 'cline\.bot|docs\.cline|github\.com/cline|discord\.gg/cline|/r/cline') { continue }
	$new = [regex]::Replace($raw, $clineLinkPattern, '$1', [System.Text.RegularExpressions.RegexOptions]::Singleline)
	$new = [regex]::Replace($new, 'href="https?://[^"]*cline[^"]*"', '')
	if ($rel -eq "components\cline-rules\ClineRulesToggleModal.tsx") {
		$new = $new.Replace(' provide Cline with ', ' provide the PASS AI agent with ')
		$new = $new.Replace(' guide Cline through ', ' guide the agent through ')
		$new = $new.Replace(' that Cline can ', ' that the agent can ')
		$new = $new.Replace(', Cline uses ', ', the agent uses ')
		$new = $new.Replace(" in Cline's execution", " in the agent's execution")
		$new = [regex]::Replace($new, '\{\s*"\s*"\s*\}\s*\n\s*Docs\s*\n', "`n")
		$new = [regex]::Replace($new, '\s*Learn more\s*', '')
	}
	if ($new -ne $raw) { Set-Utf8 $filePath $new }
}

$mcpRemoteForm = Join-Path $webviewSrc "components\mcp\configuration\tabs\add-server\AddRemoteServerForm.tsx"
if (Test-Path $mcpRemoteForm) {
	Replace-InFile $mcpRemoteForm 'import { LINKS } from "@/constants"' ''
	Replace-InFile $mcpRemoteForm ', VSCodeLink' ''
	Replace-InFile $mcpRemoteForm @'
Add a remote MCP server by providing a name and its URL endpoint.{" "}
				<VSCodeLink href={LINKS.DOCUMENTATION.REMOTE_MCP_SERVER_DOCS} style={{ display: "inline" }}>
					here.
				</VSCodeLink>
'@ 'Add a remote MCP server by providing a name and its URL endpoint.'
}

$aboutSection = Join-Path $webviewSrc "components\settings\sections\AboutSection.tsx"
if (Test-Path $aboutSection) {
	Set-Utf8 $aboutSection @'
import Section from "../Section"

interface AboutSectionProps {
	version: string
	extensionVariant?: "legacy" | "next"
	renderSectionHeader: (tabId: string) => JSX.Element | null
}

const AboutSection = ({ version, renderSectionHeader }: AboutSectionProps) => {
	return (
		<div>
			{renderSectionHeader("about")}
			<Section>
				<div className="flex px-4 flex-col gap-2">
					<h2 className="text-lg font-semibold">PASS AI Agent v{version}</h2>
					<p>
						Autonomous coding assistant for PASS AI IDE. It can use your CLI and editor to create and edit files,
						explore projects, and run terminal commands after you grant permission.
					</p>
					<p className="text-xs text-(--vscode-descriptionForeground)">
						Support and documentation are provided by PASS Consulting Group (no external Cline links in this build).
					</p>
				</div>
			</Section>
		</div>
	)
}

export default AboutSection
'@
}

$brandingDir = Join-Path (Split-Path $PSScriptRoot -Parent) "agent\branding"
$logoSrc = Join-Path $brandingDir "pass-logo-circle.png"
$logoDest = Join-Path $vscode "webview-ui\src\assets\pass-logo-circle.png"
if (Test-Path $logoSrc) {
	$logoParent = Split-Path $logoDest -Parent
	if (-not (Test-Path $logoParent)) { New-Item -ItemType Directory -Path $logoParent -Force | Out-Null }
	Copy-Item $logoSrc $logoDest -Force
}

# User-visible "Cline" -> "PASS AI" in chat/MCP/welcome copy (never type names like ClineMessage).
$agentBrandFile = Join-Path $webviewSrc "agentBrand.ts"
Set-Utf8 $agentBrandFile @'
/** User-visible agent name in PASS AI builds. */
export const AGENT_DISPLAY_NAME = "PASS AI"
'@

$displayNameReplacements = [ordered]@{
	"Cline wants" = "PASS AI wants"
	"Cline is " = "PASS AI is "
	"Cline has " = "PASS AI has "
	"Cline viewed" = "PASS AI viewed"
	"Cline recursively" = "PASS AI recursively"
	"Cline fetched" = "PASS AI fetched"
	"Cline searched" = "PASS AI searched"
	"Cline loaded" = "PASS AI loaded"
	"Cline may" = "PASS AI may"
	"Cline creates" = "PASS AI creates"
	"Cline is using" = "PASS AI is using"
	"Cline's capabilities" = "PASS AI's capabilities"
	"Cline's response" = "PASS AI's response"
	"Cline tasks" = "PASS AI tasks"
	"Cline will " = "PASS AI will "
	"Connect Cline to" = "Connect PASS AI to"
	"Let Cline take" = "Let PASS AI take"
	"give Cline " = "give PASS AI "
	"before Cline " = "before PASS AI "
	"with Cline" = "with PASS AI"
	"ask Cline " = "ask PASS AI "
	"Hi, I'm Cline" = "Hi, I'm PASS AI"
	"Sign in to Cline" = "Sign in to PASS AI"
	'"Cline" + action' = '"PASS AI" + action'
	"Cline Version" = "PASS AI Agent version"
	"Cline reads" = "PASS AI reads"
	"About Cline" = "About PASS AI"
	"You are Cline, an AI coding agent" = "You are PASS AI, an AI coding agent"
	"You are Cline, a careful and helpful" = "You are PASS AI, a careful and helpful"
	"You are Cline, a highly skilled" = "You are PASS AI, a highly skilled"
}

$uiFiles = Get-ChildItem -Path $webviewSrc -Recurse -Include *.tsx,*.ts |
	Where-Object {
		$_.FullName -notmatch '\\node_modules\\' -and
		$_.Name -notmatch '\.(test|spec|stories)\.(tsx|ts)$' -and
		$_.Name -notmatch 'Cline(Auth|Pass|Error|Model|Logo|Account|Provider|Free|Rules)' -and
		$_.DirectoryName -notmatch '\\assets\\'
	}
$sharedPromptDir = Join-Path $ClineRoot "sdk\packages\shared\src\prompt\system"
foreach ($promptFile in @("act.ts", "yolo.ts")) {
	$promptPath = Join-Path $sharedPromptDir $promptFile
	if (-not (Test-Path $promptPath)) { continue }
	$raw = [System.IO.File]::ReadAllText($promptPath)
	$new = $raw
	foreach ($pair in $displayNameReplacements.GetEnumerator()) {
		if ($new.Contains($pair.Key)) { $new = $new.Replace($pair.Key, $pair.Value) }
	}
	if ($new -ne $raw) { Set-Utf8 $promptPath $new }
}

foreach ($file in $uiFiles) {
	$raw = [System.IO.File]::ReadAllText($file.FullName)
	$new = $raw
	foreach ($pair in $displayNameReplacements.GetEnumerator()) {
		if ($new.Contains($pair.Key)) {
			$new = $new.Replace($pair.Key, $pair.Value)
		}
	}
	if ($new -ne $raw) {
		Set-Utf8 $file.FullName $new
	}
}

$terminalRegistry = Join-Path $vscode "src\hosts\vscode\terminal\VscodeTerminalRegistry.ts"
Replace-InFile $terminalRegistry 'name: "Cline"' 'name: "PASS AI"'
Replace-InFile $terminalRegistry "iconPath: new vscode.ThemeIcon(`"cline-icon`"),`r`n" ""
Replace-InFile $terminalRegistry "iconPath: new vscode.ThemeIcon(`"cline-icon`"),`n" ""

$execInTerm = Join-Path $vscode "src\hosts\vscode\hostbridge\workspace\executeCommandInTerminal.ts"
Replace-InFile $execInTerm 'name: "Cline"' 'name: "PASS AI"'
Replace-InFile $execInTerm "iconPath: new vscode.ThemeIcon(`"cline-icon`"),`r`n" ""
Replace-InFile $execInTerm "iconPath: new vscode.ThemeIcon(`"cline-icon`"),`n" ""

Write-Host "Applied PASS agent branding patches under $vscode" -ForegroundColor Green
