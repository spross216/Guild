BeforeAll {
    Import-Module (Join-Path $PSScriptRoot '../Guild/Guild.psd1') -Force
    $script:ExamplePack = (Resolve-Path (Join-Path $PSScriptRoot '../packs/example/example.pack.psd1')).ProviderPath

    function New-TestProject {
        $path = Join-Path $TestDrive "project-$([guid]::NewGuid().ToString('N').Substring(0, 8))"
        New-Item -ItemType Directory $path | Out-Null
        Set-Content (Join-Path $path 'main.ps1') 'Write-Output 1'
        $path
    }
}

Describe 'Install-GuildAgents' {
    BeforeEach {
        $script:Project = New-TestProject
        $env:GUILD_HOME = Join-Path $TestDrive "home-$([guid]::NewGuid().ToString('N').Substring(0, 8))"
        New-Item -ItemType Directory $env:GUILD_HOME | Out-Null
    }
    AfterEach { Remove-Item Env:GUILD_HOME -ErrorAction SilentlyContinue }

    It 'installs every harness at project scope' {
        $harnesses = @((Get-GuildHarness).Name)
        $result = Install-GuildAgents -Harness $harnesses -Scope Project -Path $Project -InformationAction SilentlyContinue
        $result | Where-Object Action -EQ 'Skipped' | Should -BeNullOrEmpty
        foreach ($expected in '.claude/agents/guild-reviewer.md', '.github/agents/guild-reviewer.agent.md', '.codex/agents/guild_reviewer.toml',
            '.opencode/agents/guild-reviewer.md', '.guild/roles/guild-reviewer.md', '.claude/skills/guild-deliver/SKILL.md', 'AGENTS.md', '.guild/manifest.json') {
            Join-Path $Project $expected | Should -Exist
        }
    }

    It 'installs at user scope under GUILD_HOME' {
        Install-GuildAgents -Harness claude -InformationAction SilentlyContinue | Out-Null
        Join-Path $env:GUILD_HOME '.claude/agents/guild-architect.md' | Should -Exist
        Join-Path $env:GUILD_HOME '.guild/manifest.json' | Should -Exist
    }

    It 'is idempotent' {
        Install-GuildAgents -Harness claude, agents-md -Scope Project -Path $Project -InformationAction SilentlyContinue | Out-Null
        $second = Install-GuildAgents -Harness claude, agents-md -Scope Project -Path $Project -InformationAction SilentlyContinue
        $second.Action | Select-Object -Unique | Should -Be 'Unchanged'
    }

    It 'writes the claude read-only hook and model only where they belong' {
        Install-GuildAgents -Harness claude -Scope Project -Path $Project -InformationAction SilentlyContinue | Out-Null
        $reviewer = Get-Content (Join-Path $Project '.claude/agents/guild-reviewer.md') -Raw
        $builder = Get-Content (Join-Path $Project '.claude/agents/guild-builder.md') -Raw
        $reviewer | Should -Match 'PreToolUse'
        $reviewer | Should -Match 'tools: Read, Grep, Glob, Bash\n'
        $reviewer | Should -Match 'model: opus'
        $builder | Should -Not -Match 'PreToolUse'
        $builder | Should -Match 'model: sonnet'
    }

    It 'gives the architect docs access: Markdown-only edits and the command guard' {
        Install-GuildAgents -Harness claude, copilot, opencode -Scope Project -Path $Project -InformationAction SilentlyContinue | Out-Null
        $claude = Get-Content (Join-Path $Project '.claude/agents/guild-architect.md') -Raw
        $claude | Should -Match 'tools: Read, Grep, Glob, Edit, Write, Bash\n'
        $claude | Should -Match 'Test-GuildReadOnlyCommand\.ps1'
        $claude | Should -Match "-Allow 'New-GuildDecision'"
        $claude | Should -Match 'matcher: "Edit\|Write\|MultiEdit\|NotebookEdit"'
        $claude | Should -Match 'Test-GuildDocsEdit\.ps1'
        Get-Content (Join-Path $Project '.github/agents/guild-architect.agent.md') -Raw | Should -Match "tools: \['read', 'search', 'edit'\]"
        Get-Content (Join-Path $Project '.opencode/agents/guild-architect.md') -Raw | Should -Match 'edit: ask'
        Get-Content (Join-Path $Project '.claude/agents/guild-builder.md') -Raw | Should -Not -Match 'Test-GuildDocsEdit'
    }

    It 'tells every role how to load the Guild tools' {
        Install-GuildAgents -Harness generic -Scope Project -Path $Project -InformationAction SilentlyContinue | Out-Null
        foreach ($role in 'architect', 'builder', 'reviewer', 'steward') {
            Get-Content (Join-Path $Project ".guild/roles/guild-$role.md") -Raw | Should -Match "## Guild tools[\s\S]*Import-Module '.+/Guild/Guild\.psd1'"
        }
    }

    It 'writes the routing block where Claude Code always reads, and keeps what was there' {
        New-Item -ItemType Directory (Join-Path $env:GUILD_HOME '.claude') -Force | Out-Null
        Set-Content (Join-Path $env:GUILD_HOME '.claude/CLAUDE.md') '# My own instructions'
        Install-GuildAgents -Harness claude -InformationAction SilentlyContinue | Out-Null
        $text = Get-Content (Join-Path $env:GUILD_HOME '.claude/CLAUDE.md') -Raw
        $text | Should -Match '# My own instructions'
        $text | Should -Match '## Agent routing'
        $text | Should -Match '\| design, architecture[^|]*\| `guild-architect` \|'
        $text | Should -Match 'guild-deliver'
        (Test-GuildInstall -Harness claude | Where-Object Kind -EQ 'Routing').Status | Should -Be 'Current'
        Uninstall-GuildAgents -Harness claude | Out-Null
        (Get-Content (Join-Path $env:GUILD_HOME '.claude/CLAUDE.md') -Raw).Trim() | Should -Be '# My own instructions'
    }

    It 'keeps a routing block and an instructions block side by side in AGENTS.md' {
        Install-GuildAgents -Harness codex, agents-md -Scope Project -Path $Project -InformationAction SilentlyContinue | Out-Null
        $text = Get-Content (Join-Path $Project 'AGENTS.md') -Raw
        $text | Should -Match 'guild-routing:begin'
        $text | Should -Match 'guild:begin'
        $text | Should -Match '`guild_reviewer`'
        Uninstall-GuildAgents -Harness codex -Scope Project -Path $Project | Out-Null
        $after = Get-Content (Join-Path $Project 'AGENTS.md') -Raw
        $after | Should -Not -Match 'guild-routing:begin'
        $after | Should -Match 'guild:begin'
    }

    It 'skips routing with -NoRouting, and writes it for Copilot in the repository' {
        Install-GuildAgents -Harness claude -Scope Project -Path $Project -NoRouting -InformationAction SilentlyContinue | Out-Null
        Join-Path $Project 'CLAUDE.md' | Should -Not -Exist
        Install-GuildAgents -Harness copilot -Scope Project -Path $Project -InformationAction SilentlyContinue | Out-Null
        Get-Content (Join-Path $Project '.github/copilot-instructions.md') -Raw | Should -Match '`guild-builder`'
    }

    It 'invites Claude Code to delegate on its own' {
        Install-GuildAgents -Harness claude -Scope Project -Path $Project -InformationAction SilentlyContinue | Out-Null
        Get-Content (Join-Path $Project '.claude/agents/guild-builder.md') -Raw | Should -Match 'description: ".*Use proactively for: writing or changing code'
    }

    It 'applies model overrides by role and by tier' {
        Install-GuildAgents -Harness claude -Scope Project -Path $Project -Model @{ reviewer = 'haiku'; top = 'sonnet' } -InformationAction SilentlyContinue | Out-Null
        Get-Content (Join-Path $Project '.claude/agents/guild-reviewer.md') -Raw | Should -Match 'model: haiku'
        Get-Content (Join-Path $Project '.claude/agents/guild-architect.md') -Raw | Should -Match 'model: sonnet'
    }

    It 'passes bound read-only commands to the guard' {
        $packDir = Join-Path $TestDrive 'tooling'
        New-Item -ItemType Directory $packDir -Force | Out-Null
        Set-Content "$packDir/tools.pack.psd1" "@{ Name = 'tools'; Version = '1.0.0'; Contract = '1'; Capabilities = @{ Check = @{ Command = 'Test-MyProject -Path <project>' }; Diagnose = @{ Command = 'Get-MyLog', 'Get-MyHealth' } } }"
        Install-GuildAgents -Harness claude -Scope Project -Path $Project -Pack "$packDir/tools.pack.psd1" -InformationAction SilentlyContinue | Out-Null
        Get-Content (Join-Path $Project '.claude/agents/guild-reviewer.md') -Raw | Should -Match "-Allow 'Get-MyHealth,Get-MyLog,Test-MyProject'"
    }

    It 'writes paths inside the project relative to it' {
        $packDir = Join-Path $Project 'standards'
        New-Item -ItemType Directory "$packDir/style" -Force | Out-Null
        Set-Content "$packDir/style/powershell.md" '# style'
        Set-Content "$packDir/local.pack.psd1" "@{ Name = 'local'; Version = '1.0.0'; Contract = '1'; Style = @(@{ Language = 'powershell'; Guide = 'style/powershell.md' }) }"
        Install-GuildAgents -Harness generic -Scope Project -Path $Project -Pack "$packDir/local.pack.psd1" -InformationAction SilentlyContinue | Out-Null
        $text = Get-Content (Join-Path $Project '.guild/roles/guild-builder.md') -Raw
        $text | Should -Match '`standards/style/powershell.md`'
        $text | Should -Not -Match ([regex]::Escape($Project.Replace('\', '/')))
    }

    It 'leaves a file it did not write alone' {
        $target = Join-Path $Project '.claude/agents/guild-reviewer.md'
        New-Item -ItemType Directory (Split-Path $target) -Force | Out-Null
        Set-Content $target 'my own reviewer'
        $result = Install-GuildAgents -Harness claude -Scope Project -Path $Project -InformationAction SilentlyContinue -WarningAction SilentlyContinue
        ($result | Where-Object Name -EQ 'guild-reviewer').Action | Should -Be 'Skipped'
        Get-Content $target -Raw | Should -Match 'my own reviewer'
    }

    It 'refuses to replace a hand-edited file unless -Force' {
        Install-GuildAgents -Harness generic -Scope Project -Path $Project -InformationAction SilentlyContinue | Out-Null
        $target = Join-Path $Project '.guild/roles/guild-builder.md'
        Add-Content $target 'local tweak'
        $again = Install-GuildAgents -Harness generic -Scope Project -Path $Project -InformationAction SilentlyContinue -WarningAction SilentlyContinue
        ($again | Where-Object Name -EQ 'guild-builder').Action | Should -Be 'Skipped'
        Get-Content $target -Raw | Should -Match 'local tweak'
        $forced = Install-GuildAgents -Harness generic -Scope Project -Path $Project -Force -InformationAction SilentlyContinue
        ($forced | Where-Object Name -EQ 'guild-builder').Action | Should -Be 'Updated'
        Get-Content $target -Raw | Should -Not -Match 'local tweak'
    }

    It 'leaves a hand-edited file in place when it is no longer produced' {
        Install-GuildAgents -Harness generic -Scope Project -Path $Project -InformationAction SilentlyContinue | Out-Null
        $target = Join-Path $Project '.guild/roles/guild-builder.md'
        Add-Content $target 'local tweak'
        $result = Install-GuildAgents -Harness generic -Scope Project -Path $Project -Pack $ExamplePack -InformationAction SilentlyContinue -WarningAction SilentlyContinue
        ($result | Where-Object Path -EQ $target).Action | Should -Be 'Skipped'
        $target | Should -Exist
    }

    It 'removes files no longer produced (a prefix change)' {
        Install-GuildAgents -Harness copilot -Scope Project -Path $Project -InformationAction SilentlyContinue | Out-Null
        $result = Install-GuildAgents -Harness copilot -Scope Project -Path $Project -Pack $ExamplePack -InformationAction SilentlyContinue
        ($result | Where-Object Action -EQ 'Removed').Count | Should -Be 6
        Join-Path $Project '.github/agents/guild-reviewer.agent.md' | Should -Not -Exist
        Join-Path $Project '.github/agents/acme-reviewer.agent.md' | Should -Exist
    }

    It 'keeps a shared file while another harness still uses it' {
        Install-GuildAgents -Harness generic, agents-md -Scope Project -Path $Project -InformationAction SilentlyContinue | Out-Null
        Uninstall-GuildAgents -Harness agents-md -Scope Project -Path $Project | Out-Null
        Join-Path $Project '.guild/roles/guild-reviewer.md' | Should -Exist
        Uninstall-GuildAgents -Harness generic -Scope Project -Path $Project | Out-Null
        Join-Path $Project '.guild/roles/guild-reviewer.md' | Should -Not -Exist
    }

    It 'keeps the rest of AGENTS.md when it adds and removes its block' {
        Set-Content (Join-Path $Project 'AGENTS.md') "# Project`n`nOur own instructions."
        Install-GuildAgents -Harness agents-md -Scope Project -Path $Project -InformationAction SilentlyContinue | Out-Null
        $text = Get-Content (Join-Path $Project 'AGENTS.md') -Raw
        $text | Should -Match 'Our own instructions'
        $text | Should -Match 'guild:begin'
        $text | Should -Match 'guild-reviewer.md'
        Uninstall-GuildAgents -Harness agents-md -Scope Project -Path $Project | Out-Null
        $after = Get-Content (Join-Path $Project 'AGENTS.md') -Raw
        $after | Should -Not -Match 'guild:begin'
        $after.Trim() | Should -Be "# Project`n`nOur own instructions."
    }

    It 'deletes an AGENTS.md it created when its block is removed' {
        Install-GuildAgents -Harness agents-md -Scope Project -Path $Project -InformationAction SilentlyContinue | Out-Null
        Uninstall-GuildAgents -Harness agents-md -Scope Project -Path $Project | Out-Null
        Join-Path $Project 'AGENTS.md' | Should -Not -Exist
    }

    It 'changes nothing with -WhatIf' {
        Install-GuildAgents -Harness claude -Scope Project -Path $Project -WhatIf -InformationAction SilentlyContinue | Out-Null
        Join-Path $Project '.claude' | Should -Not -Exist
        Join-Path $Project '.guild' | Should -Not -Exist
    }

    It 'refuses user scope for a project-only harness' {
        { Install-GuildAgents -Harness agents-md -InformationAction SilentlyContinue } | Should -Throw -ExpectedMessage '*project scope only*'
    }

    It 'detects harnesses from project markers' {
        New-Item -ItemType Directory (Join-Path $Project '.opencode') | Out-Null
        $result = Install-GuildAgents -Harness auto -Scope Project -Path $Project -InformationAction SilentlyContinue
        $result.Harness | Select-Object -Unique | Should -Be 'opencode'
    }
}

Describe 'Test-GuildInstall' {
    BeforeEach { $script:Project = New-TestProject }

    It 'reports Missing, Current, Outdated, Edited and Foreign' {
        (Test-GuildInstall -Harness claude -Scope Project -Path $Project | Select-Object -First 1).Status | Should -Be 'Missing'
        Install-GuildAgents -Harness claude -Scope Project -Path $Project -InformationAction SilentlyContinue | Out-Null
        Test-GuildInstall -Harness claude -Scope Project -Path $Project | ForEach-Object Status | Select-Object -Unique | Should -Be 'Current'

        $status = { param($name) (Test-GuildInstall -Harness claude -Scope Project -Path $Project -Model @{ top = 'sonnet' } | Where-Object Name -EQ $name).Status }
        & $status 'guild-reviewer' | Should -Be 'Outdated'

        Add-Content (Join-Path $Project '.claude/agents/guild-builder.md') 'tweak'
        & $status 'guild-builder' | Should -Be 'Edited'

        Set-Content (Join-Path $Project '.claude/agents/guild-steward.md') 'not ours'
        $manifest = Get-Content (Join-Path $Project '.guild/manifest.json') -Raw | ConvertFrom-Json -AsHashtable
        $manifest.Files.Remove('.claude/agents/guild-steward.md')
        $manifest | ConvertTo-Json -Depth 6 | Set-Content (Join-Path $Project '.guild/manifest.json')
        & $status 'guild-steward' | Should -Be 'Foreign'
    }
}
