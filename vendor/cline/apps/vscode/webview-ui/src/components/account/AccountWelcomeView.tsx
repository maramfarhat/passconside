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