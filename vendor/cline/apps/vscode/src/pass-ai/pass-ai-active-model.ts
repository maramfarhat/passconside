import axios from "axios"
import { getAxiosSettings } from "@/shared/net"
import { Logger } from "@/shared/services/Logger"

const PASS_AI_API_ROOT = "http://127.0.0.1:18080"

/** When user picks a server model, switch the GPU pod before the next chat turn. */
export async function requestPassAiActiveModel(modelId: string, apiKey?: string): Promise<void> {
	if (!modelId) {
		return
	}
	try {
		await axios.post(
			`${PASS_AI_API_ROOT}/api/v1/inference/active-model`,
			{ modelId },
			{
				headers: apiKey ? { Authorization: `Bearer ${apiKey}` } : {},
				...getAxiosSettings(),
				timeout: 600_000,
			},
		)
	} catch (error) {
		Logger.warn("[PASS AI] active-model switch failed (chat will retry switch):", error)
	}
}

export function shouldUsePassAiModelSwitch(baseUrl?: string): boolean {
	return Boolean(
		baseUrl?.includes("127.0.0.1:18080/v1") ||
			baseUrl?.includes("localhost:18080/v1") ||
			baseUrl?.includes("127.0.0.1:8080/v1") ||
			baseUrl?.includes("localhost:8080/v1"),
	)
}
