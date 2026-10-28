# Shared by the guard tests (dot-sourced in BeforeAll). Every case reaches the guard as hook JSON on
# stdin, the way Claude Code sends it, and never on a process command line: some case text (download or
# encoded-command strings) looks like a malware technique to endpoint scanners. Only benign -Allow
# command names are passed as arguments.
#
# Invoke-Guard sends one case through the real hook path (one process). Get-GuardExit answers from a
# batch: Initialize-GuardBatch sends many cases in one process with the test-only GuardBatchRunner.ps1 (which dot-sources the guard).
$script:Guard = Join-Path $PSScriptRoot '../guards/Test-GuildReadOnlyCommand.ps1'
$script:BatchRunner = Join-Path $PSScriptRoot 'GuardBatchRunner.ps1'
$script:GuardVerdicts = @{}

function New-GuardPayload {
    param([string] $Command, [string] $Tool = 'Bash')
    $hook = @{ tool_input = @{ command = $Command } }
    if ($Tool -and $Tool -ne 'None') { $hook.tool_name = $Tool }
    ConvertTo-Json -Compress -InputObject $hook
}

function Invoke-Guard {
    # One case through the real hook path. Returns the exit code; -Stderr returns the message as well.
    param([string] $Command, [string] $Allow, [string] $Tool = 'Bash', [switch] $Stderr)
    $arguments = @('-NoProfile', '-NonInteractive', '-File', $script:Guard)
    if ($Allow) { $arguments += '-Allow', $Allow }
    $output = New-GuardPayload -Command $Command -Tool $Tool | & pwsh @arguments 2>&1
    if ($Stderr) { return [pscustomobject]@{ Exit = $LASTEXITCODE; Message = (@($output) -join "`n") } }
    $LASTEXITCODE
}

function Get-GuardKey {
    param([string] $Command, [string] $Tool, [string] $Allow)
    "$Tool|$Allow|$Command"
}

function Initialize-GuardBatch {
    # Cases: objects with Command, Tool (Bash, PowerShell or None) and Allow. Sends the ones not answered yet.
    param([object[]] $Cases)
    $pending = [System.Collections.Generic.List[object]]::new()
    $keys = [System.Collections.Generic.HashSet[string]]::new()
    foreach ($case in $Cases) {
        $key = Get-GuardKey -Command $case.Command -Tool $case.Tool -Allow $case.Allow
        if ($script:GuardVerdicts.ContainsKey($key) -or -not $keys.Add($key)) { continue }
        $request = @{ command = $case.Command; allow = [string]$case.Allow }
        if ($case.Tool -and $case.Tool -ne 'None') { $request.tool_name = $case.Tool }
        $pending.Add(@{ Key = $key; Request = $request })
    }
    if ($pending.Count -eq 0) { return }
    $json = ConvertTo-Json -Compress -InputObject @($pending | ForEach-Object { $_.Request })
    $output = $json | & pwsh -NoProfile -NonInteractive -File $script:BatchRunner
    $results = @($output | ConvertFrom-Json)
    if ($results.Count -ne $pending.Count) { throw "The guard answered $($results.Count) of $($pending.Count) batch cases." }
    for ($i = 0; $i -lt $pending.Count; $i++) { $script:GuardVerdicts[$pending[$i].Key] = $results[$i] }
}

function Get-GuardResult {
    param([string] $Command, [string] $Tool = 'Bash', [string] $Allow)
    $key = Get-GuardKey -Command $Command -Tool $Tool -Allow $Allow
    if (-not $script:GuardVerdicts.ContainsKey($key)) { Initialize-GuardBatch -Cases @(@{ Command = $Command; Tool = $Tool; Allow = $Allow }) }
    $script:GuardVerdicts[$key]
}

function Get-GuardExit {
    param([string] $Command, [string] $Tool = 'Bash', [string] $Allow)
    (Get-GuardResult -Command $Command -Tool $Tool -Allow $Allow).exit
}
