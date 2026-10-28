# The read-only guard (docs/guard.md). The corpus in GuardCases.ps1 is asserted per tool: every block
# case under the Bash tool, the PowerShell tool and with no tool name; every allow case under the tool
# it is written for. Cases are answered from one batch process; a few go through the real hook path.
# Every case reaches the guard on stdin (see GuardHarness.ps1), never on a command line.

BeforeDiscovery {
    . (Join-Path $PSScriptRoot 'GuardCases.ps1')
    $seen = [System.Collections.Generic.HashSet[string]]::new()
    $script:BlockRows = foreach ($case in $script:GuardBlockCases) {
        $item = if ($case -is [string]) { @{ Command = $case } } else { $case }
        if ($seen.Add("$($item.Command)")) { @{ Command = $item.Command; AllowArg = [string]$item.Allow; Skipped = @($item.Skip | Where-Object { $_ }) } }
    }
    $script:AllowRows = foreach ($case in $script:GuardAllowCases) {
        @{ Command = $case.Command; ToolName = $case.Tool; AllowArg = [string]$case.Allow }
    }
    $script:OneToolRows = foreach ($case in $script:GuardBlockOneTool) { @{ Command = $case.Command; ToolName = $case.Tool } }
    $script:WithAllowRows = foreach ($case in $script:GuardBlockWithAllow) { @{ Command = $case.Command; AllowArg = [string]$case.Allow } }
}

BeforeAll {
    . (Join-Path $PSScriptRoot 'GuardHarness.ps1')
    . (Join-Path $PSScriptRoot 'GuardCases.ps1')
    $requests = [System.Collections.Generic.List[object]]::new()
    foreach ($case in $script:GuardBlockCases) {
        $item = if ($case -is [string]) { @{ Command = $case } } else { $case }
        foreach ($tool in 'Bash', 'PowerShell', 'None') { $requests.Add(@{ Command = $item.Command; Tool = $tool; Allow = [string]$item.Allow }) }
    }
    foreach ($case in $script:GuardBlockWithAllow) { foreach ($tool in 'Bash', 'PowerShell', 'None') { $requests.Add(@{ Command = $case.Command; Tool = $tool; Allow = [string]$case.Allow }) } }
    foreach ($case in $script:GuardBlockOneTool) { $requests.Add(@{ Command = $case.Command; Tool = $case.Tool; Allow = '' }) }
    foreach ($case in $script:GuardAllowCases) {
        $tools = switch ($case.Tool) { 'Both' { 'Bash', 'PowerShell' } default { $case.Tool } }
        foreach ($tool in $tools) { $requests.Add(@{ Command = $case.Command; Tool = $tool; Allow = [string]$case.Allow }) }
    }
    Initialize-GuardBatch -Cases $requests
}

Describe 'Read-only guard: must block' {
    It 'blocks <Command>' -ForEach $script:BlockRows {
        $tools = @('Bash', 'PowerShell', 'None') | Where-Object { $_ -notin $Skipped }
        $allowedBy = @(foreach ($tool in $tools) { if ((Get-GuardExit -Command $Command -Tool $tool -Allow $AllowArg) -ne 2) { $tool } })
        $allowedBy.Count | Should -Be 0 -Because "it was allowed under: $($allowedBy -join ', ')"
    }

    It 'blocks <Command> (with -Allow <AllowArg>)' -ForEach $script:WithAllowRows {
        $allowedBy = @(foreach ($tool in 'Bash', 'PowerShell', 'None') { if ((Get-GuardExit -Command $Command -Tool $tool -Allow $AllowArg) -ne 2) { $tool } })
        $allowedBy.Count | Should -Be 0 -Because "it was allowed under: $($allowedBy -join ', ')"
    }

    It 'blocks <Command> under the <ToolName> tool' -ForEach $script:OneToolRows {
        Get-GuardExit -Command $Command -Tool $ToolName | Should -Be 2
    }
}

Describe 'Read-only guard: must allow' {
    It 'allows <Command> under <ToolName>' -ForEach $script:AllowRows {
        $tools = switch ($ToolName) { 'Both' { 'Bash', 'PowerShell' } default { $ToolName } }
        $blockedBy = @(foreach ($tool in $tools) {
                $result = Get-GuardResult -Command $Command -Tool $tool -Allow $AllowArg
                if ($result.exit -ne 0) { "$tool ($($result.reason))" }
            })
        $blockedBy.Count | Should -Be 0 -Because "it was blocked under: $($blockedBy -join '; ')"
    }
}

Describe 'Read-only guard: limits and syntax' {
    It 'blocks a command over 8000 characters, and allows one at the limit' {
        $long = 'cat ' + ('a' * 7996)
        Get-GuardExit -Command $long -Tool Bash | Should -Be 0
        Get-GuardExit -Command ($long + 'a') -Tool Bash | Should -Be 2
        Get-GuardExit -Command ($long + 'a') -Tool PowerShell | Should -Be 2
    }

    It 'blocks control characters in both grammars' {
        Get-GuardExit -Command "cat README.md$([char]1)" -Tool Bash | Should -Be 2
        Get-GuardExit -Command "cat README.md$([char]1)" -Tool PowerShell | Should -Be 2
        Get-GuardExit -Command "cat README.md$([char]27)[0m" -Tool PowerShell | Should -Be 2
    }

    It 'blocks a line break in Bash, allows two read-only statements in PowerShell, and blocks both when the tool is unknown' {
        $text = "cat README.md`nls"
        Get-GuardExit -Command $text -Tool Bash | Should -Be 2
        Get-GuardExit -Command $text -Tool PowerShell | Should -Be 0
        Get-GuardExit -Command $text -Tool None | Should -Be 2
    }

    It 'blocks a syntax tree nested deeper than the limit' {
        Get-GuardExit -Command (('(' * 70) + '1' + (')' * 70)) -Tool PowerShell | Should -Be 2
        Get-GuardExit -Command 'Write-Output $(Write-Output $(Write-Output $(Get-Date)))' -Tool PowerShell | Should -Be 0
    }

    It 'blocks deep nesting at the maximum length without crashing the parser: <Name>' -ForEach @(
        @{ Name = '('; Text = (('(' * 3999) + '1' + (')' * 3999)) }
        @{ Name = '$('; Text = (('$(' * 2000) + '1' + (')' * 2000)) }
        @{ Name = '@('; Text = (('@(' * 2000) + '1' + (')' * 2000)) }
        @{ Name = '{'; Text = (('{' * 3999) + '}' * 3999) }
        @{ Name = '-not chain'; Text = (('-not ' * 1500) + '$true') }
        @{ Name = '! chain'; Text = (('!' * 7990) + '$x') }
        @{ Name = '-bnot chain'; Text = (('-bnot ' * 1300) + '1') }
        @{ Name = '[int] chain'; Text = (('[int]' * 1500) + '1') }
        @{ Name = '@{ chain'; Text = (('@{a=' * 1900) + '1' + ('}' * 1900)) }
        @{ Name = 'index chain'; Text = ('$x' + ('[0]' * 2600)) }
    ) {
        # One process each, the real hook path: a parser crash would show as an exit code other than 2.
        $text = $Text.Substring(0, [Math]::Min($Text.Length, 8000))
        Invoke-Guard -Command $text -Tool PowerShell | Should -Be 2
        Invoke-Guard -Command $text -Tool Bash | Should -Be 2
    }

    It 'blocks an empty command and one with no code in it' {
        Get-GuardExit -Command '' -Tool PowerShell | Should -Be 2
        Get-GuardExit -Command '   ' -Tool Bash | Should -Be 2
    }

    It 'blocks PowerShell syntax sent as Bash, with a pointer to the PowerShell tool' {
        $result = Get-GuardResult -Command 'Get-Content README.md | Select-Object -First 3' -Tool Bash
        $result.exit | Should -Be 2
        $result.reason | Should -Match 'PowerShell tool'
    }

    It 'gives a secret-printing option its own reason, not the file-writing one' -ForEach @(
        @{ Command = 'aws ssm get-parameter --name n --with-decryption' }
        @{ Command = 'az vm show -g rg -n web --show-values' }
    ) {
        $reason = (Get-GuardResult -Command $Command -Tool Bash).reason
        $reason | Should -Match 'prints secret values'
        $reason | Should -Not -Match 'opens a browser'
    }

    It 'says an aws read that prints environment variables prints secret values: <Command>' -ForEach @(
        @{ Command = 'aws lambda get-function --function-name f' }
        @{ Command = 'aws ecs describe-task-definition --task-definition t' }
    ) {
        (Get-GuardResult -Command $Command -Tool Bash).reason | Should -Match 'prints secret values'
    }

    It 'has no batch switch on the hook entry point (the test wrapper dot-sources the functions instead)' {
        Get-Content -LiteralPath $script:Guard -Raw | Should -Not -Match '(?i)\bbatch\b'
        Test-Path (Join-Path $PSScriptRoot 'GuardBatchRunner.ps1') | Should -BeTrue
    }

    It 'names the grammar when no tool name is given' {
        (Get-GuardResult -Command 'Get-Date' -Tool None).reason | Should -Match 'Bash grammar'
    }
}

Describe 'Read-only guard: the hook contract' {
    It 'reads hook JSON from stdin: allow, block, and a PowerShell tool payload' {
        Invoke-Guard -Command 'git status' -Tool Bash | Should -Be 0
        Invoke-Guard -Command 'git push' -Tool Bash | Should -Be 2
        Invoke-Guard -Command 'Get-ChildItem | Where-Object { $_.Length -gt 1 }' -Tool PowerShell | Should -Be 0
        Invoke-Guard -Command 'Get-ChildItem | ForEach-Object { Remove-Item $_ }' -Tool PowerShell | Should -Be 2
        Invoke-Guard -Command 'git status' -Tool None | Should -Be 0
    }

    It 'blocks input it cannot read, with a reason on stderr' {
        $output = 'not json' | & pwsh -NoProfile -NonInteractive -File $script:Guard 2>&1
        $LASTEXITCODE | Should -Be 2
        (@($output) -join ' ') | Should -Match 'Read-only role: blocked'
    }

    It 'blocks a payload with no command, a non-string command, and an unknown or non-string tool' -ForEach @(
        @{ Json = '{"tool_input":{}}' }
        @{ Json = '{"tool_name":"Bash"}' }
        @{ Json = '{"tool_name":"Bash","tool_input":{"command":5}}' }
        @{ Json = '{"tool_name":"Bash","tool_input":{"command":["git status"]}}' }
        @{ Json = '{"tool_name":"Read","tool_input":{"command":"git status"}}' }
        @{ Json = '{"tool_name":"bash","tool_input":{"command":"git status"}}' }
        @{ Json = '{"tool_name":5,"tool_input":{"command":"git status"}}' }
        @{ Json = '{"tool_name":"","tool_input":{"command":"git status"}}' }
        @{ Json = '{"tool_name":["Bash"],"tool_input":{"command":"git status"}}' }
        @{ Json = '[{"tool_name":"Bash","tool_input":{"command":"git status"}}]' }
        @{ Json = '{"tool_name":"Bash","tool_input":["git status"]}' }
        @{ Json = '"git status"' }
        @{ Json = '5' }
        @{ Json = '{"tool_name":"Bash","tool_input":{"command":"rm -rf x","command":"git status"}}' }
        @{ Json = '{"tool_name":"Bash","tool_input":{"command":"git status","command":"rm -rf x"}}' }
        @{ Json = '{"tool_name":"Bash","tool_name":"PowerShell","tool_input":{"command":"git status"}}' }
        @{ Json = 'null' }
        @{ Json = '[]' }
    ) {
        $null = $Json | & pwsh -NoProfile -NonInteractive -File $script:Guard 2>&1
        $LASTEXITCODE | Should -Be 2
    }

    It 'ignores other hook fields' {
        $json = '{"tool_name":"Bash","run_in_background":true,"timeout":5,"description":"x","tool_input":{"command":"git status","description":"y"}}'
        $null = $json | & pwsh -NoProfile -NonInteractive -File $script:Guard 2>&1
        $LASTEXITCODE | Should -Be 0
    }

    It 'gives one reason line that names what was blocked' {
        $result = Invoke-Guard -Command 'Invoke-ScriptAnalyzer -Path x -Fi' -Tool PowerShell -Stderr
        $result.Exit | Should -Be 2
        $result.Message | Should -Match "^Read-only role: blocked: .*'-Fi'.*write parameter names in full"
        $bash = Invoke-Guard -Command 'git push' -Tool Bash -Stderr
        $bash.Message | Should -Match "^Read-only role: blocked: 'git push' isn't a known read-only git command"
    }

    It 'judges -Command with -Tool, and with no tool as both grammars (benign text only)' {
        # Direct use. The text is benign on purpose: only hook JSON on stdin carries case text.
        $null = & pwsh -NoProfile -NonInteractive -File $script:Guard -Command 'git status' -Tool Bash 2>&1
        $LASTEXITCODE | Should -Be 0
        $null = & pwsh -NoProfile -NonInteractive -File $script:Guard -Command 'git status' -Tool PowerShell 2>&1
        $LASTEXITCODE | Should -Be 0
        $null = & pwsh -NoProfile -NonInteractive -File $script:Guard -Command 'git status' 2>&1
        $LASTEXITCODE | Should -Be 0
        $null = & pwsh -NoProfile -NonInteractive -File $script:Guard -Command 'git status' -Tool Read 2>&1
        $LASTEXITCODE | Should -Be 2
    }

    It 'blocks when the rule data cannot be loaded' {
        $copy = Join-Path $TestDrive 'guard-copy'
        New-Item -ItemType Directory $copy | Out-Null
        Copy-Item $script:Guard $copy
        $payload = New-GuardPayload -Command 'git status' -Tool Bash
        $null = $payload | & pwsh -NoProfile -NonInteractive -File (Join-Path $copy 'Test-GuildReadOnlyCommand.ps1') 2>&1
        $LASTEXITCODE | Should -Be 2
        Set-Content -LiteralPath (Join-Path $copy 'Test-GuildReadOnlyCommand.psd1') -Value '@{ NativeCommands = @{} }'
        $null = $payload | & pwsh -NoProfile -NonInteractive -File (Join-Path $copy 'Test-GuildReadOnlyCommand.ps1') 2>&1
        $LASTEXITCODE | Should -Be 2
    }
}
