import { describe, expect, it } from "vitest"
import { augmentUserPromptForPassAiIdentity, isPassAiIdentityQuestion } from "./pass-system-prompt"

describe("isPassAiIdentityQuestion", () => {
	it("matches who are you", () => {
		expect(isPassAiIdentityQuestion("who are you")).toBe(true)
		expect(isPassAiIdentityQuestion("hi who are you")).toBe(true)
	})
})

describe("augmentUserPromptForPassAiIdentity", () => {
	it("steers identity answers for who are you", () => {
		const out = augmentUserPromptForPassAiIdentity("who are you")
		expect(out).toContain("<pass_ai_identity>")
		expect(out).toContain("PASS AI")
		expect(out).toContain("Nemotron")
	})
})
