# Role and skill sources are tool-neutral markdown with {{tokens}}. Rendering fills the tokens from
# the merged pack; adapters only add a header. The rendered body is identical for every harness.

$script:GuildMarker = 'managed-by: guild'
$script:GuildLanguageExtensions = @{
    '.ps1' = 'powershell'; '.psm1' = 'powershell'; '.psd1' = 'powershell'
    '.py' = 'python'; '.ts' = 'typescript'; '.tsx' = 'typescript'; '.js' = 'javascript'; '.jsx' = 'javascript'
    '.cs' = 'csharp'; '.go' = 'go'; '.java' = 'java'; '.rs' = 'rust'; '.rb' = 'ruby'; '.sh' = 'shell'
    '.tf' = 'terraform'; '.bicep' = 'bicep'; '.sql' = 'sql'
}

# Role names are <prefix><separator><role>. The separator is per harness (Claude requires hyphens;
# Codex's examples use underscores) and is set while a harness's plan is rendered.
$script:GuildNameSeparator = '-'

function Get-GuildName {
    [CmdletBinding()]
    [OutputType([string])]
    param([Parameter(Mandatory)][hashtable] $Pack, [Parameter(Mandatory)][string] $Id)
    "$($Pack.Prefix)$script:GuildNameSeparator$Id"
}

function Read-GuildSource {
    # Splits a markdown file into its frontmatter (simple key: value lines) and body.
    [CmdletBinding()]
    param([Parameter(Mandatory)][string] $Path)
    $text = [System.IO.File]::ReadAllText($Path).Replace("`r`n", "`n")
    if ($text -notmatch '(?s)^---\n(?<front>.*?)\n---\n(?<body>.*)$') { throw "$Path has no frontmatter block." }
    $frontText = $Matches.front
    $body = $Matches.body.TrimStart("`n")
    $front = @{}
    foreach ($line in $frontText -split "`n") {
        if ($line -match '^(?<key>[a-z][a-z-]*):\s*(?<value>.*)$') { $front[$Matches.key] = $Matches.value.Trim() }
    }
    [pscustomobject]@{ Front = $front; Body = $body }
}

function Read-GuildRoleFile {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string] $Path, [Parameter(Mandatory)][string] $Source)
    $front = (Read-GuildSource -Path $Path)
    $role = $front.Front
    foreach ($field in 'name', 'description', 'access', 'tier') { if (-not $role[$field]) { throw "$Source is missing '$field'." } }
    if ($role.name -cnotmatch '^[a-z][a-z0-9-]*$') { throw "${Source}: name must be lowercase letters, digits and hyphens." }
    if ($role.access -notin 'write', 'docs', 'read-only') { throw "${Source}: access must be write, docs or read-only." }
    if ($role.tier -notin $script:GuildTiers) { throw "${Source}: tier must be top or mid." }
    [pscustomobject]@{
        Id          = $role.name
        Description = $role.description
        # Topics that always go to this role; drives the routing block. Optional.
        UseFor      = @(([string]$role['use-for']) -split ',' | ForEach-Object { $_.Trim() } | Where-Object { $_ })
        Access      = $role.access
        Tier        = $role.tier
        Body        = $front.Body
        Source      = $Source
    }
}

function Get-GuildRole {
    # Guild's own roles, then any roles the packs add. Pack roles can't reuse a name.
    [CmdletBinding()]
    param([hashtable] $Pack)
    $roles = @(foreach ($file in Get-ChildItem (Join-Path $script:GuildRepoRoot 'roles') -Filter '*.md' -File | Sort-Object Name) {
            $role = Read-GuildRoleFile -Path $file.FullName -Source "roles/$($file.Name)"
            if ($role.Id -notin $script:GuildRoleNames) { throw "roles/$($file.Name): name must be one of $($script:GuildRoleNames -join ', ')." }
            $role
        })
    foreach ($path in @($Pack.Roles | Where-Object { $_ })) {
        $role = Read-GuildRoleFile -Path $path -Source $path
        if ($role.Id -in $roles.Id -or $role.Id -eq $script:GuildMainSession) { throw "${path}: role name '$($role.Id)' is already taken." }
        $roles += $role
    }
    $roles
}

function Get-GuildRoleId {
    [CmdletBinding()]
    [OutputType([string[]])]
    param([hashtable] $Pack)
    @(Get-GuildRole -Pack $Pack | ForEach-Object { $_.Id })
}

function Get-GuildProjectLanguage {
    # The languages a project uses, from its file extensions. Used to pick style guides.
    [CmdletBinding()]
    [OutputType([string[]])]
    param([Parameter(Mandatory)][string] $Path)
    $found = [System.Collections.Generic.HashSet[string]]::new()
    $files = Get-ChildItem -LiteralPath $Path -Recurse -File -ErrorAction SilentlyContinue |
        Where-Object { $_.FullName -notmatch '[\\/](\.git|node_modules|\.venv|bin|obj|dist)[\\/]' } |
        Select-Object -First 5000
    foreach ($file in $files) {
        $language = $script:GuildLanguageExtensions[$file.Extension.ToLowerInvariant()]
        if ($language) { $null = $found.Add($language) }
    }
    @($found | Sort-Object)
}

function Format-GuildCommand {
    [CmdletBinding()]
    [OutputType([string])]
    param([string[]] $Command)
    (@($Command) | ForEach-Object { "``$_``" }) -join ', '
}

function Format-GuildSection {
    # The text a {{token}} stands for. Each has a fallback so a bare install reads sensibly.
    [CmdletBinding()]
    [OutputType([string])]
    param([Parameter(Mandatory)][string] $Name, [Parameter(Mandatory)][hashtable] $Pack, [AllowNull()][string[]] $Languages)

    switch ($Name) {
        'knowledge' {
            $sources = @($Pack.Knowledge | Where-Object { $_ })
            if (-not $sources) {
                return 'No standards sources are configured. Use the project''s own README, AGENTS.md and decision records; where they are silent, say that the choice is your own judgement.'
            }
            $lines = @('Standards sources, highest precedence first:', '', '| Kind | Source | Path |', '|---|---|---|')
            $lines += foreach ($source in $sources) { "| $($source.Kind) | $($source.Name) | ``$($source.Path)`` |" }
            return $lines -join "`n"
        }
        'style' {
            $guides = @($Pack.Style | Where-Object { $_ -and ($_.Language -eq '*' -or -not $Languages -or $_.Language -in $Languages) })
            $lines = @('Style guides (project first, then company, then general). The linter owns whatever it checks:', '')
            $lines += foreach ($guide in $guides) {
                $label = if ($guide.Language -eq '*') { 'all languages' } else { $guide.Language }
                $linter = if ($guide.Linter) { " (linter config: ``$($guide.Linter)``)" } else { '' }
                "- $label`: ``$($guide.Guide)``$linter"
            }
            if (-not $Languages) { $lines += '', 'Use the guide for the language you are working in.' }
            return $lines -join "`n"
        }
        'languages' {
            $policy = $Pack.Languages
            if (-not $policy -or -not ($policy.Default -or $policy.ByWorkload)) {
                return 'No language policy is configured. When a new piece needs a language, recommend one and say it is your own judgement.'
            }
            $lines = @('Language choices for new work:')
            if ($policy.Default) { $lines += "- Default: $($policy.Default)" }
            if ($policy.ByWorkload) { $lines += foreach ($workload in $policy.ByWorkload.Keys | Sort-Object) { "- ${workload}: $($policy.ByWorkload[$workload])" } }
            if ($policy.Rationale) { $lines += "- Why: ``$($policy.Rationale)``" }
            return $lines -join "`n"
        }
        'policy' {
            $lines = @()
            if ($Pack.Policy.NeverInvent) { $lines += "Never invent these; ask the human: $(@($Pack.Policy.NeverInvent) -join '; ')." }
            if ($Pack.Policy.HighRisk) { $lines += "High risk at any size (independent tests and review): $(@($Pack.Policy.HighRisk) -join '; ')." }
            return $lines -join "`n`n"
        }
        'review' {
            $review = $Pack.Review
            return "Review rounds stop after $($review.MaxRounds) with the same finding open; then the human decides. Findings are logged to ``$($review.FindingsLog)`` in the project. A finding that recurs $($review.PromoteAfter) times is a candidate for promotion."
        }
        'categories' { return "Category is one of: $(@($Pack.Review.Categories) -join ', ')." }
        'adr' {
            if ($Pack.AdrTemplate) { return "Use the format in ``$($Pack.AdrTemplate)``." }
            return 'Use the project''s existing decision record format; if it has none, use Context, Decision, Alternatives considered, Consequences.'
        }
        default { throw "Unknown section '$Name'." }
    }
}

function Expand-GuildText {
    # Replaces {{tokens}}: knowledge, style, languages, policy, review, categories, adr,
    # role:<id>, capability:<Name>, and any extra values passed in.
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)][AllowEmptyString()][string] $Text,
        [Parameter(Mandatory)][hashtable] $Pack,
        [Parameter(Mandatory)][string] $Source,
        [AllowNull()][string[]] $Languages,
        [hashtable] $Values = @{}
    )
    $builder = [System.Text.StringBuilder]::new()
    $last = 0
    foreach ($match in [regex]::Matches($Text, '\{\{(?<token>[a-z]+)(?::(?<arg>[A-Za-z-]+))?\}\}')) {
        $null = $builder.Append($Text, $last, $match.Index - $last)
        $token = $match.Groups['token'].Value
        $argument = $match.Groups['arg'].Value
        $replacement = if ($Values.ContainsKey($token)) { $Values[$token] }
        elseif ($token -eq 'role' -and $argument -in (Get-GuildRoleId -Pack $Pack)) { Get-GuildName -Pack $Pack -Id $argument }
        elseif ($token -eq 'capability' -and $argument -in $script:GuildCapabilityNames) { Get-GuildCapabilityText -Name $argument -Pack $Pack }
        elseif (-not $argument -and $token -in 'knowledge', 'style', 'languages', 'policy', 'review', 'categories', 'adr') {
            Format-GuildSection -Name $token -Pack $Pack -Languages $Languages
        }
        else { throw "${Source}: unknown token $($match.Value)." }
        $null = $builder.Append($replacement)
        $last = $match.Index + $match.Length
    }
    $null = $builder.Append($Text, $last, $Text.Length - $last)
    $builder.ToString()
}

function Get-GuildCapabilityText {
    # The bound (.tool) or fallback (.none) snippet for a capability.
    [CmdletBinding()]
    [OutputType([string])]
    param([Parameter(Mandatory)][string] $Name, [Parameter(Mandatory)][hashtable] $Pack)
    $binding = $Pack.Capabilities[$Name]
    $variant = if ($binding) { 'tool' } else { 'none' }
    $file = Join-Path $script:GuildRepoRoot "capabilities/$($Name.ToLowerInvariant()).$variant.md"
    $snippet = [System.IO.File]::ReadAllText($file).Replace("`r`n", "`n").Trim()
    if (-not $binding) { return $snippet }
    $values = @{
        command = Format-GuildCommand -Command $binding.Command
        module  = if (-not $binding.Module) { '' }
        elseif ($binding.Module -match '[\\/]') { " (first run ``Import-Module '$($binding.Module)'``)" }
        else { " (load the ``$($binding.Module)`` module first)" }
        notes   = if ($binding.Notes) { " $($binding.Notes)" } else { '' }
    }
    $snippet += ' If the command is not available, say so and continue as if no tool were configured.'
    Expand-GuildText -Text $snippet -Pack $Pack -Source "capabilities/$($Name.ToLowerInvariant()).$variant.md" -Values $values
}

function Get-GuildRoleBody {
    # Role body + the pack's addendum for that role + the shared rules.
    [CmdletBinding()]
    [OutputType([string])]
    param([Parameter(Mandatory)][object] $Role, [Parameter(Mandatory)][hashtable] $Pack, [AllowNull()][string[]] $Languages)
    $parts = @(Expand-GuildText -Text $Role.Body -Pack $Pack -Source $Role.Source -Languages $Languages)
    $addendum = $Pack.RoleAddenda[$Role.Id]
    if ($addendum) {
        $text = [System.IO.File]::ReadAllText($addendum).Replace("`r`n", "`n")
        $parts += Expand-GuildText -Text $text -Pack $Pack -Source $addendum -Languages $Languages
    }
    $rules = [System.IO.File]::ReadAllText((Join-Path $script:GuildRepoRoot 'core/rules.md')).Replace("`r`n", "`n")
    $parts += Expand-GuildText -Text $rules -Pack $Pack -Source 'core/rules.md' -Languages $Languages
    $tools = [System.IO.File]::ReadAllText((Join-Path $script:GuildRepoRoot 'core/tools.md')).Replace("`r`n", "`n")
    $parts += Expand-GuildText -Text $tools -Pack $Pack -Source 'core/tools.md' -Languages $Languages -Values @{ guildmodule = "$script:GuildRepoRoot/Guild/Guild.psd1" }
    (($parts | ForEach-Object { $_.Trim("`n") }) -join "`n`n") + "`n"
}

function Read-GuildPackSkill {
    # A skill from a pack, used as written (no tokens). Skills without frontmatter get a description
    # from their first plain paragraph.
    [CmdletBinding()]
    param([Parameter(Mandatory)][string] $Directory, [Parameter(Mandatory)][string] $Root)
    $file = Join-Path $Directory 'SKILL.md'
    $text = [System.IO.File]::ReadAllText($file).Replace("`r`n", "`n")
    $id = Split-Path $Directory -Leaf
    if ($text -match '(?s)^---\n') {
        $source = Read-GuildSource -Path $file
        $description = $source.Front['description']
        $body = $source.Body
    }
    else {
        $body = $text
        $paragraph = ($text -split "\n{2,}") | Where-Object { $_.Trim() -and $_.Trim() -notmatch '^(#|>|```|\||-)' } | Select-Object -First 1
        $description = (($paragraph -replace '\s+', ' ').Trim())
    }
    if (-not $description) { throw "${file}: has no description (frontmatter or a first paragraph)." }
    $description = $description.Trim('"')
    if ($description.Length -gt 500) { $description = $description.Substring(0, 497) + '...' }
    [pscustomobject]@{
        Id          = $id
        Description = $description
        Body        = $body
        Source      = $file.Replace('\', '/')
        Root        = $Root.Replace('\', '/')
        External    = $true
    }
}

function Get-GuildSkill {
    # Guild's skills, then the packs' skills. A pack skill with the same name replaces Guild's.
    [CmdletBinding()]
    param([hashtable] $Pack)
    $skills = [ordered]@{}
    foreach ($directory in Get-ChildItem (Join-Path $script:GuildRepoRoot 'skills') -Directory | Sort-Object Name) {
        $file = Join-Path $directory.FullName 'SKILL.md'
        if (-not (Test-Path $file)) { continue }
        $source = Read-GuildSource -Path $file
        if ($source.Front.name -ne $directory.Name) { throw "skills/$($directory.Name)/SKILL.md: name must match its directory." }
        if (-not $source.Front.description) { throw "skills/$($directory.Name)/SKILL.md is missing 'description'." }
        $skills[$directory.Name] = [pscustomobject]@{ Id = $directory.Name; Description = $source.Front.description; Body = $source.Body; Source = "skills/$($directory.Name)/SKILL.md"; Root = $null; External = $false }
    }
    foreach ($entry in @($Pack.Skills | Where-Object { $_ })) {
        $directories = if (Test-Path -LiteralPath (Join-Path $entry.Path 'SKILL.md')) { @(Get-Item -LiteralPath $entry.Path) }
        else { @(Get-ChildItem -LiteralPath $entry.Path -Directory | Where-Object { Test-Path (Join-Path $_.FullName 'SKILL.md') } | Sort-Object Name) }
        foreach ($directory in $directories) {
            $skill = Read-GuildPackSkill -Directory $directory.FullName -Root $entry.Root
            if ($skills.Contains($skill.Id) -and $skills[$skill.Id].External) { continue }   # the first (highest-precedence) pack wins
            $skills[$skill.Id] = $skill
        }
    }
    $skills.Values
}

function Get-GuildSkillBody {
    # A skill's body as installed: Guild skills are rendered; pack skills are used as written, with a
    # note saying where their relative paths point. The deliver skill gets the packs' deliver addendum.
    [CmdletBinding()]
    [OutputType([string])]
    param([Parameter(Mandatory)][object] $Skill, [Parameter(Mandatory)][hashtable] $Pack)
    $body = if ($Skill.External) {
        "> From ``$($Skill.Source)``. Relative paths in this skill are relative to ``$($Skill.Root)``.`n`n" + $Skill.Body.Trim("`n")
    }
    else { (Expand-GuildText -Text $Skill.Body -Pack $Pack -Source $Skill.Source).Trim("`n") }
    $addendum = $Pack.RoleAddenda[$script:GuildMainSession]
    if ($Skill.Id -eq $script:GuildMainSession -and $addendum) {
        $text = [System.IO.File]::ReadAllText($addendum).Replace("`r`n", "`n")
        $body += "`n`n" + (Expand-GuildText -Text $text -Pack $Pack -Source $addendum).Trim("`n")
    }
    $body + "`n"
}