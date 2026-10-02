# Sync PASS AI ops scripts to the RunPod pod (SSH key required).
param(
    [string]$SshHost = "198.13.252.107",
    [int]$Port = 23008,
    [string]$Key = "$env:USERPROFILE\.ssh\pass_ai_runpod",
    [string]$RemoteHome = "/workspace/pass-ai"
)

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $MyInvocation.MyCommand.Path

$files = @(
    @{ Local = "launch_sglang.py"; Remote = "scripts/launch_sglang.py" },
    @{ Local = "models.catalog.json"; Remote = "config/models.catalog.json" },
    @{ Local = "switch-model.sh"; Remote = "scripts/switch-model.sh" },
    @{ Local = "download-models.sh"; Remote = "scripts/download-models.sh" }
)

foreach ($f in $files) {
    $src = Join-Path $root $f.Local
    if (-not (Test-Path $src)) { throw "Missing $src" }
    scp -P $Port -i $Key $src "root@${SshHost}:$RemoteHome/$($f.Remote)"
    Write-Host "Uploaded $($f.Local)"
}

ssh -p $Port -i $Key "root@${SshHost}" "sed -i 's/\r$//' $RemoteHome/scripts/*.sh $RemoteHome/scripts/launch_sglang.py 2>/dev/null || true"
Write-Host "Done. To apply parser/catalog for active model: ssh and run switch-model.sh <model-id>."
