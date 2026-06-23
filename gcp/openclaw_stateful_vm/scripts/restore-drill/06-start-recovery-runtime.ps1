[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$RecoveryVmName,

    [Parameter(Mandatory = $true)]
    [string]$GatewaySecretId,

    [Parameter(Mandatory = $true)]
    [string]$ModelSecretId,

    [string]$ProjectId = 'ai-agent-host-497515',
    [string]$Zone = 'us-central1-a',
    [switch]$Execute,
    [string]$ApprovalPhrase
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
. "$PSScriptRoot\RestoreDrill.Common.ps1"

$expectedApproval = 'APPROVE: start recovery OpenClaw runtime for isolated restore drill'
Write-StageHeader -Title 'Restore Drill Stage 06 - Start Recovery Runtime'

Assert-NoGitHubSecretReference -SecretIds @($GatewaySecretId, $ModelSecretId)

$preflight = Invoke-RemoteBash -VmName $RecoveryVmName -ProjectId $ProjectId -Zone $Zone -ScriptText @'
set -euo pipefail
findmnt /var/lib/openclaw
sudo systemctl is-active openclaw.service 2>/dev/null || true
sudo systemctl is-enabled openclaw.service 2>/dev/null || true
sudo docker ps --format '{{.Names}}'
sudo ls -l /etc/openclaw/openclaw.env /etc/openclaw/secret-map.json /etc/openclaw/openclaw-host.env /usr/local/sbin/openclaw-prepare-runtime /etc/systemd/system/openclaw.service
sudo grep -n 'OPENCLAW_GITHUB_MODE' /etc/openclaw/openclaw.env
'@ -CaptureOutput
$preflight | ForEach-Object { Write-Host $_ }

if (-not $Execute) {
    Write-Host "Dry-run only. Re-run with -Execute and the exact approval phrase to correct the local secret map and start the recovery runtime."
    return
}

Assert-ExecuteApproved -Execute $Execute.IsPresent -ApprovalPhrase $ApprovalPhrase -ExpectedApprovalPhrase $expectedApproval

$startOutput = Invoke-RemoteBash -VmName $RecoveryVmName -ProjectId $ProjectId -Zone $Zone -ScriptText @"
set -euo pipefail
cat > /tmp/secret-map.json <<EOF
{
  "OPENCLAW_GATEWAY_TOKEN": "$GatewaySecretId",
  "GEMINI_API_KEY": "$ModelSecretId"
}
EOF
sudo mv /tmp/secret-map.json /etc/openclaw/secret-map.json
sudo chmod 0640 /etc/openclaw/secret-map.json
sudo systemctl reset-failed openclaw.service || true
sudo systemctl start openclaw.service
sudo systemctl is-active openclaw.service
sudo docker ps --format '{{.Names}} {{.Status}} {{.Image}}'
curl -fsS http://127.0.0.1:8080/health
echo
curl -fsS http://127.0.0.1:8080/readyz
"@ -CaptureOutput

$startOutput | ForEach-Object { Write-Host $_ }
