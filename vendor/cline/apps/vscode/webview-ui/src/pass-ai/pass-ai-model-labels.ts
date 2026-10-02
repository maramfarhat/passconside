/** Human labels for models served via PASS AI backend (OpenAI Compatible @ :8080/v1). */
export const PASS_AI_MODEL_LABELS: Record<string, string> = {
	"Qwen/Qwen3-Coder-Next-FP8": "PASS AI Agent — Coder Next FP8",
	"Qwen/Qwen3-Coder-30B-A3B-Instruct": "PASS AI Agent — Coder 30B MoE",
	"Qwen/Qwen3-VL-30B-A3B-Instruct-FP8": "PASS AI Vision — VL 30B FP8",
	"Qwen/Qwen2.5-Coder-32B-Instruct": "Fast Coder 32B",
	"zai-org/GLM-4.7-Flash": "GLM-4.7 Flash (blocked)",
}

export function passAiModelLabel(modelId: string, baseUrl?: string): string {
	if (!baseUrl?.includes(":18080") && !baseUrl?.includes(":8080")) {
		return modelId
	}
	return PASS_AI_MODEL_LABELS[modelId] ?? modelId
}

export function isPassAiInferenceBaseUrl(baseUrl?: string): boolean {
	return Boolean(
		baseUrl?.includes("127.0.0.1:18080") ||
			baseUrl?.includes("localhost:18080") ||
			baseUrl?.includes("127.0.0.1:8080") ||
			baseUrl?.includes("localhost:8080"),
	)
}

/** Shown under the model picker when PASS AI backend is selected. */
export const PASS_AI_MODEL_HINTS: Record<string, string> = {
	"Qwen/Qwen3-Coder-Next-FP8":
		"Max quality but slow (~84GB VRAM). Use for hard tasks; prefer Coder 30B MoE daily.",
	"Qwen/Qwen3-Coder-30B-A3B-Instruct":
		"Recommended main Cline agent: native tools, faster than Coder Next FP8.",
	"Qwen/Qwen3-VL-30B-A3B-Instruct-FP8":
		"Optional vision (screenshots). Experimental; download on pod with PASS_AI_DOWNLOAD_VL=1.",
	"zai-org/GLM-4.7-Flash":
		"Not supported on this Blackwell pod yet (SGLang). Do not use.",
	"Qwen/Qwen2.5-Coder-32B-Instruct":
		"Dense 32B agent (good balance). Tool JSON is normalized by the PASS API for Cline.",
}

export function passAiModelHint(modelId: string, baseUrl?: string): string | undefined {
	if (!isPassAiInferenceBaseUrl(baseUrl)) {
		return undefined
	}
	return PASS_AI_MODEL_HINTS[modelId]
}
