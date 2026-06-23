[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$RecoveryVmName,

    [Parameter(Mandatory = $true)]
    [string]$RecoveryServiceAccountEmail,

    [Parameter(Mandatory = $true)]
    [string]$FirewallRuleName,

    [Parameter(Mandatory = $true)]
    [string]$GatewaySecretId,

    [Parameter(Mandatory = $true)]
    [string]$ModelSecretId,

    [Parameter(Mandatory = $true)]
    [string]$RestoredDiskName,

    [string]$ProjectId = 'ai-agent-host-497515',
    [string]$Zone = 'us-central1-a',
    [switch]$Execute,
    [string]$ApprovalPhrase,
    [switch]$DeleteRestoredDisk,
    [string]$DeleteDiskApprovalPhrase
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
. "$PSScriptRoot\RestoreDrill.Common.ps1"

$expectedApproval = 'APPROVE: cleanup isolated restore drill resources'
Write-StageHeader -Title 'Restore Drill Stage 08 - Cleanup'

Assert-NoGitHubSecretReference -SecretIds @($GatewaySecretId, $ModelSecretId)

$preflight = Invoke-RemoteBash -VmName $RecoveryVmName -ProjectId $ProjectId -Zone $Zone -ScriptText @'
set -euo pipefail
sudo systemctl is-active openclaw.service 2>/dev/null || true
findmnt /var/lib/openclaw || true
sudo docker ps --format '{{.Names}} {{.Status}}'
'@ -CaptureOutput
$preflight | ForEach-Object { Write-Host $_ }

if (-not $Execute) {
    Write-Host 'Dry-run only. Re-run with -Execute and the exact approval phrase to perform cleanup.'
    return
}

Assert-ExecuteApproved -Execute $Execute.IsPresent -ApprovalPhrase $ApprovalPhrase -ExpectedApprovalPhrase $expectedApproval

Invoke-RemoteBash -VmName $RecoveryVmName -ProjectId $ProjectId -Zone $Zone -ScriptText @'
set -euo pipefail
sudo systemctl stop openclaw.service || true
sudo umount /var/lib/openclaw || true
sudo docker ps -a --format '{{.Names}} {{.Status}}'
'@ | Out-Null

Invoke-ExternalCommand -FilePath 'gcloud' -ArgumentList @(
    'artifacts', 'repositories', 'remove-iam-policy-binding', $script:RestoreDrillDefaults.ArtifactRegistryRepository,
    "--project=$ProjectId",
    "--location=$($script:RestoreDrillDefaults.ArtifactRegistryLocation)",
    "--member=serviceAccount:$RecoveryServiceAccountEmail",
    '--role=roles/artifactregistry.reader'
)

foreach ($secretId in @($GatewaySecretId, $ModelSecretId)) {
    Invoke-ExternalCommand -FilePath 'gcloud' -ArgumentList @(
        'secrets', 'remove-iam-policy-binding', $secretId,
        "--project=$ProjectId",
        "--member=serviceAccount:$RecoveryServiceAccountEmail",
        '--role=roles/secretmanager.secretAccessor'
    )
}

Invoke-ExternalCommand -FilePath 'gcloud' -ArgumentList @(
    'compute', 'instances', 'delete', $RecoveryVmName,
    "--project=$ProjectId",
    "--zone=$Zone",
    '--quiet'
)

Invoke-ExternalCommand -FilePath 'gcloud' -ArgumentList @(
    'compute', 'firewall-rules', 'delete', $FirewallRuleName,
    "--project=$ProjectId",
    '--quiet'
)

Invoke-ExternalCommand -FilePath 'gcloud' -ArgumentList @(
    'iam', 'service-accounts', 'delete', $RecoveryServiceAccountEmail,
    "--project=$ProjectId",
    '--quiet'
)

if ($DeleteRestoredDisk) {
    Assert-ExecuteApproved -Execute $true -ApprovalPhrase $DeleteDiskApprovalPhrase -ExpectedApprovalPhrase $script:RestoreDrillDefaults.DeleteDiskApprovalPhrase
    Invoke-ExternalCommand -FilePath 'gcloud' -ArgumentList @(
        'compute', 'disks', 'delete', $RestoredDiskName,
        "--project=$ProjectId",
        "--zone=$Zone",
        '--quiet'
    )
}

Write-Host 'Cleanup complete. The restored disk is preserved unless separate deletion approval was provided.'
