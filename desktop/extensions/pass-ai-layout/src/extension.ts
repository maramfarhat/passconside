import * as vscode from "vscode";

const AGENT_VIEW_ID = "claude-dev.SidebarProvider";
const AGENT_CONTAINER = "workbench.view.extension.claude-dev-ActivityBar";
const LAYOUT_FIXED_KEY = "passAiAgentLayoutFixedV3";

async function openAgentPanel(): Promise<void> {
	try {
		await vscode.commands.executeCommand("workbench.action.focusAuxiliaryBar");
	} catch {
		// ignore
	}
	try {
		await vscode.commands.executeCommand(AGENT_CONTAINER);
	} catch {
		try {
			await vscode.commands.executeCommand(`${AGENT_VIEW_ID}.focus`);
		} catch {
			// Agent extension not installed yet.
		}
	}
}

async function repairAgentLayout(context: vscode.ExtensionContext): Promise<void> {
	if (context.globalState.get<boolean>(LAYOUT_FIXED_KEY)) {
		return;
	}
	try {
		await vscode.commands.executeCommand("workbench.action.resetViewLocations");
	} catch {
		// ignore
	}
	await openAgentPanel();
	await context.globalState.update(LAYOUT_FIXED_KEY, true);
}

export function activate(context: vscode.ExtensionContext): void {
	context.subscriptions.push(
		vscode.commands.registerCommand("pass-ai.toggleAgentPanel", () => openAgentPanel()),
		vscode.commands.registerCommand("pass-ai.fixAgentLayout", async () => {
			await context.globalState.update(LAYOUT_FIXED_KEY, false);
			await repairAgentLayout(context);
			void vscode.window.showInformationMessage(
				"PASS AI agent layout reset. If the title still looks wrong, run Developer: Reload Window.",
			);
		}),
	);

	void repairAgentLayout(context);
}

export function deactivate(): void {}
