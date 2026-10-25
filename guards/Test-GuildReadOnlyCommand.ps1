<#
.SYNOPSIS
    Read-only guard for Guild's read-only roles. A Claude Code PreToolUse hook on Bash: reads the
    hook JSON from stdin, exits 0 to allow the command and 2 to block it (stderr goes to the agent).

.DESCRIPTION
    A guardrail, not a security boundary. Every command segment must start with a known read-only
    command (or one passed with -Allow), output redirection is blocked, nested shells are blocked,
    and the whole command is scanned for anything that changes files, version control, or cloud
    state. Run with -Command to test a string directly.

.PARAMETER Allow
    Extra commands a read-only role may run, comma-separated. The installer passes the commands a
    pack binds to Describe, Diagnose and Check, and New-GuildDecision for docs roles. Allowed commands
    are trusted even when their verb (New-, Test-) would otherwise look like a change.
#>
[CmdletBinding()]
param([string] $Command, [string] $Allow)

$ErrorActionPreference = 'Stop'

$readOnly = @(
    'cat', 'type', 'ls', 'dir', 'head', 'tail', 'less', 'more', 'grep', 'rg', 'find', 'wc', 'sort', 'uniq',
    'diff', 'echo', 'pwd', 'which', 'where', 'jq', 'cd', 'true', 'tree', 'file', 'stat', 'du', 'df',
    'Get-Content', 'Get-ChildItem', 'Get-Item', 'Get-ItemProperty', 'Select-String', 'Select-Object',
    'Where-Object', 'ForEach-Object', 'Format-Table', 'Format-List', 'Out-String', 'ConvertFrom-Json',
    'ConvertTo-Json', 'Measure-Object', 'Sort-Object', 'Group-Object', 'Test-Path', 'Resolve-Path',
    'Join-Path', 'Split-Path', 'Set-Location', 'Push-Location', 'Pop-Location', 'Write-Output',
    'Get-Command', 'Get-Module', 'Get-Help', 'Import-Module', 'Import-PowerShellDataFile', 'Get-FileHash',
    'Get-Date', 'Get-Location', 'Invoke-Pester', 'New-PesterConfiguration', 'Invoke-ScriptAnalyzer'
)
# Guild's own read-only tools: context, briefs, documentation drift, repository surveys, findings summary.
$guildTools = @('Get-GuildContext', 'New-GuildBrief', 'Test-GuildDocs', 'Get-GuildRepoSurvey', 'Get-GuildFindingSummary', 'Get-GuildPack', 'Test-GuildInstall')
$allowed = @($Allow -split ',' | ForEach-Object { $_.Trim() } | Where-Object { $_ -match '^[A-Za-z][\w-]*$' })
$readOnly += $guildTools + $allowed

$readVerbs = @{
    git     = @('status', 'diff', 'log', 'show', 'blame', 'grep', 'ls-files', 'rev-parse', 'branch', 'remote', 'shortlog', 'describe')
    gh      = @('run list', 'run view', 'run watch', 'pr view', 'pr diff', 'pr list', 'pr checks', 'pr status',
        'workflow list', 'workflow view', 'repo view', 'issue view', 'issue list', 'release list', 'release view')
    az      = @('show', 'list', 'query', 'exists', 'version', 'get')
    aws     = @('describe', 'list', 'get')
    gcloud  = @('describe', 'list', 'get')
    kubectl = @('get', 'describe', 'logs', 'version', 'top', 'explain')
}

# Anywhere in the command, these mean a change. Checked across the whole string, including inside
# script blocks and quotes.
$mutating = @(
    '\b(Remove|Set|Add|Clear|New|Copy|Move|Rename|Out|Start|Stop|Restart|Update|Install|Uninstall|Publish|Register|Unregister|Enable|Disable|Reset|Grant|Revoke|Write|Export|Compress|Expand|Save|Send|Submit|Invoke)-[A-Za-z]+\b'
    '(^|[\s;&|(])(iex|saps|ni|ri|rm|del|rd|rmdir|mv|cp|md|mkdir)(?=\s|$)'
    '(^|[\s;&|(])(touch|chmod|chown|chgrp|ln|tee|truncate|dd|shred|curl|wget|npm|npx|pnpm|yarn|pip|pip3|uv|winget|choco|scoop|brew|apt|apt-get|yum|dnf|make|docker|terraform|helm)(\s|$)'
    '\bsed\s+(-[a-zA-Z]*i|--in-place)'
    '\bgit\s+(-C\s+\S+\s+)?(push|commit|reset|checkout|switch|merge|rebase|clean|stash|add|rm|mv|restore|cherry-pick|revert|apply|am|pull|fetch|init|clone|config|worktree|submodule|gc|prune|update-ref|notes)\b'
    '\bgit\s+(-C\s+\S+\s+)?(branch|tag)\s+(-[a-zA-Z]*[dDmMcCf]|--delete|--move|--copy|--force)'
    '\bgh\s+(api\b.*(-X|--method)\s+(POST|PUT|PATCH|DELETE)|api\b.*\s(-f|-F|--field|--raw-field|--input)\s|auth|secret|variable)'
    '\b(az|aws|gcloud)\s+.*\b(create|delete|update|set|add|remove|start|stop|restart|deploy|purge|import|assign|reset|rotate|regenerate|login|logout|put|run|invoke)\b'
    '\baz\s+rest\b(?!.*--method\s+get)'
    '\bkubectl\s+(apply|create|delete|edit|patch|replace|scale|rollout|exec|cp|label|annotate|drain|cordon)\b'
    '\bfind\b.*\s-(delete|exec|execdir|ok|fprint)\b'
)
# Commands on the allowed list that the broad patterns above would otherwise catch.
$exempt = '(?i)\b(' + ((@('Set-Location', 'Out-String', 'New-PesterConfiguration', 'Invoke-Pester', 'Invoke-ScriptAnalyzer', 'Write-Output') + $guildTools + $allowed | ForEach-Object { [regex]::Escape($_) }) -join '|') + ')\b'

function Get-BlockReason {
    param([string] $Text)

    if ($Text -match '(?i)(^|[\s;&|(])(pwsh|powershell|bash|sh|zsh|cmd|wsl)(\.exe)?\s+(-c|-command|/c|-encodedcommand|-e)\b') {
        return 'a nested shell; run the command directly'
    }
    $withoutSafeRedirects = $Text -replace '\d?>\s*&\d', '' -replace '\d?>\s*(\$null|/dev/null|nul)\b', ''
    if ($withoutSafeRedirects -match '>') { return 'output redirection to a file' }

    $scan = $Text -replace $exempt, ''
    foreach ($pattern in $mutating) {
        $match = [regex]::Match($scan, $pattern, 'IgnoreCase')
        if ($match.Success) { return "'$($match.Value.Trim())' changes something" }
    }

    foreach ($segment in [regex]::Split($Text, '\|\||&&|[;|\n]')) {
        $segment = $segment.Trim().TrimStart('&', '(', '{', '@', ' ').Trim()
        if (-not $segment -or $segment -match '^[)}"'']+$') { continue }
        if ($segment -match '^\$[\w.:]+\s*=\s*(?<rhs>.*)$') { $segment = $Matches.rhs.Trim() }
        if (-not $segment -or $segment -match '^[\$''"\d@\[(-]') { continue }

        $words = $segment -split '\s+'
        $first = $words[0].Trim('"', "'")
        $tool = ([System.IO.Path]::GetFileNameWithoutExtension($first)).ToLowerInvariant()
        if ($readVerbs.ContainsKey($tool)) {
            $rest = ($words | Select-Object -Skip 1 | Where-Object { $_ -notmatch '^-' -or $_ -match '^-C$' }) -join ' '
            $rest = $rest -replace '^-C\s+\S+\s*', ''
            $allowed = $readVerbs[$tool] | Where-Object { $rest -match "^$([regex]::Escape($_))\b" -or $rest -match "\b$([regex]::Escape($_))\b" }
            if ($tool -eq 'git' -and $rest -match '^branch\s+\S') { return 'git branch with a name creates a branch' }
            if (-not $allowed) { return "'$tool $(@($words | Select-Object -Skip 1 -First 2) -join ' ')' is not a known read-only $tool command" }
            continue
        }
        if ($first -notin $readOnly) { return "'$first' is not on the read-only list" }
    }
    $null
}

if (-not $PSBoundParameters.ContainsKey('Command')) {
    try {
        $hookInput = [Console]::In.ReadToEnd() | ConvertFrom-Json
        $Command = [string]$hookInput.tool_input.command
    }
    catch {
        [Console]::Error.WriteLine('Read-only guard: could not read the hook input, so the command is blocked.')
        exit 2
    }
}

$reason = Get-BlockReason -Text $Command
if ($reason) {
    [Console]::Error.WriteLine("Read-only role: blocked because of $reason. You don't change things; report what you needed instead.")
    exit 2
}
exit 0
