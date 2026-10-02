import * as vscode from 'vscode';

export function activate(context: vscode.ExtensionContext): void {
	const disposable = vscode.commands.registerCommand('passAi.showWelcome', () => {
		void vscode.commands.executeCommand(
			'workbench.action.openWalkthrough',
			'pass-consulting.pass-ai-welcome#passAi.getStarted'
		);
	});
	context.subscriptions.push(disposable);
}

export function deactivate(): void {}
