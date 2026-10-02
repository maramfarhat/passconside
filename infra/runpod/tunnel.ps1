#Requires -Version 5.1
param(
	[string]$SshHost = "198.13.252.107",
	[int]$SshPort = 23008,
	[string]$Key = (Join-Path $env:USERPROFILE ".ssh\pass_ai_runpod"),
	[int]$LocalPort = 30000
)

$AdminPort = 30001
Write-Host "Tunnels localhost:${LocalPort} -> SGLang, localhost:${AdminPort} -> admin API. Ctrl+C to stop." -ForegroundColor Cyan
ssh -N `
	-L "${LocalPort}:127.0.0.1:${LocalPort}" `
	-L "${AdminPort}:127.0.0.1:${AdminPort}" `
	-p $SshPort -i $Key "root@${SshHost}"
