[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$RecoveryServiceAccountEmail,

    [Parameter(Mandatory = $true)]
    [string]$GatewaySecretId,

    [Parameter(Mandatory = $true)]
    [string]$ModelSecretId,

    [string]$ProjectId = 'ai-agent-host-497515',
    [string]$ArtifactRegistryRepository = 'ai-agent-runtime',
    [string]$ArtifactRegistryLocation = 'us-central1',
    [switch]$Execute,
    [string]$ApprovalPhrase
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
. "$PSScriptRoot\RestoreDrill.Common.ps1"

$expectedApproval = 'APPROVE: grant temporary recovery IAM for isolated restore drill'
Write-StageHeader -Title 'Restore Drill Stage 04 - Grant Temporary IAM'

Assert-NoGitHubSecretReference -SecretIds @($GatewaySecretId, $ModelSecretId)

$repo = Test-ArtifactRepositoryExists -ProjectId $ProjectId -Location $ArtifactRegistryLocation -Repository $ArtifactRegistryRepository
$gatewaySecret = Test-SecretMetadata -ProjectId $ProjectId -SecretId $GatewaySecretId
$modelSecret = Test-SecretMetadata -ProjectId $ProjectId -SecretId $ModelSecretId

[pscustomobject]@{
    RecoveryServiceAccount = $RecoveryServiceAccountEmail
    ArtifactRepository     = $repo.name
    GatewaySecretId        = $gatewaySecret.name
    ModelSecretId          = $modelSecret.name
} | Format-List

if (-not $Execute) {
    Write-Host "Dry-run only. Re-run with -Execute and the exact approval phrase to grant temporary IAM."
    return
}

Assert-ExecuteApproved -Execute $Execute.IsPresent -ApprovalPhrase $ApprovalPhrase -ExpectedApprovalPhrase $expectedApproval

Invoke-ExternalCommand -FilePath 'gcloud' -ArgumentList @(
    'artifacts', 'repositories', 'add-iam-policy-binding', $ArtifactRegistryRepository,
    "--project=$ProjectId",
    "--location=$ArtifactRegistryLocation",
    "--member=serviceAccount:$RecoveryServiceAccountEmail",
    '--role=roles/artifactregistry.reader'
)

foreach ($secretId in @($GatewaySecretId, $ModelSecretId)) {
    Invoke-ExternalCommand -FilePath 'gcloud' -ArgumentList @(
        'secrets', 'add-iam-policy-binding', $secretId,
        "--project=$ProjectId",
        "--member=serviceAccount:$RecoveryServiceAccountEmail",
        '--role=roles/secretmanager.secretAccessor'
    )
}

Write-Host 'Temporary IAM grants applied.'
