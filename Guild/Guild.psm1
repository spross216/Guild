# Version 1 catches uninitialized variables. Later versions also treat a missing hashtable key as an
# error, and packs and adapters are sparse hashtables where a missing key means "not set".
Set-StrictMode -Version 1.0

$script:GuildRoot = $PSScriptRoot
$script:GuildRepoRoot = (Split-Path $PSScriptRoot -Parent).Replace('\', '/')
$script:GuildVersion = (Import-PowerShellDataFile (Join-Path $PSScriptRoot 'Guild.psd1')).ModuleVersion
$script:GuildAdapterCache = $null

foreach ($folder in 'Private', 'Public') {
    foreach ($file in Get-ChildItem -Path (Join-Path $PSScriptRoot $folder) -Filter '*.ps1' -File) {
        . $file.FullName
    }
}
