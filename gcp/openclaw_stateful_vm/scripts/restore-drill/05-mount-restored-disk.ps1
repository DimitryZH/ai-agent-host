[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$RecoveryVmName,

    [string]$ExpectedLabel = 'openclaw-state',
    [string]$ProjectId = 'ai-agent-host-497515',
    [string]$Zone = 'us-central1-a',
    [switch]$Execute,
    [string]$ApprovalPhrase
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
. "$PSScriptRoot\RestoreDrill.Common.ps1"

$expectedApproval = 'APPROVE: mount restored disk at var lib openclaw for isolated restore drill'
Write-StageHeader -Title 'Restore Drill Stage 05 - Mount Restored Disk'

$preflight = Invoke-RemoteBash -VmName $RecoveryVmName -ProjectId $ProjectId -Zone $Zone -ScriptText @"
set -euo pipefail
sudo systemctl is-active openclaw.service 2>/dev/null || true
sudo docker ps --format '{{.Names}}'
lsblk -f
mount | grep openclaw || true
"@ -CaptureOutput
$preflight | ForEach-Object { Write-Host $_ }

if (-not $Execute) {
    Write-Host "Dry-run only. Re-run with -Execute and the exact approval phrase to mount the restored disk."
    return
}

Assert-ExecuteApproved -Execute $Execute.IsPresent -ApprovalPhrase $ApprovalPhrase -ExpectedApprovalPhrase $expectedApproval

$mountOutput = Invoke-RemoteBash -VmName $RecoveryVmName -ProjectId $ProjectId -Zone $Zone -ScriptText @"
set -euo pipefail
DISK_DEVICE=`$(lsblk -nr -o NAME,LABEL | awk '`$2 == ""$ExpectedLabel"" { print ""/dev/""`$1 }' | head -n 1)
if [ -z "`$DISK_DEVICE" ]; then
  echo "Unable to identify restored disk by label $ExpectedLabel" >&2
  exit 1
fi
sudo mkdir -p $($script:RestoreDrillDefaults.StateMountPath)
if mount | grep -q ' $($script:RestoreDrillDefaults.StateMountPath) '; then
  echo "$($script:RestoreDrillDefaults.StateMountPath) already mounted"
else
  sudo mount "`$DISK_DEVICE" $($script:RestoreDrillDefaults.StateMountPath)
fi
findmnt $($script:RestoreDrillDefaults.StateMountPath)
sudo ls -ld $($script:RestoreDrillDefaults.StateMountPath) $($script:RestoreDrillDefaults.StateMountPath)/state $($script:RestoreDrillDefaults.StateMountPath)/workspace
sudo find $($script:RestoreDrillDefaults.StateMountPath) -mindepth 1 -maxdepth 1 -printf '%y %M %u %g %f\n' | sort
sudo find $($script:RestoreDrillDefaults.StateMountPath)/state/devices -maxdepth 2 \( -type d -o -type f \) | sort | head -n 20
sudo find $($script:RestoreDrillDefaults.StateMountPath)/state/agents/main/sessions -maxdepth 1 \( -type d -o -type f \) | sort | head -n 40
"@ -CaptureOutput

$mountOutput | ForEach-Object { Write-Host $_ }
