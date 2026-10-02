import type { McpServer } from "@shared/mcp"

const MCP_KEYWORD = /\bmcp\b/i

function normalizeToken(value: string): string {
	return value.toLowerCase().replace(/[^a-z0-9]+/g, "")
}

function promptContainsServerName(prompt: string, serverName: string): boolean {
	const lower = prompt.toLowerCase()
	if (lower.includes(serverName.toLowerCase())) {
		return true
	}
	const compactPrompt = normalizeToken(prompt)
	const compactName = normalizeToken(serverName)
	return compactName.length >= 2 && compactPrompt.includes(compactName)
}

/** Names the user likely meant when they mention an MCP server in natural language. */
export function extractLikelyMcpServerNamesFromPrompt(prompt: string): string[] {
	const names = new Set<string>()
	const useMcp = prompt.match(/\b(?:use|via|with|from)\s+([A-Za-z0-9][\w.-]{1,48})\s+mcp\b/i)
	if (useMcp?.[1]) {
		names.add(useMcp[1])
	}
	const mcpServer = prompt.match(/\b([A-Za-z0-9][\w.-]{1,48})\s+mcp(?:\s+server)?\b/i)
	if (mcpServer?.[1] && !/^(a|an|the|this|that|my|your)$/i.test(mcpServer[1])) {
		names.add(mcpServer[1])
	}
	return [...names]
}

export function matchMcpServersInPrompt(prompt: string, servers: readonly McpServer[]): McpServer[] {
	if (!prompt.trim()) {
		return []
	}
	const byName = servers.filter((server) => promptContainsServerName(prompt, server.name))
	if (byName.length) {
		return byName
	}
	if (!MCP_KEYWORD.test(prompt)) {
		return []
	}
	const hints = extractLikelyMcpServerNamesFromPrompt(prompt)
	if (!hints.length) {
		return []
	}
	return servers.filter((server) =>
		hints.some((hint) => normalizeToken(hint) === normalizeToken(server.name) || promptContainsServerName(hint, server.name)),
	)
}

function formatToolNames(server: McpServer): string {
	const tools = server.tools?.map((tool) => tool.name).filter(Boolean) ?? []
	if (!tools.length) {
		return "(no tools listed yet — wait for connection or use MCP settings to refresh)"
	}
	return tools.slice(0, 12).join(", ") + (tools.length > 12 ? ", …" : "")
}

function windowsShellHint(platform: NodeJS.Platform): string {
	if (platform !== "win32") {
		return ""
	}
	return `
If you must use the terminal on Windows, use PowerShell syntax (e.g. \`Get-ChildItem\`), not Unix \`ls -la\` or CMD-style \`dir /b /s\` (PowerShell treats \`/b\` as a path).`
}

/**
 * When the user asks for a named MCP server, steer the model to MCP tools before shell exploration.
 * Appended text is for the model only (not shown in the chat task bubble).
 */
export function augmentPromptForMcpFirst(
	prompt: string,
	servers: readonly McpServer[],
	platform: NodeJS.Platform = process.platform,
): string {
	const trimmed = prompt.trim()
	if (!trimmed) {
		return prompt
	}

	const mentionsMcp = MCP_KEYWORD.test(trimmed)
	const matched = matchMcpServersInPrompt(trimmed, servers)
	const hintedNames = mentionsMcp ? extractLikelyMcpServerNamesFromPrompt(trimmed) : []

	if (!mentionsMcp && !matched.length) {
		return prompt
	}

	if (matched.length) {
		const blocks = matched.map((server) => {
			const toolPrefix = `${server.name}__`
			const status =
				server.status === "connected"
					? "connected"
					: server.disabled
						? "disabled in MCP settings"
						: server.status
			return `- Server "${server.name}" (${status}). MCP tools use names like \`${toolPrefix}<tool>\`. Available tools: ${formatToolNames(server)}.`
		})
		return `${trimmed}

<pass_ai_mcp_first>
The user requested MCP server tool(s). These configured servers match the request:
${blocks.join("\n")}
Before running terminal/shell commands to explore the repo, call the matching MCP tools above (use_mcp / MCP tool names). Only fall back to the terminal if MCP tools cannot answer or the server is not connected.
${windowsShellHint(platform)}
</pass_ai_mcp_first>`
	}

	if (hintedNames.length) {
		const configured = servers.map((s) => s.name).join(", ") || "(none configured)"
		return `${trimmed}

<pass_ai_mcp_first>
The user asked to use MCP (${hintedNames.map((n) => `"${n}"`).join(", ")}), but no configured MCP server with that name was found.
Configured MCP servers: ${configured}.
Tell the user to add or enable the server under Customize → MCP → Installed, then retry. Do not substitute shell listing commands for the requested MCP server.
${windowsShellHint(platform)}
</pass_ai_mcp_first>`
	}

	if (mentionsMcp) {
		const configured = servers.map((s) => s.name).join(", ") || "(none configured)"
		return `${trimmed}

<pass_ai_mcp_first>
The user mentioned MCP. Check configured servers (${configured}) and prefer MCP tools over terminal exploration when a server applies.
${windowsShellHint(platform)}
</pass_ai_mcp_first>`
	}

	return prompt
}
