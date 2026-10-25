# Helpers for the project-facing commands: the installed pack, documentation files, Mermaid blocks,
# path references and git timestamps. All read-only.

$script:GuildSkippedDirectory = '(^|[\\/])(\.[^\\/]+|node_modules|build|dist|bin|obj|TestResults)([\\/]|$)'
$script:GuildMermaidTypes = @('flowchart', 'graph', 'sequenceDiagram', 'classDiagram', 'stateDiagram', 'stateDiagram-v2', 'erDiagram',
    'gantt', 'pie', 'journey', 'gitGraph', 'mindmap', 'timeline', 'quadrantChart', 'requirementDiagram', 'C4Context', 'C4Container',
    'C4Component', 'C4Dynamic', 'C4Deployment', 'sankey-beta', 'xychart-beta', 'block-beta', 'packet-beta', 'architecture-beta', 'kanban')

function Get-GuildRelative {
    [CmdletBinding()]
    [OutputType([string])]
    param([Parameter(Mandatory)][string] $Root, [Parameter(Mandatory)][string] $Path)
    [System.IO.Path]::GetRelativePath($Root, $Path).Replace('\', '/')
}

function Get-GuildInstalledPack {
    # The merged pack installed for a project: its .guild/pack.json, else the user scope's, else the defaults.
    [CmdletBinding()]
    [OutputType([hashtable])]
    param([Parameter(Mandatory)][string] $Root)
    foreach ($candidate in (Join-Path $Root '.guild/pack.json'), (Join-Path (Get-GuildHome) '.guild/pack.json')) {
        if (Test-Path -LiteralPath $candidate) { return (Get-Content -LiteralPath $candidate -Raw | ConvertFrom-Json -AsHashtable) }
    }
    Resolve-GuildPack
}

function Get-GuildDocFile {
    # Markdown files in a project, skipping hidden, generated and dependency folders.
    [CmdletBinding()]
    param([Parameter(Mandatory)][string] $Root)
    Get-ChildItem -LiteralPath $Root -Recurse -File -Include '*.md', '*.markdown' -ErrorAction SilentlyContinue |
        # Template sources (paths with __Tokens__) describe files rendered elsewhere; their links resolve there.
        Where-Object { $relative = Get-GuildRelative $Root $_.FullName; $relative -notmatch $script:GuildSkippedDirectory -and $relative -notmatch '__\w+__' } |
        Sort-Object FullName
}

function Get-GuildMarkdownLine {
    # Each line of a Markdown file with its number and whether it sits in a fenced block (and which language).
    [CmdletBinding()]
    param([Parameter(Mandatory)][string] $Path)
    $fence = $null
    $number = 0
    foreach ($line in [System.IO.File]::ReadAllLines($Path)) {
        $number++
        if ($line -match '^\s*(```|~~~)\s*(?<lang>[\w-]*)') {
            if ($fence) { [pscustomobject]@{ Number = $number; Text = $line; Fence = $fence; Delimiter = $true }; $fence = $null; continue }
            $fence = if ($Matches.lang) { $Matches.lang } else { 'text' }
            [pscustomobject]@{ Number = $number; Text = $line; Fence = $fence; Delimiter = $true }
            continue
        }
        [pscustomobject]@{ Number = $number; Text = $line; Fence = $fence; Delimiter = $false }
    }
}

function Get-GuildMermaidBlock {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string] $Path)
    $block = $null
    foreach ($line in Get-GuildMarkdownLine -Path $Path) {
        if ($line.Delimiter -and $line.Fence -eq 'mermaid' -and -not $block) { $block = [pscustomobject]@{ Line = $line.Number; Lines = [System.Collections.Generic.List[object]]::new() }; continue }
        if ($block -and $line.Delimiter) { $block; $block = $null; continue }
        if ($block) { $block.Lines.Add($line) }
    }
}

function Test-GuildPathCandidate {
    # Is this text a repository path worth checking? Placeholders, URLs and absolute paths are not.
    [CmdletBinding()]
    [OutputType([bool])]
    param([Parameter(Mandatory)][string] $Text)
    if ($Text -match '[<>*{}$|"]|__|^[a-z]+:|^~|^-|^/|\\\\|\s') { return $false }
    $Text -match '^\.{0,2}/?[\w.-]+(/[\w.-]+)+/?$' -and ($Text -match '\.[A-Za-z0-9]{1,8}$' -or $Text.EndsWith('/'))
}

function Resolve-GuildLocalPath {
    # The full path a reference points at, if it claims to be in this repository (its first segment
    # exists here, at the root or beside the document); $null for references to other repositories.
    [CmdletBinding()]
    [OutputType([string])]
    param([Parameter(Mandatory)][string] $Reference, [Parameter(Mandatory)][string] $Root, [Parameter(Mandatory)][string] $DocDirectory)
    $clean = $Reference.TrimEnd('/') -replace '^\./', ''
    foreach ($base in $Root, $DocDirectory) {
        $full = [System.IO.Path]::GetFullPath((Join-Path $base $clean))
        if (Test-Path -LiteralPath $full) { return $full }
    }
    $first = ($clean -split '/')[0]
    if ($first -in '.', '..') { return [System.IO.Path]::GetFullPath((Join-Path $DocDirectory $clean)) }
    foreach ($base in $Root, $DocDirectory) {
        if (Test-Path -LiteralPath (Join-Path $base $first)) { return [System.IO.Path]::GetFullPath((Join-Path $base $clean)) }
    }
    $null
}

function Get-GuildCommitTime {
    # Unix time of the last commit touching a path, cached; $null outside git or for untracked paths.
    [CmdletBinding()]
    param([Parameter(Mandatory)][string] $Root, [Parameter(Mandatory)][string] $Path, [Parameter(Mandatory)][hashtable] $Cache)
    if ($Cache.ContainsKey($Path)) { return $Cache[$Path] }
    $value = git -C $Root log -1 --format=%ct -- $Path 2>$null
    $Cache[$Path] = if ($LASTEXITCODE -eq 0 -and $value) { [long]$value } else { $null }
    $Cache[$Path]
}
