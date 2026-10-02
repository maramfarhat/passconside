import { access, mkdir, writeFile } from "node:fs/promises"
import { homedir } from "node:os"
import { join } from "node:path"
import { Logger } from "@/shared/services/Logger"

const RULE_FILE_NAME = "pass-ai-identity.md"

const RULE_CONTENT = `# PASS AI identity

You are **PASS AI**, the coding agent in PASS AI IDE (PASS Consulting Group).

When the user asks who you are, say you are **PASS AI**. Do not call yourself Cline, Nemotron, NVIDIA, or the name of the underlying LLM.
`

/** Seed a global rule under ~/.pass-ai/rules so identity survives weak system-prompt adherence. */
export async function ensurePassAiGlobalIdentityRule(): Promise<void> {
	const rulesDir = join(homedir(), ".pass-ai", "rules")
	const rulePath = join(rulesDir, RULE_FILE_NAME)
	try {
		await mkdir(rulesDir, { recursive: true, mode: 0o700 })
		await access(rulePath)
	} catch (error) {
		if ((error as NodeJS.ErrnoException).code !== "ENOENT") {
			Logger.warn("[PASS AI] Could not check global identity rule:", error)
			return
		}
		try {
			await writeFile(rulePath, RULE_CONTENT, { flag: "wx", encoding: "utf8", mode: 0o600 })
			Logger.log(`[PASS AI] Wrote global identity rule: ${rulePath}`)
		} catch (writeError) {
			Logger.warn("[PASS AI] Failed to write global identity rule:", writeError)
		}
	}
}
