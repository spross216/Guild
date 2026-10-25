<#
.SYNOPSIS
    Validate this standards repository.
.EXAMPLE
    ./build.ps1
#>
[CmdletBinding()]
param()
$ErrorActionPreference = 'Stop'
Import-Module Pester -MinimumVersion 5.5.0
$config = New-PesterConfiguration
$config.Run.Path = Join-Path $PSScriptRoot 'tests'
$config.Run.PassThru = $true
$config.Output.Verbosity = 'Normal'
$result = Invoke-Pester -Configuration $config
if ($result.FailedCount -gt 0) { throw "Pester: $($result.FailedCount) test(s) failed." }
