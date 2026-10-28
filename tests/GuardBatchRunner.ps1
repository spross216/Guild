# Test support only: judges many cases in one process. Stdin holds a JSON array of { tool_name, command, allow };
# stdout gets a JSON array of { exit, reason } in the same order. It dot-sources the guard, which then only
# defines its functions, so the hook entry point has no batch switch for an agent to reach.
param()
. (Join-Path $PSScriptRoot '../guards/Test-GuildReadOnlyCommand.ps1')
$cases = @(ConvertFrom-Json -InputObject (Read-StandardInput) -NoEnumerate)
$results = foreach ($case in $cases[0]) {
    $toolName = $null
    if ($case.PSObject.Properties['tool_name']) { $toolName = $case.tool_name }
    $allowList = @()
    if ($case.PSObject.Properties['allow']) { $allowList = ConvertTo-AllowList ([string]$case.allow) }
    $message = Test-GuildCommandText -Text $case.command -ToolName $toolName -AllowList $allowList
    [pscustomobject]@{ exit = $(if ($message) { 2 } else { 0 }); reason = $message }
}
ConvertTo-Json -InputObject @($results) -Compress
