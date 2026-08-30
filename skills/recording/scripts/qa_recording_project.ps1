[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$ProjectRoot
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$root = (Resolve-Path -LiteralPath $ProjectRoot).Path
$failures = [System.Collections.Generic.List[string]]::new()
$passes = [System.Collections.Generic.List[string]]::new()

function Add-Pass { param([string]$Message) $script:passes.Add($Message) }
function Add-Failure { param([string]$Message) $script:failures.Add($Message) }

function Assert-Check {
    param([bool]$Condition, [string]$PassMessage, [string]$FailureMessage)
    if ($Condition) { Add-Pass $PassMessage } else { Add-Failure $FailureMessage }
}

function Read-JsonFile {
    param([string]$Path)
    try {
        return Get-Content -LiteralPath $Path -Raw -Encoding UTF8 | ConvertFrom-Json
    }
    catch {
        throw "JSON parse failed: $Path :: $($_.Exception.Message)"
    }
}

function Test-Sha256 {
    param([AllowNull()][string]$Value)
    return $null -ne $Value -and $Value -match '^[A-Fa-f0-9]{64}$'
}

function Test-SafeRelativePath {
    param([AllowNull()][string]$Value)
    if ([string]::IsNullOrWhiteSpace($Value)) { return $false }
    if ([System.IO.Path]::IsPathRooted($Value)) { return $false }
    if ($Value.Contains(':')) { return $false }
    $segments = @($Value -split '[\\/]')
    if ($segments.Count -eq 0) { return $false }
    foreach ($segment in $segments) {
        if ([string]::IsNullOrWhiteSpace($segment) -or $segment -eq '.' -or $segment -eq '..') { return $false }
    }
    return $true
}

function Get-ContainedProjectPath {
    param([string]$RootPath, [AllowNull()][string]$RelativePath)
    if (-not (Test-SafeRelativePath $RelativePath)) { return $null }

    $normalizedRoot = [System.IO.Path]::GetFullPath($RootPath).TrimEnd([System.IO.Path]::DirectorySeparatorChar, [System.IO.Path]::AltDirectorySeparatorChar)
    $fullPath = [System.IO.Path]::GetFullPath((Join-Path $normalizedRoot $RelativePath))
    $rootPrefix = $normalizedRoot + [System.IO.Path]::DirectorySeparatorChar
    if (-not $fullPath.StartsWith($rootPrefix, [System.StringComparison]::OrdinalIgnoreCase)) { return $null }

    $current = $normalizedRoot
    foreach ($segment in @($RelativePath -split '[\\/]')) {
        $current = Join-Path $current $segment
        if (Test-Path -LiteralPath $current) {
            $item = Get-Item -LiteralPath $current -Force
            if (($item.Attributes -band [System.IO.FileAttributes]::ReparsePoint) -ne 0) { return $null }
        }
    }
    return $fullPath
}

function Get-StringSha256 {
    param([AllowEmptyString()][string]$Text)
    $bytes = [System.Text.Encoding]::UTF8.GetBytes($Text)
    $sha = [System.Security.Cryptography.SHA256]::Create()
    try {
        return ([BitConverter]::ToString($sha.ComputeHash($bytes)) -replace '-', '')
    }
    finally {
        $sha.Dispose()
    }
}

function Test-MeaningfulValue {
    param([AllowNull()]$Value)
    if ($null -eq $Value) { return $false }
    if ($Value -is [string]) { return -not [string]::IsNullOrWhiteSpace([string]$Value) }
    if ($Value -is [System.Management.Automation.PSCustomObject]) {
        foreach ($property in @($Value.PSObject.Properties)) {
            if (Test-MeaningfulValue $property.Value) { return $true }
        }
        return $false
    }
    if ($Value -is [System.Collections.IDictionary]) {
        foreach ($key in $Value.Keys) {
            if (Test-MeaningfulValue $Value[$key]) { return $true }
        }
        return $false
    }
    if ($Value -is [System.Collections.IEnumerable]) {
        foreach ($item in $Value) {
            if (Test-MeaningfulValue $item) { return $true }
        }
        return $false
    }
    return $true
}

function Test-HashBindingObject {
    param([AllowNull()]$Value)
    if ($null -eq $Value) { return $false }
    $properties = @($Value.PSObject.Properties)
    if ($properties.Count -eq 0) { return $false }
    foreach ($property in $properties) {
        if (-not (Test-Sha256 ([string]$property.Value))) { return $false }
    }
    return $true
}

function Get-StateNames {
    return @(
        'S00_INIT',
        'S10_SOURCE_FROZEN',
        'S20_EVIDENCE_READY',
        'S30_SCOPE_CONFIRMED',
        'S40_PEOPLE_RIGHTS_CONFIRMED',
        'S50_LIBRARY_READY',
        'S60_ASSETS_PLANNED',
        'S70_BRANCHES_READY',
        'S80_QA_PASSED',
        'S90_RELEASE_CANDIDATE',
        'S100_RELEASE_AUTHORIZED',
        'S110_RELEASED',
        'S120_DISTRIBUTION_VERIFIED'
    )
}

function Get-StateRank {
    param([string]$State)
    return [Array]::IndexOf((Get-StateNames), $State)
}

function Get-Speaker {
    param([object]$Registry, [string]$SpeakerId)
    $matches = @($Registry.speakers | Where-Object { [string]$_.stable_speaker_id -eq $SpeakerId })
    if ($matches.Count -ne 1) { return $null }
    return $matches[0]
}

function Get-ApprovedGrants {
    param([object]$Ledger, [string]$Domain)
    return @($Ledger.grants | Where-Object { [string]$_.domain -eq $Domain -and [string]$_.status -eq 'APPROVED' })
}

function Test-GrantCoversSpeaker {
    param([object]$Ledger, [string]$Domain, [string]$SpeakerId)
    foreach ($grant in @(Get-ApprovedGrants $Ledger $Domain)) {
        if ([string]$grant.subject_id -eq $SpeakerId) { return $true }
        if ($null -ne $grant.scope.PSObject.Properties['speaker_ids']) {
            if (@($grant.scope.speaker_ids) -contains $SpeakerId) { return $true }
        }
    }
    return $false
}

function Get-EventById {
    param([object[]]$Events, [AllowNull()][string]$EventId)
    if ([string]::IsNullOrWhiteSpace($EventId)) { return $null }
    $matches = @($Events | Where-Object { [string]$_.event_id -eq $EventId })
    if ($matches.Count -ne 1) { return $null }
    return $matches[0]
}

try {
    $requiredFiles = @{
        Project = 'project-contract.json'
        Source = 'evidence/source-manifest.json'
        Turns = 'evidence/turns.jsonl'
        EvidenceSchema = 'evidence/evidence-turn.schema.json'
        Scope = 'decisions/formal-scope.json'
        Speakers = 'decisions/speaker-registry.json'
        Rights = 'decisions/rights-ledger.json'
        AuthorizationSchema = 'decisions/authorization-grant.schema.json'
        Brand = 'decisions/brand-profile.json'
        Plan = 'plans/ASSET_PLAN.json'
        PlanView = 'plans/ASSET_PLAN.md'
        PodcastPlan = 'branches/podcast/PODCAST_EDIT_PLAN.json'
        PodcastPlanView = 'branches/podcast/PODCAST_EDIT_PLAN.md'
        State = 'state/project-state.json'
        Events = 'audit/events.jsonl'
        Library = 'library/CONTENT_LIBRARY.md'
        QaTemplate = 'qa/BRANCH_QA.md'
        ReleaseTemplate = 'releases/RELEASE_CANDIDATE.template.json'
    }

    $resolvedFiles = @{}
    foreach ($entry in $requiredFiles.GetEnumerator()) {
        $candidate = Join-Path $root $entry.Value
        $resolvedFiles[$entry.Key] = $candidate
        Assert-Check (Test-Path -LiteralPath $candidate -PathType Leaf) "required file exists: $($entry.Value)" "required file missing: $($entry.Value)"
    }
    if (@($resolvedFiles.Values | Where-Object { -not (Test-Path -LiteralPath $_ -PathType Leaf) }).Count -gt 0) {
        throw 'Required project files are missing.'
    }

    $project = Read-JsonFile $resolvedFiles.Project
    $source = Read-JsonFile $resolvedFiles.Source
    $scope = Read-JsonFile $resolvedFiles.Scope
    $speakers = Read-JsonFile $resolvedFiles.Speakers
    $rights = Read-JsonFile $resolvedFiles.Rights
    $brand = Read-JsonFile $resolvedFiles.Brand
    $plan = Read-JsonFile $resolvedFiles.Plan
    $podcastPlan = Read-JsonFile $resolvedFiles.PodcastPlan
    $state = Read-JsonFile $resolvedFiles.State
    $releaseTemplate = Read-JsonFile $resolvedFiles.ReleaseTemplate

    $projectIdValues = @(
        [string]$project.project_id,
        [string]$source.project_id,
        [string]$scope.project_id,
        [string]$speakers.project_id,
        [string]$rights.project_id,
        [string]$brand.project_id,
        [string]$plan.project_id,
        [string]$podcastPlan.project_id,
        [string]$state.project_id,
        [string]$releaseTemplate.project_id
    )
    Assert-Check (@($projectIdValues | Where-Object { [string]::IsNullOrWhiteSpace($_) }).Count -eq 0) 'all project_id values are non-empty' 'one or more project_id values are empty'
    Assert-Check (@($projectIdValues | Select-Object -Unique).Count -eq 1) 'project_id is consistent' 'project_id differs across project contracts'

    Assert-Check ([bool]$project.source_policy.immutable_after_freeze) 'source immutability is enabled' 'source immutability must be enabled'
    Assert-Check (-not [bool]$project.source_policy.analyze_active_partial_files) 'active partial analysis is disabled' 'active partial files must not be analyzed'
    Assert-Check (Test-SafeRelativePath ([string]$project.source_policy.working_derivatives_directory)) 'working derivatives path is safe' 'working derivatives path is unsafe'
    foreach ($property in $project.paths.PSObject.Properties) {
        Assert-Check (Test-SafeRelativePath ([string]$property.Value)) "safe project path: $($property.Name)" "unsafe project path: $($property.Name)"
    }

    $eventLines = @(Get-Content -LiteralPath $resolvedFiles.Events -Encoding UTF8 | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
    $events = @()
    foreach ($line in $eventLines) {
        try {
            $event = $line | ConvertFrom-Json
            $events += $event
            Assert-Check (-not [string]::IsNullOrWhiteSpace([string]$event.event_id)) 'audit event has an ID' 'audit event lacks an ID'
            Assert-Check (-not [string]::IsNullOrWhiteSpace([string]$event.at)) 'audit event has a timestamp' 'audit event lacks a timestamp'
            Assert-Check (-not [string]::IsNullOrWhiteSpace([string]$event.decision)) 'audit event has a decision' 'audit event lacks a decision'
            Assert-Check ($null -ne $event.scope) 'audit event has scope' 'audit event lacks scope'
            Assert-Check ($null -ne $event.bound_sha256) 'audit event has hash bindings' 'audit event lacks hash bindings'
            try { [void][DateTimeOffset]::Parse([string]$event.at); Add-Pass 'audit event timestamp parses' } catch { Add-Failure 'audit event timestamp is invalid' }
        }
        catch {
            Add-Failure "audit event JSON parse failed: $($_.Exception.Message)"
        }
    }
    $eventIds = @($events | ForEach-Object { [string]$_.event_id })
    Assert-Check ($events.Count -gt 0) 'audit log is non-empty' 'audit log is empty'
    Assert-Check (@($eventIds | Select-Object -Unique).Count -eq $eventIds.Count) 'audit event IDs are unique' 'audit event IDs are duplicated'

    $stateRank = Get-StateRank ([string]$state.current_state)
    $lastSafeRank = Get-StateRank ([string]$state.last_safe_state)
    Assert-Check ($stateRank -ge 0) "known state: $($state.current_state)" "unknown project state: $($state.current_state)"
    Assert-Check ($lastSafeRank -ge 0) 'last_safe_state is known' 'last_safe_state is unknown'
    Assert-Check ($lastSafeRank -le $stateRank) 'last_safe_state does not exceed current state' 'last_safe_state is ahead of current state'

    $initialEvents = @($events | Where-Object { [string]$_.to -eq 'S00_INIT' -and [string]$_.decision -eq 'CREATED' })
    Assert-Check ($initialEvents.Count -eq 1) 'audit log has one creation event' 'audit log must have exactly one S00 creation event'
    $stateNames = Get-StateNames
    if ($stateRank -gt 0) {
        for ($rank = 1; $rank -le $stateRank; $rank++) {
            $expectedFrom = $stateNames[$rank - 1]
            $expectedTo = $stateNames[$rank]
            $transitionEvents = @($events | Where-Object { [string]$_.from -eq $expectedFrom -and [string]$_.to -eq $expectedTo -and [string]$_.decision -eq 'APPROVED' })
            Assert-Check ($transitionEvents.Count -eq 1) "state transition is audited: $expectedFrom -> $expectedTo" "state transition missing or duplicated: $expectedFrom -> $expectedTo"
            if ($transitionEvents.Count -eq 1) {
                $transition = $transitionEvents[0]
                Assert-Check (-not [string]::IsNullOrWhiteSpace([string]$transition.confirmation_text)) "state transition has evidence: $expectedTo" "state transition lacks confirmation evidence: $expectedTo"
                Assert-Check (Test-MeaningfulValue $transition.scope) "state transition has scope: $expectedTo" "state transition lacks meaningful scope: $expectedTo"
                Assert-Check (Test-HashBindingObject $transition.bound_sha256) "state transition binds hashes: $expectedTo" "state transition lacks valid hash bindings: $expectedTo"
            }
        }
    }

    $sourceStatusAllowed = @('COLLECTING', 'FROZEN')
    Assert-Check ($sourceStatusAllowed -contains [string]$source.status) 'source status is valid' 'source status is invalid'
    $sourceFiles = @($source.files)
    $sourceIds = @($sourceFiles | ForEach-Object { [string]$_.source_id })
    Assert-Check (@($sourceIds | Select-Object -Unique).Count -eq $sourceIds.Count) 'source IDs are unique' 'source IDs are duplicated'
    Assert-Check ($sourceFiles.Count -eq [int]$source.summary.file_count) 'source file count is consistent' 'source file count does not match summary'
    $byteSum = 0L
    $partialCount = 0
    foreach ($sourceFile in $sourceFiles) {
        $byteSum += [long]$sourceFile.bytes
        if ([bool]$sourceFile.is_partial -or [string]$sourceFile.relative_path -match '(?i)(^|[.])partial([.]|$)') { $partialCount++ }
        $fullSourcePath = Get-ContainedProjectPath $root ([string]$sourceFile.relative_path)
        Assert-Check ($null -ne $fullSourcePath) "contained source path: $($sourceFile.source_id)" "unsafe or reparse-point source path: $($sourceFile.source_id)"
        Assert-Check (Test-Sha256 ([string]$sourceFile.sha256)) "valid source hash: $($sourceFile.source_id)" "invalid source hash: $($sourceFile.source_id)"
        if ($null -ne $fullSourcePath) {
            Assert-Check (Test-Path -LiteralPath $fullSourcePath -PathType Leaf) "source file exists: $($sourceFile.source_id)" "source file missing: $($sourceFile.source_id)"
            if (Test-Path -LiteralPath $fullSourcePath -PathType Leaf) {
                Assert-Check ((Get-Item -LiteralPath $fullSourcePath).Length -eq [long]$sourceFile.bytes) "source size matches: $($sourceFile.source_id)" "source size mismatch: $($sourceFile.source_id)"
                Assert-Check ((Get-FileHash -Algorithm SHA256 -LiteralPath $fullSourcePath).Hash -eq [string]$sourceFile.sha256) "source hash matches: $($sourceFile.source_id)" "source hash mismatch: $($sourceFile.source_id)"
            }
        }
    }
    Assert-Check ($byteSum -eq [long]$source.summary.total_bytes) 'source byte total is consistent' 'source byte total does not match summary'
    Assert-Check ($partialCount -eq [int]$source.summary.partial_file_count) 'source partial count is consistent' 'source partial count does not match files'
    if ([string]$source.status -eq 'FROZEN') {
        Assert-Check (-not [string]::IsNullOrWhiteSpace([string]$source.frozen_at)) 'frozen manifest has a timestamp' 'frozen manifest lacks frozen_at'
        Assert-Check ($partialCount -eq 0) 'frozen manifest has zero partial files' 'frozen manifest contains partial files'
        Assert-Check ([int]$source.summary.hash_verified_count -eq $sourceFiles.Count) 'all frozen source hashes are verified' 'not all frozen source hashes are verified'
    }

    if ([string]$scope.status -eq 'APPROVED') {
        Assert-Check ([string]$scope.formal_timecode -eq '00:00:00.000') 'formal scope resets to zero' 'approved formal scope must reset to 00:00:00.000'
        Assert-Check (-not [string]::IsNullOrWhiteSpace([string]$scope.anchor_turn_id)) 'formal scope has an anchor turn' 'approved formal scope lacks anchor turn'
        Assert-Check (-not [string]::IsNullOrWhiteSpace([string]$scope.source_id)) 'formal scope has a source ID' 'approved formal scope lacks source ID'
        Assert-Check (-not [string]::IsNullOrWhiteSpace([string]$scope.source_timecode)) 'formal scope has a source timecode' 'approved formal scope lacks source timecode'
        Assert-Check (-not [string]::IsNullOrWhiteSpace([string]$scope.approval_source)) 'formal scope has approval evidence' 'approved formal scope lacks approval evidence'
    }
    foreach ($range in @($scope.restricted_ranges)) {
        Assert-Check ([string]$range.policy -in @('EVIDENCE_ONLY', 'EXISTENCE_ONLY')) 'restricted range has a valid policy' 'restricted range has an invalid policy'
        if ([string]$range.policy -eq 'EXISTENCE_ONLY') {
            $allowedRangeFields = @('range_id', 'source_id', 'start', 'end', 'policy', 'reason', 'authorized_by', 'recorded_at')
            foreach ($property in @($range.PSObject.Properties)) {
                Assert-Check ($allowedRangeFields -contains [string]$property.Name) "existence-only range field is allowed: $($property.Name)" "existence-only range leaks forbidden field: $($property.Name)"
            }
        }
    }

    Assert-Check ([string]$speakers.unknown_policy -eq 'EVIDENCE_ONLY') 'unknown speakers remain evidence-only' 'unknown speaker policy must be EVIDENCE_ONLY'
    $speakerIds = @($speakers.speakers | ForEach-Object { [string]$_.stable_speaker_id })
    Assert-Check (@($speakerIds | Where-Object { [string]::IsNullOrWhiteSpace($_) }).Count -eq 0) 'stable speaker IDs are non-empty' 'a stable speaker ID is empty'
    Assert-Check (@($speakerIds | Select-Object -Unique).Count -eq $speakerIds.Count) 'stable speaker IDs are unique' 'stable speaker IDs are duplicated'
    foreach ($speaker in @($speakers.speakers)) {
        foreach ($field in @('display_name_status', 'public_identity_status', 'editorial_policy', 'original_audio_use_status', 'voice_enrollment_status', 'voice_trial_status', 'synthetic_voice_status', 'digital_likeness_status')) {
            Assert-Check ($null -ne $speaker.PSObject.Properties[$field]) "speaker field exists: $($speaker.stable_speaker_id).$field" "speaker field missing: $($speaker.stable_speaker_id).$field"
        }
        if ([string]$speaker.display_name_status -ne 'CONFIRMED') {
            Assert-Check ([string]$speaker.editorial_policy -eq 'EVIDENCE_ONLY') "unconfirmed speaker remains isolated: $($speaker.stable_speaker_id)" "unconfirmed speaker leaks into editorial output: $($speaker.stable_speaker_id)"
            Assert-Check ([string]$speaker.synthetic_voice_status -ne 'APPROVED') "unconfirmed speaker voice remains blocked: $($speaker.stable_speaker_id)" "unconfirmed speaker has synthetic voice approval: $($speaker.stable_speaker_id)"
        }
    }

    $turnLines = @(Get-Content -LiteralPath $resolvedFiles.Turns -Encoding UTF8 | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
    $turns = @()
    foreach ($line in $turnLines) {
        try {
            $turn = $line | ConvertFrom-Json
            $turns += $turn
            Assert-Check (-not [string]::IsNullOrWhiteSpace([string]$turn.turn_id)) 'evidence turn has an ID' 'evidence turn lacks an ID'
            Assert-Check (Test-Sha256 ([string]$turn.source_sha256)) "evidence turn has a source hash: $($turn.turn_id)" "evidence turn has an invalid source hash: $($turn.turn_id)"
            $boundSource = @($sourceFiles | Where-Object { [string]$_.source_id -eq [string]$turn.source_id })
            Assert-Check ($boundSource.Count -eq 1) "evidence source exists: $($turn.turn_id)" "evidence source missing or ambiguous: $($turn.turn_id)"
            if ($boundSource.Count -eq 1) {
                Assert-Check ([string]$turn.source_sha256 -eq [string]$boundSource[0].sha256) "evidence source hash matches: $($turn.turn_id)" "evidence source hash mismatch: $($turn.turn_id)"
            }
            Assert-Check ($null -ne $turn.source_time) "evidence turn has source time: $($turn.turn_id)" "evidence turn lacks source time: $($turn.turn_id)"

            if ([string]$turn.editorial_policy -eq 'EXISTENCE_ONLY') {
                $allowedTurnFields = @('turn_id', 'source_id', 'source_sha256', 'track', 'source_time', 'session_time', 'absolute_time', 'scope', 'editorial_policy', 'restriction_reason')
                foreach ($property in @($turn.PSObject.Properties)) {
                    Assert-Check ($allowedTurnFields -contains [string]$property.Name) "existence-only turn field is allowed: $($property.Name)" "existence-only turn leaks forbidden field: $($property.Name)"
                }
            }
            else {
                $rawTextProperty = $turn.PSObject.Properties['raw_text']
                Assert-Check ($null -ne $rawTextProperty) "evidence turn contains raw text: $($turn.turn_id)" "evidence turn lacks raw text: $($turn.turn_id)"
            }

            if ([string]$turn.scope -ne 'FORMAL') {
                Assert-Check ([string]$turn.editorial_policy -ne 'ALLOWED') "non-formal turn stays isolated: $($turn.turn_id)" "non-formal turn is editorially allowed: $($turn.turn_id)"
            }
            $stableSpeakerId = $null
            if ($null -ne $turn.PSObject.Properties['stable_speaker_id']) { $stableSpeakerId = [string]$turn.stable_speaker_id }
            if ([string]::IsNullOrWhiteSpace($stableSpeakerId)) {
                Assert-Check ([string]$turn.editorial_policy -ne 'ALLOWED') "unresolved turn stays isolated: $($turn.turn_id)" "unresolved turn leaks into editorial output: $($turn.turn_id)"
            }
            elseif ($null -eq (Get-Speaker $speakers $stableSpeakerId)) {
                Assert-Check ([string]$turn.editorial_policy -ne 'ALLOWED') "unregistered turn stays isolated: $($turn.turn_id)" "unregistered speaker leaks into editorial output: $($turn.turn_id)"
            }
        }
        catch {
            Add-Failure "evidence turn JSON parse failed: $($_.Exception.Message)"
        }
    }
    $turnIds = @($turns | ForEach-Object { [string]$_.turn_id })
    Assert-Check (@($turnIds | Select-Object -Unique).Count -eq $turnIds.Count) 'evidence turn IDs are unique' 'evidence turn IDs are duplicated'

    $requiredDomains = @(
        'DISPLAY_NAME', 'PUBLIC_IDENTITY', 'ORIGINAL_AUDIO_USE', 'VOICE_ENROLLMENT', 'VOICE_TRIAL',
        'BATCH_SYNTHESIS', 'DIGITAL_LIKENESS', 'EXTERNAL_KNOWLEDGE_WRITE', 'DRAFT_UPLOAD', 'PUBLIC_RELEASE'
    )
    Assert-Check (@($rights.required_domains | Select-Object -Unique).Count -eq @($rights.required_domains).Count) 'required authorization domains are unique' 'required authorization domains are duplicated'
    foreach ($domain in $requiredDomains) {
        Assert-Check (@($rights.required_domains) -contains $domain) "required authorization domain declared: $domain" "required authorization domain missing: $domain"
    }

    $allowedGrantStates = @('PENDING', 'APPROVED', 'DENIED', 'REVOKED', 'EXPIRED')
    $grantIds = @($rights.grants | ForEach-Object { [string]$_.grant_id })
    Assert-Check (@($grantIds | Where-Object { [string]::IsNullOrWhiteSpace($_) }).Count -eq 0) 'authorization grant IDs are non-empty' 'an authorization grant ID is empty'
    Assert-Check (@($grantIds | Select-Object -Unique).Count -eq $grantIds.Count) 'authorization grant IDs are unique' 'authorization grant IDs are duplicated'
    foreach ($grant in @($rights.grants)) {
        Assert-Check ($requiredDomains -contains [string]$grant.domain) "known authorization domain: $($grant.domain)" "unknown authorization domain: $($grant.domain)"
        Assert-Check ($allowedGrantStates -contains [string]$grant.status) "valid authorization status: $($grant.grant_id)" "invalid authorization status: $($grant.grant_id)=$($grant.status)"
        Assert-Check (-not [string]::IsNullOrWhiteSpace([string]$grant.subject_id)) "authorization grant has a subject: $($grant.grant_id)" "authorization grant lacks a subject: $($grant.grant_id)"
        if ([string]$grant.status -eq 'APPROVED') {
            Assert-Check (-not [string]::IsNullOrWhiteSpace([string]$grant.confirmation_text)) "approved grant has confirmation: $($grant.grant_id)" "approved grant lacks confirmation: $($grant.grant_id)"
            Assert-Check (-not [string]::IsNullOrWhiteSpace([string]$grant.approved_at)) "approved grant has timestamp: $($grant.grant_id)" "approved grant lacks timestamp: $($grant.grant_id)"
            Assert-Check (Test-MeaningfulValue $grant.scope) "approved grant has meaningful scope: $($grant.grant_id)" "approved grant lacks meaningful scope: $($grant.grant_id)"
            $approvalEvent = Get-EventById $events ([string]$grant.approval_event_id)
            Assert-Check ($null -ne $approvalEvent) "approved grant binds an audit event: $($grant.grant_id)" "approved grant lacks a matching audit event: $($grant.grant_id)"
            if ($null -ne $approvalEvent) {
                $eventDomain = $null
                if ($null -ne $approvalEvent.scope.PSObject.Properties['authorization_domain']) { $eventDomain = [string]$approvalEvent.scope.authorization_domain }
                Assert-Check ([string]$approvalEvent.decision -eq 'AUTHORIZATION_APPROVED') "grant event is an authorization approval: $($grant.grant_id)" "grant event has the wrong decision: $($grant.grant_id)"
                Assert-Check ($eventDomain -eq [string]$grant.domain) "grant event domain matches: $($grant.grant_id)" "grant event domain mismatch: $($grant.grant_id)"
                Assert-Check ([string]$approvalEvent.confirmation_text -eq [string]$grant.confirmation_text) "grant confirmation matches event: $($grant.grant_id)" "grant confirmation differs from event: $($grant.grant_id)"
                Assert-Check ([string]$approvalEvent.at -eq [string]$grant.approved_at) "grant timestamp matches event: $($grant.grant_id)" "grant timestamp differs from event: $($grant.grant_id)"
                Assert-Check (Test-HashBindingObject $approvalEvent.bound_sha256) "grant event binds hashes: $($grant.grant_id)" "grant event lacks valid hash bindings: $($grant.grant_id)"
            }
        }
    }

    $speakerGrantMap = @{
        public_identity_status = 'PUBLIC_IDENTITY'
        original_audio_use_status = 'ORIGINAL_AUDIO_USE'
        voice_enrollment_status = 'VOICE_ENROLLMENT'
        voice_trial_status = 'VOICE_TRIAL'
        synthetic_voice_status = 'BATCH_SYNTHESIS'
        digital_likeness_status = 'DIGITAL_LIKENESS'
    }
    foreach ($speaker in @($speakers.speakers)) {
        foreach ($mapping in $speakerGrantMap.GetEnumerator()) {
            if ([string]$speaker.($mapping.Key) -eq 'APPROVED') {
                Assert-Check (Test-GrantCoversSpeaker $rights $mapping.Value ([string]$speaker.stable_speaker_id)) "speaker approval has a matching grant: $($speaker.stable_speaker_id).$($mapping.Key)" "speaker approval lacks a matching grant: $($speaker.stable_speaker_id).$($mapping.Key)"
            }
        }
    }

    foreach ($trialGrant in @(Get-ApprovedGrants $rights 'VOICE_TRIAL')) {
        foreach ($speakerId in @($trialGrant.scope.speaker_ids)) {
            Assert-Check (Test-GrantCoversSpeaker $rights 'VOICE_ENROLLMENT' ([string]$speakerId)) "voice trial is backed by enrollment: $speakerId" "voice trial lacks enrollment approval: $speakerId"
        }
    }
    foreach ($batchGrant in @(Get-ApprovedGrants $rights 'BATCH_SYNTHESIS')) {
        foreach ($speakerId in @($batchGrant.scope.speaker_ids)) {
            Assert-Check (Test-GrantCoversSpeaker $rights 'VOICE_TRIAL' ([string]$speakerId)) "batch synthesis is backed by a trial: $speakerId" "batch synthesis lacks trial approval: $speakerId"
        }
        Assert-Check (Test-SafeRelativePath ([string]$batchGrant.scope.segment_manifest_path)) 'batch grant has a safe segment manifest path' 'batch grant lacks a safe segment manifest path'
        Assert-Check (Test-Sha256 ([string]$batchGrant.scope.segment_manifest_sha256)) 'batch grant binds a segment manifest hash' 'batch grant lacks a valid segment manifest hash'
        Assert-Check (@($batchGrant.bound_artifacts).Count -gt 0) 'batch grant binds artifacts' 'batch grant does not bind artifacts'
        foreach ($boundary in @('ORIGINAL_AUDIO_USE', 'DIGITAL_LIKENESS', 'DRAFT_UPLOAD', 'PUBLIC_RELEASE')) {
            Assert-Check (@($batchGrant.does_not_grant) -contains $boundary) "batch grant does not grant $boundary" "batch grant overreaches into $boundary"
        }
    }

    if ([string]$brand.profile_id -eq 'DEEPEVOLUTIONS_PODCAST') {
        $intro = $brand.fixed_intro
        Assert-Check ([string]$brand.host_display_name -eq 'Toni') 'DeepEvolutions host is Toni' 'DeepEvolutions host name drifted'
        Assert-Check ((Get-StringSha256 ([string]$intro.user_original_text)) -eq [string]$intro.user_original_text_sha256) 'original intro hash matches' 'original intro hash mismatch'
        Assert-Check ((Get-StringSha256 ([string]$intro.normalized_tts_text)) -eq [string]$intro.normalized_tts_text_sha256) 'normalized intro hash matches' 'normalized intro hash mismatch'
        Assert-Check ([int]$intro.required_per_episode -eq 1 -and [int]$intro.required_position -eq 1) 'fixed intro count and position are locked' 'fixed intro count or position drifted'
        Assert-Check ([string]$intro.segment_type -eq 'INTRO' -and [string]$intro.role -eq 'OWNER') 'fixed intro role binding is narrow' 'fixed intro role binding drifted'
    }
    elseif ([string]$brand.profile_id -eq 'BLANK') {
        Assert-Check ($null -eq $brand.fixed_intro) 'blank brand has no inherited intro' 'blank brand inherited a fixed intro'
    }

    $allowedBranchStates = @('SELECTED', 'OPTIONAL', 'SKIPPED', 'BLOCKED', 'COMPLETE')
    $expectedBranches = @('podcast', 'article', 'video', 'social', 'knowledge', 'commercial')
    $actualBranches = @($plan.branches.PSObject.Properties | ForEach-Object { $_.Name })
    foreach ($branchName in $expectedBranches) {
        Assert-Check ($actualBranches -contains $branchName) "asset branch exists: $branchName" "asset branch missing: $branchName"
    }
    foreach ($property in $plan.branches.PSObject.Properties) {
        $branch = $property.Value
        Assert-Check ($allowedBranchStates -contains [string]$branch.status) "valid branch status: $($property.Name)" "invalid branch status: $($property.Name)=$($branch.status)"
        if ([string]$branch.status -eq 'COMPLETE') {
            Assert-Check ([string]$branch.qa_status -eq 'PASS') "completed branch QA passed: $($property.Name)" "completed branch lacks PASS QA: $($property.Name)"
            $outputs = @($branch.output_paths)
            Assert-Check ($outputs.Count -gt 0) "completed branch has outputs: $($property.Name)" "completed branch has no outputs: $($property.Name)"
            foreach ($output in $outputs) {
                $fullOutputPath = Get-ContainedProjectPath $root ([string]$output)
                Assert-Check ($null -ne $fullOutputPath) "contained branch output path: $output" "unsafe or reparse-point branch output path: $output"
                if ($null -ne $fullOutputPath) {
                    Assert-Check (Test-Path -LiteralPath $fullOutputPath -PathType Leaf) "branch output file exists: $output" "branch output is missing or not a file: $output"
                }
            }
        }
    }

    $podcastBranch = $plan.branches.podcast
    Assert-Check ([string]$podcastBranch.editorial_model -eq 'ORIGINAL_AUDIO_LED') 'podcast asset plan is original-audio-led' 'podcast asset plan is not original-audio-led'
    Assert-Check ([string]$podcastBranch.narration_policy -eq 'INTRO_AND_MINIMAL_TRANSITIONS_ONLY') 'podcast narration is limited' 'podcast narration policy is too broad'
    Assert-Check ([int]$podcastBranch.preferred_episode_minutes.min -eq 30 -and [int]$podcastBranch.preferred_episode_minutes.max -eq 60) 'podcast preferred duration is 30-60 minutes' 'podcast preferred duration drifted'
    Assert-Check ($null -eq $podcastBranch.preferred_episode_minutes.hard_cap) 'podcast duration has no hard cap' 'podcast duration incorrectly has a hard cap'
    Assert-Check ([double]$podcastBranch.original_audio_share.floor -ge 0.90) 'podcast original-audio floor is at least 90%' 'podcast original-audio floor is below 90%'
    Assert-Check ([double]$podcastBranch.original_audio_share.target -ge 0.95) 'podcast original-audio target is at least 95%' 'podcast original-audio target is below 95%'

    Assert-Check ([string]$podcastPlan.editorial_model -eq 'ORIGINAL_AUDIO_LED') 'podcast edit plan is original-audio-led' 'podcast edit plan is not original-audio-led'
    Assert-Check ([string]$podcastPlan.narration_policy -eq 'INTRO_AND_MINIMAL_TRANSITIONS_ONLY') 'podcast edit plan limits narration' 'podcast edit plan narration policy is too broad'
    Assert-Check ([string]$podcastPlan.formal_episode_asset_kind -eq 'FORMAL_LONGFORM_PODCAST') 'formal podcast asset kind is locked' 'formal podcast asset kind drifted'
    Assert-Check (@($podcastPlan.forbidden_episode_asset_kinds) -contains 'SHORT_AUDIO_SUMMARY' -and @($podcastPlan.forbidden_episode_asset_kinds) -contains 'NARRATED_DIGEST') 'short summaries are excluded from formal episodes' 'short summaries are not structurally separated'
    $allowedNarrationTypes = @($podcastPlan.allowed_narration_types)
    Assert-Check (@($allowedNarrationTypes).Count -eq 2 -and $allowedNarrationTypes -contains 'INTRO' -and $allowedNarrationTypes -contains 'NECESSARY_TRANSITION') 'podcast narration types are narrowly locked' 'podcast narration types are not narrowly locked'
    Assert-Check ([double]$podcastPlan.original_audio_share.floor -ge 0.90) 'podcast edit plan floor is at least 90%' 'podcast edit plan floor is below 90%'
    Assert-Check ([double]$podcastPlan.original_audio_share.target -ge 0.95) 'podcast edit plan target is at least 95%' 'podcast edit plan target is below 95%'

    if ([string]$podcastBranch.status -in @('BLOCKED', 'COMPLETE')) {
        Assert-Check (-not [string]::IsNullOrWhiteSpace([string]$podcastPlan.episode_count_rationale)) 'podcast episode count has a rationale' 'podcast episode count lacks a rationale'
        Assert-Check (@($podcastPlan.episodes).Count -gt 0) 'podcast edit plan has episodes' 'podcast edit plan has no episodes'
    }
    if ([string]$podcastBranch.status -eq 'COMPLETE') {
        Assert-Check ([string]$podcastPlan.status -eq 'COMPLETE') 'completed podcast has a complete edit plan' 'completed podcast edit plan is not COMPLETE'
        foreach ($episode in @($podcastPlan.episodes)) {
            $originalSeconds = [double]$episode.actual_original_audio_seconds
            $narrationSeconds = [double]$episode.actual_narration_seconds
            $spokenSeconds = $originalSeconds + $narrationSeconds
            $computedShare = 0.0
            if ($spokenSeconds -gt 0) { $computedShare = $originalSeconds / $spokenSeconds }
            Assert-Check ([string]$episode.asset_kind -eq 'FORMAL_LONGFORM_PODCAST') "podcast episode has the formal asset kind: $($episode.episode_id)" "short or narrated digest is mislabeled as a formal podcast: $($episode.episode_id)"
            Assert-Check (-not [string]::IsNullOrWhiteSpace([string]$episode.theme)) "podcast episode has a theme: $($episode.episode_id)" "podcast episode lacks a theme: $($episode.episode_id)"
            Assert-Check ([double]$episode.actual_total_seconds -gt 0) "podcast episode has actual duration: $($episode.episode_id)" "podcast episode lacks actual duration: $($episode.episode_id)"
            Assert-Check ($originalSeconds -gt 0 -and $narrationSeconds -ge 0) "podcast episode duration components are valid: $($episode.episode_id)" "podcast episode duration components are invalid: $($episode.episode_id)"
            Assert-Check ($computedShare -ge [double]$podcastPlan.original_audio_share.floor) "podcast episode meets original-audio floor: $($episode.episode_id)" "podcast episode falls below original-audio floor: $($episode.episode_id)"
            Assert-Check ([Math]::Abs($computedShare - [double]$episode.original_audio_share) -le 0.001) "podcast episode audio share recomputes: $($episode.episode_id)" "podcast episode audio share is inconsistent: $($episode.episode_id)"
            Assert-Check ([int]$episode.source_clip_count -gt 0) "podcast episode has source clips: $($episode.episode_id)" "podcast episode has no source clips: $($episode.episode_id)"
            Assert-Check ([string]$episode.full_listen_qa -eq 'PASS') "podcast episode passed full-listen QA: $($episode.episode_id)" "podcast episode lacks full-listen QA: $($episode.episode_id)"
            Assert-Check ([string]$episode.original_audio_rights_qa -eq 'PASS') "podcast episode passed original-audio rights QA: $($episode.episode_id)" "podcast episode lacks original-audio rights QA: $($episode.episode_id)"
            foreach ($speakerId in @($episode.original_audio_speaker_ids)) {
                Assert-Check (Test-GrantCoversSpeaker $rights 'ORIGINAL_AUDIO_USE' ([string]$speakerId)) "podcast source speaker has original-audio grant: $speakerId" "podcast source speaker lacks original-audio grant: $speakerId"
            }
            $narrationDurationSum = 0.0
            foreach ($segment in @($episode.narration_segments)) {
                Assert-Check ($allowedNarrationTypes -contains [string]$segment.type) "podcast narration type is allowed: $($segment.segment_id)" "podcast narration type is forbidden: $($segment.segment_id)"
                Assert-Check (-not [string]::IsNullOrWhiteSpace([string]$segment.necessity_reason)) "podcast narration has a necessity reason: $($segment.segment_id)" "podcast narration lacks a necessity reason: $($segment.segment_id)"
                $narrationDurationSum += [double]$segment.duration_seconds
            }
            Assert-Check ([Math]::Abs($narrationDurationSum - $narrationSeconds) -le 1.0) "podcast narration duration recomputes: $($episode.episode_id)" "podcast narration duration is inconsistent: $($episode.episode_id)"
        }
    }

    $candidate = $null
    $candidateFullPath = $null
    $candidateHash = $null
    if (-not [string]::IsNullOrWhiteSpace([string]$state.current_release_candidate)) {
        $candidateFullPath = Get-ContainedProjectPath $root ([string]$state.current_release_candidate)
        Assert-Check ($null -ne $candidateFullPath) 'release candidate path is contained' 'release candidate path is unsafe or crosses a reparse point'
        if ($null -ne $candidateFullPath) {
            Assert-Check (Test-Path -LiteralPath $candidateFullPath -PathType Leaf) 'release candidate file exists' 'release candidate is missing or not a file'
            if (Test-Path -LiteralPath $candidateFullPath -PathType Leaf) {
                $candidate = Read-JsonFile $candidateFullPath
                $candidateHash = (Get-FileHash -Algorithm SHA256 -LiteralPath $candidateFullPath).Hash
            }
        }
    }

    if ($stateRank -lt (Get-StateRank 'S90_RELEASE_CANDIDATE')) {
        Assert-Check ([string]::IsNullOrWhiteSpace([string]$state.current_release_candidate)) 'pre-release state has no release candidate' 'release candidate exists before S90'
    }

    if ($null -ne $candidate) {
        Assert-Check ([string]$candidate.project_id -eq [string]$project.project_id) 'release candidate project matches' 'release candidate project mismatch'
        Assert-Check ([bool]$candidate.immutable) 'release candidate is immutable' 'release candidate is not immutable'
        Assert-Check ([string]$candidate.status -eq 'READY_FOR_AUTHORIZATION') 'release candidate is frozen for authorization' 'release candidate status is not READY_FOR_AUTHORIZATION'
        Assert-Check ([string]$candidate.operation -in @('DRAFT_UPLOAD', 'PUBLIC_RELEASE')) 'release candidate operation is valid' 'release candidate operation is invalid'
        Assert-Check (-not [string]::IsNullOrWhiteSpace([string]$candidate.platform)) 'release candidate binds a platform' 'release candidate lacks a platform'
        Assert-Check (-not [string]::IsNullOrWhiteSpace([string]$candidate.account)) 'release candidate binds an account' 'release candidate lacks an account'
        Assert-Check (-not [string]::IsNullOrWhiteSpace([string]$candidate.previewed_at)) 'release candidate records preview time' 'release candidate lacks preview time'
        foreach ($binding in @($candidate.input_bindings.PSObject.Properties)) {
            Assert-Check (Test-Sha256 ([string]$binding.Value)) "release input hash is valid: $($binding.Name)" "release input hash is invalid: $($binding.Name)"
        }
        $candidateArtifacts = @($candidate.artifacts)
        Assert-Check ($candidateArtifacts.Count -gt 0) 'release candidate binds artifacts' 'release candidate has no artifacts'
        $blockedPattern = '(?i)(UNKNOWN([_-]SPEAKER)?|UNRESOLVED|CLUSTER-[A-Z0-9_-]+|TODO|PLACEHOLDER)|\u5185\u90E8\u5BA1\u9605|\u672A\u53D1\u5E03|\u8349\u6848|\u5F85\u5BA1'
        foreach ($artifact in $candidateArtifacts) {
            $artifactPath = Get-ContainedProjectPath $root ([string]$artifact.relative_path)
            Assert-Check ($null -ne $artifactPath) "release artifact path is contained: $($artifact.artifact_id)" "release artifact path is unsafe: $($artifact.artifact_id)"
            if ([string]$candidate.operation -eq 'PUBLIC_RELEASE') {
                $portablePath = ([string]$artifact.relative_path).Replace('\\', '/')
                Assert-Check ($portablePath.StartsWith('releases/public/', [System.StringComparison]::OrdinalIgnoreCase)) "public artifact is in releases/public: $($artifact.artifact_id)" "public artifact is outside releases/public: $($artifact.artifact_id)"
            }
            Assert-Check (Test-Sha256 ([string]$artifact.sha256)) "release artifact has a valid hash: $($artifact.artifact_id)" "release artifact has an invalid hash: $($artifact.artifact_id)"
            if ($null -ne $artifactPath) {
                Assert-Check (Test-Path -LiteralPath $artifactPath -PathType Leaf) "release artifact exists: $($artifact.artifact_id)" "release artifact is missing or not a file: $($artifact.artifact_id)"
                if (Test-Path -LiteralPath $artifactPath -PathType Leaf) {
                    Assert-Check ((Get-FileHash -Algorithm SHA256 -LiteralPath $artifactPath).Hash -eq [string]$artifact.sha256) "release artifact hash matches: $($artifact.artifact_id)" "release artifact hash mismatch: $($artifact.artifact_id)"
                    if ([string]$candidate.operation -eq 'PUBLIC_RELEASE' -and ([System.IO.Path]::GetExtension($artifactPath) -in @('.md', '.txt', '.json', '.csv', '.srt', '.vtt'))) {
                        $artifactText = Get-Content -LiteralPath $artifactPath -Raw -Encoding UTF8
                        Assert-Check (-not ($artifactText -match $blockedPattern)) "public artifact is free of blocked markers: $($artifact.artifact_id)" "blocked marker leaked into public artifact: $($artifact.artifact_id)"
                    }
                }
            }
        }

        $metadataPath = Get-ContainedProjectPath $root ([string]$candidate.public_metadata.relative_path)
        Assert-Check ($null -ne $metadataPath) 'public metadata path is contained' 'public metadata path is unsafe'
        Assert-Check (Test-Sha256 ([string]$candidate.public_metadata.sha256)) 'public metadata hash is valid' 'public metadata hash is invalid'
        if ($null -ne $metadataPath) {
            Assert-Check (Test-Path -LiteralPath $metadataPath -PathType Leaf) 'public metadata exists' 'public metadata is missing or not a file'
            if (Test-Path -LiteralPath $metadataPath -PathType Leaf) {
                Assert-Check ((Get-FileHash -Algorithm SHA256 -LiteralPath $metadataPath).Hash -eq [string]$candidate.public_metadata.sha256) 'public metadata hash matches' 'public metadata hash mismatch'
            }
        }

        $identityRules = @(
            @{ Field = 'public_speaker_ids'; SpeakerField = 'public_identity_status'; Domain = 'PUBLIC_IDENTITY' },
            @{ Field = 'original_audio_speaker_ids'; SpeakerField = 'original_audio_use_status'; Domain = 'ORIGINAL_AUDIO_USE' },
            @{ Field = 'synthetic_voice_speaker_ids'; SpeakerField = 'synthetic_voice_status'; Domain = 'BATCH_SYNTHESIS' },
            @{ Field = 'digital_likeness_speaker_ids'; SpeakerField = 'digital_likeness_status'; Domain = 'DIGITAL_LIKENESS' }
        )
        foreach ($rule in $identityRules) {
            foreach ($speakerId in @($candidate.identity_bindings.($rule.Field))) {
                $boundSpeaker = Get-Speaker $speakers ([string]$speakerId)
                Assert-Check ($null -ne $boundSpeaker) "release identity speaker exists: $speakerId" "release identity speaker is unknown: $speakerId"
                if ($null -ne $boundSpeaker) {
                    Assert-Check ([string]$boundSpeaker.($rule.SpeakerField) -eq 'APPROVED') "release speaker status is approved: $speakerId/$($rule.Domain)" "release speaker status is not approved: $speakerId/$($rule.Domain)"
                    Assert-Check (Test-GrantCoversSpeaker $rights $rule.Domain ([string]$speakerId)) "release speaker has a matching grant: $speakerId/$($rule.Domain)" "release speaker lacks a matching grant: $speakerId/$($rule.Domain)"
                }
            }
        }
    }

    $approvedReleaseGrants = @(
        @(Get-ApprovedGrants $rights 'DRAFT_UPLOAD')
        @(Get-ApprovedGrants $rights 'PUBLIC_RELEASE')
    )
    foreach ($releaseGrant in $approvedReleaseGrants) {
        Assert-Check ($stateRank -ge (Get-StateRank 'S100_RELEASE_AUTHORIZED')) "release grant is reflected in state: $($releaseGrant.grant_id)" "release grant approved before S100: $($releaseGrant.grant_id)"
        Assert-Check ($null -ne $candidate) "release grant has a candidate: $($releaseGrant.grant_id)" "release grant lacks a candidate: $($releaseGrant.grant_id)"
        if ($null -ne $candidate) {
            Assert-Check ([string]$candidate.operation -eq [string]$releaseGrant.domain) "release operation matches grant: $($releaseGrant.grant_id)" "release operation differs from grant: $($releaseGrant.grant_id)"
            Assert-Check ([string]$candidate.platform -eq [string]$releaseGrant.scope.platform) "release platform matches grant: $($releaseGrant.grant_id)" "release platform differs from grant: $($releaseGrant.grant_id)"
            Assert-Check ([string]$candidate.account -eq [string]$releaseGrant.scope.account) "release account matches grant: $($releaseGrant.grant_id)" "release account differs from grant: $($releaseGrant.grant_id)"
            Assert-Check (Test-Sha256 ([string]$releaseGrant.scope.release_candidate_sha256)) "release grant binds a candidate hash: $($releaseGrant.grant_id)" "release grant lacks a candidate hash: $($releaseGrant.grant_id)"
            Assert-Check ([string]$candidateHash -eq [string]$releaseGrant.scope.release_candidate_sha256) "release candidate hash matches grant: $($releaseGrant.grant_id)" "release candidate changed after grant: $($releaseGrant.grant_id)"
        }
        if ([string]$releaseGrant.domain -eq 'DRAFT_UPLOAD') {
            Assert-Check (@($releaseGrant.does_not_grant) -contains 'PUBLIC_RELEASE') 'draft upload does not grant public release' 'draft upload grant overreaches into public release'
        }
    }

    if ($stateRank -ge (Get-StateRank 'S10_SOURCE_FROZEN')) {
        Assert-Check ([string]$source.status -eq 'FROZEN') 'S10+ has frozen sources' 'state advanced without frozen sources'
    }
    if ($stateRank -ge (Get-StateRank 'S20_EVIDENCE_READY')) {
        Assert-Check ($turns.Count -gt 0) 'S20+ has evidence turns' 'state advanced without evidence turns'
    }
    if ($stateRank -ge (Get-StateRank 'S30_SCOPE_CONFIRMED')) {
        Assert-Check ([string]$scope.status -eq 'APPROVED') 'S30+ has approved formal scope' 'state advanced without approved formal scope'
    }
    if ($stateRank -ge (Get-StateRank 'S40_PEOPLE_RIGHTS_CONFIRMED')) {
        Assert-Check ([string]$speakers.decision.status -eq 'APPROVED') 'S40+ has an approved speaker decision' 'state advanced without an approved speaker decision'
    }
    if ($stateRank -ge (Get-StateRank 'S50_LIBRARY_READY')) {
        Assert-Check ([string]$plan.library_status -in @('READY', 'COMPLETE')) 'S50+ has a ready content library' 'state advanced without a ready content library'
    }
    if ($stateRank -ge (Get-StateRank 'S60_ASSETS_PLANNED')) {
        Assert-Check (-not [string]::IsNullOrWhiteSpace([string]$plan.updated_at)) 'S60+ has an updated asset plan' 'state advanced without an updated asset plan'
    }
    $activeBranches = @($plan.branches.PSObject.Properties | Where-Object { [string]$_.Value.status -in @('SELECTED', 'BLOCKED', 'COMPLETE') })
    if ($stateRank -ge (Get-StateRank 'S70_BRANCHES_READY')) {
        Assert-Check ($activeBranches.Count -gt 0) 'S70+ has at least one active branch' 'state advanced without an active asset branch'
    }
    if ($stateRank -ge (Get-StateRank 'S80_QA_PASSED')) {
        $unfinishedBranches = @($plan.branches.PSObject.Properties | Where-Object { [string]$_.Value.status -in @('SELECTED', 'BLOCKED') })
        $completeBranches = @($plan.branches.PSObject.Properties | Where-Object { [string]$_.Value.status -eq 'COMPLETE' })
        Assert-Check ($unfinishedBranches.Count -eq 0) 'S80+ has no unfinished selected branch' 'state advanced while a selected branch is unfinished or blocked'
        Assert-Check ($completeBranches.Count -gt 0) 'S80+ has a completed branch' 'state advanced without a completed branch'
    }
    if ($stateRank -ge (Get-StateRank 'S90_RELEASE_CANDIDATE')) {
        Assert-Check ($null -ne $candidate) 'S90+ has a valid release candidate file' 'state advanced without a valid release candidate file'
    }
    if ($stateRank -ge (Get-StateRank 'S100_RELEASE_AUTHORIZED')) {
        Assert-Check ($approvedReleaseGrants.Count -gt 0) 'S100+ has an approved release grant' 'state advanced without an approved release grant'
        if ($null -ne $candidate) {
            $matchingReleaseGrant = @($approvedReleaseGrants | Where-Object {
                [string]$_.domain -eq [string]$candidate.operation -and
                [string]$_.scope.platform -eq [string]$candidate.platform -and
                [string]$_.scope.account -eq [string]$candidate.account -and
                [string]$_.scope.release_candidate_sha256 -eq [string]$candidateHash
            })
            Assert-Check ($matchingReleaseGrant.Count -eq 1) 'S100+ has exactly one grant for the current candidate' 'current candidate lacks one exact release grant'
        }
    }
}
catch {
    Add-Failure "QA runner crashed: $($_.Exception.Message)"
}

Write-Host 'Recording Skill Project QA'
Write-Host "PASS: $($passes.Count)"
Write-Host "FAIL: $($failures.Count)"

if ($failures.Count -gt 0) {
    Write-Host ''
    Write-Host 'Failures:'
    foreach ($failure in $failures) { Write-Host " - $failure" }
    exit 1
}

Write-Host 'RESULT: PASS'
exit 0
