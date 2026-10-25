BeforeAll {
    $script:Guard = Join-Path $PSScriptRoot '../guards/Test-GuildReadOnlyCommand.ps1'
    function Invoke-Guard {
        param([string] $Command, [string] $Allow)
        $arguments = @('-NoProfile', '-NonInteractive', '-File', $script:Guard, '-Command', $Command)
        if ($Allow) { $arguments += '-Allow', $Allow }
        $null = & pwsh @arguments 2>&1
        $LASTEXITCODE
    }
}

Describe 'Read-only guard' {
    It 'allows <Command>' -ForEach @(
        @{ Command = 'git status' }
        @{ Command = 'git -C ../repo log --oneline -5' }
        @{ Command = 'git branch -a' }
        @{ Command = 'git diff HEAD~1 | Select-String TODO' }
        @{ Command = 'Get-Content README.md | Select-Object -First 20' }
        @{ Command = 'rg --files | wc -l' }
        @{ Command = 'gh run view 123 --log-failed' }
        @{ Command = 'gh pr diff 42' }
        @{ Command = 'az webapp list --query "[].name"' }
        @{ Command = 'kubectl get pods -n web' }
        @{ Command = 'Invoke-Pester ./tests 2>&1' }
        @{ Command = '$files = Get-ChildItem src; $files.Count' }
    ) {
        Invoke-Guard -Command $Command | Should -Be 0
    }

    It 'blocks <Command>' -ForEach @(
        @{ Command = 'git commit -m x' }
        @{ Command = 'git push' }
        @{ Command = 'git branch feature' }
        @{ Command = 'git tag v1.0' }
        @{ Command = 'git -C ../repo checkout main' }
        @{ Command = 'Remove-Item -Recurse src' }
        @{ Command = 'Get-Content a.txt | Set-Content b.txt' }
        @{ Command = 'echo hi > notes.txt' }
        @{ Command = 'rm -rf build' }
        @{ Command = 'sed -i s/a/b/ file.txt' }
        @{ Command = 'curl https://example.com' }
        @{ Command = 'pwsh -c "Remove-Item x"' }
        @{ Command = 'bash -c "ls"' }
        @{ Command = 'gh pr merge 42' }
        @{ Command = 'gh api repos/o/r/issues -f title=x' }
        @{ Command = 'az group delete --name rg' }
        @{ Command = 'aws s3 rm s3://bucket/key' }
        @{ Command = 'kubectl apply -f deploy.yaml' }
        @{ Command = 'find . -name "*.tmp" -delete' }
        @{ Command = 'npm install' }
        @{ Command = 'Invoke-Expression $code' }
        @{ Command = 'some-unknown-tool --flag' }
    ) {
        Invoke-Guard -Command $Command | Should -Be 2
    }

    It 'always allows Guild''s read-only tools' {
        Invoke-Guard -Command 'Get-GuildContext -Path .' | Should -Be 0
        Invoke-Guard -Command 'Test-GuildDocs -Path . -Owner architect' | Should -Be 0
        Invoke-Guard -Command 'New-GuildDecision -Title x' | Should -Be 2
        Invoke-Guard -Command 'New-GuildDecision -Title x' -Allow 'New-GuildDecision' | Should -Be 0
    }

    It 'allows commands passed with -Allow' {
        Invoke-Guard -Command 'Test-MyProject -Path .' | Should -Be 2
        Invoke-Guard -Command 'Test-MyProject -Path .' -Allow 'Test-MyProject,Get-MyLog' | Should -Be 0
    }

    It 'reads the hook JSON from stdin and blocks on input it cannot read' {
        '{"tool_input":{"command":"git status"}}' | pwsh -NoProfile -NonInteractive -File $script:Guard 2>&1 | Out-Null
        $LASTEXITCODE | Should -Be 0
        '{"tool_input":{"command":"git push"}}' | pwsh -NoProfile -NonInteractive -File $script:Guard 2>&1 | Out-Null
        $LASTEXITCODE | Should -Be 2
        'not json' | pwsh -NoProfile -NonInteractive -File $script:Guard 2>&1 | Out-Null
        $LASTEXITCODE | Should -Be 2
    }
}

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
