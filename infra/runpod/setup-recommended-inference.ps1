# Deploy PASS AI RunPod scripts, download recommended agent model, switch GPU to Coder 30B MoE.
param(
    [string]$SshHost = "198.13.252.107",
    [int]$Port = 23008,
    [string]$Key = "$env:USERPROFILE\.ssh\pass_ai_runpod",
    [string]$ModelId = "Qwen/Qwen3-Coder-30B-A3B-Instruct"
)

$ErrorActionPreference = "Stop"
$here = Split-Path -Parent $MyInvocation.MyCommand.Path
& (Join-Path $here "deploy-runpod-scripts.ps1") -SshHost $SshHost -Port $Port -Key $Key

Write-Host "Downloading models on pod (Coder 30B MoE; may take a while on first run)..."
ssh -p $Port -i $Key "root@${SshHost}" "bash /workspace/pass-ai/scripts/download-models.sh"

Write-Host "Switching active model to $ModelId (SGLang restart ~2-5 min)..."
ssh -p $Port -i $Key "root@${SshHost}" "bash /workspace/pass-ai/scripts/switch-model.sh '$ModelId'"

Write-Host "Done. Restart Spring Boot API locally and pick '$ModelId' in PASS AI settings (or rebuild agent for new default)."
