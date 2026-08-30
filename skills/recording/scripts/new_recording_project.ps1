[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidatePattern('^[a-z0-9][a-z0-9._-]{2,63}$')]
    [string]$ProjectId,

    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$Title,

    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$Destination,

    [Parameter(Mandatory = $false)]
    [ValidateNotNullOrEmpty()]
    [string]$Timezone = 'Asia/Shanghai',

    [Parameter(Mandatory = $false)]
    [ValidateSet('DeepEvolutions', 'Blank')]
    [string]$BrandProfile = 'Blank'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$skillRoot = Split-Path -Parent $PSScriptRoot
$templateRoot = Join-Path $skillRoot 'assets/templates'
$skillRootFull = [System.IO.Path]::GetFullPath($skillRoot)

if (-not [System.IO.Path]::IsPathRooted($Destination)) {
    throw 'Destination must be an absolute path.'
}

$targetRoot = [System.IO.Path]::GetFullPath($Destination)
$createdAt = [DateTimeOffset]::Now.ToString('o')
$utf8NoBom = [System.Text.UTF8Encoding]::new($false)

$skillPrefix = $skillRootFull.TrimEnd([System.IO.Path]::DirectorySeparatorChar, [System.IO.Path]::AltDirectorySeparatorChar) + [System.IO.Path]::DirectorySeparatorChar
if ($targetRoot -eq $skillRootFull -or $targetRoot.StartsWith($skillPrefix, [System.StringComparison]::OrdinalIgnoreCase)) {
    throw 'Destination must not be inside the recording skill directory.'
}

if (Test-Path -LiteralPath $targetRoot) {
    throw "Destination already exists; refusing to overwrite: $targetRoot"
}

function Read-JsonTemplate {
    param([Parameter(Mandatory = $true)][string]$Name)
    $path = Join-Path $templateRoot $Name
    return Get-Content -LiteralPath $path -Raw -Encoding UTF8 | ConvertFrom-Json
}

function Write-JsonDocument {
    param(
        [Parameter(Mandatory = $true)][object]$Value,
        [Parameter(Mandatory = $true)][string]$Path
    )
    $json = $Value | ConvertTo-Json -Depth 100
    [System.IO.File]::WriteAllText($Path, $json + [Environment]::NewLine, $utf8NoBom)
}

function Copy-Template {
    param(
        [Parameter(Mandatory = $true)][string]$Source,
        [Parameter(Mandatory = $true)][string]$DestinationPath
    )
    Copy-Item -LiteralPath (Join-Path $skillRoot $Source) -Destination $DestinationPath
}

$directories = @(
    $targetRoot,
    (Join-Path $targetRoot 'inputs/audio'),
    (Join-Path $targetRoot 'work'),
    (Join-Path $targetRoot 'evidence'),
    (Join-Path $targetRoot 'decisions'),
    (Join-Path $targetRoot 'library'),
    (Join-Path $targetRoot 'plans'),
    (Join-Path $targetRoot 'branches/podcast'),
    (Join-Path $targetRoot 'branches/article'),
    (Join-Path $targetRoot 'branches/video'),
    (Join-Path $targetRoot 'branches/social'),
    (Join-Path $targetRoot 'branches/knowledge'),
    (Join-Path $targetRoot 'branches/commercial'),
    (Join-Path $targetRoot 'qa'),
    (Join-Path $targetRoot 'audit'),
    (Join-Path $targetRoot 'state'),
    (Join-Path $targetRoot 'releases/public')
)

foreach ($directory in $directories) {
    [void](New-Item -ItemType Directory -Path $directory)
}

$project = Read-JsonTemplate 'project-contract.json'
$project.project_id = $ProjectId
$project.title = $Title
$project.created_at = $createdAt
$project.timezone = $Timezone
Write-JsonDocument $project (Join-Path $targetRoot 'project-contract.json')

$sourceManifest = Read-JsonTemplate 'source-manifest.json'
$sourceManifest.project_id = $ProjectId
Write-JsonDocument $sourceManifest (Join-Path $targetRoot 'evidence/source-manifest.json')

$formalScope = Read-JsonTemplate 'formal-scope.json'
$formalScope.project_id = $ProjectId
Write-JsonDocument $formalScope (Join-Path $targetRoot 'decisions/formal-scope.json')

$speakers = Read-JsonTemplate 'speaker-registry.json'
$speakers.project_id = $ProjectId
if ($BrandProfile -eq 'DeepEvolutions') {
    $owner = [pscustomobject]@{
        stable_speaker_id = 'SPK-OWNER'
        machine_cluster_ids = @()
        display_name = 'Toni'
        display_name_status = 'CONFIRMED'
        public_identity_status = 'PENDING'
        editorial_policy = 'ALLOWED'
        original_audio_use_status = 'PENDING'
        voice_enrollment_status = 'PENDING'
        voice_trial_status = 'PENDING'
        synthetic_voice_status = 'PENDING'
        digital_likeness_status = 'PENDING'
    }
    $speakers.speakers = @($owner)
}
Write-JsonDocument $speakers (Join-Path $targetRoot 'decisions/speaker-registry.json')

$rights = Read-JsonTemplate 'rights-ledger.json'
$rights.project_id = $ProjectId
Write-JsonDocument $rights (Join-Path $targetRoot 'decisions/rights-ledger.json')

$brand = Read-JsonTemplate 'brand-profile.json'
$brand.project_id = $ProjectId
if ($BrandProfile -eq 'Blank') {
    $brand.profile_id = 'BLANK'
    $brand.applies_to = 'No brand profile selected'
    $brand.host_display_name = $null
    $brand.program_name = $null
    $brand.fixed_intro = $null
}
Write-JsonDocument $brand (Join-Path $targetRoot 'decisions/brand-profile.json')

$assetPlan = Read-JsonTemplate 'asset-plan.json'
$assetPlan.project_id = $ProjectId
$assetPlan.updated_at = $createdAt
Write-JsonDocument $assetPlan (Join-Path $targetRoot 'plans/ASSET_PLAN.json')

$state = Read-JsonTemplate 'project-state.json'
$state.project_id = $ProjectId
$state.updated_at = $createdAt
Write-JsonDocument $state (Join-Path $targetRoot 'state/project-state.json')

$release = Read-JsonTemplate 'RELEASE_CANDIDATE.template.json'
$release.project_id = $ProjectId
Write-JsonDocument $release (Join-Path $targetRoot 'releases/RELEASE_CANDIDATE.template.json')

$podcastEditPlan = Read-JsonTemplate 'PODCAST_EDIT_PLAN.json'
$podcastEditPlan.project_id = $ProjectId
Write-JsonDocument $podcastEditPlan (Join-Path $targetRoot 'branches/podcast/PODCAST_EDIT_PLAN.json')

Copy-Template 'assets/EXECUTION_CHECKLIST.md' (Join-Path $targetRoot 'EXECUTION_CHECKLIST.md')
Copy-Template 'assets/ASSET_PLAN.md' (Join-Path $targetRoot 'plans/ASSET_PLAN.md')
Copy-Template 'assets/templates/PROJECT_BRIEF.md' (Join-Path $targetRoot 'PROJECT_BRIEF.md')
Copy-Template 'assets/templates/CONTENT_LIBRARY.md' (Join-Path $targetRoot 'library/CONTENT_LIBRARY.md')
Copy-Template 'assets/templates/BRANCH_QA.md' (Join-Path $targetRoot 'qa/BRANCH_QA.md')
Copy-Template 'assets/templates/evidence-turn.schema.json' (Join-Path $targetRoot 'evidence/evidence-turn.schema.json')
Copy-Template 'assets/templates/authorization-grant.schema.json' (Join-Path $targetRoot 'decisions/authorization-grant.schema.json')
Copy-Template 'assets/templates/PODCAST_EDIT_PLAN.md' (Join-Path $targetRoot 'branches/podcast/PODCAST_EDIT_PLAN.md')

[System.IO.File]::WriteAllText((Join-Path $targetRoot 'evidence/turns.jsonl'), '', $utf8NoBom)

$event = [ordered]@{
    event_id = 'EVT-000001'
    at = $createdAt
    from = $null
    to = 'S00_INIT'
    decision = 'CREATED'
    confirmation_text = 'Project scaffold created.'
    scope = @{ project_id = $ProjectId }
    bound_sha256 = @{}
}
$eventLine = $event | ConvertTo-Json -Depth 20 -Compress
[System.IO.File]::WriteAllText((Join-Path $targetRoot 'audit/events.jsonl'), $eventLine + [Environment]::NewLine, $utf8NoBom)

$qaScript = Join-Path $PSScriptRoot 'qa_recording_project.ps1'
& $qaScript -ProjectRoot $targetRoot
if ($LASTEXITCODE -ne 0) {
    throw 'The project was created, but initial QA failed.'
}

Write-Host "Created recording project: $targetRoot"
Write-Host "Brand profile: $BrandProfile"
Write-Host 'Next: copy source audio without modifying it, populate evidence/source-manifest.json, then freeze sources.'
