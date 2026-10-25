<#
.SYNOPSIS
    Lint and test Guild.
.EXAMPLE
    ./build.ps1
.EXAMPLE
    ./build.ps1 -Task Test
#>
[CmdletBinding()]
param([ValidateSet('Lint', 'Test')][string[]] $Task = @('Lint', 'Test'))

$ErrorActionPreference = 'Stop'
Push-Location $PSScriptRoot
try {
    if ($Task -contains 'Lint') {
        Write-Host '== PSScriptAnalyzer' -ForegroundColor Cyan
        Import-Module PSScriptAnalyzer -MinimumVersion 1.21.0
        $settings = Import-PowerShellDataFile (Join-Path $PSScriptRoot 'PSScriptAnalyzerSettings.psd1')
        $findings = foreach ($path in 'Guild', 'guards', 'adapters', 'packs', 'scaffolds', 'tests', 'build.ps1') {
            $pathSettings = $settings.Clone()
            if ($path -eq 'tests') { $pathSettings.ExcludeRules = @($settings.ExcludeRules) + 'PSUseDeclaredVarsMoreThanAssignments', 'PSReviewUnusedParameter' }
            if ($path -eq 'build.ps1') { $pathSettings.ExcludeRules = @($settings.ExcludeRules) + 'PSAvoidUsingWriteHost' }
            Invoke-ScriptAnalyzer -Path $path -Recurse -Settings $pathSettings
        }
        if ($findings) {
            $findings | Format-Table -AutoSize RuleName, Severity, ScriptName, Line, Message | Out-String -Width 220 | Write-Host
            throw "PSScriptAnalyzer reported $(@($findings).Count) finding(s)."
        }
        Write-Host '  No findings.'
    }
    if ($Task -contains 'Test') {
        Write-Host '== Pester' -ForegroundColor Cyan
        Import-Module Pester -MinimumVersion 5.5.0
        $config = New-PesterConfiguration
        $config.Run.Path = './tests'
        $config.Run.PassThru = $true
        $config.Output.Verbosity = 'Normal'
        $result = Invoke-Pester -Configuration $config
        if ($result.FailedCount -gt 0 -or $result.FailedContainersCount -gt 0) {
            throw "Pester: $($result.FailedCount) test(s) and $($result.FailedContainersCount) container(s) failed."
        }
        if ($result.SkippedCount -gt 0) { throw "Pester skipped $($result.SkippedCount) test(s); skipped tests are not allowed." }
        if ($result.PassedCount -eq 0) { throw 'Pester passed zero tests.' }
    }
}
finally {
    Pop-Location
}
