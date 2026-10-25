function New-GuildDecision {
    <#
    .SYNOPSIS
        Creates the next numbered decision record in a project.
    .DESCRIPTION
        Finds the decision folder (docs/decisions, decisions or docs/adr, or creates docs/decisions),
        takes the next four-digit number, and writes NNNN-title-in-kebab-case.md with Context, Decision,
        Alternatives considered and Consequences sections to fill in. Never overwrites. Returns the path.
    .EXAMPLE
        New-GuildDecision -Title 'Use a queue between the webhook and the job'
    .EXAMPLE
        New-GuildDecision -Path C:\repos\app -Title 'Python for the scoring step' -Status Accepted -WhatIf
    #>
    [CmdletBinding(SupportsShouldProcess)]
    [OutputType([string])]
    param(
        [string] $Path = (Get-Location).Path,
        [Parameter(Mandatory)][ValidateLength(3, 120)][string] $Title,
        [ValidateSet('Proposed', 'Accepted')][string] $Status = 'Proposed',
        [string] $Directory
    )
    $root = Get-GuildScopeRoot -Scope Project -Path $Path
    if (-not $Directory) {
        $Directory = @('docs/decisions', 'decisions', 'docs/adr') | Where-Object { Test-Path -LiteralPath (Join-Path $root $_) -PathType Container } | Select-Object -First 1
        if (-not $Directory) { $Directory = 'docs/decisions' }
    }
    $folder = Join-Path $root $Directory
    $numbers = @(Get-ChildItem -LiteralPath $folder -Filter '*.md' -File -ErrorAction SilentlyContinue |
            Where-Object Name -Match '^(\d{4})-' | ForEach-Object { [int]$Matches[1] })
    $next = '{0:D4}' -f [int]$(if ($numbers) { ($numbers | Measure-Object -Maximum).Maximum + 1 } else { 1 })
    $slug = ($Title.ToLowerInvariant() -replace '[^a-z0-9]+', '-').Trim('-')
    if ($slug.Length -gt 60) { $slug = $slug.Substring(0, 60).Trim('-') }
    $file = Join-Path $folder "$next-$slug.md"
    if (Test-Path -LiteralPath $file) { throw "$file already exists." }

    $content = @(
        "# ${next}: $Title"
        ''
        "**Date:** $([DateTime]::Now.ToString('yyyy-MM-dd'))"
        "**Status:** $Status"
        ''
        '## Context'
        ''
        'The problem and the constraints that shaped the decision. State what was verified, not assumed.'
        ''
        '## Decision'
        ''
        'What was decided, specific enough to implement without guessing.'
        ''
        '## Alternatives considered'
        ''
        '- **Option** - why it was or wasn''t chosen.'
        ''
        '## Consequences'
        ''
        'What gets easier or harder, follow-up work, and trade-offs accepted deliberately.'
    ) -join "`n"
    if ($PSCmdlet.ShouldProcess($file, 'Create decision record')) {
        if (-not (Test-Path -LiteralPath $folder)) { New-Item -ItemType Directory -Path $folder -Force | Out-Null }
        [System.IO.File]::WriteAllText($file, $content + "`n", $script:GuildUtf8NoBom)
    }
    $file
}
