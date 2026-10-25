function Get-GuildContext {
    <#
    .SYNOPSIS
        One snapshot of a project to start a task from: what it is, which standards apply, how to check
        it, and what it documents.
    .DESCRIPTION
        Read-only. Combines the project's files and git state with the pack installed for it
        (.guild/pack.json in the project, else in the user scope, else Guild's defaults). Every role
        starts a task from the same facts instead of rediscovering them. -AsMarkdown gives a block to
        paste into a brief.
    .EXAMPLE
        Get-GuildContext -Path C:\repos\outage-report
    .EXAMPLE
        Get-GuildContext -AsMarkdown
    #>
    [CmdletBinding()]
    param(
        [string] $Path = (Get-Location).Path,
        [switch] $AsMarkdown
    )
    $root = Get-GuildScopeRoot -Scope Project -Path $Path
    $pack = Get-GuildInstalledPack -Root $root

    $git = [ordered]@{ Repository = $false; Branch = $null; Head = $null; Clean = $null; Remote = $null }
    if (Get-Command git -ErrorAction SilentlyContinue) {
        $inside = git -C $root rev-parse --is-inside-work-tree 2>$null
        if ($LASTEXITCODE -eq 0 -and $inside -eq 'true') {
            $git.Repository = $true
            $git.Branch = git -C $root branch --show-current 2>$null
            $git.Head = git -C $root rev-parse --short HEAD 2>$null
            $git.Clean = -not (git -C $root status --porcelain 2>$null)
            $remote = git -C $root remote get-url origin 2>$null
            $git.Remote = if ($LASTEXITCODE -eq 0) { $remote } else { $null }
        }
    }

    $docs = @(Get-GuildDocFile -Root $root)
    $diagrams = foreach ($doc in $docs) { foreach ($block in Get-GuildMermaidBlock -Path $doc.FullName) { "$(Get-GuildRelative $root $doc.FullName):$($block.Line)" } }
    $decisionDirectory = @('docs/decisions', 'decisions', 'docs/adr') | Where-Object { Test-Path -LiteralPath (Join-Path $root $_) -PathType Container } | Select-Object -First 1
    $findingsLog = Join-Path $root $pack.Review.FindingsLog
    $check = $pack.Capabilities['Check']

    $context = [pscustomobject]@{
        Path          = $root
        Languages     = @(Get-GuildProjectLanguage -Path $root)
        Pack          = @($pack.Layers)
        Standards     = @($pack.Knowledge | Where-Object { $_ } | ForEach-Object { [pscustomobject]@{ Kind = $_.Kind; Name = $_.Name; Path = $_.Path } })
        Check         = if ($check) { [pscustomobject]@{ Command = @($check.Command); Module = $check.Module } } else { $null }
        Git           = [pscustomobject]$git
        AgentsFile    = Test-Path -LiteralPath (Join-Path $root 'AGENTS.md')
        Docs          = @($docs | ForEach-Object { Get-GuildRelative $root $_.FullName })
        Diagrams      = @($diagrams)
        Decisions     = if ($decisionDirectory) { [pscustomobject]@{ Directory = $decisionDirectory; Count = @(Get-ChildItem -LiteralPath (Join-Path $root $decisionDirectory) -Filter '*.md' -File | Where-Object Name -Match '^\d{4}-').Count } } else { $null }
        FindingsLog   = if (Test-Path -LiteralPath $findingsLog) { [pscustomobject]@{ Path = $pack.Review.FindingsLog; Entries = @(Get-Content -LiteralPath $findingsLog | Where-Object { $_.Trim() }).Count } } else { $null }
    }
    if (-not $AsMarkdown) { return $context }

    $tick = [char]96
    $checkText = if ($check) { (@($check.Command) | ForEach-Object { "$tick$_$tick" }) -join ', ' } else { 'none configured; use the project''s own test and lint commands' }
    $code = { param($Text) "$tick$Text$tick" }
    $gitText = if (-not $git.Repository) { 'not a repository' }
    else {
        $state = if ($git.Clean) { 'clean' } else { 'uncommitted changes' }
        $origin = if ($git.Remote) { ", origin $(& $code $git.Remote)" } else { '' }
        "branch $(& $code $git.Branch) at $(& $code $git.Head), $state$origin"
    }
    $decisionText = if ($context.Decisions) { "$($context.Decisions.Count) in $(& $code $context.Decisions.Directory)" } else { 'none' }
    $languageText = if ($context.Languages) { $context.Languages -join ', ' } else { 'none detected' }
    $agentsText = if ($context.AgentsFile) { 'present' } else { 'missing' }
    $lines = @(
        "## Project context: $(Split-Path $root -Leaf)"
        ''
        "- Path: $(& $code $root)"
        "- Languages: $languageText"
        "- Git: $gitText"
        "- Pack: $($context.Pack -join ' > ')"
        "- Check: $checkText"
        "- AGENTS.md: $agentsText"
        "- Decision records: $decisionText"
        "- Docs: $($context.Docs.Count) Markdown file(s), $($context.Diagrams.Count) Mermaid diagram(s)"
    )
    if ($context.Standards) {
        $lines += '', 'Standards, highest precedence first:'
        $lines += foreach ($source in $context.Standards) { "- $($source.Kind): $(& $code $source.Path)" }
    }
    $lines -join "`n"
}
