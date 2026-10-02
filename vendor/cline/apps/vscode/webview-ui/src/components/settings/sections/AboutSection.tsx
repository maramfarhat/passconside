import Section from "../Section"

interface AboutSectionProps {
	version: string
	extensionVariant?: "legacy" | "next"
	renderSectionHeader: (tabId: string) => JSX.Element | null
}

const AboutSection = ({ version, renderSectionHeader }: AboutSectionProps) => {
	return (
		<div>
			{renderSectionHeader("about")}
			<Section>
				<div className="flex px-4 flex-col gap-2">
					<h2 className="text-lg font-semibold">PASS AI Agent v{version}</h2>
					<p>
						Autonomous coding assistant for PASS AI IDE. It can use your CLI and editor to create and edit files,
						explore projects, and run terminal commands after you grant permission.
					</p>
					<p className="text-xs text-(--vscode-descriptionForeground)">
						Support and documentation are provided by PASS Consulting Group (no external Cline links in this build).
					</p>
				</div>
			</Section>
		</div>
	)
}

export default AboutSection