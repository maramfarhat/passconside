import { promises as fs } from "node:fs"
import * as os from "node:os"
import * as path from "node:path"
import { StateManager } from "@/core/storage/StateManager"
import { getProviderSettingsManager } from "@/sdk/provider-migration"
import { Logger } from "@/shared/services/Logger"

const PASS_AI_OPENAI_PROVIDER = "openai" as const
const DEFAULT_SERVER_MODEL = "Qwen/Qwen3-Coder-30B-A3B-Instruct"

type EndpointsFile = {
	inferenceOpenAiBaseUrl?: string
	appBaseUrl?: string
}

async function readJsonIfExists(filePath: string): Promise<EndpointsFile | null> {
	try {
		const raw = await fs.readFile(filePath, "utf8")
		return JSON.parse(raw) as EndpointsFile
	} catch {
		return null
	}
}

async function readInferenceApiKey(): Promise<string | undefined> {
	const keyPath = path.join(os.homedir(), ".pass-ai", "inference-api-key")
	try {
		const key = (await fs.readFile(keyPath, "utf8")).trim()
		return key || undefined
	} catch {
		return undefined
	}
}

async function resolveInferenceBaseUrl(extensionFsPath: string): Promise<string | null> {
	const bundled = await readJsonIfExists(path.join(extensionFsPath, "endpoints.json"))
	if (bundled?.inferenceOpenAiBaseUrl) {
		return bundled.inferenceOpenAiBaseUrl.trim()
	}
	const user = await readJsonIfExists(path.join(os.homedir(), ".pass-ai", "endpoints.json"))
	if (user?.inferenceOpenAiBaseUrl) {
		return user.inferenceOpenAiBaseUrl.trim()
	}
	if (bundled?.appBaseUrl) {
		return `${bundled.appBaseUrl.replace(/\/+$/, "")}/v1`
	}
	return null
}

/** PASS AI standalone: OpenAI Compatible → local Spring Boot / GPU; hide cloud providers. */
export async function ensurePassAiServerProvider(extensionFsPath: string): Promise<void> {
	const baseUrl = await resolveInferenceBaseUrl(extensionFsPath)
	if (!baseUrl) {
		return
	}

	const inferenceApiKey = await readInferenceApiKey()
	const state = StateManager.get()
	const api = state.getApiConfiguration()

	state.replaceRemoteConfig({
		...state.getRemoteConfigSettings(),
		remoteConfiguredProviders: [PASS_AI_OPENAI_PROVIDER],
		openAiBaseUrl: baseUrl,
	})

	state.setApiConfiguration({
		...api,
		planModeApiProvider: PASS_AI_OPENAI_PROVIDER,
		actModeApiProvider: PASS_AI_OPENAI_PROVIDER,
		planModeOpenAiModelId: api.planModeOpenAiModelId || DEFAULT_SERVER_MODEL,
		actModeOpenAiModelId: api.actModeOpenAiModelId || DEFAULT_SERVER_MODEL,
		openRouterApiKey: "",
		...(inferenceApiKey ? { openAiApiKey: inferenceApiKey } : {}),
	})

	try {
		getProviderSettingsManager().saveProviderSettings(
			{
				provider: "openai-compatible",
				baseUrl,
				...(inferenceApiKey ? { apiKey: inferenceApiKey } : {}),
			},
			{ setLastUsed: true },
		)
	} catch (error) {
		Logger.warn("[PASS AI] Failed to seed OpenAI Compatible provider settings:", error)
	}

	Logger.log(`[PASS AI] API provider locked to PASS AI Server at ${baseUrl}`)
}
