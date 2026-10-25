@{
    RootModule        = 'Guild.psm1'
    ModuleVersion     = '0.3.0'
    GUID              = '5b0c4f7e-2d8a-4a63-9f3e-6c1d2b7a9e41'
    Author            = 'Sean Ross'
    Description       = 'Portable agent roles (architect, builder, reviewer, steward) for any agent harness, configured by data-only packs.'
    PowerShellVersion = '7.2'
    FunctionsToExport = @(
        'Install-GuildAgents', 'Uninstall-GuildAgents', 'Test-GuildInstall', 'Get-GuildHarness', 'Get-GuildPack',
        'Add-GuildFinding', 'Get-GuildFindingSummary', 'Get-GuildContext', 'New-GuildBrief', 'New-GuildDecision', 'Test-GuildDocs',
        'Get-GuildRepoSurvey', 'New-GuildStandardsRepo'
    )
    CmdletsToExport   = @()
    VariablesToExport = @()
    AliasesToExport   = @()
    PrivateData       = @{
        PSData = @{
            Tags         = @('agents', 'ai', 'claude', 'copilot', 'codex', 'opencode', 'guardrails', 'agents-md')
            ProjectUri   = 'https://github.com/spross216/Guild'
            LicenseUri   = 'https://github.com/spross216/Guild/blob/main/LICENSE'
            ReleaseNotes = 'https://github.com/spross216/Guild/blob/main/CHANGELOG.md'
        }
    }
}
