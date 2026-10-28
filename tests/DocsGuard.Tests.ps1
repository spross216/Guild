# The docs role's edit guard: Markdown and diagram files only.

Describe 'Docs edit guard' {
    BeforeAll { $script:DocsGuard = Join-Path $PSScriptRoot '../guards/Test-GuildDocsEdit.ps1' }

    It 'allows <_>' -ForEach @('docs/architecture.md', 'README.md', 'C:/repo/docs/flows.mmd') {
        & pwsh -NoProfile -NonInteractive -File $DocsGuard -Path $_ 2>&1 | Out-Null
        $LASTEXITCODE | Should -Be 0
    }

    It 'blocks <_>' -ForEach @('src/Job.ps1', 'main.bicep', '.github/workflows/ci.yml', 'docs/notes.md.ps1') {
        & pwsh -NoProfile -NonInteractive -File $DocsGuard -Path $_ 2>&1 | Out-Null
        $LASTEXITCODE | Should -Be 2
    }

    It 'reads the hook JSON from stdin' {
        '{"tool_input":{"file_path":"docs/a.md"}}' | pwsh -NoProfile -NonInteractive -File $DocsGuard 2>&1 | Out-Null
        $LASTEXITCODE | Should -Be 0
        '{"tool_input":{"file_path":"src/a.ps1"}}' | pwsh -NoProfile -NonInteractive -File $DocsGuard 2>&1 | Out-Null
        $LASTEXITCODE | Should -Be 2
    }
}
