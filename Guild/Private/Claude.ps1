# The installed Claude Code version. The guard hooks use `onFailure: block`, which needs 2.1.295 or later.

function Invoke-GuildClaudeVersion {
    # The text `claude --version` prints, or $null. Bounded to ten seconds.
    [CmdletBinding()]
    [OutputType([string])]
    param()
    $command = Get-Command -Name claude -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
    if (-not $command) { return $null }
    $info = [System.Diagnostics.ProcessStartInfo]::new($command.Source, '--version')
    $info.RedirectStandardOutput = $true
    $info.RedirectStandardError = $true
    $info.UseShellExecute = $false
    $process = [System.Diagnostics.Process]::Start($info)
    try {
        if (-not $process.WaitForExit(10000)) { $process.Kill(); return $null }
        $process.StandardOutput.ReadToEnd()
    }
    finally { $process.Dispose() }
}

function Get-GuildClaudeVersion {
    # The installed Claude Code version, or $null when claude isn't on the PATH or its version can't be read.
    [CmdletBinding()]
    [OutputType([version])]
    param()
    if (-not (Get-Command -Name claude -ErrorAction SilentlyContinue)) { return $null }
    try { $text = Invoke-GuildClaudeVersion } catch { return $null }
    if ("$text" -match '(\d+\.\d+\.\d+)') { return [version]$Matches[1] }
    $null
}
