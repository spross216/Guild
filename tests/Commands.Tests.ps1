# The deterministic commands agents use during work: context, briefs, decision records, documentation
# drift, repository surveys and standards-repository scaffolding.

BeforeAll {
    Import-Module (Join-Path $PSScriptRoot '../Guild/Guild.psd1') -Force
    # Keep a real user-scope install (~/.guild/pack.json) out of these tests.
    $env:GUILD_HOME = Join-Path $TestDrive 'home'

    function Invoke-Git {
        param([string] $Repo, [Parameter(ValueFromRemainingArguments)][string[]] $GitArgs)
        $out = & git -C $Repo -c user.name=guild-test -c user.email=guild-test@example.invalid @GitArgs 2>&1
        if ($LASTEXITCODE -ne 0) { throw "git $($GitArgs -join ' ') failed: $out" }
    }

    function New-Project {
        $root = Join-Path $TestDrive ([guid]::NewGuid().ToString('N').Substring(0, 8))
        New-Item -ItemType Directory "$root/src", "$root/docs/decisions", "$root/tests" -Force | Out-Null
        Set-Content "$root/src/Job.ps1" 'function Invoke-Job {}'
        Set-Content "$root/tests/Job.Tests.ps1" "Describe 'x' { It 'y' { } }"
        Set-Content "$root/AGENTS.md" '# Agent instructions'
        Set-Content "$root/docs/decisions/0001-start.md" '# 0001: Start'
        Set-Content "$root/README.md" @'
# App

See [the design](docs/design.md) and `src/Job.ps1`. Infrastructure is in `function-apps/<app>` in another repository.

```powershell
./scripts/not-checked-in-code.ps1
```
'@
        Set-Content "$root/docs/design.md" @'
# Design

```mermaid
flowchart LR
  A[Timer] --> B["src/Job.ps1"]
```
'@
        Invoke-Git $root init -b main --quiet
        Invoke-Git $root add -A
        Invoke-Git $root commit -m start --quiet
        $root
    }
}

AfterAll {
    Remove-Item Env:GUILD_HOME -ErrorAction SilentlyContinue
    Get-ChildItem $TestDrive -Recurse -Force -File | Where-Object IsReadOnly | ForEach-Object { $_.IsReadOnly = $false }
}

Describe 'Get-GuildContext' {
    It 'reports the project''s facts' {
        $root = New-Project
        $context = Get-GuildContext -Path $root
        $context.Languages | Should -Contain 'powershell'
        $context.Git.Branch | Should -Be 'main'
        $context.Git.Clean | Should -BeTrue
        $context.AgentsFile | Should -BeTrue
        $context.Docs | Should -Contain 'docs/design.md'
        $context.Diagrams | Should -Be @('docs/design.md:3')
        $context.Decisions.Count | Should -Be 1
        $context.Check | Should -BeNullOrEmpty
    }

    It 'uses the installed pack for standards and the check' {
        $root = New-Project
        $packDir = Join-Path $TestDrive 'ctx-pack'
        New-Item -ItemType Directory "$packDir/std" -Force | Out-Null
        Set-Content "$packDir/c.pack.psd1" "@{ Name = 'c'; Version = '1.0.0'; Contract = '1'; Knowledge = @(@{ Name = 's'; Kind = 'standards'; Path = 'std' }); Capabilities = @{ Check = @{ Command = 'Test-Thing -Path <project>' } } }"
        Install-GuildAgents -Harness generic -Scope Project -Path $root -Pack "$packDir/c.pack.psd1" -InformationAction SilentlyContinue | Out-Null
        $markdown = Get-GuildContext -Path $root -AsMarkdown
        $markdown | Should -Match 'Check: `Test-Thing -Path <project>`'
        $markdown | Should -Match 'standards: `.+/std`'
    }
}

Describe 'New-GuildBrief' {
    It 'writes the standard sections, with the high-risk requirements when asked' {
        $root = New-Project
        $brief = New-GuildBrief -Role builder -Goal 'Add a retry' -Path $root -Paths 'src/Job.ps1' -Constraints 'Keep the public signature' -Done 'A test for the retry' -HighRisk
        foreach ($section in '# Brief for guild-builder', '## Goal', '## Read first', '## Paths', '## Constraints', '## Done means', '## High risk', '## Project context') {
            $brief | Should -Match ([regex]::Escape($section))
        }
        $brief | Should -Match '- `src/Job.ps1`'
        $brief | Should -Match 'Keep the public signature'
        $brief | Should -Match "The author's tests don't count"
    }
}

Describe 'New-GuildDecision' {
    It 'creates the next numbered record and never overwrites' {
        $root = New-Project
        $path = New-GuildDecision -Path $root -Title 'Use a queue between the webhook and the job'
        Split-Path $path -Leaf | Should -Be '0002-use-a-queue-between-the-webhook-and-the-job.md'
        Get-Content $path -Raw | Should -Match '# 0002: Use a queue between the webhook and the job[\s\S]*## Context[\s\S]*## Consequences'
        (New-GuildDecision -Path $root -Title 'Another') | Split-Path -Leaf | Should -Be '0003-another.md'
    }

    It 'creates docs/decisions when the project has no decision folder, and honors -WhatIf' {
        $root = Join-Path $TestDrive 'nodecisions'
        New-Item -ItemType Directory $root | Out-Null
        $path = New-GuildDecision -Path $root -Title 'First' -WhatIf
        $path | Should -Match '0001-first\.md$' -Because 'the planned path is returned'
        Join-Path $root 'docs' | Should -Not -Exist
        New-GuildDecision -Path $root -Title 'First' | Split-Path -Leaf | Should -Be '0001-first.md'
    }
}

Describe 'Test-GuildDocs' {
    It 'finds nothing in a consistent project' {
        $root = New-Project
        Test-GuildDocs -Path $root -InformationAction SilentlyContinue | Should -BeNullOrEmpty
    }

    It 'finds broken links and missing paths for the steward, ignoring other repositories and code blocks' {
        $root = New-Project
        Add-Content "$root/README.md" "`nAlso [the runbook](docs/runbook.md) and ``src/Missing.ps1``."
        $findings = Test-GuildDocs -Path $root -InformationAction SilentlyContinue
        $findings | Where-Object Kind -EQ 'BrokenLink' | ForEach-Object Detail | Should -Match 'docs/runbook.md'
        $findings | Where-Object Kind -EQ 'MissingPath' | ForEach-Object Detail | Should -Match 'src/Missing.ps1'
        @($findings | Where-Object Owner -NE 'steward') | Should -BeNullOrEmpty
        $findings.Detail | Should -Not -Match 'function-apps|not-checked-in'
    }

    It 'finds diagram problems for the architect' {
        $root = New-Project
        Set-Content "$root/docs/design.md" "# Design`n`n``````mermaid`nflowhcart LR`n  A[Timer --> B[""src/Gone.ps1""]`n``````"
        $findings = Test-GuildDocs -Path $root -Owner architect -InformationAction SilentlyContinue
        $findings.Kind | Should -Contain 'MermaidSyntax'
        $findings.Kind | Should -Contain 'MermaidReference'
        ($findings | Where-Object Kind -EQ 'MermaidSyntax').Detail -join ' ' | Should -Match "flowhcart.*|Unbalanced \[\]"
    }

    It 'flags documents whose referenced files changed after them' {
        $root = New-Project
        Start-Sleep -Seconds 1
        Add-Content "$root/src/Job.ps1" '# changed'
        Invoke-Git $root commit -am change --quiet
        $findings = Test-GuildDocs -Path $root -InformationAction SilentlyContinue
        ($findings | Where-Object { $_.Kind -eq 'PossiblyStale' -and $_.File -eq 'README.md' }).Detail | Should -Match 'src/Job.ps1'
        ($findings | Where-Object { $_.Kind -eq 'MermaidStale' -and $_.File -eq 'docs/design.md' }).Owner | Should -Be 'architect'
    }
}

Describe 'Get-GuildRepoSurvey' {
    It 'reports facts about a repository' {
        $root = New-Project
        New-Item -ItemType Directory "$root/.github/workflows" -Force | Out-Null
        Set-Content "$root/.github/workflows/ci.yml" "name: CI`non:`n  push:`n  pull_request:`npermissions:`n  contents: read`njobs:`n  build:`n    environment: dev`n    steps:`n      - uses: actions/checkout@v4`n      - uses: azure/login@v2`n        with:`n          client-id: x"
        Set-Content "$root/main.tf" 'provider "azurerm" {}'
        Set-Content "$root/PSScriptAnalyzerSettings.psd1" '@{}'
        $survey = Get-GuildRepoSurvey -Path $root
        $survey.Languages.powershell | Should -BeGreaterThan 0
        $survey.Tests.Pester | Should -Be 1
        $survey.Linting | Should -Contain 'PSScriptAnalyzerSettings.psd1'
        $survey.CI[0].Name | Should -Be 'CI'
        $survey.CI[0].Triggers | Should -Be @('pull_request', 'push')
        $survey.CI[0].Environments | Should -Be @('dev')
        $survey.CI[0].OidcLogin | Should -BeTrue
        $survey.Infrastructure.TerraformProviders | Should -Be @('azurerm')
        $survey.Docs.DecisionRecords | Should -Be 1
        $survey.Docs.MermaidDiagrams | Should -Be 1
        $survey.AgentFiles | Should -Contain 'AGENTS.md'
        (Get-GuildRepoSurvey -Path $root -AsJson | ConvertFrom-Json).Repository | Should -Be (Split-Path $root -Leaf)
    }
}

Describe 'New-GuildStandardsRepo' {
    It 'scaffolds a standards repository whose pack validates and excludes drafts' {
        $parent = Join-Path $TestDrive 'repos'
        New-Item -ItemType Directory $parent | Out-Null
        $result = New-GuildStandardsRepo -Path $parent -Name 'platform-standards' -Prefix 'plat' -Description 'Platform team engineering standards' -InformationAction SilentlyContinue
        $result.GitInitialized | Should -BeTrue
        foreach ($file in 'README.md', 'AGENTS.md', 'standards/README.md', 'drafts/README.md', 'decisions/0001-create-this-standards-repository.md', 'docs/provenance.md', 'evidence/README.md', 'guild/platform-standards.pack.psd1', 'tests/Consistency.Tests.ps1', 'build.ps1') {
            Join-Path $result.Path $file | Should -Exist
        }
        $pack = Get-GuildPack -Pack $result.Pack
        $pack.Prefix | Should -Be 'plat'
        @($pack.Knowledge | Where-Object { $_.Path -match 'drafts' }) | Should -BeNullOrEmpty
        Get-ChildItem $result.Path -Recurse -File | Select-String -Pattern '__(Name|Prefix|Description|Date)__' | Should -BeNullOrEmpty
    }

    It 'refuses a directory that is not empty, and writes nothing with -WhatIf' {
        $parent = Join-Path $TestDrive 'busy'
        New-Item -ItemType Directory "$parent/taken" -Force | Out-Null
        Set-Content "$parent/taken/x.txt" 'x'
        { New-GuildStandardsRepo -Path $parent -Name 'taken' -Prefix 'tk' -Description 'Taken already' } | Should -Throw '*not empty*'
        New-GuildStandardsRepo -Path $parent -Name 'planned' -Prefix 'pl' -Description 'Planned only' -WhatIf | Out-Null
        Join-Path $parent 'planned' | Should -Not -Exist
    }
}
