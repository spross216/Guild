# Packs are data-only .psd1 files that carry everything company- or tool-specific. They are read
# with Import-PowerShellDataFile, so loading a pack never runs code.

$script:GuildContracts = @('1')
$script:GuildPackKeys = @('Name', 'Version', 'Contract', 'Description', 'Extends', 'Prefix', 'Knowledge', 'AdrTemplate',
    'Languages', 'Style', 'Capabilities', 'Roles', 'Skills', 'RoleAddenda', 'Policy', 'Review', 'Models')
$script:GuildKnowledgeKinds = @('decisions', 'standards', 'patterns', 'skills')
$script:GuildCapabilityNames = @('Scaffold', 'Describe', 'Check', 'Diagnose', 'Update', 'Infra', 'Promote')
$script:GuildRoleNames = @('architect', 'builder', 'reviewer', 'steward')
$script:GuildTiers = @('top', 'mid')
# Lists that accumulate across layers (later pack first) instead of being replaced.
$script:GuildListKeys = @('Knowledge', 'Style', 'Roles', 'Skills', 'Policy.NeverInvent', 'Policy.HighRisk', 'Review.Categories')
# RoleAddenda may also target the main session's delivery procedure.
$script:GuildMainSession = 'deliver'

function Assert-GuildKeys {
    [CmdletBinding()]
    param([Parameter(Mandatory)][object] $Value, [Parameter(Mandatory)][string[]] $Allowed, [Parameter(Mandatory)][string] $Where)
    if ($Value -isnot [hashtable]) { throw "$Where must be a hashtable (@{ ... })." }
    foreach ($key in $Value.Keys) {
        if ($key -notin $Allowed) { throw "$Where has an unknown key '$key'. Known: $($Allowed -join ', ')." }
    }
}

function Resolve-GuildPathValue {
    # Expands {pack}, {env:NAME} (and {guild} in the defaults) and returns a full path with forward slashes.
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)][string] $Value,
        [Parameter(Mandatory)][string] $PackDirectory,
        [Parameter(Mandatory)][string] $Key,
        [switch] $AllowGuildRoot,
        [switch] $NoExistenceCheck
    )
    if ($Value -match '^(?:[A-Za-z]:[\\/]|[\\/]|~)') {
        throw "$Key is an absolute path ('$Value'). Use a path relative to the pack, {pack} or {env:NAME} so the pack works on any machine."
    }
    $resolved = $Value
    foreach ($match in [regex]::Matches($Value, '\{(?<token>[^{}]+)\}')) {
        $token = $match.Groups['token'].Value
        $replacement = if ($token -eq 'pack') { $PackDirectory }
        elseif ($token -eq 'guild' -and $AllowGuildRoot) { $script:GuildRepoRoot }
        elseif ($token -match '^env:(?<name>[A-Za-z_][A-Za-z0-9_]*)$') {
            $envValue = [Environment]::GetEnvironmentVariable($Matches.name)
            if (-not $envValue) { throw "$Key uses {env:$($Matches.name)}, which is not set." }
            $envValue
        }
        else { throw "$Key uses an unknown token {$token}. Known: {pack}, {env:NAME}." }
        $resolved = $resolved.Replace($match.Value, $replacement)
    }
    if (-not [System.IO.Path]::IsPathRooted($resolved)) { $resolved = Join-Path $PackDirectory $resolved }
    $full = [System.IO.Path]::GetFullPath($resolved).Replace('\', '/')
    if (-not $NoExistenceCheck -and -not (Test-Path -LiteralPath $full)) { throw "$Key points at '$full', which does not exist." }
    $full
}

function Read-GuildPackFile {
    # Loads and validates one pack file. Path values come back resolved against the pack's directory.
    [CmdletBinding()]
    param([Parameter(Mandatory)][string] $Path, [switch] $IsDefaults)

    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { throw "Pack not found: $Path" }
    $full = (Resolve-Path -LiteralPath $Path).ProviderPath
    try { $data = Import-PowerShellDataFile -LiteralPath $full }
    catch { throw "$full is not a valid PowerShell data file: $($_.Exception.Message)" }
    $where = Split-Path $full -Leaf
    $paths = @{ PackDirectory = (Split-Path $full -Parent); AllowGuildRoot = $IsDefaults }

    Assert-GuildKeys -Value $data -Allowed $script:GuildPackKeys -Where $where
    foreach ($key in 'Name', 'Version', 'Contract') { if (-not $data[$key]) { throw "${where}: missing required key '$key'." } }
    if ([string]$data.Contract -notin $script:GuildContracts) {
        throw "${where}: Contract '$($data.Contract)' is not supported by this Guild version (supported: $($script:GuildContracts -join ', '))."
    }
    if ($data.ContainsKey('Prefix') -and $data.Prefix -notmatch '^[a-z][a-z0-9]*$') { throw "${where}: Prefix must be lowercase letters and digits." }
    if ($data.ContainsKey('Extends')) { $data.Extends = @($data.Extends) }

    if ($data.ContainsKey('Knowledge')) {
        $data.Knowledge = @(foreach ($entry in @($data.Knowledge)) {
                Assert-GuildKeys -Value $entry -Allowed 'Name', 'Kind', 'Path' -Where "${where}: Knowledge entry"
                foreach ($key in 'Name', 'Kind', 'Path') { if (-not $entry[$key]) { throw "${where}: Knowledge entry is missing '$key'." } }
                if ($entry.Kind -notin $script:GuildKnowledgeKinds) { throw "${where}: Knowledge '$($entry.Name)' has unknown Kind '$($entry.Kind)'. Known: $($script:GuildKnowledgeKinds -join ', ')." }
                $entry.Path = Resolve-GuildPathValue -Value $entry.Path -Key "${where}: Knowledge '$($entry.Name)'" @paths
                $entry
            })
    }
    if ($data.ContainsKey('AdrTemplate')) { $data.AdrTemplate = Resolve-GuildPathValue -Value $data.AdrTemplate -Key "${where}: AdrTemplate" @paths }

    if ($data.ContainsKey('Languages')) {
        Assert-GuildKeys -Value $data.Languages -Allowed 'Default', 'ByWorkload', 'Rationale' -Where "${where}: Languages"
        if ($data.Languages.ContainsKey('ByWorkload') -and $data.Languages.ByWorkload -isnot [hashtable]) { throw "${where}: Languages.ByWorkload must be a hashtable of workload = language." }
        if ($data.Languages.Rationale) { $data.Languages.Rationale = Resolve-GuildPathValue -Value $data.Languages.Rationale -Key "${where}: Languages.Rationale" @paths }
    }

    if ($data.ContainsKey('Style')) {
        $data.Style = @(foreach ($entry in @($data.Style)) {
                Assert-GuildKeys -Value $entry -Allowed 'Language', 'Guide', 'Linter' -Where "${where}: Style entry"
                foreach ($key in 'Language', 'Guide') { if (-not $entry[$key]) { throw "${where}: Style entry is missing '$key'." } }
                $entry.Guide = Resolve-GuildPathValue -Value $entry.Guide -Key "${where}: Style '$($entry.Language)' Guide" @paths
                # Linter is a path inside the target project; it is cited, not resolved here.
                $entry
            })
    }

    if ($data.ContainsKey('Capabilities')) {
        Assert-GuildKeys -Value $data.Capabilities -Allowed $script:GuildCapabilityNames -Where "${where}: Capabilities"
        foreach ($name in @($data.Capabilities.Keys)) {
            $capability = $data.Capabilities[$name]
            Assert-GuildKeys -Value $capability -Allowed 'Command', 'Module', 'Notes' -Where "${where}: Capabilities.$name"
            if (-not $capability.Command) { throw "${where}: Capabilities.$name needs a Command." }
            $capability.Command = @($capability.Command)
            # A Module given as a path (relative to the pack, or with {pack}/{env:}) is resolved; a bare name stays a name.
            if ($capability['Module'] -and $capability.Module -match '[\\/{]') {
                $capability.Module = Resolve-GuildPathValue -Value $capability.Module -Key "${where}: Capabilities.$name Module" @paths
            }
        }
    }

    if ($data.ContainsKey('Roles')) {
        $data.Roles = @(foreach ($rolePath in @($data.Roles)) {
                if ($rolePath -isnot [string]) { throw "${where}: Roles entries are paths to role files." }
                Resolve-GuildPathValue -Value $rolePath -Key "${where}: Roles" @paths
            })
    }

    if ($data.ContainsKey('Skills')) {
        $data.Skills = @(foreach ($entry in @($data.Skills)) {
                Assert-GuildKeys -Value $entry -Allowed 'Path', 'Root' -Where "${where}: Skills entry"
                if (-not $entry['Path']) { throw "${where}: Skills entry is missing 'Path'." }
                $entry.Path = Resolve-GuildPathValue -Value $entry.Path -Key "${where}: Skills Path" @paths
                $entry.Root = if ($entry['Root']) { Resolve-GuildPathValue -Value $entry.Root -Key "${where}: Skills Root" @paths } else { $entry.Path }
                $entry
            })
    }

    if ($data.ContainsKey('RoleAddenda')) {
        # Keys are checked against the roster once every pack is merged (packs can add roles).
        if ($data.RoleAddenda -isnot [hashtable]) { throw "${where}: RoleAddenda must be a hashtable of role = path." }
        foreach ($role in @($data.RoleAddenda.Keys)) {
            $data.RoleAddenda[$role] = Resolve-GuildPathValue -Value $data.RoleAddenda[$role] -Key "${where}: RoleAddenda.$role" @paths
        }
    }

    if ($data.ContainsKey('Policy')) {
        Assert-GuildKeys -Value $data.Policy -Allowed 'NeverInvent', 'HighRisk' -Where "${where}: Policy"
        foreach ($key in @($data.Policy.Keys)) { $data.Policy[$key] = @($data.Policy[$key]) }
    }

    if ($data.ContainsKey('Review')) {
        Assert-GuildKeys -Value $data.Review -Allowed 'MaxRounds', 'PromoteAfter', 'FindingsLog', 'Categories' -Where "${where}: Review"
        foreach ($key in 'MaxRounds', 'PromoteAfter') {
            if ($data.Review.ContainsKey($key) -and ($data.Review[$key] -isnot [int] -or $data.Review[$key] -lt 1)) { throw "${where}: Review.$key must be a whole number of at least 1." }
        }
        if ($data.Review.ContainsKey('FindingsLog') -and $data.Review.FindingsLog -match '^(?:[A-Za-z]:[\\/]|[\\/]|~)') { throw "${where}: Review.FindingsLog must be relative to the project." }
        if ($data.Review.ContainsKey('Categories')) { $data.Review.Categories = @($data.Review.Categories) }
    }

    if ($data.ContainsKey('Models')) {
        $harnesses = @((Get-GuildAdapter).Name)
        Assert-GuildKeys -Value $data.Models -Allowed $harnesses -Where "${where}: Models"
        foreach ($harness in @($data.Models.Keys)) {
            $models = $data.Models[$harness]
            Assert-GuildKeys -Value $models -Allowed 'Tiers', 'Roles' -Where "${where}: Models.$harness"
            if ($models.Tiers) { Assert-GuildKeys -Value $models.Tiers -Allowed $script:GuildTiers -Where "${where}: Models.$harness.Tiers" }
            if ($models.Roles -and $models.Roles -isnot [hashtable]) { throw "${where}: Models.$harness.Roles must be a hashtable of role = model." }
        }
    }

    [pscustomobject]@{ Path = $full; Data = $data }
}

function Find-GuildPackFile {
    # An Extends entry is a path (ends in .psd1, relative to the extending pack) or a pack name,
    # looked up next to the extending pack and then in each directory of $env:GUILD_PACK_PATH.
    [CmdletBinding()]
    [OutputType([string])]
    param([Parameter(Mandatory)][string] $Reference, [Parameter(Mandatory)][string] $FromDirectory)
    if ($Reference -like '*.psd1') {
        $candidate = if ([System.IO.Path]::IsPathRooted($Reference)) { $Reference } else { Join-Path $FromDirectory $Reference }
        if (Test-Path -LiteralPath $candidate -PathType Leaf) { return (Resolve-Path -LiteralPath $candidate).ProviderPath }
        throw "Extends '$Reference': no such file."
    }
    $directories = @($FromDirectory) + @(($env:GUILD_PACK_PATH -split [System.IO.Path]::PathSeparator) | Where-Object { $_ })
    foreach ($directory in $directories) {
        foreach ($candidate in (Join-Path $directory "$Reference.pack.psd1"), (Join-Path $directory "$Reference/$Reference.pack.psd1")) {
            if (Test-Path -LiteralPath $candidate -PathType Leaf) { return (Resolve-Path -LiteralPath $candidate).ProviderPath }
        }
    }
    throw "Extends '$Reference': no $Reference.pack.psd1 next to the extending pack or in `$env:GUILD_PACK_PATH."
}

function Get-GuildPackChain {
    # The pack and everything it extends, bases first.
    [CmdletBinding()]
    param([Parameter(Mandatory)][string] $Path, [string[]] $Stack = @())
    $pack = Read-GuildPackFile -Path $Path
    if ($pack.Path -in $Stack) { throw "Packs extend each other in a cycle: $(($Stack + $pack.Path) -join ' -> ')" }
    foreach ($reference in @($pack.Data['Extends'] | Where-Object { $_ })) {
        $basePath = Find-GuildPackFile -Reference $reference -FromDirectory (Split-Path $pack.Path -Parent)
        Get-GuildPackChain -Path $basePath -Stack ($Stack + $pack.Path)
    }
    $pack
}

function Merge-GuildData {
    # Later wins: scalars are replaced, hashtables merge by key, and list keys accumulate with the
    # later layer's entries first so they read in precedence order.
    [CmdletBinding()]
    [OutputType([hashtable])]
    param([Parameter(Mandatory)][hashtable] $Base, [Parameter(Mandatory)][hashtable] $Overlay, [string] $KeyPath = '')
    $result = @{}
    foreach ($key in $Base.Keys) { $result[$key] = $Base[$key] }
    foreach ($key in $Overlay.Keys) {
        $path = if ($KeyPath) { "$KeyPath.$key" } else { $key }
        $over = $Overlay[$key]
        $under = $result[$key]
        if ($path -in $script:GuildListKeys) {
            $seen = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
            $result[$key] = @(foreach ($item in @($over) + @($under)) {
                    if ($null -eq $item) { continue }
                    $identity = if ($item -is [hashtable]) { "$($item['Path'])|$($item['Guide'])" } else { [string]$item }
                    if ($seen.Add($identity)) { $item }
                })
        }
        elseif ($over -is [hashtable] -and $under -is [hashtable]) { $result[$key] = Merge-GuildData -Base $under -Overlay $over -KeyPath $path }
        else { $result[$key] = $over }
    }
    $result
}

function Resolve-GuildPack {
    # Framework defaults, then each pack (and what it extends) in the order given. Returns the merged
    # pack with a Layers list naming what went into it.
    [CmdletBinding()]
    [OutputType([hashtable])]
    param([string[]] $Path = @())
    $defaults = Read-GuildPackFile -Path (Join-Path $script:GuildRoot 'defaults.pack.psd1') -IsDefaults
    $merged = $defaults.Data
    $layers = [System.Collections.Generic.List[string]]::new()
    $layers.Add("$($defaults.Data.Name) $($defaults.Data.Version)")
    $loaded = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    foreach ($packPath in $Path) {
        foreach ($pack in Get-GuildPackChain -Path $packPath) {
            if (-not $loaded.Add($pack.Path)) { continue }
            $merged = Merge-GuildData -Base $merged -Overlay $pack.Data
            $layers.Add("$($pack.Data.Name) $($pack.Data.Version)")
        }
    }
    $merged.Remove('Extends')
    $merged['Layers'] = $layers.ToArray()

    # Role-keyed settings must name a role in the merged roster.
    $roster = @(Get-GuildRoleId -Pack $merged)
    foreach ($role in @(if ($merged.RoleAddenda) { $merged.RoleAddenda.Keys })) {
        if ($role -notin $roster -and $role -ne $script:GuildMainSession) { throw "RoleAddenda names unknown role '$role'. Roles: $($roster -join ', '), and '$script:GuildMainSession' for the main session." }
    }
    foreach ($harness in @($merged.Models.Keys)) {
        $roles = $merged.Models[$harness]['Roles']
        foreach ($role in @(if ($roles) { $roles.Keys })) {
            if ($role -notin $roster) { throw "Models.$harness.Roles names unknown role '$role'. Roles: $($roster -join ', ')." }
        }
    }
    $merged
}
