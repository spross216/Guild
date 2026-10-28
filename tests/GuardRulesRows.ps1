# Rows for GuardRules.Tests.ps1, dot-sourced at discovery and at run time (Pester keeps the two apart).
$script:RulesPath = Join-Path $PSScriptRoot '../guards/Test-GuildReadOnlyCommand.psd1'
$script:RuleData = Import-PowerShellDataFile -LiteralPath $script:RulesPath
$script:CommandRows = foreach ($name in $script:RuleData.PowerShellCommands.Keys | Sort-Object) { @{ CommandName = $name } }
$script:TypeRows = foreach ($type in $script:RuleData.StaticMembers.Keys | Sort-Object) { @{ TypeName = $type } }

# Forbidden Bash characters (docs/guard.md 5.1) inserted at every position of two plain commands.
$forbidden = @('\', '`', '$', ';', '&', '|', '<', '>', '(', ')', '{', '}', '"', "'", '#', '!', "`n", "`r")
$script:InsertRows = foreach ($base in 'cat README.md', 'git log --oneline') {
    foreach ($char in $forbidden) {
        @{ Shown = "'$base' with U+$('{0:X4}' -f [int][char]$char[0])"; Texts = @(foreach ($position in 0..$base.Length) { $base.Insert($position, $char) }) }
    }
}

# Denied options and every prefix of them down to two characters (docs/guard.md 6, prefix rule).
$prefixGroups = [ordered]@{}
$addPrefixes = {
    param($Prefix, $Names)
    foreach ($name in $Names) {
        foreach ($length in 2..$name.Length) {
            if (-not $prefixGroups.Contains($Prefix)) { $prefixGroups[$Prefix] = [System.Collections.Generic.List[string]]::new() }
            $prefixGroups[$Prefix].Add("$Prefix --$($name.Substring(0, $length)) x")
        }
    }
}
foreach ($command in 'rg', 'file', 'tree') {
    $entry = $script:RuleData.NativeCommands[$command]
    if ($entry.DenyLong) { & $addPrefixes $command $entry.DenyLong }
}
$git = $script:RuleData.NativeCommands.git
foreach ($sub in $git.Subcommands.Keys) {
    if ($git.Subcommands[$sub].Mode -eq 'Deny') { & $addPrefixes "git $sub" (@($git.Subcommands[$sub].DenyLong) + @($git.DenyLong)) }
}
& $addPrefixes 'gh pr view 1' $script:RuleData.NativeCommands.gh.DenyLong
& $addPrefixes 'kubectl get pods' $script:RuleData.NativeCommands.kubectl.DenyLong
foreach ($command in 'rg', 'tree', 'file') {
    foreach ($char in $script:RuleData.NativeCommands[$command].DenyShort.ToCharArray()) {
        if (-not $prefixGroups.Contains("$command short")) { $prefixGroups["$command short"] = [System.Collections.Generic.List[string]]::new() }
        $prefixGroups["$command short"].Add("$command -$char x")
    }
}
$script:PrefixRows = foreach ($key in $prefixGroups.Keys) { @{ Shown = $key; Texts = $prefixGroups[$key].ToArray() } }

