import { describe, expect, it } from "vitest"
import { promptWarrantsAutoWorkspace, slugFromTaskPrompt } from "./pass-workspace"

describe("promptWarrantsAutoWorkspace", () => {
	it("does not create a folder for greetings", () => {
		expect(promptWarrantsAutoWorkspace("hi")).toBe(false)
		expect(promptWarrantsAutoWorkspace("Hello!")).toBe(false)
		expect(promptWarrantsAutoWorkspace("hey how are you")).toBe(false)
	})

	it("creates a folder when the message is a real task", () => {
		expect(promptWarrantsAutoWorkspace("Build a small Django site named atelier")).toBe(true)
		expect(promptWarrantsAutoWorkspace("Create shop/index.html in this workspace")).toBe(true)
		expect(promptWarrantsAutoWorkspace("fix the login bug in auth.ts")).toBe(true)
	})
})

describe("slugFromTaskPrompt", () => {
	it("uses the first path segment instead of the full prompt", () => {
		const prompt =
			"Create shop/index.html in this workspace using the editor tool. Do not paste the full HTML in chat only."
		expect(slugFromTaskPrompt(prompt)).toBe("shop")
	})

	it("uses quoted project names", () => {
		expect(slugFromTaskPrompt('Build a "todo app" with React')).toBe("todo-app")
	})

	it("caps slug length at 24 characters", () => {
		expect(slugFromTaskPrompt("implement jwt auth middleware")).toBe("implement-jwt-auth-middl")
		expect(slugFromTaskPrompt("implement jwt auth middleware").length).toBeLessThanOrEqual(24)
	})
})
