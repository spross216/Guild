function Get-GuildPack {
    <#
    .SYNOPSIS
        Validates packs and shows the merged result the roles are rendered from.
    .DESCRIPTION
        Merges the framework defaults with the given packs (and whatever they extend), in order.
        Throws, naming the file and key, if a pack is invalid. Layers lists what went in.
    .EXAMPLE
        Get-GuildPack -Pack C:\packs\acme.pack.psd1
    .EXAMPLE
        Get-GuildPack -Pack .\project.pack.psd1 -AsJson
    #>
    [CmdletBinding()]
    param([string[]] $Pack = @(), [switch] $AsJson)
    $merged = Resolve-GuildPack -Path $Pack
    if ($AsJson) { return $merged | ConvertTo-Json -Depth 8 }
    $merged
}
