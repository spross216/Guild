function Get-GuildHarness {
    <#
    .SYNOPSIS
        Lists the agent harnesses Guild can install for, and what each supports.
    .DESCRIPTION
        Mode is Subagents (native agent files), Instructions (one agent plays the roles from an
        instructions file) or Files (plain role files). Detected means its command is on PATH.
    .EXAMPLE
        Get-GuildHarness | Format-Table Name, DisplayName, Mode, Detected
    .EXAMPLE
        Get-GuildHarness -Name codex | Format-List
    #>
    [CmdletBinding()]
    param([string] $Name)
    $adapters = if ($Name) { Get-GuildAdapter -Name $Name } else { Get-GuildAdapter }
    foreach ($adapter in $adapters) {
        $commands = @($adapter.Detect.Command | Where-Object { $_ })
        [pscustomobject]@{
            Name             = $adapter.Name
            DisplayName      = $adapter.DisplayName
            Mode             = switch ($adapter.Kind) { 'agents' { 'Subagents' } 'instructions' { 'Instructions' } default { 'Files' } }
            UserDirectory    = $adapter.UserDirectory
            ProjectDirectory = $adapter.ProjectDirectory
            Skills           = [bool]($adapter.SkillsUserDirectory -or $adapter.SkillsProjectDirectory)
            ModelPerRole     = $adapter.Kind -eq 'agents'
            ReadOnly         = $adapter.ReadOnly
            Detected         = @($commands | Where-Object { Get-Command $_ -ErrorAction SilentlyContinue }).Count -gt 0
            Notes            = $adapter.Notes
        }
    }
}
