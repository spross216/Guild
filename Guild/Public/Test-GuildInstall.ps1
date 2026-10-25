function Test-GuildInstall {
    <#
    .SYNOPSIS
        Compares what is installed with what Install-GuildAgents would write now.
    .DESCRIPTION
        Status per file: Current, Missing, Outdated (Guild's file, older than the sources or packs),
        Edited (changed by hand since Guild wrote it) or Foreign (a file Guild didn't write is in
        the way). Use the same -Pack and -Model you install with.
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
        }
    }
}
