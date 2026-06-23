Set-StrictMode -Version Latest

$script:RestoreDrillDefaults = [ordered]@{
    ProjectId                   = 'ai-agent-host-497515'
    Zone                        = 'us-central1-a'
    Region                      = 'us-central1'
    NetworkName                 = 'openclaw-stateful-vpc'
    SubnetworkName              = 'openclaw-stateful-subnet'
    ProductionDiskName          = 'openclaw-stateful-state'
    ProductionMigName           = 'openclaw-stateful-mig'
    ArtifactRegistryRepository  = 'ai-agent-runtime'
    ArtifactRegistryLocation    = 'us-central1'
    StateMountPath              = '/var/lib/openclaw'
    RecoveryServiceAccountIdFmt = 'oclaw-restore-{0}-sa'
    RecoveryVmNameFmt           = 'openclaw-stateful-restore-{0}-vm'
    RestoredDiskNameFmt         = 'openclaw-stateful-restore-{0}-disk'
    RecoveryFirewallNameFmt     = 'openclaw-stateful-restore-{0}-iap-ssh'
    DefaultMachineType          = 'e2-small'
    DefaultBootDiskSizeGb       = 20
    DefaultBootDiskType         = 'pd-balanced'
    UbuntuImageFamily           = 'ubuntu-2404-lts'
    UbuntuImageProject          = 'ubuntu-os-cloud'
    DeleteDiskApprovalPhrase    = 'APPROVE: delete restored disk for isolated restore drill cleanup'
}

function Write-StageHeader {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Title
    )

    Write-Host ''
    Write-Host ('=' * 80)
    Write-Host $Title
    Write-Host ('=' * 80)
}

function Get-RestoreDrillDateStamp {
    param(
        [datetime]$Date = (Get-Date)
    )

    return $Date.ToString('yyyyMMdd')
}

function New-RecoveryResourceNames {
    param(
        [Parameter(Mandatory = $true)]
        [string]$DateStamp
    )

    $serviceAccountId = [string]::Format($script:RestoreDrillDefaults.RecoveryServiceAccountIdFmt, $DateStamp)

    [pscustomobject]@{
        DateStamp           = $DateStamp
        ServiceAccountId    = $serviceAccountId
        ServiceAccountEmail = '{0}@{1}.iam.gserviceaccount.com' -f $serviceAccountId, $script:RestoreDrillDefaults.ProjectId
        RecoveryVmName      = [string]::Format($script:RestoreDrillDefaults.RecoveryVmNameFmt, $DateStamp)
        RestoredDiskName    = [string]::Format($script:RestoreDrillDefaults.RestoredDiskNameFmt, $DateStamp)
        FirewallRuleName    = [string]::Format($script:RestoreDrillDefaults.RecoveryFirewallNameFmt, $DateStamp)
    }
}

function Assert-CommandAvailable {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Name
    )

    if (-not (Get-Command -Name $Name -ErrorAction SilentlyContinue)) {
        throw "Required command not found in PATH: $Name"
    }
}

function Assert-ExecuteApproved {
    param(
        [Parameter(Mandatory = $true)]
        [bool]$Execute,

        [Parameter(Mandatory = $true)]
        [string]$ApprovalPhrase,

        [Parameter(Mandatory = $true)]
        [string]$ExpectedApprovalPhrase
    )

    if (-not $Execute) {
        throw "This stage is mutating. Re-run with -Execute and the exact approval phrase."
    }

    if ([string]::IsNullOrWhiteSpace($ApprovalPhrase) -or $ApprovalPhrase -cne $ExpectedApprovalPhrase) {
        throw "Approval phrase mismatch. Expected exactly: $ExpectedApprovalPhrase"
    }
}

function Assert-NoGitHubSecretReference {
    param(
        [Parameter(Mandatory = $true)]
        [string[]]$SecretIds
    )

    foreach ($secretId in $SecretIds) {
        if ($secretId -match 'github' -or $secretId -match '^gh[_-]') {
            throw "GitHub secret references are not allowed in the restore drill: $secretId"
        }
    }
}

function Format-ExternalCommand {
    param(
        [Parameter(Mandatory = $true)]
        [string]$FilePath,

        [Parameter(Mandatory = $true)]
        [string[]]$ArgumentList
    )

    return ($FilePath + ' ' + (($ArgumentList | ForEach-Object {
                    if ($_ -match '\s') {
                        '"' + ($_ -replace '"', '\"') + '"'
                    }
                    else {
                        $_
                    }
                }) -join ' '))
}

function Invoke-ExternalCommand {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$FilePath,

        [Parameter(Mandatory = $true)]
        [string[]]$ArgumentList,

        [switch]$CaptureOutput
    )

    $formatted = Format-ExternalCommand -FilePath $FilePath -ArgumentList $ArgumentList
    Write-Host ">> $formatted"

    if ($CaptureOutput) {
        $output = & $FilePath @ArgumentList
        if ($LASTEXITCODE -ne 0) {
            throw "Command failed with exit code ${LASTEXITCODE}: $formatted"
        }

        return $output
    }

    & $FilePath @ArgumentList
    if ($LASTEXITCODE -ne 0) {
        throw "Command failed with exit code ${LASTEXITCODE}: $formatted"
    }
}

function Invoke-GcloudJson {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string[]]$ArgumentList
    )

    $output = Invoke-ExternalCommand -FilePath 'gcloud' -ArgumentList ($ArgumentList + '--format=json') -CaptureOutput

    if ([string]::IsNullOrWhiteSpace(($output -join ''))) {
        return $null
    }

    return ($output -join [Environment]::NewLine) | ConvertFrom-Json -Depth 100
}

function ConvertTo-BashSingleQuoted {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Value
    )

    return ("'{0}'" -f ($Value -replace "'", "'""'""'"))
}

function Invoke-RemoteBash {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$VmName,

        [Parameter(Mandatory = $true)]
        [string]$ScriptText,

        [string]$ProjectId = $script:RestoreDrillDefaults.ProjectId,
        [string]$Zone = $script:RestoreDrillDefaults.Zone,
        [switch]$CaptureOutput
    )

    $quotedScript = ConvertTo-BashSingleQuoted -Value $ScriptText
    $remoteCommand = "bash -lc $quotedScript"
    $args = @(
        'compute', 'ssh', $VmName,
        "--project=$ProjectId",
        "--zone=$Zone",
        '--tunnel-through-iap',
        "--command=$remoteCommand"
    )

    return Invoke-ExternalCommand -FilePath 'gcloud' -ArgumentList $args -CaptureOutput:$CaptureOutput
}

function Test-SnapshotReady {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$SnapshotName,

        [string]$ProjectId = $script:RestoreDrillDefaults.ProjectId
    )

    $snapshot = Invoke-GcloudJson -ArgumentList @(
        'compute', 'snapshots', 'describe', $SnapshotName,
        "--project=$ProjectId"
    )

    if ($snapshot.status -ne 'READY') {
        throw "Snapshot is not READY: $SnapshotName"
    }

    return $snapshot
}

function Test-DiskExists {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$DiskName,

        [string]$ProjectId = $script:RestoreDrillDefaults.ProjectId,
        [string]$Zone = $script:RestoreDrillDefaults.Zone
    )

    try {
        $disk = Invoke-GcloudJson -ArgumentList @(
            'compute', 'disks', 'describe', $DiskName,
            "--project=$ProjectId",
            "--zone=$Zone"
        )
        return $disk
    }
    catch {
        return $null
    }
}

function Test-InstanceExists {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$InstanceName,

        [string]$ProjectId = $script:RestoreDrillDefaults.ProjectId,
        [string]$Zone = $script:RestoreDrillDefaults.Zone
    )

    try {
        $instance = Invoke-GcloudJson -ArgumentList @(
            'compute', 'instances', 'describe', $InstanceName,
            "--project=$ProjectId",
            "--zone=$Zone"
        )
        return $instance
    }
    catch {
        return $null
    }
}

function Test-FirewallRuleExists {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$FirewallRuleName,

        [string]$ProjectId = $script:RestoreDrillDefaults.ProjectId
    )

    try {
        $rule = Invoke-GcloudJson -ArgumentList @(
            'compute', 'firewall-rules', 'describe', $FirewallRuleName,
            "--project=$ProjectId"
        )
        return $rule
    }
    catch {
        return $null
    }
}

function Test-ServiceAccountExists {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$ServiceAccountEmail,

        [string]$ProjectId = $script:RestoreDrillDefaults.ProjectId
    )

    try {
        $account = Invoke-GcloudJson -ArgumentList @(
            'iam', 'service-accounts', 'describe', $ServiceAccountEmail,
            "--project=$ProjectId"
        )
        return $account
    }
    catch {
        return $null
    }
}

function Get-ProductionDiskSummary {
    [CmdletBinding()]
    param(
        [string]$ProjectId = $script:RestoreDrillDefaults.ProjectId,
        [string]$Zone = $script:RestoreDrillDefaults.Zone
    )

    return Invoke-GcloudJson -ArgumentList @(
        'compute', 'disks', 'describe', $script:RestoreDrillDefaults.ProductionDiskName,
        "--project=$ProjectId",
        "--zone=$Zone"
    )
}

function Get-ProductionMigSummary {
    [CmdletBinding()]
    param(
        [string]$ProjectId = $script:RestoreDrillDefaults.ProjectId
    )

    return Invoke-GcloudJson -ArgumentList @(
        'compute', 'instance-groups', 'managed', 'list',
        "--project=$ProjectId"
    )
}

function Test-ArtifactRepositoryExists {
    [CmdletBinding()]
    param(
        [string]$ProjectId = $script:RestoreDrillDefaults.ProjectId,
        [string]$Location = $script:RestoreDrillDefaults.ArtifactRegistryLocation,
        [string]$Repository = $script:RestoreDrillDefaults.ArtifactRegistryRepository
    )

    return Invoke-GcloudJson -ArgumentList @(
        'artifacts', 'repositories', 'describe', $Repository,
        "--project=$ProjectId",
        "--location=$Location"
    )
}

function Test-SecretMetadata {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$SecretId,

        [string]$ProjectId = $script:RestoreDrillDefaults.ProjectId
    )

    return Invoke-GcloudJson -ArgumentList @(
        'secrets', 'describe', $SecretId,
        "--project=$ProjectId"
    )
}
