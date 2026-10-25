# Writing generated files safely. A manifest per scope (~/.guild/manifest.json for user installs,
# <project>/.guild/manifest.json for project installs) records each file Guild wrote, its hash and
# which harnesses use it. Guild never overwrites a file it didn't write, and refuses to overwrite
# one that was edited by hand since, unless -Force.

$script:GuildUtf8NoBom = [System.Text.UTF8Encoding]::new($false)
# Managed blocks are delimited by <!-- <id>:begin ... --> and <!-- <id>:end -->. 'guild' is the
# instructions-mode block; 'guild-routing' is the routing block for harnesses with subagents. Different
# ids can share one file (AGENTS.md) without replacing each other.
function Get-GuildBlockPattern {
    [CmdletBinding()]
    [OutputType([string])]
    param([string] $Id = 'guild')
    "(?s)\n*<!-- $([regex]::Escape($Id)):begin[^\n]*-->.*?<!-- $([regex]::Escape($Id)):end -->\n?"
}

function Get-GuildHash {
    [CmdletBinding()]
    [OutputType([string])]
    param([Parameter(Mandatory)][AllowEmptyString()][string] $Text)
    $bytes = [System.Text.Encoding]::UTF8.GetBytes($Text.Replace("`r`n", "`n"))
    [System.Convert]::ToHexString([System.Security.Cryptography.SHA256]::HashData($bytes)).ToLowerInvariant()
}

function Read-GuildText {
    [CmdletBinding()]
    [OutputType([string])]
    param([Parameter(Mandatory)][string] $Path)
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { return $null }
    [System.IO.File]::ReadAllText($Path).Replace("`r`n", "`n")
}

function Write-GuildText {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string] $Path, [Parameter(Mandatory)][AllowEmptyString()][string] $Text)
    $directory = Split-Path $Path -Parent
    if (-not (Test-Path -LiteralPath $directory)) { New-Item -ItemType Directory -Path $directory -Force | Out-Null }
    [System.IO.File]::WriteAllText($Path, $Text, $script:GuildUtf8NoBom)
}

function Get-GuildHome {
    # The user-scope root: $env:GUILD_HOME if set (tests, sandboxes), else the home directory.
    [CmdletBinding()]
    [OutputType([string])]
    param()
    if ($env:GUILD_HOME) { return [System.IO.Path]::GetFullPath($env:GUILD_HOME) }
    [System.IO.Path]::GetFullPath($HOME)
}

function Get-GuildScopeRoot {
    [CmdletBinding()]
    [OutputType([string])]
    param([Parameter(Mandatory)][ValidateSet('User', 'Project')][string] $Scope, [string] $Path)
    if ($Scope -eq 'User') { return Get-GuildHome }
    if (-not $Path) { throw '-Scope Project needs -Path <project directory>.' }
    if (-not (Test-Path -LiteralPath $Path -PathType Container)) { throw "Project directory not found: $Path" }
    (Resolve-Path -LiteralPath $Path).ProviderPath
}

function Resolve-GuildTargetPath {
    # Adapter paths use ~ for the home directory (user scope) or are relative to the project.
    [CmdletBinding()]
    [OutputType([string])]
    param([Parameter(Mandatory)][string] $Value, [Parameter(Mandatory)][string] $Root)
    $relative = $Value -replace '^~[\\/]?', ''
    [System.IO.Path]::GetFullPath((Join-Path $Root $relative))
}

function Get-GuildManifestKey {
    # Manifest keys are relative to the scope root, with forward slashes, so a project manifest can be committed.
    [CmdletBinding()]
    [OutputType([string])]
    param([Parameter(Mandatory)][string] $FullPath, [Parameter(Mandatory)][string] $Root)
    [System.IO.Path]::GetRelativePath($Root, $FullPath).Replace('\', '/')
}

function Read-GuildManifest {
    [CmdletBinding()]
    [OutputType([hashtable])]
    param([Parameter(Mandatory)][string] $Root)
    $path = Join-Path $Root '.guild/manifest.json'
    $manifest = @{ Tool = 'guild'; Files = @{}; Sections = @{} }
    if (Test-Path -LiteralPath $path) {
        $loaded = Get-Content -LiteralPath $path -Raw | ConvertFrom-Json -AsHashtable
        foreach ($key in 'Files', 'Sections') { if ($loaded[$key]) { $manifest[$key] = $loaded[$key] } }
    }
    $manifest
}

function Save-GuildManifest {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string] $Root, [Parameter(Mandatory)][hashtable] $Manifest)
    $Manifest['Version'] = $script:GuildVersion
    Write-GuildText -Path (Join-Path $Root '.guild/manifest.json') -Text (($Manifest | ConvertTo-Json -Depth 6) + "`n")
}

function Get-GuildWriteAction {
    # Decides what to do with one generated file. Returns Created, Updated, Unchanged or Skipped (with a note).
    [CmdletBinding()]
    param([Parameter(Mandatory)][string] $Path, [Parameter(Mandatory)][string] $Content, [AllowNull()][hashtable] $Entry, [switch] $Force)
    $current = Read-GuildText -Path $Path
    if ($null -eq $current) { return @{ Action = 'Created'; Note = $null } }
    if ($current -ceq $Content) { return @{ Action = 'Unchanged'; Note = $null } }
    if ($Entry) {
        if ((Get-GuildHash $current) -eq $Entry.Hash -or $Force) { return @{ Action = 'Updated'; Note = $null } }
        return @{ Action = 'Skipped'; Note = 'edited by hand since Guild wrote it; re-run with -Force to replace it' }
    }
    if ($current.Contains($script:GuildMarker)) { return @{ Action = 'Updated'; Note = 'adopted: written by Guild but missing from the manifest' } }
    @{ Action = 'Skipped'; Note = 'exists and was not written by Guild; left alone' }
}

function Set-GuildBlock {
    # Inserts or replaces the managed block in an instructions file's text.
    [CmdletBinding()]
    [OutputType([string])]
    param([AllowNull()][string] $Text, [Parameter(Mandatory)][string] $Block, [string] $Id = 'guild')
    if (-not $Text) { return $Block + "`n" }
    $pattern = Get-GuildBlockPattern -Id $Id
    if ($Text -match $pattern) {
        return [regex]::Replace($Text, $pattern, { param($m) $null = $m; "`n`n$Block`n" }, 'None').TrimStart("`n")
    }
    $Text.TrimEnd("`n") + "`n`n" + $Block + "`n"
}

function Remove-GuildBlock {
    [CmdletBinding()]
    [OutputType([string])]
    param([Parameter(Mandatory)][AllowEmptyString()][string] $Text, [string] $Id = 'guild')
    $result = [regex]::Replace($Text, (Get-GuildBlockPattern -Id $Id), "`n").Trim("`n")
    if ($result) { $result + "`n" } else { '' }
}
