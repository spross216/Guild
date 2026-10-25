function New-GuildStandardsRepo {
    <#
    .SYNOPSIS
        Scaffolds a local standards repository whose accepted standards a Guild pack points at.
    .DESCRIPTION
        Creates <Path>/<Name> with standards/ (accepted only), drafts/ (synthesized proposals), decisions/,
        evidence/ (repository surveys), docs/provenance.md, a Guild pack in guild/, and a consistency test
        that keeps drafts out of the pack and requires every standard to cite its sources. Runs
        git init -b main unless -NoGit.

        It never creates a remote repository, commits or pushes; the human does that. Refuses to write into
        a directory that exists and isn't empty.
    .EXAMPLE
        New-GuildStandardsRepo -Path C:\repos -Name platform-standards -Prefix plat -Description 'Platform team engineering standards'
    .EXAMPLE
        New-GuildStandardsRepo -Path C:\repos -Name data-standards -Prefix data -Description 'Data engineering standards' -WhatIf
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)][string] $Path,
        [Parameter(Mandatory)][ValidatePattern('^[a-z][a-z0-9-]{1,60}$')][string] $Name,
        [Parameter(Mandatory)][ValidatePattern('^[a-z][a-z0-9]{1,15}$')][string] $Prefix,
        [Parameter(Mandatory)][ValidatePattern('^[^''"`$\\]{3,200}$')][string] $Description,
        [switch] $NoGit
    )
    if (-not $PSBoundParameters.ContainsKey('InformationAction')) { $InformationPreference = 'Continue' }
    if (-not (Test-Path -LiteralPath $Path -PathType Container)) { throw "Parent directory not found: $Path" }
    $target = Join-Path (Resolve-Path -LiteralPath $Path).ProviderPath $Name
    if ((Test-Path -LiteralPath $target) -and (Get-ChildItem -LiteralPath $target -Force | Select-Object -First 1)) {
        throw "$target already exists and is not empty."
    }

    $scaffold = Join-Path $script:GuildRepoRoot 'scaffolds/standards-repo'
    $values = @{ Name = $Name; Prefix = $Prefix; Description = $Description; Date = [DateTime]::Now.ToString('yyyy-MM-dd') }
    $expand = { param([string] $Text) foreach ($key in $values.Keys) { $Text = $Text.Replace("__$($key)__", $values[$key]) }; $Text }
    $plan = foreach ($file in Get-ChildItem -LiteralPath $scaffold -Recurse -File -Force) {
        $relative = & $expand (Get-GuildRelative $scaffold $file.FullName)
        [pscustomobject]@{ Path = Join-Path $target $relative; Relative = $relative; Content = & $expand ([System.IO.File]::ReadAllText($file.FullName).Replace("`r`n", "`n")) }
    }
    if (-not $PSCmdlet.ShouldProcess($target, "Create standards repository ($(@($plan).Count) files)")) { return $plan | Select-Object Relative }

    foreach ($item in $plan) { Write-GuildText -Path $item.Path -Text $item.Content }
    $gitInitialized = $false
    if (-not $NoGit -and (Get-Command git -ErrorAction SilentlyContinue)) {
        git -C $target init -b main --quiet
        $gitInitialized = $LASTEXITCODE -eq 0
    }
    $nextSteps = @(
        "Survey the sources: Get-GuildRepoSurvey -Path <repository> -AsJson | Set-Content '$target/evidence/<repository>-<date>.json'"
        "Write drafts in '$target/drafts' with **Status:** Draft and a ## Sources section; record them in docs/provenance.md."
        'Have a person review and accept drafts (move to standards/, status Accepted), then run ./build.ps1.'
        "The human creates the remote repository and pushes; then: Install-GuildAgents -Pack '$target/guild/$Name.pack.psd1'"
    )
    Write-Information -MessageData "Created $target. Next:`n  $($nextSteps -join "`n  ")"
    [pscustomobject]@{ Path = $target; Files = @($plan.Relative); GitInitialized = $gitInitialized; Pack = Join-Path $target "guild/$Name.pack.psd1"; NextSteps = $nextSteps }
}
