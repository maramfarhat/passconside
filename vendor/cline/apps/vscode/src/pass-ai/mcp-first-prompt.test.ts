import { describe, expect, it } from "vitest"
import type { McpServer } from "@shared/mcp"
import { augmentPromptForMcpFirst, matchMcpServersInPrompt } from "./mcp-first-prompt"

function server(partial: Partial<McpServer> & Pick<McpServer, "name">): McpServer {
	return {
		config: "{}",
		status: "connected",
		tools: [{ name: "ask_question" }],
		...partial,
	}
}

describe("matchMcpServersInPrompt", () => {
	it("matches DeepWiki when named in the prompt", () => {
		const servers = [server({ name: "DeepWiki" })]
		expect(matchMcpServersInPrompt("Use DeepWiki mcp server tool to explain architecture", servers)).toHaveLength(1)
	})
})

describe("augmentPromptForMcpFirst", () => {
	it("adds MCP-first guidance when a configured server matches", () => {
		const out = augmentPromptForMcpFirst(
			"Use DeepWiki mcp server tool to explain the architecture of this repository.",
			[server({ name: "DeepWiki", tools: [{ name: "read_wiki" }] })],
			"win32",
		)
		expect(out).toContain("<pass_ai_mcp_first>")
		expect(out).toContain('Server "DeepWiki"')
		expect(out).toContain("read_wiki")
		expect(out).toContain("DeepWiki__")
		expect(out).toContain("PowerShell")
	})

	it("leaves casual prompts unchanged", () => {
		const prompt = "hello there"
		expect(augmentPromptForMcpFirst(prompt, [server({ name: "DeepWiki" })])).toBe(prompt)
	})
})
