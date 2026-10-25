Set-StrictMode -Version Latest

function Test-AcmeProject {
    <#
    .SYNOPSIS
        Example check: Acme's repository rules, then the project's own build.
    .EXAMPLE
        Test-AcmeProject -Path .
    #>
    [CmdletBinding()]
    param([string] $Path = (Get-Location).Path)
    $root = (Resolve-Path -LiteralPath $Path).ProviderPath
    $results = [System.Collections.Generic.List[object]]::new()
    $results.Add([pscustomobject]@{ Rule = 'readme'; Passed = (Test-Path (Join-Path $root 'README.md')); Detail = 'A README describes the project.' })
    $results.Add([pscustomobject]@{ Rule = 'agents'; Passed = (Test-Path (Join-Path $root 'AGENTS.md')); Detail = 'AGENTS.md gives coding agents their instructions.' })
    $build = Join-Path $root 'scripts/Invoke-Build.ps1'
    if (Test-Path $build) {
        & pwsh -NoProfile -NonInteractive -File $build -Task Lint, Test | Out-Null
        $results.Add([pscustomobject]@{ Rule = 'build'; Passed = ($LASTEXITCODE -eq 0); Detail = 'The project''s own lint and tests pass.' })
    }
    $results.ToArray()
}

Export-ModuleMember -Function Test-AcmeProject
