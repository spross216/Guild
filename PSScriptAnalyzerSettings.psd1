@{
    Severity     = @('Error', 'Warning')
    ExcludeRules = @(
        # Install-GuildAgents and friends act on a set of roles on purpose.
        'PSUseSingularNouns'
        # Write-*/Set-* helpers in Private/ are only called from public functions that gate with ShouldProcess.
        'PSUseShouldProcessForStateChangingFunctions'
    )
}
