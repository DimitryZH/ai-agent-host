[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$SnapshotName,

    [Parameter(Mandatory = $true)]
    [string]$RestoredDiskName,

    [string]$DiskType = 'pd-balanced',
    [string]$ProjectId = 'ai-agent-host-497515',
    [string]$Zone = 'us-central1-a',
    [switch]$Execute,
    [string]$ApprovalPhrase
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
. "$PSScriptRoot\RestoreDrill.Common.ps1"

$expectedApproval = 'APPROVE: create restored disk from selected snapshot for isolated restore drill'
Write-StageHeader -Title 'Restore Drill Stage 02 - Create Restored Disk'

$snapshot = Test-SnapshotReady -SnapshotName $SnapshotName -ProjectId $ProjectId
$existingDisk = Test-DiskExists -DiskName $RestoredDiskName -ProjectId $ProjectId -Zone $Zone

if ($existingDisk) {
    Write-Host "Restored disk already exists:"
    $existingDisk | Select-Object name, status, sizeGb, type, users | Format-List
    return
}

Write-Host "Preflight result: restored disk does not exist and can be created from $SnapshotName"

if (-not $Execute) {
    Write-Host "Dry-run only. Re-run with -Execute and the exact approval phrase to create the restored disk."
    return
}

Assert-ExecuteApproved -Execute $Execute.IsPresent -ApprovalPhrase $ApprovalPhrase -ExpectedApprovalPhrase $expectedApproval

Invoke-ExternalCommand -FilePath 'gcloud' -ArgumentList @(
    'compute', 'disks', 'create', $RestoredDiskName,
    "--project=$ProjectId",
    "--zone=$Zone",
    "--source-snapshot=$SnapshotName",
    "--type=$DiskType"
)

$createdDisk = Test-DiskExists -DiskName $RestoredDiskName -ProjectId $ProjectId -Zone $Zone
$createdDisk | Select-Object name, status, sizeGb, type, users, sourceSnapshot | Format-List
