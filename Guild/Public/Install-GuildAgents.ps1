function Install-GuildAgents {
    <#
    .SYNOPSIS
        Installs the Guild roles (architect, builder, reviewer, steward) and skills for one or more agent harnesses.
    .DESCRIPTION
        Roles are tool-neutral markdown. This merges the framework defaults with any packs you give
        (company standards, tooling such as a scaffolder), fills in the roles, and writes them in
        each harness's own format. Get-GuildHarness lists the harnesses.

        Never overwrites a file Guild didn't write, and won't replace one edited by hand since
        unless -Force. Roles no longer produced are removed. Re-run after changing a pack or a role.
    .PARAMETER Harness
        One or more harness names, or 'auto' to detect: commands on PATH for user scope, marker
        directories (.claude, .github/agents, .codex, ...) for project scope.
    .PARAMETER Pack
        Pack files (.pack.psd1), applied in order on top of the framework defaults. A pack's
        Extends entries are applied before it.
    .PARAMETER Model
        Model overrides by role (reviewer) or tier (top, mid). Model names are harness-specific,
        so use this with one harness at a time.
    .EXAMPLE
        Install-GuildAgents -Harness claude
    .EXAMPLE
        Install-GuildAgents -Harness claude, copilot -Scope Project -Path C:\repos\app -Pack C:\packs\acme.pack.psd1
    .EXAMPLE
        Install-GuildAgents -Harness auto -WhatIf
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)]
        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete)
                $null = $commandName, $parameterName
                @('auto') + @((Get-ChildItem (Join-Path (Split-Path (Get-Module Guild).Path -Parent | Split-Path -Parent) 'adapters') -Filter '*.psd1').BaseName) |
                    Where-Object { $_ -like "$wordToComplete*" }
            })]
        [string[]] $Harness,
        [ValidateSet('User', 'Project')][string] $Scope = 'User',
        [string] $Path,
        [string[]] $Pack = @(),
        [hashtable] $Model = @{},
        [switch] $NoSkills,
        # Don't write the routing block into the harness's always-read instructions file (CLAUDE.md, ...).
        [switch] $NoRouting,
        [switch] $Force
    )

    if (-not $PSBoundParameters.ContainsKey('InformationAction')) { $InformationPreference = 'Continue' }
    $root = Get-GuildScopeRoot -Scope $Scope -Path $Path
    $merged = Resolve-GuildPack -Path $Pack
    $languages = if ($Scope -eq 'Project') { Get-GuildProjectLanguage -Path $root } else { $null }
    $manifest = Read-GuildManifest -Root $root
    $results = [System.Collections.Generic.List[object]]::new()
    $changed = $false

    foreach ($name in Resolve-GuildHarnessList -Harness $Harness -Scope $Scope -Root $root) {
        $adapter = Get-GuildAdapter -Name $name
        $plan = @(Get-GuildInstallPlan -Adapter $adapter -Scope $Scope -Root $root -Pack $merged -Languages $languages -ModelOverride $Model -NoSkills:$NoSkills -NoRouting:$NoRouting)
        $produced = [System.Collections.Generic.HashSet[string]]::new()
        $newDirectory = $plan | Where-Object Kind -EQ 'Role' | Select-Object -First 1 | ForEach-Object { -not (Test-Path (Split-Path $_.Path -Parent)) }

        foreach ($item in $plan) {
            $key = Get-GuildManifestKey -FullPath $item.Path -Root $root
            $null = $produced.Add($key)
            if ($item.Kind -in 'Instructions', 'Routing') {
                $key = "$key#$($item.BlockId)"
                $current = Read-GuildText -Path $item.Path
                $updated = Set-GuildBlock -Text $current -Block $item.Content -Id $item.BlockId
                $action = if ($null -eq $current) { 'Created' } elseif ($current -ceq $updated) { 'Unchanged' } else { 'Updated' }
                $entry = $manifest.Sections[$key]
                if ($action -eq 'Unchanged' -or $PSCmdlet.ShouldProcess($item.Path, "$action Guild $($item.Kind.ToLowerInvariant()) block")) {
                    if ($action -ne 'Unchanged') { Write-GuildText -Path $item.Path -Text $updated }
                    $manifest.Sections[$key] = @{
                        Targets     = @(@($entry.Targets | Where-Object { $_ }) + $name | Select-Object -Unique)
                        CreatedFile = if ($entry) { [bool]$entry.CreatedFile } else { $null -eq $current }
                    }
                    $changed = $true
                }
                $results.Add([pscustomobject]@{ Harness = $name; Kind = $item.Kind; Name = $item.Name; Path = $item.Path; Action = $action; Note = $null })
                continue
            }

            $entry = $manifest.Files[$key]
            $decision = Get-GuildWriteAction -Path $item.Path -Content $item.Content -Entry $entry -Force:$Force
            $apply = $decision.Action -eq 'Unchanged' -or ($decision.Action -in 'Created', 'Updated' -and $PSCmdlet.ShouldProcess($item.Path, "$($decision.Action) $($item.Name)"))
            if ($apply) {
                if ($decision.Action -ne 'Unchanged') { Write-GuildText -Path $item.Path -Text $item.Content }
                $manifest.Files[$key] = @{
                    Hash    = Get-GuildHash $item.Content
                    Source  = $item.Source
                    Targets = @(@($entry.Targets | Where-Object { $_ }) + $name | Select-Object -Unique)
                }
                $changed = $true
            }
            $results.Add([pscustomobject]@{ Harness = $name; Kind = $item.Kind; Name = $item.Name; Path = $item.Path; Action = $decision.Action; Note = $decision.Note })
        }

        # Files this harness had that the current roles and skills no longer produce.
        foreach ($key in @($manifest.Files.Keys)) {
            $entry = $manifest.Files[$key]
            if ($name -notin @($entry.Targets) -or $produced.Contains($key)) { continue }
            $remaining = @($entry.Targets | Where-Object { $_ -ne $name })
            $fullPath = Join-Path $root $key
            if ($remaining) {
                if ($PSCmdlet.ShouldProcess($fullPath, "Stop tracking for $name")) { $entry.Targets = $remaining; $changed = $true }
                continue
            }
            $current = Read-GuildText -Path $fullPath
            if ($null -ne $current -and (Get-GuildHash $current) -ne $entry.Hash -and -not $Force) {
                $results.Add([pscustomobject]@{ Harness = $name; Kind = 'File'; Name = (Split-Path $key -Leaf); Path = $fullPath; Action = 'Skipped'; Note = 'no longer produced, but edited by hand; left in place (-Force removes it)' })
                continue
            }
            if ($PSCmdlet.ShouldProcess($fullPath, 'Remove file no longer produced')) {
                if ($null -ne $current) { Remove-Item -LiteralPath $fullPath -Force }
                $manifest.Files.Remove($key)
                $changed = $true
            }
            $results.Add([pscustomobject]@{ Harness = $name; Kind = 'File'; Name = (Split-Path $key -Leaf); Path = $fullPath; Action = 'Removed'; Note = 'no longer produced' })
        }

        if ($name -eq 'claude' -and $newDirectory -and -not $WhatIfPreference) {
            Write-Information -MessageData 'Created the Claude Code agents directory. Restart Claude Code once so it picks up the new agents.'
        }
        if ($adapter.Kind -ne 'agents') { Write-Information -MessageData "$($adapter.DisplayName): $($adapter.Notes)" }
    }

    if ($changed -and -not $WhatIfPreference) {
        Save-GuildManifest -Root $root -Manifest $manifest
        Write-GuildText -Path (Join-Path $root '.guild/pack.json') -Text (($merged | ConvertTo-Json -Depth 8) + "`n")
    }
    foreach ($skipped in $results | Where-Object Action -EQ 'Skipped') { Write-Warning "$($skipped.Path): $($skipped.Note)" }
    $results.ToArray()
}
