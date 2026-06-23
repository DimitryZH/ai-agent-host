[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$RecoveryVmName,

    [string]$ProjectId = 'ai-agent-host-497515',
    [string]$Zone = 'us-central1-a',
    [switch]$RunMinimalCompletion
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
. "$PSScriptRoot\RestoreDrill.Common.ps1"

Write-StageHeader -Title 'Restore Drill Stage 07 - Validate Local API'

$validationOutput = Invoke-RemoteBash -VmName $RecoveryVmName -ProjectId $ProjectId -Zone $Zone -ScriptText @'
set -euo pipefail
sudo systemctl is-active openclaw.service
sudo docker ps --format '{{.Names}} {{.Status}}'
curl -fsS http://127.0.0.1:8080/health
echo
curl -fsS http://127.0.0.1:8080/readyz
echo
python3 - <<'PY'
from pathlib import Path
import json
import subprocess

token = Path('/run/openclaw/secrets/OPENCLAW_GATEWAY_TOKEN').read_text().strip()
command = [
    'curl',
    '-fsS',
    '-H',
    f'Authorization: Bearer {token}',
    'http://127.0.0.1:8080/v1/models',
]
result = subprocess.run(command, capture_output=True, text=True, check=True)
payload = json.loads(result.stdout)
models = []
for item in payload.get('data', [])[:10]:
    if isinstance(item, dict):
        models.append(item.get('id') or item.get('name') or '<unknown>')
print(json.dumps({'count': len(payload.get('data', [])), 'models': models}))
PY
'@ -CaptureOutput

$validationOutput | ForEach-Object { Write-Host $_ }

if ($RunMinimalCompletion) {
    Write-Warning 'Minimal completion validation is intentionally opt-in and should be approved separately in operator workflow.'
}
