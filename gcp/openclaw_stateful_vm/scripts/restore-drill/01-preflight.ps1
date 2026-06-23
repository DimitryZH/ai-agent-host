[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$SnapshotName,

    [string]$RestoredDiskName = (New-RecoveryResourceNames -DateStamp (Get-RestoreDrillDateStamp)).RestoredDiskName,
    [string]$ProjectId = 'ai-agent-host-497515',
    [string]$Zone = 'us-central1-a'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
. "$PSScriptRoot\RestoreDrill.Common.ps1"

Write-StageHeader -Title 'Restore Drill Stage 01 - Preflight'
Assert-CommandAvailable -Name 'gcloud'

$snapshot = Test-SnapshotReady -SnapshotName $SnapshotName -ProjectId $ProjectId
$sourceDiskOk = ($snapshot.sourceDisk -match "/disks/$($script:RestoreDrillDefaults.ProductionDiskName)$")

if (-not $sourceDiskOk) {
    throw "Snapshot source disk is not $($script:RestoreDrillDefaults.ProductionDiskName): $($snapshot.sourceDisk)"
}

$productionDisk = Get-ProductionDiskSummary -ProjectId $ProjectId -Zone $Zone
$writerCount = @($productionDisk.users).Count

if ($writerCount -ne 1) {
    throw "Production disk writer count is not exactly one: $writerCount"
}

$migSummary = Get-ProductionMigSummary -ProjectId $ProjectId
$targetDisk = Test-DiskExists -DiskName $RestoredDiskName -ProjectId $ProjectId -Zone $Zone

[pscustomobject]@{
    SnapshotName        = $SnapshotName
    SnapshotStatus      = $snapshot.status
    SnapshotSourceDisk  = $snapshot.sourceDisk
    ProductionDisk      = $productionDisk.name
    ProductionWriters   = @($productionDisk.users)
    ProductionMig       = $migSummary
    RestoredDiskName    = $RestoredDiskName
    RestoredDiskPresent = ($null -ne $targetDisk)
} | Format-List

if ($targetDisk) {
    Write-Warning "Target restored disk already exists: $RestoredDiskName"
}
