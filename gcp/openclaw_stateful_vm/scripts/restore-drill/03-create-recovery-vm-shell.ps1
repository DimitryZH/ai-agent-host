[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$RestoredDiskName,

    [string]$DateStamp = (Get-RestoreDrillDateStamp),
    [string]$ProjectId = 'ai-agent-host-497515',
    [string]$Zone = 'us-central1-a',
    [switch]$Execute,
    [string]$ApprovalPhrase
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
. "$PSScriptRoot\RestoreDrill.Common.ps1"

$expectedApproval = 'APPROVE: create temporary recovery VM shell for isolated restore drill'
$names = New-RecoveryResourceNames -DateStamp $DateStamp

Write-StageHeader -Title 'Restore Drill Stage 03 - Create Recovery VM Shell'

$disk = Test-DiskExists -DiskName $RestoredDiskName -ProjectId $ProjectId -Zone $Zone
if (-not $disk) {
    throw "Restored disk not found: $RestoredDiskName"
}

$existingVm = Test-InstanceExists -InstanceName $names.RecoveryVmName -ProjectId $ProjectId -Zone $Zone
$existingFirewall = Test-FirewallRuleExists -FirewallRuleName $names.FirewallRuleName -ProjectId $ProjectId
$existingSa = Test-ServiceAccountExists -ServiceAccountEmail $names.ServiceAccountEmail -ProjectId $ProjectId

[pscustomobject]@{
    RestoredDiskName        = $RestoredDiskName
    RecoveryVmName          = $names.RecoveryVmName
    RecoveryServiceAccount  = $names.ServiceAccountEmail
    RecoveryFirewallRule    = $names.FirewallRuleName
    RestoredDiskAttachedTo  = @($disk.users)
    VmAlreadyExists         = ($null -ne $existingVm)
    ServiceAccountExists    = ($null -ne $existingSa)
    FirewallRuleExists      = ($null -ne $existingFirewall)
} | Format-List

if (-not $Execute) {
    Write-Host "Dry-run only. Re-run with -Execute and the exact approval phrase to create the recovery VM shell."
    return
}

Assert-ExecuteApproved -Execute $Execute.IsPresent -ApprovalPhrase $ApprovalPhrase -ExpectedApprovalPhrase $expectedApproval

if (-not $existingSa) {
    Invoke-ExternalCommand -FilePath 'gcloud' -ArgumentList @(
        'iam', 'service-accounts', 'create', $names.ServiceAccountId,
        "--project=$ProjectId",
        '--display-name=OpenClaw restore drill recovery identity'
    )
}

if (-not $existingFirewall) {
    Invoke-ExternalCommand -FilePath 'gcloud' -ArgumentList @(
        'compute', 'firewall-rules', 'create', $names.FirewallRuleName,
        "--project=$ProjectId",
        "--network=$($script:RestoreDrillDefaults.NetworkName)",
        '--direction=INGRESS',
        '--action=ALLOW',
        '--rules=tcp:22',
        '--source-ranges=35.235.240.0/20',
        "--target-service-accounts=$($names.ServiceAccountEmail)"
    )
}

if (-not $existingVm) {
    Invoke-ExternalCommand -FilePath 'gcloud' -ArgumentList @(
        'compute', 'instances', 'create', $names.RecoveryVmName,
        "--project=$ProjectId",
        "--zone=$Zone",
        "--machine-type=$($script:RestoreDrillDefaults.DefaultMachineType)",
        "--subnet=$($script:RestoreDrillDefaults.SubnetworkName)",
        '--no-address',
        "--service-account=$($names.ServiceAccountEmail)",
        '--scopes=cloud-platform',
        "--image-family=$($script:RestoreDrillDefaults.UbuntuImageFamily)",
        "--image-project=$($script:RestoreDrillDefaults.UbuntuImageProject)",
        "--boot-disk-size=$($script:RestoreDrillDefaults.DefaultBootDiskSizeGb)GB",
        "--boot-disk-type=$($script:RestoreDrillDefaults.DefaultBootDiskType)"
    )
}

Invoke-ExternalCommand -FilePath 'gcloud' -ArgumentList @(
    'compute', 'instances', 'attach-disk', $names.RecoveryVmName,
    "--project=$ProjectId",
    "--zone=$Zone",
    "--disk=$RestoredDiskName",
    '--device-name=openclaw-stateful-restore'
)

$lsblkOutput = Invoke-RemoteBash -VmName $names.RecoveryVmName -ProjectId $ProjectId -Zone $Zone -ScriptText @'
set -euo pipefail
hostname
lsblk -f
'@ -CaptureOutput

$lsblkOutput | ForEach-Object { Write-Host $_ }
