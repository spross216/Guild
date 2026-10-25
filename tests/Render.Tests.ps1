BeforeAll {
    Import-Module (Join-Path $PSScriptRoot '../Guild/Guild.psd1') -Force
    $script:RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).ProviderPath
}

Describe 'Role sources' {
    It 'has the four roles with valid frontmatter' {
        InModuleScope Guild {
            $roles = @(Get-GuildRole)
            $roles.Id | Should -Be @('architect', 'builder', 'reviewer', 'steward')
            ($roles | Where-Object Access -EQ 'read-only').Id | Should -Be @('reviewer')
            ($roles | Where-Object Access -EQ 'docs').Id | Should -Be @('architect')
        }
    }

    It 'has a bound and a fallback snippet for every capability' {
        InModuleScope Guild {
            foreach ($name in $script:GuildCapabilityNames) {
                foreach ($variant in 'tool', 'none') {
                    Join-Path $script:GuildRepoRoot "capabilities/$($name.ToLowerInvariant()).$variant.md" | Should -Exist
                }
            }
        }
    }
}

Describe 'Rendering' {
    It 'leaves no tokens behind, with no packs' {
        InModuleScope Guild {
            $pack = Resolve-GuildPack
            foreach ($role in Get-GuildRole) {
                $body = Get-GuildRoleBody -Role $role -Pack $pack -Languages $null
                $body | Should -Not -Match '\{\{'
                $body | Should -Match 'Shared rules'
            }
            foreach ($skill in Get-GuildSkill) { New-GuildSkillFile -Skill $skill -Pack $pack | Should -Not -Match '\{\{' }
        }
    }

    It 'uses the fallback when a capability is unbound and the command when it is bound' {
        InModuleScope Guild {
            $pack = Resolve-GuildPack
            $builder = Get-GuildRole | Where-Object Id -EQ 'builder'
            Get-GuildRoleBody -Role $builder -Pack $pack -Languages $null | Should -Match 'No check is configured'

            $pack.Capabilities = @{ Check = @{ Command = @('Invoke-ProjectCheck -Path .'); Module = 'ProjectTools' } }
            $bound = Get-GuildRoleBody -Role $builder -Pack $pack -Languages $null
            $bound | Should -Match '`Invoke-ProjectCheck -Path \.`'
            $bound | Should -Match 'load the `ProjectTools` module first'
            $bound | Should -Not -Match 'No check is configured'
        }
    }

    It 'shows only the style guides for the project''s languages, plus general ones' {
        InModuleScope Guild {
            $pack = Resolve-GuildPack -Path (Join-Path $script:GuildRepoRoot 'packs/example/example.pack.psd1')
            $style = Format-GuildSection -Name style -Pack $pack -Languages @('python')
            $style | Should -Not -Match 'powershell:'
            $style | Should -Match 'all languages'
            Format-GuildSection -Name style -Pack $pack -Languages @('powershell') | Should -Match 'powershell:'
        }
    }

    It 'appends the pack''s addendum to its role only' {
        InModuleScope Guild {
            $pack = Resolve-GuildPack -Path (Join-Path $script:GuildRepoRoot 'packs/example/example.pack.psd1')
            $roles = @(Get-GuildRole)
            Get-GuildRoleBody -Role ($roles | Where-Object Id -EQ 'reviewer') -Pack $pack -Languages $null | Should -Match 'Acme review notes'
            Get-GuildRoleBody -Role ($roles | Where-Object Id -EQ 'builder') -Pack $pack -Languages $null | Should -Not -Match 'Acme review notes'
        }
    }

    It 'throws on an unknown token' {
        InModuleScope Guild {
            { Expand-GuildText -Text 'see {{nonsense}}' -Pack (Resolve-GuildPack) -Source 'test' } | Should -Throw -ExpectedMessage '*unknown token {{nonsense}}*'
        }
    }

    It 'writes the same body for every harness, apart from the role-name separator' {
        InModuleScope Guild {
            $pack = Resolve-GuildPack
            $role = Get-GuildRole | Where-Object Id -EQ 'reviewer'
            $bodies = foreach ($adapter in Get-GuildAdapter) {
                $script:GuildNameSeparator = if ($adapter.NameSeparator) { $adapter.NameSeparator } else { '-' }
                try {
                    $file = New-GuildRoleFile -Adapter $adapter -Role $role -Pack $pack -Body (Get-GuildRoleBody -Role $role -Pack $pack -Languages $null)
                    $body = if ($adapter.Format -eq 'codex') { ($file -split "developer_instructions = '''`n", 2)[1] -replace "'''`n$", '' }
                    else { ($file -split '-->\n\n', 2)[1] }
                    $body.Replace('guild_', 'guild-').TrimEnd("`n")
                }
                finally { $script:GuildNameSeparator = '-' }
            }
            @($bodies | Select-Object -Unique) | Should -HaveCount 1
        }
    }
}

Describe 'Neutrality' {
    It 'names no company or product in <Path>' -ForEach @(
        @{ Path = 'roles' }, @{ Path = 'core' }, @{ Path = 'capabilities' }, @{ Path = 'skills' }, @{ Path = 'style' },
        @{ Path = 'adapters' }, @{ Path = 'packs' }, @{ Path = 'Guild' }, @{ Path = 'guards' }, @{ Path = 'docs' }, @{ Path = 'scaffolds' }, @{ Path = 'README.md' }, @{ Path = 'AGENTS.md' }
    ) {
        # Names that must never appear in the framework: tooling products by default, plus any company
        # or product names you keep in tests/neutral-terms.local.txt (git-ignored, one per line).
        $terms = @('automation-forge', 'forge')
        $local = Join-Path $script:RepoRoot 'tests/neutral-terms.local.txt'
        if (Test-Path $local) { $terms += @(Get-Content $local | ForEach-Object { $_.Trim() } | Where-Object { $_ -and $_ -notmatch '^#' }) }
        $pattern = '(?i)\b(' + (($terms | ForEach-Object { [regex]::Escape($_) }) -join '|') + ')\b'
        $hits = Get-ChildItem -LiteralPath (Join-Path $script:RepoRoot $Path) -Recurse -File |
            Select-String -Pattern $pattern -AllMatches
        $hits | ForEach-Object { "$($_.Path):$($_.LineNumber)" } | Should -BeNullOrEmpty
    }

    It 'keeps cloud providers out of the role prose' {
        $hits = Get-ChildItem -LiteralPath (Join-Path $script:RepoRoot 'roles'), (Join-Path $script:RepoRoot 'core'), (Join-Path $script:RepoRoot 'capabilities'), (Join-Path $script:RepoRoot 'skills') -Recurse -File |
            Select-String -Pattern '\b(azure|aws|gcp|google cloud|entra|bicep)\b'
        $hits | ForEach-Object { "$($_.Path):$($_.LineNumber)" } | Should -BeNullOrEmpty
    }
}
