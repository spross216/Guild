function Get-GuildRepoSurvey {
    <#
    .SYNOPSIS
        A factual inventory of a repository, as evidence for design or for synthesizing standards.
    .DESCRIPTION
        Read-only and offline. Reports what is there, never what should be: languages by file count,
        build entry points, test frameworks, linter and formatter configuration, CI workflows and the
        actions and reusable workflows they use, infrastructure as code, documentation, agent
        instruction files, and Function App markers. File contents are only searched for these facts;
        nothing from them is copied into the survey, so it carries no secrets or data.

        Run it over several repositories and compare: a practice found in two or three of them is a
        candidate standard; one found once is a project convention.
    .EXAMPLE
        Get-GuildRepoSurvey -Path C:\repos\outage-report
    .EXAMPLE
        'C:\repos\a', 'C:\repos\b' | ForEach-Object { Get-GuildRepoSurvey -Path $_ -AsJson } | Set-Content surveys.jsonl
    #>
    [CmdletBinding()]
    param(
        [Parameter(ValueFromPipeline)][string] $Path = (Get-Location).Path,
        [switch] $AsJson
    )
    process {
        $root = Get-GuildScopeRoot -Scope Project -Path $Path
        $files = @(Get-ChildItem -LiteralPath $root -Recurse -File -Force -ErrorAction SilentlyContinue |
                Where-Object { (Get-GuildRelative $root $_.FullName) -notmatch '(^|[\\/])(\.git|node_modules|\.venv|venv|bin|obj|dist|build|TestResults|\.guild)([\\/]|$)' })
        $relative = @($files | ForEach-Object { Get-GuildRelative $root $_.FullName })
        $has = { param($Pattern) @($relative | Where-Object { $_ -match $Pattern }) }
        $contains = { param($Pattern, $Text) [bool](@($files | Where-Object { $_.Name -match $Pattern -and $_.Length -lt 1MB } | Where-Object { Select-String -LiteralPath $_.FullName -Pattern $Text -Quiet -ErrorAction SilentlyContinue })) }

        $languages = [ordered]@{}
        foreach ($group in $files | Where-Object { $script:GuildLanguageExtensions[$_.Extension.ToLowerInvariant()] } | Group-Object { $script:GuildLanguageExtensions[$_.Extension.ToLowerInvariant()] } | Sort-Object Count -Descending) {
            $languages[$group.Name] = $group.Count
        }

        $workflows = foreach ($workflow in $files | Where-Object { (Get-GuildRelative $root $_.FullName) -match '^\.github/workflows/[^/]+\.ya?ml$' }) {
            $text = [System.IO.File]::ReadAllText($workflow.FullName)
            [pscustomobject]@{
                File        = $workflow.Name
                Name        = if ($text -match '(?m)^name:\s*(?<n>.+)$') { $Matches.n.Trim().Trim('"', "'") } else { $null }
                Triggers    = @([regex]::Matches(($text -split '(?m)^jobs:')[0], '(?m)^\s{2}(?<t>push|pull_request|workflow_dispatch|workflow_call|repository_dispatch|schedule|release):') | ForEach-Object { $_.Groups['t'].Value } | Sort-Object -Unique)
                Permissions = $text -match '(?m)^permissions:'
                Environments = @([regex]::Matches($text, '(?m)^\s+environment:\s*(?<e>[\w-]+)') | ForEach-Object { $_.Groups['e'].Value } | Sort-Object -Unique)
                Uses        = @([regex]::Matches($text, 'uses:\s*(?<u>[^\s@#]+)') | ForEach-Object { $_.Groups['u'].Value } | Sort-Object -Unique)
                OidcLogin   = $text -match 'azure/login@' -and $text -match 'client-id:'
                StoredCreds = $text -match 'azure/login@' -and $text -match '\bcreds:'
            }
        }

        $terraformProviders = @(foreach ($tf in $files | Where-Object Extension -EQ '.tf') {
                [regex]::Matches([System.IO.File]::ReadAllText($tf.FullName), 'provider\s+"(?<p>[\w-]+)"') | ForEach-Object { $_.Groups['p'].Value }
            }) | Sort-Object -Unique

        $survey = [pscustomobject]@{
            Repository    = Split-Path $root -Leaf
            SurveyedAt    = [DateTime]::UtcNow.ToString('o')
            Remote        = $(if (Get-Command git -ErrorAction SilentlyContinue) { $remote = git -C $root remote get-url origin 2>$null; if ($LASTEXITCODE -eq 0) { $remote } })
            Head          = $(if (Get-Command git -ErrorAction SilentlyContinue) { $head = git -C $root rev-parse --short HEAD 2>$null; if ($LASTEXITCODE -eq 0) { $head } })
            Languages     = [pscustomobject]$languages
            Build         = [pscustomobject]@{
                EntryPoints = @(& $has '^(scripts/Invoke-Build\.ps1|build\.ps1|Makefile|package\.json|pyproject\.toml|[^/]+\.sln|[^/]+\.csproj)$')
            }
            Tests         = [pscustomobject]@{
                Pester    = @(& $has '\.Tests\.ps1$').Count
                Pytest    = @(& $has '(^|/)(test_[^/]+|[^/]+_test)\.py$|(^|/)conftest\.py$').Count
                JavaScript = @(& $has '\.(test|spec)\.[jt]sx?$').Count
                DotNet    = @(& $has '\.Tests?\.csproj$').Count
                CoverageGate = (& $contains '^(Invoke-Build\.ps1|PesterConfiguration\.psd1|pyproject\.toml|package\.json)$' '(?i)coverage.*(threshold|percent|fail_under|minimum)')
            }
            Linting       = @(& $has '(^|/)(PSScriptAnalyzerSettings\.psd1|\.eslintrc[^/]*|eslint\.config\.[cm]?js|ruff\.toml|\.flake8|\.editorconfig|\.prettierrc[^/]*|bicepconfig\.json)$')
            CI            = @($workflows)
            Infrastructure = [pscustomobject]@{
                Bicep              = @(& $has '\.bicep$').Count
                BicepParams        = @(& $has '\.bicepparam$').Count
                Terraform          = @(& $has '\.tf$').Count
                TerraformProviders = @($terraformProviders)
                ArmTemplates       = @(& $has '(^|/)azuredeploy[^/]*\.json$').Count
            }
            FunctionApp   = [pscustomobject]@{
                HostJson      = @(& $has '(^|/)host\.json$').Count -gt 0
                Functions     = @(& $has '(^|/)function\.json$').Count
                LocalSettingsIgnored = (Test-Path -LiteralPath (Join-Path $root '.gitignore')) -and [bool](Select-String -LiteralPath (Join-Path $root '.gitignore') -Pattern 'local\.settings\.json' -Quiet)
            }
            Docs          = [pscustomobject]@{
                Readme          = @(& $has '^README\.md$').Count -gt 0
                MarkdownFiles   = @(& $has '\.md$').Count
                DecisionRecords = @(& $has '(^|/)(docs/)?(decisions|adr)/\d{4}-[^/]+\.md$').Count
                MermaidDiagrams = @($files | Where-Object { $_.Extension -eq '.md' } | ForEach-Object { @(Get-GuildMermaidBlock -Path $_.FullName).Count } | Measure-Object -Sum).Sum
            }
            AgentFiles    = @(& $has '^(AGENTS\.md|CLAUDE\.md|GEMINI\.md|\.github/copilot-instructions\.md|\.cursorrules|\.cursor/rules/[^/]+|\.github/agents/[^/]+)$')
            Containers    = @(& $has '(^|/)(Dockerfile|docker-compose\.ya?ml|compose\.ya?ml)$').Count
        }
        if ($AsJson) { $survey | ConvertTo-Json -Depth 6 -Compress } else { $survey }
    }
}
