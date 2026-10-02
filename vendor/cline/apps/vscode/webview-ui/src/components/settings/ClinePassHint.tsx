/** PASS AI: no ClinePass promos in standalone product. */
import type { ApiProvider } from "@shared/api"

interface ClinePassHintProps {
	selectedProvider: ApiProvider
	currentMode: string
}

export const ClinePassHint = (_props: ClinePassHintProps) => null