function Uninstall-GuildAgents {
    <#
    .SYNOPSIS
        Removes what Install-GuildAgents wrote for the given harnesses.
    .DESCRIPTION
        Uses the manifest: removes Guild's files for each harness (unless another harness still uses
        them) and Guild's block from instructions files. Files edited by hand since Guild wrote them
        are left in place unless -Force.
    .EXAMPLE
        Uninstall-GuildAgents -Harness claude
    .EXAMPLE
        Uninstall-GuildAgents -Harness agents-md -Scope Project -Path C:\repos\app -WhatIf
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)][string[]] $Harness,
        [ValidateSet('User', 'Project')][string] $Scope = 'User',
        [string] $Path,
        [switch] $Force
    )
    $root = Get-GuildScopeRoot -Scope $Scope -Path $Path
    $manifest = Read-GuildManifest -Root $root
    $names = @($Harness | ForEach-Object { (Get-GuildAdapter -Name $_).Name })
    $changed = $false

    foreach ($key in @($manifest.Files.Keys)) {
        $entry = $manifest.Files[$key]
        $mine = @($entry.Targets | Where-Object { $_ -in $names })
        if (-not $mine) { continue }
        $remaining = @($entry.Targets | Where-Object { $_ -notin $names })
        $fullPath = Join-Path $root $key
        if ($remaining) {
            if ($PSCmdlet.ShouldProcess($fullPath, "Stop tracking for $($mine -join ', ')")) { $entry.Targets = $remaining; $changed = $true }
            continue
        }
        $current = Read-GuildText -Path $fullPath
        if ($null -ne $current -and (Get-GuildHash $current) -ne $entry.Hash -and -not $Force) {
            Write-Warning "${fullPath}: edited by hand since Guild wrote it; left in place (-Force removes it)."
            [pscustomobject]@{ Path = $fullPath; Action = 'Skipped' }
            continue
        }
        if ($PSCmdlet.ShouldProcess($fullPath, 'Remove')) {
            if ($null -ne $current) { Remove-Item -LiteralPath $fullPath -Force }
            $directory = Split-Path $fullPath -Parent
            if ((Split-Path $fullPath -Leaf) -eq 'SKILL.md' -and -not (Get-ChildItem -LiteralPath $directory -Force -ErrorAction SilentlyContinue)) { Remove-Item -LiteralPath $directory -Force }
            $manifest.Files.Remove($key)
            $changed = $true
            [pscustomobject]@{ Path = $fullPath; Action = 'Removed' }
        }
    }

    foreach ($key in @($manifest.Sections.Keys)) {
        $entry = $manifest.Sections[$key]
        if (-not @($entry.Targets | Where-Object { $_ -in $names })) { continue }
        $remaining = @($entry.Targets | Where-Object { $_ -notin $names })
        $filePart, $blockId = $key -split '#', 2
        if (-not $blockId) { $blockId = 'guild' }
        $fullPath = Join-Path $root $filePart
        if ($remaining) { $entry.Targets = $remaining; $changed = $true; continue }
        if ($PSCmdlet.ShouldProcess($fullPath, "Remove Guild block ($blockId)")) {
            $current = Read-GuildText -Path $fullPath
            if ($null -ne $current) {
                $text = Remove-GuildBlock -Text $current -Id $blockId
                if (-not $text -and $entry.CreatedFile) { Remove-Item -LiteralPath $fullPath -Force } else { Write-GuildText -Path $fullPath -Text $text }
            }
            $manifest.Sections.Remove($key)
            $changed = $true
            [pscustomobject]@{ Path = $fullPath; Action = 'Removed block' }
        }
    }

    if ($changed -and -not $WhatIfPreference) { Save-GuildManifest -Root $root -Manifest $manifest }
}
