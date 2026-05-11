param (
    [switch]$Global,
    [string]$Project,
    [switch]$Force,
    [ValidateSet("core", "design", "review", "deploy", "full")]
    [string]$GstackProfile = "core"
)

$RepoRoot = $PSScriptRoot
$CoreAgents = Join-Path $RepoRoot "core\AGENTS.md"
$SkillsDir = Join-Path $RepoRoot "skills"
$ManagedGstackInstaller = Join-Path $RepoRoot "scripts\install-managed-gstack.sh"

# Skills that rely on "staying in current conversation" and are incompatible
# with Codex App's architecture (each skill invocation = new task context).
# These skills work via AGENTS.md rule-level recognition instead.
$CodexExcludedSkills = @("btw", "loop")
$ManagedOfficialSkills = @("gstack")
$OfficialGstackInstalled = $false
$GstackBootstrapInstalled = $false
$CoreExposedGstackSkills = @(
    "gstack",
    "gstack-office-hours",
    "gstack-plan-ceo-review",
    "gstack-plan-design-review",
    "gstack-plan-eng-review",
    "gstack-design-review",
    "gstack-review",
    "gstack-investigate",
    "gstack-browse",
    "gstack-qa",
    "gstack-ship"
)

function Backup-IfExists {
    param ([string]$FilePath)
    if (Test-Path $FilePath) {
        $BackupPath = "$FilePath.bak"
        Copy-Item $FilePath $BackupPath -Force
        Write-Host "    Backed up existing: $FilePath -> $BackupPath" -ForegroundColor Yellow
    }
}

function Test-AnyPath {
    param ([string[]]$Candidates)
    foreach ($candidate in $Candidates) {
        if (Test-Path $candidate) {
            return $true
        }
    }
    return $false
}

function Add-MissingSkillIfAbsent {
    param (
        [System.Collections.Generic.List[string]]$Missing,
        [string]$Label,
        [string[]]$Candidates
    )

    if (-not (Test-AnyPath $Candidates)) {
        $Missing.Add($Label)
    }
}

function Assert-ManagedGstackInstall {
    param ([switch]$AllowArchiveInstall)

    $missing = New-Object System.Collections.Generic.List[string]

    $gstackRepoDir = Join-Path $HOME ".gstack\repos\gstack"
    $hasGitCheckout = Test-Path (Join-Path $gstackRepoDir ".git")
    $hasArchiveCheckout = (Test-Path (Join-Path $gstackRepoDir "VERSION")) -and (Test-Path (Join-Path $gstackRepoDir "package.json"))

    if (-not $hasGitCheckout -and -not ($AllowArchiveInstall -and $hasArchiveCheckout)) {
        $missing.Add("official gstack repo (~/.gstack/repos/gstack)")
    }

    Add-MissingSkillIfAbsent $missing "Claude runtime (~/.claude/skills/gstack)" @(
        (Join-Path $HOME ".claude\skills\gstack\SKILL.md"),
        (Join-Path $HOME ".claude\skills\gstack")
    )
    Add-MissingSkillIfAbsent $missing "Claude office-hours skill (~/.claude/skills/gstack-office-hours or office-hours)" @(
        (Join-Path $HOME ".claude\skills\gstack-office-hours\SKILL.md"),
        (Join-Path $HOME ".claude\skills\office-hours\SKILL.md")
    )
    Add-MissingSkillIfAbsent $missing "Claude investigate skill (~/.claude/skills/gstack-investigate or investigate)" @(
        (Join-Path $HOME ".claude\skills\gstack-investigate\SKILL.md"),
        (Join-Path $HOME ".claude\skills\investigate\SKILL.md")
    )
    Add-MissingSkillIfAbsent $missing "Claude plan-eng-review skill (~/.claude/skills/gstack-plan-eng-review or plan-eng-review)" @(
        (Join-Path $HOME ".claude\skills\gstack-plan-eng-review\SKILL.md"),
        (Join-Path $HOME ".claude\skills\plan-eng-review\SKILL.md")
    )
    Add-MissingSkillIfAbsent $missing "Claude plan-ceo-review skill (~/.claude/skills/gstack-plan-ceo-review or plan-ceo-review)" @(
        (Join-Path $HOME ".claude\skills\gstack-plan-ceo-review\SKILL.md"),
        (Join-Path $HOME ".claude\skills\plan-ceo-review\SKILL.md")
    )
    Add-MissingSkillIfAbsent $missing "Claude plan-design-review skill (~/.claude/skills/gstack-plan-design-review or plan-design-review)" @(
        (Join-Path $HOME ".claude\skills\gstack-plan-design-review\SKILL.md"),
        (Join-Path $HOME ".claude\skills\plan-design-review\SKILL.md")
    )
    Add-MissingSkillIfAbsent $missing "Claude design-review skill (~/.claude/skills/gstack-design-review or design-review)" @(
        (Join-Path $HOME ".claude\skills\gstack-design-review\SKILL.md"),
        (Join-Path $HOME ".claude\skills\design-review\SKILL.md")
    )
    Add-MissingSkillIfAbsent $missing "Claude qa skill (~/.claude/skills/gstack-qa or qa)" @(
        (Join-Path $HOME ".claude\skills\gstack-qa\SKILL.md"),
        (Join-Path $HOME ".claude\skills\qa\SKILL.md")
    )
    Add-MissingSkillIfAbsent $missing "Claude review skill (~/.claude/skills/gstack-review or review)" @(
        (Join-Path $HOME ".claude\skills\gstack-review\SKILL.md"),
        (Join-Path $HOME ".claude\skills\review\SKILL.md")
    )
    Add-MissingSkillIfAbsent $missing "Claude ship skill (~/.claude/skills/gstack-ship or ship)" @(
        (Join-Path $HOME ".claude\skills\gstack-ship\SKILL.md"),
        (Join-Path $HOME ".claude\skills\ship\SKILL.md")
    )

    Add-MissingSkillIfAbsent $missing "Codex gstack runtime (~/.codex/skills/gstack/SKILL.md)" @(
        (Join-Path $HOME ".codex\skills\gstack\SKILL.md")
    )
    Add-MissingSkillIfAbsent $missing "Codex office-hours skill (~/.codex/skills/gstack-office-hours/SKILL.md)" @(
        (Join-Path $HOME ".codex\skills\gstack-office-hours\SKILL.md")
    )
    Add-MissingSkillIfAbsent $missing "Codex investigate skill (~/.codex/skills/gstack-investigate/SKILL.md)" @(
        (Join-Path $HOME ".codex\skills\gstack-investigate\SKILL.md")
    )
    Add-MissingSkillIfAbsent $missing "Codex plan-eng-review skill (~/.codex/skills/gstack-plan-eng-review/SKILL.md)" @(
        (Join-Path $HOME ".codex\skills\gstack-plan-eng-review\SKILL.md")
    )
    Add-MissingSkillIfAbsent $missing "Codex plan-ceo-review skill (~/.codex/skills/gstack-plan-ceo-review/SKILL.md)" @(
        (Join-Path $HOME ".codex\skills\gstack-plan-ceo-review\SKILL.md")
    )
    Add-MissingSkillIfAbsent $missing "Codex plan-design-review skill (~/.codex/skills/gstack-plan-design-review/SKILL.md)" @(
        (Join-Path $HOME ".codex\skills\gstack-plan-design-review\SKILL.md")
    )
    Add-MissingSkillIfAbsent $missing "Codex design-review skill (~/.codex/skills/gstack-design-review/SKILL.md)" @(
        (Join-Path $HOME ".codex\skills\gstack-design-review\SKILL.md")
    )
    Add-MissingSkillIfAbsent $missing "Codex browse skill (~/.codex/skills/gstack-browse/SKILL.md)" @(
        (Join-Path $HOME ".codex\skills\gstack-browse\SKILL.md")
    )
    Add-MissingSkillIfAbsent $missing "Codex qa skill (~/.codex/skills/gstack-qa/SKILL.md)" @(
        (Join-Path $HOME ".codex\skills\gstack-qa\SKILL.md")
    )
    Add-MissingSkillIfAbsent $missing "Codex review skill (~/.codex/skills/gstack-review/SKILL.md)" @(
        (Join-Path $HOME ".codex\skills\gstack-review\SKILL.md")
    )
    Add-MissingSkillIfAbsent $missing "Codex ship skill (~/.codex/skills/gstack-ship/SKILL.md)" @(
        (Join-Path $HOME ".codex\skills\gstack-ship\SKILL.md")
    )

    if ($missing.Count -gt 0) {
        $message = @(
            "Official gstack install is incomplete. Missing:"
            ($missing | ForEach-Object { "  - $_" })
            "Lotus global rules live in AGENTS/CLAUDE files, but slash skills must exist in each host's global skills directory."
        ) -join "`n"
        throw $message
    }
}

function Confirm-GlobalRuleOverwrite {
    param ([string[]]$Targets)

    $existing = @($Targets | Where-Object { Test-Path $_ })
    if ($existing.Count -eq 0) {
        return
    }

    if ($Force -or $env:LOTUS_ASSUME_YES -eq "1") {
        Write-Host "  Overwrite confirmation skipped (-Force / LOTUS_ASSUME_YES=1)." -ForegroundColor Yellow
        return
    }

    if (-not [Environment]::UserInteractive) {
        throw "Existing global rule/config files would be overwritten, but no interactive confirmation is available. Re-run with -Force or LOTUS_ASSUME_YES=1."
    }

    Write-Host "Existing global rule/config files detected. Lotus will back them up to .bak and then overwrite them:" -ForegroundColor Yellow
    $existing | ForEach-Object { Write-Host "  - $_" -ForegroundColor Yellow }
    $answer = Read-Host "Continue and overwrite these global files? [y/N]"
    if ($answer -notmatch '^(?i:y(?:es)?)$') {
        throw "Cancelled. No global rules were overwritten."
    }
}

function Copy-LotusSkills {
    param (
        [string]$TargetDir,
        [string[]]$ExcludedSkills = @()
    )

    if (-not (Test-Path $TargetDir)) {
        New-Item -ItemType Directory -Path $TargetDir -Force | Out-Null
    }

    Get-ChildItem (Join-Path $SkillsDir "*.md") | ForEach-Object {
        $baseName = [System.IO.Path]::GetFileNameWithoutExtension($_.Name)
        if ($ExcludedSkills -notcontains $baseName) {
            Copy-Item $_.FullName $TargetDir -Force
        }
    }
}

function Convert-ToCodexSkill {
    param (
        [string]$SourceFile,
        [string]$TargetDir
    )

    $content = Get-Content $SourceFile -Raw -Encoding UTF8

    $skillName = ""
    $description = ""
    if ($content -match '(?s)^---\r?\n(.*?)\r?\n---') {
        $frontmatter = $Matches[1]
        if ($frontmatter -match 'name:\s*(.+)') {
            $skillName = $Matches[1].Trim()
        }
        if ($frontmatter -match 'description:\s*(.+)') {
            $description = $Matches[1].Trim()
        }
    }

    if (-not $skillName) {
        $skillName = [System.IO.Path]::GetFileNameWithoutExtension($SourceFile)
    }
    if (-not $description) {
        $description = "Lotus skill: $skillName"
    }

    $allowedTools = switch ($skillName) {
        "auto-build" { "Bash, Read" }
        "btw" { "Read, AskUserQuestion" }
        "feynman" { "Read, AskUserQuestion" }
        "polanyi-tacit" { "Read, AskUserQuestion" }
        "powerup" { "Read, AskUserQuestion" }
        "insights" { "Read, Bash, Grep, Glob" }
        "image-2" { "Read, Write, Edit, Grep, Glob, Bash, AskUserQuestion" }
        "loop" { "Bash, Read, AskUserQuestion" }
        "agent-training-loop" { "Read, Write, Edit, Grep, Glob, Bash, AskUserQuestion" }
        "baseline-packager" { "Read, Write, Edit, Grep, Glob, Bash, AskUserQuestion" }
        "conversion-copywriter" { "Read, AskUserQuestion" }
        "subagent" { "Bash, Read, Write, Edit, Grep, Glob, AskUserQuestion" }
        "web-to-design-md" { "Read, Write, Edit, Grep, Glob, AskUserQuestion, WebSearch" }
        "taste-skill" { "Read, Write, Edit, Grep, Glob, Bash, AskUserQuestion" }
        "gstack" { "Bash, Read, Write, Edit, Grep, Glob, AskUserQuestion" }
        default { "Read, AskUserQuestion" }
    }

    $body = $content -replace '(?s)^---\r?\n.*?\r?\n---\r?\n?', ''

    $codexFrontmatter = @"
---
name: $skillName
description: |
  $description
allowed-tools:
$(($allowedTools -split ', ' | ForEach-Object { "  - $_" }) -join "`n")
---
"@

    $codexContent = "$codexFrontmatter`n$body"

    $skillDir = Join-Path $TargetDir $skillName
    if (-not (Test-Path $skillDir)) {
        New-Item -ItemType Directory -Path $skillDir -Force | Out-Null
    }

    $utf8NoBom = New-Object System.Text.UTF8Encoding $false
    [System.IO.File]::WriteAllText((Join-Path $skillDir "SKILL.md"), $codexContent, $utf8NoBom)
}

function Get-ClaudeGstackSkillName {
    param ([string]$SkillName)

    if ($SkillName -eq "gstack") {
        return "gstack"
    }

    return ($SkillName -replace '^gstack-', '')
}

function Copy-DirectoryClean {
    param (
        [string]$Source,
        [string]$Destination
    )

    if (Test-Path $Destination) {
        Remove-Item $Destination -Recurse -Force
    }
    New-Item -ItemType Directory -Path ([System.IO.Path]::GetDirectoryName($Destination)) -Force | Out-Null
    Copy-Item $Source $Destination -Recurse -Force
}

function Sync-GstackSkillsFromGeneratedDocs {
    param (
        [string]$GstackDir,
        [string]$ClaudeSkills,
        [string]$CodexSkills
    )

    $agentsSkills = Join-Path $GstackDir ".agents\skills"
    if (-not (Test-Path $agentsSkills)) {
        throw "Generated gstack skills not found at $agentsSkills."
    }

    New-Item -ItemType Directory -Path $ClaudeSkills -Force | Out-Null
    New-Item -ItemType Directory -Path $CodexSkills -Force | Out-Null

    foreach ($skillName in $CoreExposedGstackSkills) {
        $sourceSkillDir = Join-Path $agentsSkills $skillName
        $sourceSkillFile = Join-Path $sourceSkillDir "SKILL.md"
        if (-not (Test-Path $sourceSkillFile)) {
            throw "Expected generated gstack skill is missing: $sourceSkillFile"
        }

        $codexTarget = Join-Path $CodexSkills $skillName
        Copy-DirectoryClean -Source $sourceSkillDir -Destination $codexTarget

        $claudeSkillName = Get-ClaudeGstackSkillName $skillName
        $claudeTarget = Join-Path $ClaudeSkills $claudeSkillName
        New-Item -ItemType Directory -Path $claudeTarget -Force | Out-Null
        Copy-Item $sourceSkillFile (Join-Path $claudeTarget "SKILL.md") -Force
    }

    Write-Host "  Synced official gstack top-level skills without Git/Bash"
}

function New-GstackBootstrapSkillContent {
    param (
        [string]$SkillName,
        [string]$DisplayName
    )

    return @"
---
name: $SkillName
description: |
  Bootstrap entry for official gstack $DisplayName. Lotus installed this fallback because Git or Git Bash was not available during global setup.
allowed-tools:
  - Read
  - AskUserQuestion
---

# Official gstack bootstrap

This is a real top-level skill entry, installed so `/gstack-*` commands do not disappear on machines without Git or Git Bash.

The full official gstack runtime is not installed yet. To enable this skill's full workflow:

1. Install Git for Windows: https://git-scm.com/download/win
2. Open a fresh PowerShell.
3. Re-run:

```powershell
install.ps1 -Global
```

If you are running from outside the Lotus repo, use the full path to `install.ps1`.
"@
}

function Test-IsGstackBootstrapSkillFile {
    param ([string]$SkillFile)

    if (-not (Test-Path $SkillFile)) {
        return $false
    }

    $content = Get-Content $SkillFile -Raw -ErrorAction SilentlyContinue
    return $content -like "*Bootstrap entry for official gstack*"
}

function Write-GstackBootstrapSkillIfNeeded {
    param (
        [string]$TargetDir,
        [string]$SkillName,
        [string]$DisplayName,
        [System.Text.UTF8Encoding]$Encoding,
        [switch]$OnlyMissing
    )

    $skillFile = Join-Path $TargetDir "SKILL.md"
    if (Test-Path $skillFile) {
        if (-not (Test-IsGstackBootstrapSkillFile -SkillFile $skillFile)) {
            return $false
        }
        if ($OnlyMissing) {
            return $false
        }
    }

    New-Item -ItemType Directory -Path $TargetDir -Force | Out-Null
    [System.IO.File]::WriteAllText(
        $skillFile,
        (New-GstackBootstrapSkillContent -SkillName $SkillName -DisplayName $DisplayName),
        $Encoding
    )

    return $true
}

function Install-GstackBootstrapSkills {
    param (
        [string]$ClaudeSkills,
        [string]$CodexSkills,
        [switch]$OnlyMissing
    )

    $utf8NoBom = New-Object System.Text.UTF8Encoding $false
    New-Item -ItemType Directory -Path $ClaudeSkills, $CodexSkills -Force | Out-Null
    $written = 0
    $preserved = 0

    foreach ($skillName in $CoreExposedGstackSkills) {
        $displayName = if ($skillName -eq "gstack") { "runtime" } else { ($skillName -replace '^gstack-', '') }

        $codexTarget = Join-Path $CodexSkills $skillName
        if (Write-GstackBootstrapSkillIfNeeded -TargetDir $codexTarget -SkillName $skillName -DisplayName $displayName -Encoding $utf8NoBom -OnlyMissing:$OnlyMissing) {
            $written++
        } else {
            $preserved++
        }

        $claudeSkillName = Get-ClaudeGstackSkillName $skillName
        $claudeTarget = Join-Path $ClaudeSkills $claudeSkillName
        if (Write-GstackBootstrapSkillIfNeeded -TargetDir $claudeTarget -SkillName $claudeSkillName -DisplayName $displayName -Encoding $utf8NoBom -OnlyMissing:$OnlyMissing) {
            $written++
        } else {
            $preserved++
        }
    }

    Write-Host "  Installed bootstrap entries for the 11 official gstack top-level skills ($written written, $preserved preserved)"
}

if ($Global) {
    Write-Host "Installing Global Rules & Skills..." -ForegroundColor Cyan

    $ClaudeRuleFile = Join-Path $HOME ".claude\CLAUDE.md"
    $CodexRuleFile = Join-Path $HOME ".codex\AGENTS.md"

    Confirm-GlobalRuleOverwrite @(
        $ClaudeRuleFile,
        $CodexRuleFile
    )

    $ClaudeDir = Join-Path $HOME ".claude"
    if (-not (Test-Path $ClaudeDir)) { New-Item -ItemType Directory -Path $ClaudeDir -Force | Out-Null }
    Backup-IfExists $ClaudeRuleFile
    Copy-Item $CoreAgents $ClaudeRuleFile -Force

    $ClaudeSkills = Join-Path $ClaudeDir "skills"
    if (-not (Test-Path $ClaudeSkills)) { New-Item -ItemType Directory -Path $ClaudeSkills -Force | Out-Null }
    Copy-LotusSkills -TargetDir $ClaudeSkills -ExcludedSkills $ManagedOfficialSkills
    Write-Host "  Claude Code configured"

    $CodexDir = Join-Path $HOME ".codex"
    if (-not (Test-Path $CodexDir)) { New-Item -ItemType Directory -Path $CodexDir -Force | Out-Null }
    Backup-IfExists $CodexRuleFile
    Copy-Item $CoreAgents $CodexRuleFile -Force

    $CodexSkills = Join-Path $CodexDir "skills"
    if (-not (Test-Path $CodexSkills)) { New-Item -ItemType Directory -Path $CodexSkills -Force | Out-Null }

    foreach ($excluded in $CodexExcludedSkills) {
        $excludedDir = Join-Path $CodexSkills $excluded
        if (Test-Path $excludedDir) {
            Remove-Item $excludedDir -Recurse -Force
            Write-Host "    Removed incompatible skill: $excluded"
        }
    }

    Get-ChildItem (Join-Path $SkillsDir "*.md") | ForEach-Object {
        $baseName = [System.IO.Path]::GetFileNameWithoutExtension($_.Name)
        if (($CodexExcludedSkills + $ManagedOfficialSkills) -contains $baseName) {
            Write-Host "    Skipped (managed elsewhere or in-context only): $baseName"
        } else {
            Convert-ToCodexSkill -SourceFile $_.FullName -TargetDir $CodexSkills
            Write-Host "    Converted skill: $baseName"
        }
    }
    Write-Host "  Codex CLI configured (rules + Lotus-only compatible skills)"

    Write-Host "  Installing official gstack upstream..."
    if (-not (Get-Command bash -ErrorAction SilentlyContinue)) {
        Write-Warning "Git Bash was not found. Installing bootstrap entries for the official gstack top-level skills."
        Install-GstackBootstrapSkills -ClaudeSkills $ClaudeSkills -CodexSkills $CodexSkills
        $GstackBootstrapInstalled = $true
    } else {
        $BashManagedGstackInstaller = $ManagedGstackInstaller -replace '\\', '/'

        $previousGstackProfile = $env:LOTUS_GSTACK_PROFILE
        $env:LOTUS_GSTACK_PROFILE = $GstackProfile
        try {
            & bash $BashManagedGstackInstaller
            if ($LASTEXITCODE -ne 0) {
                throw "Official gstack installation failed. Lotus rules were written, but slash skills were not fully installed."
            }

            Assert-ManagedGstackInstall
            $OfficialGstackInstalled = $true
            Write-Host "  Official gstack configured for Claude/Codex"
        }
        catch {
            Write-Warning $_
            Write-Warning "Installing bootstrap entries so the default gstack slash skills remain visible."
            Install-GstackBootstrapSkills -ClaudeSkills $ClaudeSkills -CodexSkills $CodexSkills -OnlyMissing
            $GstackBootstrapInstalled = $true
        }
        finally {
            if ($null -ne $previousGstackProfile) {
                $env:LOTUS_GSTACK_PROFILE = $previousGstackProfile
            } else {
                Remove-Item Env:LOTUS_GSTACK_PROFILE -ErrorAction SilentlyContinue
            }
        }
    }

    Write-Host ""
    Write-Host "Global installation completed successfully!" -ForegroundColor Green
    Write-Host "If any existing configs were overwritten, .bak backups have been created." -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Codex note:" -ForegroundColor Cyan
    Write-Host "  - Global rules were installed to $CodexDir\AGENTS.md and are auto-loaded in local repos."
    Write-Host "  - `-Global` does not create `AGENTS.md` inside each project folder."
    Write-Host "  - Run `.\install.ps1 -Project nextjs|vite|html` inside a project when you want local `AGENTS.md` and `.agents/rules/` files."
    if ($OfficialGstackInstalled) {
        Write-Host "  - Official gstack is managed at $HOME\.gstack\repos\gstack and kept auto-updatable."
    } elseif ($GstackBootstrapInstalled) {
        Write-Host "  - The 11 official gstack top-level skill entries were installed as bootstrap skills."
        Write-Host "  - Install Git for Windows, then re-run install.ps1 -Global to install the full official gstack runtime."
    }
    Write-Host "  - Official gstack top-level exposure profile: $GstackProfile"
    Write-Host "  - Hidden official gstack skills stay in ~/.gstack/repos/gstack/.agents/skills and can still be routed by AGENTS.md."
    Write-Host "  - Slash skills live in the managed global skills folders ~/.claude/skills and ~/.codex/skills."
}

if ($Project) {
    Write-Host "Installing Project Template: $Project..." -ForegroundColor Cyan
    $TemplateDir = Join-Path $RepoRoot "templates\$Project"

    if (-not (Test-Path $TemplateDir)) {
        Write-Error "Template '$Project' not found in templates directory."
        exit 1
    }

    Copy-Item (Join-Path $TemplateDir "*") (Get-Location) -Recurse -Force

    $ConventionsFile = Join-Path $RepoRoot "core\CONVENTIONS.md"
    if (Test-Path $ConventionsFile) {
        Copy-Item $ConventionsFile (Get-Location) -Force
    }

    Write-Host "Project template '$Project' applied to current directory." -ForegroundColor Green
    Write-Host "Remember to adjust the design system and tech stack files in `.agents/rules/`." -ForegroundColor Yellow
}

if (-not $Global -and -not $Project) {
    Write-Host "Lotus Installer" -ForegroundColor Cyan
    Write-Host "--------------------"
    Write-Host "Usage:"
    Write-Host "  .\install.ps1 -Global                                  (Install global rules to the managed Claude/Codex folders)"
    Write-Host "  .\install.ps1 -Global -GstackProfile core              (Default curated official gstack top-level set)"
    Write-Host "  .\install.ps1 -Global -GstackProfile full              (Expose the full official gstack top-level set)"
    Write-Host "  .\install.ps1 -Global -Force                           (Overwrite existing global configs without prompting)"
    Write-Host "  .\install.ps1 -Project <name>                          (Apply template to current directory)"
    Write-Host ""
    Write-Host "Available gstack profiles: core, design, review, deploy, full"
    Write-Host "Available templates: nextjs, vite, html"
}
