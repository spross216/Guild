function New-GuildBrief {
    <#
    .SYNOPSIS
        Writes a hand-off for a role with the same sections every time.
    .DESCRIPTION
        Read-only; returns Markdown. Sections: goal, the standards to read (from the project's installed
        pack unless -Standards is given), paths, constraints, what done means (always including the
        project's check), and for -HighRisk the independent testing and review the change needs. The
        project context from Get-GuildContext is appended so the role starts from the same facts.
    .EXAMPLE
        New-GuildBrief -Role builder -Goal 'Add a retry to the export call' -Paths src/Modules/Export/Private/Invoke-ExportApi.ps1
    .EXAMPLE
        New-GuildBrief -Role reviewer -Goal 'Review the token validation change' -HighRisk -Done 'Verdict with findings'
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)][ValidatePattern('^[a-z][a-z0-9-]*$')][string] $Role,
        [Parameter(Mandatory)][string] $Goal,
        [string] $Path = (Get-Location).Path,
        [string[]] $Paths = @(),
        [string[]] $Standards = @(),
        [string[]] $Constraints = @(),
        [string[]] $Done = @(),
        [switch] $HighRisk
    )
    $root = Get-GuildScopeRoot -Scope Project -Path $Path
    $pack = Get-GuildInstalledPack -Root $root
    $roleName = "$($pack.Prefix)-$Role"
    $check = $pack.Capabilities['Check']
    $checkLine = if ($check) { "``$(@($check.Command)[0].Replace('<project>', $root))`` passes" } else { 'the project''s own test and lint commands pass (say which you ran)' }

    $standardsLines = if ($Standards) { $Standards | ForEach-Object { "- ``$_``" } }
    elseif (@($pack.Knowledge | Where-Object { $_ })) { $pack.Knowledge | Where-Object { $_ } | ForEach-Object { "- $($_.Kind): ``$($_.Path)``" } }
    else { '- No standards sources are configured: use the project''s README, AGENTS.md and decision records.' }

    $lines = @(
        "# Brief for $roleName"
        ''
        '## Goal'
        ''
        $Goal
        ''
        '## Read first'
        ''
        $standardsLines
        ''
        '## Paths'
        ''
        $(if ($Paths) { $Paths | ForEach-Object { "- ``$_``" } } else { '- Not narrowed: find the relevant files and say which you touched.' })
        ''
        '## Constraints'
        ''
        $(foreach ($constraint in $Constraints) { "- $constraint" })
        '- Never commit, push, deploy or change remote state.'
        "- Never invent: $(@($pack.Policy.NeverInvent) -join '; '). Ask instead."
        ''
        '## Done means'
        ''
        $(foreach ($item in $Done) { "- $item" })
        "- Verified: $checkLine."
        '- The report labels each change attempted, completed, verified or failed.'
    )
    if ($HighRisk) {
        $lines += '', '## High risk', ''
        $lines += "- This change is high risk ($(@($pack.Policy.HighRisk) -join '; ')). The author's tests don't count: it needs independent tests, then an independent review that sees the QA statement."
    }
    $lines += '', (Get-GuildContext -Path $root -AsMarkdown)
    ($lines -join "`n").Replace("`n`n`n", "`n`n") + "`n"
}
