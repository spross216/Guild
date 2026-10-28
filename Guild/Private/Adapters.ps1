# One data file per harness in adapters/. Kind says how roles reach the tool: 'agents' (native
# subagent files), 'instructions' (plain role files plus a managed block in an instructions file),
# or 'plain' (role files only). Format picks the header writer below. Adding a harness that uses an
# existing format is a new data file and nothing else.

$script:GuildAdapterKeys = @('Name', 'DisplayName', 'Kind', 'Format', 'UserDirectory', 'ProjectDirectory', 'FileName',
    'SkillsUserDirectory', 'SkillsProjectDirectory', 'InstructionsUserFile', 'InstructionsProjectFile', 'RoutingUserFile', 'RoutingProjectFile',
    'NameSeparator', 'Tools', 'ReadOnly', 'DefaultModels', 'Detect', 'Notes')
$script:GuildFormats = @('claude', 'copilot', 'codex', 'opencode', 'plain')

function Get-GuildAdapter {
    [CmdletBinding()]
    param([string] $Name)
    if (-not $script:GuildAdapterCache) {
        $script:GuildAdapterCache = @(foreach ($file in Get-ChildItem (Join-Path $script:GuildRepoRoot 'adapters') -Filter '*.psd1' -File | Sort-Object Name) {
                $adapter = Import-PowerShellDataFile -LiteralPath $file.FullName
                $where = "adapters/$($file.Name)"
                Assert-GuildKeys -Value $adapter -Allowed $script:GuildAdapterKeys -Where $where
                if ($adapter.Name -ne $file.BaseName) { throw "${where}: Name must match the file name." }
                if ($adapter.Kind -notin 'agents', 'instructions', 'plain') { throw "${where}: Kind must be agents, instructions or plain." }
                if ($adapter.Format -notin $script:GuildFormats) { throw "${where}: Format must be one of $($script:GuildFormats -join ', ')." }
                if (-not $adapter.FileName -or -not ($adapter.UserDirectory -or $adapter.ProjectDirectory)) { throw "${where}: needs FileName and a UserDirectory or ProjectDirectory." }
                [pscustomobject]$adapter
            })
    }
    if ($Name) {
        $match = $script:GuildAdapterCache | Where-Object Name -EQ $Name
        if (-not $match) { throw "Unknown harness '$Name'. Known: $(($script:GuildAdapterCache.Name) -join ', ')." }
        return $match
    }
    $script:GuildAdapterCache
}

function ConvertTo-GuildYamlString {
    # A double-quoted YAML scalar: safe for colons, quotes and backslashes.
    [CmdletBinding()]
    [OutputType([string])]
    param([Parameter(Mandatory)][AllowEmptyString()][string] $Value)
    '"' + $Value.Replace('\', '\\').Replace('"', '\"') + '"'
}

function ConvertTo-GuildTomlString {
    [CmdletBinding()]
    [OutputType([string])]
    param([Parameter(Mandatory)][AllowEmptyString()][string] $Value)
    '"' + $Value.Replace('\', '\\').Replace('"', '\"') + '"'
}

function Get-GuildModel {
    # Installer override (by role or tier), then the pack's role entry, then its tier entry, then
    # the adapter's default. $null means the harness's own default.
    [CmdletBinding()]
    [OutputType([string])]
    param([Parameter(Mandatory)][object] $Adapter, [Parameter(Mandatory)][hashtable] $Pack, [Parameter(Mandatory)][object] $Role, [hashtable] $Override = @{})
    if ($Override[$Role.Id]) { return $Override[$Role.Id] }
    if ($Override[$Role.Tier]) { return $Override[$Role.Tier] }
    $models = $Pack.Models[$Adapter.Name]
    if ($models -and $models.Roles -and $models.Roles[$Role.Id]) { return $models.Roles[$Role.Id] }
    if ($models -and $models.Tiers -and $models.Tiers[$Role.Tier]) { return $models.Tiers[$Role.Tier] }
    if ($Adapter.DefaultModels -and $Adapter.DefaultModels[$Role.Tier]) { return $Adapter.DefaultModels[$Role.Tier] }
    $null
}

function Get-GuildGuardAllowList {
    # Commands a guarded role may run besides the guard's built-in list: the first word of each command
    # bound to Describe, Diagnose and Check, and New-GuildDecision for docs roles.
    [CmdletBinding()]
    [OutputType([string[]])]
    param([Parameter(Mandatory)][hashtable] $Pack, [string] $Access = 'read-only')
    $commands = @(foreach ($name in 'Describe', 'Diagnose', 'Check') {
            foreach ($command in @($Pack.Capabilities[$name].Command | Where-Object { $_ })) { ($command -split '\s+')[0] }
        })
    if ($Access -eq 'docs') { $commands += 'New-GuildDecision' }
    @($commands | Sort-Object -Unique)
}

function New-GuildRoleFile {
    # The full text of one role file for one harness.
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)][object] $Adapter,
        [Parameter(Mandatory)][object] $Role,
        [Parameter(Mandatory)][hashtable] $Pack,
        [Parameter(Mandatory)][string] $Body,
        [hashtable] $ModelOverride = @{}
    )
    $name = Get-GuildName -Pack $Pack -Id $Role.Id
    $description = Expand-GuildText -Text $Role.Description -Pack $Pack -Source $Role.Source
    $model = Get-GuildModel -Adapter $Adapter -Pack $Pack -Role $Role -Override $ModelOverride
    $tools = @($Adapter.Tools[$Role.Access])
    $marker = "$script:GuildMarker | source: $($Role.Source) | edit the source and re-run Install-GuildAgents"

    if ($Adapter.Format -eq 'codex') {
        if ($Body.Contains("'''")) { throw "$($Role.Source) contains ''' and cannot be written as a TOML literal string." }
        $lines = @(
            "# $marker"
            "name = $(ConvertTo-GuildTomlString $name)"
            "description = $(ConvertTo-GuildTomlString $description)"
        )
        if ($model) { $lines += "model = $(ConvertTo-GuildTomlString $model)" }
        $lines += "developer_instructions = '''", $Body.TrimEnd("`n"), "'''"
        return ($lines -join "`n") + "`n"
    }

    $header = switch ($Adapter.Format) {
        'claude' {
            # Claude Code delegates on its own when a description invites it to.
            "name: $name"
            "description: $(ConvertTo-GuildYamlString "$description Use proactively for: $(if ($Role.UseFor) { $Role.UseFor -join ', ' } else { 'work matching this description' }).")"
            "tools: $($tools -join ', ')"
            if ($model) { "model: $model" }
            if ($Role.Access -in 'read-only', 'docs') {
                # Shell commands that change things are blocked; docs roles may also edit Markdown only.
                $guard = (Join-Path $script:GuildRepoRoot 'guards/Test-GuildReadOnlyCommand.ps1').Replace('\', '/')
                $allow = Get-GuildGuardAllowList -Pack $Pack -Access $Role.Access
                $command = "pwsh -NoProfile -NonInteractive -File '$($guard.Replace("'", "''"))'"
                if ($allow) { $command += " -Allow '$($allow -join ',')'" }
                'hooks:'
                '  PreToolUse:'
                '    - matcher: "Bash|PowerShell"'
                '      hooks:'
                '        - type: command'
                "          command: $(ConvertTo-GuildYamlString $command)"
                '          timeout: 30'
                '          onFailure: block'
                if ($Role.Access -eq 'docs') {
                    $docsGuard = (Join-Path $script:GuildRepoRoot 'guards/Test-GuildDocsEdit.ps1').Replace('\', '/')
                    '    - matcher: "Edit|Write|MultiEdit|NotebookEdit"'
                    '      hooks:'
                    '        - type: command'
                    "          command: $(ConvertTo-GuildYamlString "pwsh -NoProfile -NonInteractive -File '$($docsGuard.Replace("'", "''"))'")"
                    '          timeout: 30'
                    '          onFailure: block'
                }
            }
        }
        'copilot' {
            "name: $name"
            "description: $(ConvertTo-GuildYamlString $description)"
            "tools: [$(($tools | ForEach-Object { "'$_'" }) -join ', ')]"
            if ($model) { "model: $(ConvertTo-GuildYamlString $model)" }
        }
        'opencode' {
            "description: $(ConvertTo-GuildYamlString $description)"
            'mode: subagent'
            if ($model) { "model: $model" }
            if ($Role.Access -in 'read-only', 'docs') {
                'permission:'
                # Docs roles may edit (Markdown only, stated in the role); every edit asks the human.
                "  edit: $(if ($Role.Access -eq 'docs') { 'ask' } else { 'deny' })"
                '  bash:'
                '    "*": ask'
                foreach ($git in 'git status*', 'git diff*', 'git log*', 'git show*') { "    `"$git`": allow" }
            }
        }
        'plain' {
            "name: $name"
            "description: $(ConvertTo-GuildYamlString $description)"
            "access: $($Role.Access)"
            "tier: $($Role.Tier)"
            if ($model) { "model: $model" }
        }
    }
    ((@('---') + @($header) + @('---', "<!-- $marker -->", '', $Body.TrimEnd("`n"))) -join "`n") + "`n"
}

function New-GuildSkillFile {
    [CmdletBinding()]
    [OutputType([string])]
    param([Parameter(Mandatory)][object] $Skill, [Parameter(Mandatory)][hashtable] $Pack)
    $body = Get-GuildSkillBody -Skill $Skill -Pack $Pack
    $description = if ($Skill.External) { $Skill.Description } else { Expand-GuildText -Text $Skill.Description -Pack $Pack -Source $Skill.Source }
    $lines = @(
        '---'
        "name: $($Pack.Prefix)-$($Skill.Id)"
        "description: $(ConvertTo-GuildYamlString $description)"
        '---'
        "<!-- $script:GuildMarker | source: $($Skill.Source) | edit the source and re-run Install-GuildAgents -->"
        ''
        $body.TrimEnd("`n")
    )
    ($lines -join "`n") + "`n"
}

function New-GuildInstructionsBlock {
    # The managed block for instructions-mode harnesses: where the roles are, and how to use them.
    [CmdletBinding()]
    [OutputType([string])]
    param([Parameter(Mandatory)][hashtable] $Pack, [Parameter(Mandatory)][object[]] $Roles, [Parameter(Mandatory)][string] $RoleDirectory, [Parameter(Mandatory)][object] $Adapter)
    $deliver = Get-GuildSkill -Pack $Pack | Where-Object Id -EQ $script:GuildMainSession
    $lines = @(
        '<!-- guild:begin (managed by Install-GuildAgents; edits inside this block are replaced) -->'
        '## Agent roles'
        ''
        "This tool has no native subagents, so you play these roles in turn. When a task calls for a role, read its file and follow it for that part of the work. Role files are in ``$RoleDirectory``."
        ''
        '| Role | Access | Use for |'
        '|---|---|---|'
    )
    foreach ($role in $Roles) {
        $description = Expand-GuildText -Text $Role.Description -Pack $Pack -Source $Role.Source
        $file = $Adapter.FileName.Replace('{name}', (Get-GuildName -Pack $Pack -Id $role.Id))
        $lines += "| ``$file`` | $($role.Access) | $(($description -split '(?<=\.)\s')[0]) |"
    }
    $lines += ''
    $lines += 'When playing a read-only role, change nothing; when playing a docs role, change Markdown documentation only. Finish one role''s work and report before taking the next role, so the review is as independent as one agent can make it.'
    if ($deliver) {
        # Nest the skill's headings under "## Agent roles".
        $procedure = (Get-GuildSkillBody -Skill $deliver -Pack $Pack).Trim("`n")
        $lines += '', ($procedure -replace '(?m)^(#+) ', '##$1 ')
    }
    $lines += '<!-- guild:end -->'
    $lines -join "`n"
}

function New-GuildRoutingBlock {
    # The managed block for harnesses with subagents: delegate every matching request to its agent.
    [CmdletBinding()]
    [OutputType([string])]
    param([Parameter(Mandatory)][hashtable] $Pack, [Parameter(Mandatory)][object[]] $Roles, [switch] $Skills)
    $deliver = "$($Pack.Prefix)-deliver"
    $lines = @(
        '<!-- guild-routing:begin (managed by Install-GuildAgents; edits inside this block are replaced) -->'
        '## Agent routing'
        ''
        'These agents are installed. Every time a request involves a topic below, delegate that part to the agent named; don''t do it in the main session, even when it looks quick. You coordinate: break the request down, brief each agent, reconcile what they return, and report.'
        ''
        '| When the request involves | Delegate to |'
        '|---|---|'
    )
    foreach ($role in $Roles) {
        $topics = if ($role.UseFor) { $role.UseFor -join ', ' } else { ((Expand-GuildText -Text $role.Description -Pack $Pack -Source $role.Source) -split '(?<=\.)\s')[0] }
        $lines += "| $topics | ``$(Get-GuildName -Pack $Pack -Id $role.Id)`` |"
    }
    $lines += ''
    $lines += 'Order and risk:'
    $lines += $(if ($Skills) { "- Follow the ``$deliver`` skill for the order of work and for high-risk changes." } else { '- Design before building anything with more than one piece; the author is never the only reviewer.' })
    $lines += "- High-risk changes ($(@($Pack.Policy.HighRisk) -join '; ')) always go builder, then an independent tester if one is installed, then reviewer, at any size."
    $lines += '- A request that spans several topics goes to several agents, in that order.'
    $lines += '- Start each delegation with `Get-GuildContext` and hand it over with `New-GuildBrief`.'
    $lines += '- Say which agent you are delegating to and why. You may do a typo fix or a one-line documentation change yourself.'
    $lines += '<!-- guild-routing:end -->'
    $lines -join "`n"
}
