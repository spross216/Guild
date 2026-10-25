function Get-GuildFindingSummary {
    <#
    .SYNOPSIS
        Groups a project's findings log and flags what has recurred enough to promote.
    .DESCRIPTION
        Groups findings by category and cited rule. Promote is true once a group reaches
        PromoteAfter occurrences (from the installed pack unless given). Findings without a rule are
        grouped by category only, so they are a weaker signal; cite rules to sharpen it.
    .EXAMPLE
        Get-GuildFindingSummary -Path . | Where-Object Promote
    .EXAMPLE
        Get-GuildFindingSummary -Path C:\repos\app -PromoteAfter 3
    #>
    [CmdletBinding()]
    param([Parameter(Mandatory)][string] $Path, [int] $PromoteAfter)
    $root = Get-GuildScopeRoot -Scope Project -Path $Path
    $settings = Get-GuildReviewSetting -Root $root
    if (-not $PromoteAfter) { $PromoteAfter = [int]$settings.PromoteAfter }
    $log = Join-Path $root $settings.FindingsLog
    if (-not (Test-Path -LiteralPath $log)) { Write-Verbose "No findings log at $log."; return }

    $findings = foreach ($line in Get-Content -LiteralPath $log) {
        if (-not $line.Trim()) { continue }
        try { $entry = $line | ConvertFrom-Json -AsHashtable } catch { Write-Warning "Skipping a line that is not JSON in ${log}."; continue }
        if ($entry['category']) { $entry }
    }
    $groups = @($findings) | Where-Object { $_ } | Group-Object { "$($_['category'])|$($_['rule'])" }
    foreach ($group in $groups | Sort-Object Count -Descending) {
        $items = @($group.Group | Sort-Object { $_['time'] })
        [pscustomobject]@{
            Category  = $items[0]['category']
            Rule      = $items[0]['rule']
            Count     = $group.Count
            Promote   = $group.Count -ge $PromoteAfter
            FirstSeen = $items[0]['time']
            LastSeen  = $items[-1]['time']
            Examples  = @($items | Select-Object -Last 3 | ForEach-Object { $_['summary'] })
        }
    }
}
