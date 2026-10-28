function Test-GuildInstall {
    <#
    .SYNOPSIS
        Compares what is installed with what Install-GuildAgents would write now.
    .DESCRIPTION
        Status per file: Current, Missing, Outdated (Guild's file, older than the sources or packs),
        Edited (changed by hand since Guild wrote it) or Foreign (a file Guild didn't write is in
        the way). Use the same -Pack and -Model you install with.

        With the claude harness it also reads `claude --version` and reports Kind 'Claude': Current from
        2.1.295 (when `onFailure: block` was added), Outdated below it (with a warning), Unknown when claude
        isn't on the PATH.

        It also reports, with Kind 'Guard', each guard script an installed agent's hook names
        (and the guard's rule data file): Current when it exists, Missing when it doesn't. A hook
        whose script is missing can't start, so check this after moving or deleting the Guild folder.
    .EXAMPLE
        Test-GuildInstall -Harness claude
    .EXAMPLE
        Test-GuildInstall -Harness copilot -Scope Project -Path C:\repos\app -Pack C:\packs\acme.pack.psd1 | Where-Object Status -NE Current
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string[]] $Harness,
        [ValidateSet('User', 'Project')][string] $Scope = 'User',
        [string] $Path,
        [string[]] $Pack = @(),
        [hashtable] $Model = @{},
        [switch] $NoSkills,
        [switch] $NoRouting
    )
    $root = Get-GuildScopeRoot -Scope $Scope -Path $Path
    $merged = Resolve-GuildPack -Path $Pack
    $languages = if ($Scope -eq 'Project') { Get-GuildProjectLanguage -Path $root } else { $null }
    $manifest = Read-GuildManifest -Root $root

    foreach ($name in Resolve-GuildHarnessList -Harness $Harness -Scope $Scope -Root $root) {
        $adapter = Get-GuildAdapter -Name $name
        foreach ($item in Get-GuildInstallPlan -Adapter $adapter -Scope $Scope -Root $root -Pack $merged -Languages $languages -ModelOverride $Model -NoSkills:$NoSkills -NoRouting:$NoRouting) {
            $current = Read-GuildText -Path $item.Path
            $status = if ($item.Kind -in 'Instructions', 'Routing') {
                if ($null -eq $current -or $current -notmatch (Get-GuildBlockPattern -Id $item.BlockId)) { 'Missing' }
                elseif ((Set-GuildBlock -Text $current -Block $item.Content -Id $item.BlockId) -ceq $current) { 'Current' }
                else { 'Outdated' }
            }
            elseif ($null -eq $current) { 'Missing' }
            elseif ($current -ceq $item.Content) { 'Current' }
            else {
                $entry = $manifest.Files[(Get-GuildManifestKey -FullPath $item.Path -Root $root)]
                if ($entry -and (Get-GuildHash $current) -eq $entry.Hash) { 'Outdated' }
                elseif ($entry -or $current.Contains($script:GuildMarker)) { 'Edited' }
                else { 'Foreign' }
            }
            [pscustomobject]@{ Harness = $name; Kind = $item.Kind; Name = $item.Name; Path = $item.Path; Status = $status }
            # A hook whose guard script is gone can't start (and a hook that can't start is blocked only
            # with onFailure: block), so say so.
            $hookText = if ($null -ne $current) { $current } else { $item.Content }
            $seenPaths = [System.Collections.Generic.HashSet[string]]::new()
            foreach ($hook in [regex]::Matches($hookText, "-File '(?<path>(?:[^']|'')+Test-Guild\w+\.ps1)'")) {
                $scriptPath = $hook.Groups['path'].Value.Replace("''", "'")
                $targets = @($scriptPath)
                if ($scriptPath -like '*Test-GuildReadOnlyCommand.ps1') { $targets += [System.IO.Path]::ChangeExtension($scriptPath, '.psd1') }
                foreach ($target in $targets) {
                    if (-not $seenPaths.Add($target)) { continue }
                    [pscustomobject]@{ Harness = $name; Kind = 'Guard'; Name = (Split-Path $target -Leaf); Path = $target; Status = $(if (Test-Path -LiteralPath $target -PathType Leaf) { 'Current' } else { 'Missing' }) }
                }
            }
        }

        # The hooks use onFailure: block, which Claude Code supports from 2.1.295. Unknown (claude not found) is not a failure.
        if ($name -eq 'claude') {
            $version = Get-GuildClaudeVersion
            $minimum = [version]'2.1.295'
            $claudeStatus = if ($null -eq $version) { 'Unknown' } elseif ($version -lt $minimum) { 'Outdated' } else { 'Current' }
            $note = switch ($claudeStatus) {
                'Unknown' { 'claude was not found on the PATH, so its version could not be checked; the hooks need 2.1.295 or later' }
                'Outdated' { "Claude Code $version is older than $minimum; the guard hooks' onFailure: block is ignored, so a hook that cannot start would let the tool run" }
                default { $null }
            }
            if ($claudeStatus -eq 'Outdated') { Write-Warning $note }
            [pscustomobject]@{ Harness = $name; Kind = 'Claude'; Name = 'claude'; Path = $null; Status = $claudeStatus; Note = $note }
        }
    }
}
