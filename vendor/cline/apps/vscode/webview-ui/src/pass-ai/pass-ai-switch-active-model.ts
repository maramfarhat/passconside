import axios from "axios"

const PASS_AI_API = "http://127.0.0.1:18080"

export async function switchPassAiActiveModel(modelId: string, apiKey?: string): Promise<void> {
	if (!modelId.trim()) {
		return
	}
	await axios.post(
		`${PASS_AI_API}/api/v1/inference/active-model`,
		{ modelId },
		{
			timeout: 600_000,
			headers: apiKey?.trim() ? { Authorization: `Bearer ${apiKey.trim()}` } : {},
		},
	)
}
