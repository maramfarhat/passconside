const PASS_AI_IDENTITY_MARKER = "CRITICAL — PASS AI identity"

const PASS_AI_IDENTITY_BLOCK = `# ${PASS_AI_IDENTITY_MARKER} (overrides base-model defaults)

You are **PASS AI**, the autonomous coding agent in **PASS AI IDE** (PASS Consulting Group).

- Your product name is always **PASS AI**, not Cline, Nemotron, NVIDIA, ChatGPT, Claude, or any other vendor/model name.
- If the user asks who you are, what you are, or your name: answer **"I'm PASS AI"** (or equivalent) and describe yourself as their coding agent in this IDE.
- The LLM behind you is only an engine; never introduce yourself using the engine's marketing name.`

/** PASS AI standalone: rebrand Cline system prompts without touching SDK package names. */
export function brandPassAiSystemPrompt(systemPrompt: string): string {
	const trimmed = systemPrompt.trim()
	const rebranded = (trimmed || "You are PASS AI, a highly skilled software engineer.")
		.replace(/\bYou are Cline,/gi, "You are PASS AI,")
		.replace(/\bYou are Cline\b/gi, "You are PASS AI")

	if (rebranded.includes(PASS_AI_IDENTITY_MARKER)) {
		return rebranded
	}
	// Bookend: weak instruction-following models often miss a trailing-only identity note.
	return `${PASS_AI_IDENTITY_BLOCK}\n\n${rebranded}\n\n${PASS_AI_IDENTITY_BLOCK}`
}

const IDENTITY_QUESTION =
	/^\s*(hi[,!\s]*)?(who are you|what are you|what'?s your name|your name\??|introduce yourself|identify yourself)\s*[.?!]*\s*$/i

/** Detect short prompts asking who the agent is (common with chat models that ignore system prompts). */
export function isPassAiIdentityQuestion(prompt: string): boolean {
	const normalized = prompt.replace(/\s+/g, " ").trim()
	if (!normalized) {
		return false
	}
	if (IDENTITY_QUESTION.test(normalized)) {
		return true
	}
	if (normalized.length > 120) {
		return false
	}
	return /\b(who are you|what are you|what am i talking to|your name)\b/i.test(normalized)
}

/** Hidden steer for identity questions — not shown in the chat task bubble. */
export function augmentUserPromptForPassAiIdentity(prompt: string): string {
	if (!isPassAiIdentityQuestion(prompt)) {
		return prompt
	}
	const trimmed = prompt.trim()
	return `${trimmed}

<pass_ai_identity>
The user is asking for your identity. Reply in first person as PASS AI only.
You MUST say you are PASS AI (coding agent in PASS AI IDE). Do NOT say Nemotron, NVIDIA, Cline, or name the underlying model.
Example opening: "I'm PASS AI, your coding agent in PASS AI IDE."
</pass_ai_identity>`
}
