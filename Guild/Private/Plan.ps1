function Find-GuildHarness {
    # Harnesses in use: a command on PATH (user scope) or a marker directory (project scope).
    [CmdletBinding()]
    [OutputType([string[]])]
    param([Parameter(Mandatory)][ValidateSet('User', 'Project')][string] $Scope, [Parameter(Mandatory)][string] $Root)
    @(foreach ($adapter in Get-GuildAdapter) {
            $detect = $adapter.Detect
            if (-not $detect) { continue }
            $found = if ($Scope -eq 'User') { @($detect.Command | Where-Object { $_ -and (Get-Command $_ -ErrorAction SilentlyContinue) }).Count -gt 0 }
            else { @($detect.ProjectMarker | Where-Object { $_ -and (Test-Path -LiteralPath (Join-Path $Root $_)) }).Count -gt 0 }
            if ($found) { $adapter.Name }
        })
}

function Resolve-GuildHarnessList {
    [CmdletBinding()]
    [OutputType([string[]])]
    param([Parameter(Mandatory)][string[]] $Harness, [Parameter(Mandatory)][string] $Scope, [Parameter(Mandatory)][string] $Root)
    $names = foreach ($name in $Harness) {
        if ($name -eq 'auto') {
            $detected = Find-GuildHarness -Scope $Scope -Root $Root
            if (-not $detected) { throw 'No supported harness detected. Name one with -Harness (Get-GuildHarness lists them).' }
            $detected
        }
        else { (Get-GuildAdapter -Name $name).Name }
    }
    @($names | Select-Object -Unique)
}

function Get-GuildInstallPlan {
    # Every file (and instructions block) one harness needs, with its full content. Nothing is written.
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][object] $Adapter,
        [Parameter(Mandatory)][ValidateSet('User', 'Project')][string] $Scope,
        [Parameter(Mandatory)][string] $Root,
        [Parameter(Mandatory)][hashtable] $Pack,
        [AllowNull()][string[]] $Languages,
        [hashtable] $ModelOverride = @{},
        [switch] $NoSkills,
        [switch] $NoRouting
    )
    $roleDirectory = if ($Scope -eq 'User') { $Adapter.UserDirectory } else { $Adapter.ProjectDirectory }
    if (-not $roleDirectory) { throw "$($Adapter.DisplayName) ($($Adapter.Name)) supports $(if ($Scope -eq 'User') { 'project' } else { 'user' }) scope only." }
    $directory = Resolve-GuildTargetPath -Value $roleDirectory -Root $Root
    $roles = @(Get-GuildRole -Pack $Pack)
    $script:GuildNameSeparator = if ($Adapter.NameSeparator) { $Adapter.NameSeparator } else { '-' }
    try {
        foreach ($role in $roles) {
            $body = Get-GuildRoleBody -Role $role -Pack $Pack -Languages $Languages
            $name = Get-GuildName -Pack $Pack -Id $role.Id
            [pscustomobject]@{
                Harness = $Adapter.Name
                Kind    = 'Role'
                Name    = $name
                Path    = Join-Path $directory $Adapter.FileName.Replace('{name}', $name)
                Content = ConvertTo-GuildPortableText -Text (New-GuildRoleFile -Adapter $Adapter -Role $role -Pack $Pack -Body $body -ModelOverride $ModelOverride) -Scope $Scope -Root $Root
                Source  = $role.Source
            }
        }

        $skillsDirectory = if ($Scope -eq 'User') { $Adapter.SkillsUserDirectory } else { $Adapter.SkillsProjectDirectory }
        if ($skillsDirectory -and -not $NoSkills) {
            $skillsRoot = Resolve-GuildTargetPath -Value $skillsDirectory -Root $Root
            foreach ($skill in Get-GuildSkill -Pack $Pack) {
                [pscustomobject]@{
                    Harness = $Adapter.Name
                    Kind    = 'Skill'
                    Name    = "$($Pack.Prefix)-$($skill.Id)"
                    Path    = Join-Path $skillsRoot "$($Pack.Prefix)-$($skill.Id)/SKILL.md"
                    Content = ConvertTo-GuildPortableText -Text (New-GuildSkillFile -Skill $skill -Pack $Pack) -Scope $Scope -Root $Root
                    Source  = $skill.Source
                }
            }
        }

        if ($Adapter.Kind -eq 'instructions') {
            $instructions = if ($Scope -eq 'User') { $Adapter.InstructionsUserFile } else { $Adapter.InstructionsProjectFile }
            if (-not $instructions) { throw "$($Adapter.DisplayName) has no instructions file for $Scope scope." }
            [pscustomobject]@{
                Harness = $Adapter.Name
                Kind    = 'Instructions'
                BlockId = 'guild'
                Name    = Split-Path $instructions -Leaf
                Path    = Resolve-GuildTargetPath -Value $instructions -Root $Root
                Content = ConvertTo-GuildPortableText -Text (New-GuildInstructionsBlock -Pack $Pack -Roles $roles -RoleDirectory $roleDirectory -Adapter $Adapter) -Scope $Scope -Root $Root
                Source  = 'skills/deliver/SKILL.md'
            }
        }

        $routing = if ($Scope -eq 'User') { $Adapter.RoutingUserFile } else { $Adapter.RoutingProjectFile }
        if ($Adapter.Kind -eq 'agents' -and $routing -and -not $NoRouting) {
            [pscustomobject]@{
                Harness = $Adapter.Name
                Kind    = 'Routing'
                BlockId = 'guild-routing'
                Name    = Split-Path $routing -Leaf
                Path    = Resolve-GuildTargetPath -Value $routing -Root $Root
                Content = New-GuildRoutingBlock -Pack $Pack -Roles $roles -Skills:([bool]$skillsDirectory -and -not $NoSkills)
                Source  = 'roles'
            }
        }
    }
    finally { $script:GuildNameSeparator = '-' }
}

function ConvertTo-GuildPortableText {
    # In a project install, paths inside the project are written relative to it so the generated
    # files can be committed. Paths outside it (a standards clone, Guild itself) stay absolute.
    [CmdletBinding()]
    [OutputType([string])]
    param([Parameter(Mandatory)][string] $Text, [Parameter(Mandatory)][string] $Scope, [Parameter(Mandatory)][string] $Root)
    if ($Scope -ne 'Project') { return $Text }
    $Text.Replace($Root.Replace('\', '/').TrimEnd('/') + '/', '')
}
