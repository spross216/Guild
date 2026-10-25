# Packs that add roles, add or replace skills, and extend the main session's delivery procedure.

BeforeAll {
    Import-Module (Join-Path $PSScriptRoot '../Guild/Guild.psd1') -Force

    $script:PackDir = Join-Path $TestDrive 'org'
    New-Item -ItemType Directory "$PackDir/roles", "$PackDir/addenda", "$PackDir/skills/code-review", "$PackDir/skills/bicep" -Force | Out-Null
    Set-Content "$PackDir/roles/security.md" @'
---
name: security
description: Read-only security reviewer. Use for changes touching identity, secrets or the network; hand findings to {{role:builder}}.
access: read-only
tier: top
---
You are **{{role:security}}**. Review adversarially.

{{knowledge}}
'@
    Set-Content "$PackDir/addenda/deliver.md" "## Organization routing`n`n- Anything touching identity also goes to {{role:security}}."
    # A skill without frontmatter, like many in existing standards repositories.
    Set-Content "$PackDir/skills/code-review/SKILL.md" "# SKILL: Code Review`n`n> Canonical note.`n`nProcedure for reviewing code against standards/security.md.`n`n1. Read the diff."
    Set-Content "$PackDir/skills/bicep/SKILL.md" "---`nname: bicep`ndescription: `"Use when changing Bicep.`"`n---`n# Bicep`n`nUse modules. Keep `${{ secrets.X }}` out."
    Set-Content "$PackDir/org.pack.psd1" @'
@{
    Name        = 'org'
    Version     = '1.0.0'
    Contract    = '1'
    Roles       = @('roles/security.md')
    Skills      = @(@{ Path = 'skills'; Root = '.' })
    RoleAddenda = @{ deliver = 'addenda/deliver.md' }
    Models      = @{ claude = @{ Roles = @{ security = 'opus' } } }
}
'@
    $script:Pack = "$PackDir/org.pack.psd1"
}

Describe 'Pack roles' {
    It 'adds the pack''s role to the roster and renders its tokens' {
        InModuleScope Guild -Parameters @{ P = $Pack } {
            param($P)
            $merged = Resolve-GuildPack -Path $P
            (Get-GuildRole -Pack $merged).Id | Should -Be @('architect', 'builder', 'reviewer', 'steward', 'security')
            $security = Get-GuildRole -Pack $merged | Where-Object Id -EQ 'security'
            $body = Get-GuildRoleBody -Role $security -Pack $merged -Languages $null
            $body | Should -Match 'You are \*\*guild-security\*\*'
            $body | Should -Match 'Shared rules'
        }
    }

    It 'installs the pack role read-only with its model' {
        $project = Join-Path $TestDrive 'project-roles'
        New-Item -ItemType Directory $project | Out-Null
        Install-GuildAgents -Harness claude -Scope Project -Path $project -Pack $Pack -InformationAction SilentlyContinue | Out-Null
        $text = Get-Content (Join-Path $project '.claude/agents/guild-security.md') -Raw
        $text | Should -Match 'tools: Read, Grep, Glob, Bash\n'
        $text | Should -Match 'PreToolUse'
        $text | Should -Match 'model: opus'
    }

    It 'refuses a pack role that reuses a name' {
        $dir = Join-Path $TestDrive 'clash'
        New-Item -ItemType Directory $dir | Out-Null
        Set-Content "$dir/reviewer.md" "---`nname: reviewer`ndescription: x`naccess: read-only`ntier: top`n---`nbody"
        Set-Content "$dir/clash.pack.psd1" "@{ Name = 'clash'; Version = '1.0.0'; Contract = '1'; Roles = @('reviewer.md') }"
        InModuleScope Guild -Parameters @{ P = "$dir/clash.pack.psd1" } {
            param($P)
            { Get-GuildRole -Pack (Resolve-GuildPack -Path $P) } | Should -Throw "*'reviewer' is already taken*"
        }
    }

    It 'rejects an addendum or model for a role nobody defines' {
        $dir = Join-Path $TestDrive 'unknown'
        New-Item -ItemType Directory $dir | Out-Null
        Set-Content "$dir/a.md" 'x'
        Set-Content "$dir/u.pack.psd1" "@{ Name = 'u'; Version = '1.0.0'; Contract = '1'; RoleAddenda = @{ tester = 'a.md' } }"
        { Get-GuildPack -Pack "$dir/u.pack.psd1" } | Should -Throw "*unknown role 'tester'*"
    }
}

Describe 'Pack skills' {
    It 'replaces a Guild skill of the same name and adds new ones, used as written' {
        InModuleScope Guild -Parameters @{ P = $Pack } {
            param($P)
            $merged = Resolve-GuildPack -Path $P
            $skills = @(Get-GuildSkill -Pack $merged)
            $skills.Id | Should -Be @('code-review', 'deliver', 'bicep')
            $review = $skills | Where-Object Id -EQ 'code-review'
            $review.External | Should -BeTrue
            $review.Description | Should -Be 'Procedure for reviewing code against standards/security.md.'
            $file = New-GuildSkillFile -Skill ($skills | Where-Object Id -EQ 'bicep') -Pack $merged
            $file | Should -Match 'name: guild-bicep'
            $file | Should -Match 'description: "Use when changing Bicep\."'
            $file | Should -Match 'Relative paths in this skill are relative to'
            $file | Should -Match '\$\{\{ secrets\.X \}\}' -Because 'pack skills are not token-expanded'
        }
    }

    It 'appends the pack''s deliver addendum to the delivery procedure' {
        InModuleScope Guild -Parameters @{ P = $Pack } {
            param($P)
            $merged = Resolve-GuildPack -Path $P
            $deliver = Get-GuildSkill -Pack $merged | Where-Object Id -EQ 'deliver'
            $body = Get-GuildSkillBody -Skill $deliver -Pack $merged
            $body | Should -Match 'Delivering a change'
            $body | Should -Match 'also goes to guild-security'
        }
    }

    It 'carries pack roles and the addendum into an instructions block' {
        $project = Join-Path $TestDrive 'project-block'
        New-Item -ItemType Directory $project | Out-Null
        Install-GuildAgents -Harness agents-md -Scope Project -Path $project -Pack $Pack -InformationAction SilentlyContinue | Out-Null
        $text = Get-Content (Join-Path $project 'AGENTS.md') -Raw
        $text | Should -Match 'guild-security\.md'
        $text | Should -Match 'Organization routing'
        Join-Path $project '.guild/skills/guild-bicep/SKILL.md' | Should -Exist
    }
}

Describe 'Pack capability modules' {
    It 'resolves a module path relative to the pack and tells the role to import it' {
        $dir = Join-Path $TestDrive 'tooling'
        New-Item -ItemType Directory "$dir/checks" -Force | Out-Null
        Set-Content "$dir/checks/Tools.psd1" '@{}'
        Set-Content "$dir/tools.pack.psd1" "@{ Name = 'tools'; Version = '1.0.0'; Contract = '1'; Capabilities = @{ Check = @{ Command = 'Test-Thing -Path <project>'; Module = 'checks/Tools.psd1' } } }"
        InModuleScope Guild -Parameters @{ P = "$dir/tools.pack.psd1"; D = $dir.Replace('\', '/') } {
            param($P, $D)
            $merged = Resolve-GuildPack -Path $P
            $merged.Capabilities.Check.Module | Should -Be "$D/checks/Tools.psd1"
            Get-GuildCapabilityText -Name Check -Pack $merged | Should -Match ([regex]::Escape("first run ``Import-Module '$D/checks/Tools.psd1'``"))
        }
    }

    It 'keeps a bare module name as a name' {
        InModuleScope Guild {
            $pack = Resolve-GuildPack
            $pack.Capabilities = @{ Check = @{ Command = @('Test-Thing'); Module = 'ThingTools' } }
            Get-GuildCapabilityText -Name Check -Pack $pack | Should -Match 'load the `ThingTools` module first'
        }
    }
}
