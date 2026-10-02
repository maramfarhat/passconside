import passLogo from "@/assets/pass-logo-circle.png"

type PassBrandMarkProps = {
	variant?: "hero" | "header"
	showWordmark?: boolean
}

export function PassBrandMark({ variant = "header", showWordmark = true }: PassBrandMarkProps) {
	const imgClass = variant === "hero" ? "h-24 w-24" : "h-8 w-8"

	return (
		<div className="flex items-center gap-2.5 pass-ai-brand-mark shrink-0">
			<img alt="PASS Consulting Group" className={`${imgClass} rounded-full object-cover`} src={passLogo} />
			{showWordmark && (
				<span className="font-semibold text-base tracking-tight whitespace-nowrap">
					<span className="text-white">PASS </span>
					<span className="pass-ai-gradient-text">AI</span>
				</span>
			)}
		</div>
	)
}
