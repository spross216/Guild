function Add-GuildFinding {
    <#
    .SYNOPSIS
        Appends a review's verdict and findings to the project's findings log.
    .DESCRIPTION
        The reviewer is read-only, so the main session records its report. Accepts the reviewer's
        JSON (on its own or inside a ```json block in its prose) or an object with verdict and
        findings. Writes one JSON line per finding, or one line for a review with none. The log path
        and the allowed categories come from the installed pack (.guild/pack.json).
    .EXAMPLE
        Add-GuildFinding -Path . -Report $reviewerOutput -Model opus
    .EXAMPLE
        @{ verdict = 'APPROVE'; findings = @() } | Add-GuildFinding -Path C:\repos\app -Change 'add retry to fetch'
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)][string] $Path,
        [Parameter(Mandatory, ValueFromPipeline)][object] $Report,
        [string] $Role,
        [string] $Model,
        [string] $Change
    )
    process {
        $root = Get-GuildScopeRoot -Scope Project -Path $Path
        $settings = Get-GuildReviewSetting -Root $root
        $review = ConvertFrom-GuildReport -Report $Report
        $verdict = [string]$review['verdict']
        if ($verdict -notin 'APPROVE', 'CHANGES_REQUIRED') { throw "verdict must be APPROVE or CHANGES_REQUIRED, not '$verdict'." }

        $base = [ordered]@{
            time    = [DateTime]::UtcNow.ToString('o')
            verdict = $verdict
            role    = if ($Role) { $Role } else { $review['role'] }
            model   = if ($Model) { $Model } else { $review['model'] }
            change  = if ($Change) { $Change } else { $review['change'] }
        }
        $lines = foreach ($finding in $review['findings']) {
            if ($finding['severity'] -notin 'high', 'medium', 'low') { throw "Finding '$($finding['summary'])': severity must be high, medium or low." }
            if ($finding['category'] -notin @($settings.Categories)) { throw "Finding '$($finding['summary'])': category must be one of $(@($settings.Categories) -join ', ')." }
            if (-not $finding['summary']) { throw 'Every finding needs a summary.' }
            $line = [ordered]@{} + $base
            foreach ($key in 'severity', 'category', 'rule', 'file', 'line', 'summary', 'fix') { $line[$key] = $finding[$key] }
            $line | ConvertTo-Json -Compress
        }
        if (-not $lines) { $lines = @($base | ConvertTo-Json -Compress) }

        $log = Join-Path $root $settings.FindingsLog
        if ($PSCmdlet.ShouldProcess($log, "Append $(@($review['findings']).Count) finding(s)")) {
            $directory = Split-Path $log -Parent
            if (-not (Test-Path -LiteralPath $directory)) { New-Item -ItemType Directory -Path $directory -Force | Out-Null }
            [System.IO.File]::AppendAllText($log, (($lines -join "`n") + "`n"), $script:GuildUtf8NoBom)
        }
        [pscustomobject]@{ Log = $log; Verdict = $verdict; Findings = @($review['findings']).Count }
    }
}
