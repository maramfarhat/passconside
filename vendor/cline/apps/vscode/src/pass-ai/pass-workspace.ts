import { randomBytes } from "node:crypto"
import { access, mkdir, writeFile } from "node:fs/promises"
import { homedir } from "node:os"
import { join } from "node:path"
import { isChatWorkspacePath } from "@cline/shared/storage"
import * as vscode from "vscode"
import { Logger } from "@/shared/services/Logger"

const AGENTS_RULES_FILE_NAME = "AGENTS.md"

const PASS_WORKSPACE_RULES = `# PASS AI workspace

This folder was created for your current agent task. Treat it as the project root:
create and edit files here unless the user asks you to use a different path.

If the user wants to move the project elsewhere, say where files live and offer to
continue in the new location after they open that folder in PASS AI.
`

/** Shared chat fallback dirs (Cline legacy or PASS AI data dir). */
function isEphemeralChatWorkspace(fsPath: string): boolean {
	const normalized = fsPath.replace(/\\/g, "/").toLowerCase()
	if (isChatWorkspacePath(fsPath)) {
		return true
	}
	return /\/\.pass-ai\/data\/workspaces\/chat\/?$/.test(normalized)
}

function workspaceNeedsAutoProject(): boolean {
	const folders = vscode.workspace.workspaceFolders
	if (!folders?.length) {
		return true
	}
	if (folders.length === 1 && isEphemeralChatWorkspace(folders[0].uri.fsPath)) {
		return true
	}
	return false
}

const SLUG_STOP_WORDS = new Set([
	"a",
	"an",
	"the",
	"this",
	"that",
	"in",
	"on",
	"at",
	"to",
	"for",
	"and",
	"or",
	"with",
	"using",
	"use",
	"via",
	"from",
	"please",
	"create",
	"make",
	"build",
	"add",
	"write",
	"generate",
	"do",
	"not",
	"only",
	"full",
	"paste",
	"chat",
	"workspace",
	"folder",
	"file",
	"files",
	"project",
	"tool",
	"tools",
	"editor",
	"agent",
	"here",
])

const MAX_SLUG_LEN = 24

/** Casual messages that should not spawn a project folder (Cursor-style: task first). */
const GREETING_ONLY =
	/^\s*(hi|hello|hey|hiya|yo|sup|thanks|thank\s*you|thx|ok|okay|k|yes|no|yep|nope|test|help|\?+|how\s+are\s+you|what'?s\s+up|good\s+(morning|afternoon|evening)|who\s+are\s+you|what\s+can\s+you\s+do)[\s!.,?]*$/i

const TASK_VERB =
	/\b(build|create|fix|implement|write|refactor|debug|deploy|set\s*up|setup|install|migrate|update|delete|remove|generate|scaffold|convert|integrate|develop|design|review|optimize|rename|add|make|run|execute|continue|finish|open|change|replace|patch|fixing|building|creating)\b/i

const CHIT_CHAT_WORDS = new Set([
	"hi",
	"hello",
	"hey",
	"hiya",
	"yo",
	"sup",
	"thanks",
	"thank",
	"you",
	"thx",
	"ok",
	"okay",
	"yes",
	"no",
	"test",
	"help",
	"how",
	"are",
	"what",
	"when",
	"where",
	"why",
	"who",
	"can",
	"could",
	"would",
	"please",
	"doing",
	"good",
	"morning",
	"afternoon",
	"evening",
])

/**
 * Only auto-create a workspace folder when the first message looks like a real task,
 * not a greeting or small talk.
 */
export function promptWarrantsAutoWorkspace(prompt: string): boolean {
	const normalized = prompt.replace(/\s+/g, " ").trim()
	if (!normalized) {
		return false
	}

	if (/(^|\s)[A-Za-z0-9_.-]+(?:[/\\][A-Za-z0-9_.-]+)+/.test(normalized)) {
		return true
	}
	if (/["'`“”‘’][^"'`“”‘’]{2,40}["'`“”‘’]/.test(normalized)) {
		return true
	}
	if (/@\w/.test(normalized)) {
		return true
	}
	if (GREETING_ONLY.test(normalized)) {
		return false
	}
	if (TASK_VERB.test(normalized)) {
		return true
	}

	const words = normalized
		.toLowerCase()
		.replace(/[^a-z0-9\s/-]+/g, " ")
		.split(/\s+/)
		.filter(Boolean)
	const significant = words.filter((w) => w.length >= 2 && !SLUG_STOP_WORDS.has(w.replace(/[/\\].*$/, "")))

	if (significant.length >= 2 && normalized.length >= 16) {
		if (significant.every((w) => CHIT_CHAT_WORDS.has(w))) {
			return false
		}
		return true
	}

	const slug = slugFromTaskPrompt(normalized)
	const greetingSlugs = new Set(["hi", "hey", "yo", "ok", "test", "help", "hello", "thanks", "thank-you"])
	if (greetingSlugs.has(slug) && words.length <= 4) {
		return false
	}

	return false
}

function toSlugToken(text: string): string {
	return text
		.toLowerCase()
		.normalize("NFKD")
		.replace(/[\u0300-\u036f]/g, "")
		.replace(/[^a-z0-9]+/g, "-")
		.replace(/^-+|-+$/g, "")
}

/** Derive a short folder name from the user's first message (Cursor-style, not the full prompt). */
export function slugFromTaskPrompt(prompt: string): string {
	const normalized = prompt
		.replace(/@[\w./-]+/g, " ")
		.replace(/\s+/g, " ")
		.trim()

	// Prefer the first path segment: "shop/index.html" -> "shop"
	const pathLike = normalized.match(/(?:^|\s)([A-Za-z0-9_.-]+(?:[/\\][A-Za-z0-9_.-]+)+)/)
	if (pathLike) {
		const firstSegment = pathLike[1].split(/[/\\]/)[0]
		const fromPath = toSlugToken(firstSegment)
		if (fromPath.length >= 2) {
			return fromPath.slice(0, MAX_SLUG_LEN)
		}
	}

	// Quoted name: create a "todo app" -> "todo-app"
	const quoted = normalized.match(/["'`“”‘’]([^"'`“”‘’]{2,40})["'`“”‘’]/)
	if (quoted) {
		const fromQuote = toSlugToken(quoted[1])
		if (fromQuote.length >= 2) {
			return fromQuote.slice(0, MAX_SLUG_LEN)
		}
	}

	const words = normalized
		.toLowerCase()
		.replace(/[^a-z0-9\s/-]+/g, " ")
		.split(/\s+/)
		.filter(Boolean)

	const significant: string[] = []
	for (const word of words) {
		const bare = word.replace(/[/\\].*$/, "")
		if (bare.length < 2 || SLUG_STOP_WORDS.has(bare)) {
			continue
		}
		significant.push(bare)
		if (significant.length >= 4) {
			break
		}
	}

	if (significant.length) {
		const fromWords = toSlugToken(significant.join("-"))
		if (fromWords.length >= 2) {
			return fromWords.slice(0, MAX_SLUG_LEN)
		}
	}

	const fallback = toSlugToken(normalized.slice(0, 60))
	return (fallback || "project").slice(0, MAX_SLUG_LEN)
}

async function resolveUniqueProjectDir(baseName: string): Promise<{ dirPath: string; displayName: string }> {
	const root = join(homedir(), ".pass-ai", "workspaces")
	await mkdir(root, { recursive: true, mode: 0o700 })
	let candidate = baseName
	let dirPath = join(root, candidate)
	for (let attempt = 0; attempt < 8; attempt++) {
		try {
			await access(dirPath)
			candidate = `${baseName}-${randomBytes(2).toString("hex")}`
			dirPath = join(root, candidate)
		} catch (error) {
			if ((error as NodeJS.ErrnoException).code === "ENOENT") {
				return { dirPath, displayName: candidate }
			}
			throw error
		}
	}
	candidate = `${baseName}-${Date.now()}`
	return { dirPath: join(root, candidate), displayName: candidate }
}

async function seedWorkspaceRules(dirPath: string): Promise<void> {
	await mkdir(dirPath, { recursive: true, mode: 0o700 })
	const rulesPath = join(dirPath, AGENTS_RULES_FILE_NAME)
	try {
		await writeFile(rulesPath, PASS_WORKSPACE_RULES, { flag: "wx" })
	} catch (error) {
		if ((error as NodeJS.ErrnoException).code !== "EEXIST") {
			throw error
		}
	}
}

/**
 * When no real folder is open, create a project directory from the task prompt
 * and add it to the VS Code workspace (Cursor-style).
 */
export async function ensurePassWorkspaceFromPrompt(prompt?: string): Promise<string | undefined> {
	const text = prompt?.trim()
	if (!text) {
		return undefined
	}
	if (!promptWarrantsAutoWorkspace(text)) {
		Logger.log("[PASS AI] Skipping auto workspace (no task in first message)")
		return undefined
	}
	if (!workspaceNeedsAutoProject()) {
		return undefined
	}

	const baseName = slugFromTaskPrompt(text)
	const { dirPath, displayName } = await resolveUniqueProjectDir(baseName)
	await seedWorkspaceRules(dirPath)

	const uri = vscode.Uri.file(dirPath)
	const folders = vscode.workspace.workspaceFolders
	let opened = false

	if (!folders?.length) {
		opened = vscode.workspace.updateWorkspaceFolders(0, null, { uri, name: displayName }) ?? false
	} else if (folders.length === 1 && isEphemeralChatWorkspace(folders[0].uri.fsPath)) {
		opened = vscode.workspace.updateWorkspaceFolders(0, 1, { uri, name: displayName }) ?? false
	}

	if (!opened) {
		Logger.warn(`[PASS AI] Could not open workspace folder: ${dirPath}`)
		return dirPath
	}

	Logger.log(`[PASS AI] Opened workspace from task context: ${dirPath}`)
	return dirPath
}
