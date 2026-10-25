function Test-GuildDocs {
    <#
    .SYNOPSIS
        Finds documentation drift in a project, each finding tagged with the role that owns the fix.
    .DESCRIPTION
        Read-only. Checks every Markdown file outside hidden, generated and dependency folders:

        Steward (prose):
          BrokenLink      a relative link to a file or folder that doesn't exist
          MissingPath     an inline code path in this repository that doesn't exist
          PossiblyStale   files the document references changed after the document did (git history)
        Architect (diagrams, every ```mermaid block):
          MermaidSyntax     no recognized diagram type, or unbalanced brackets
          MermaidReference  a path in the diagram that doesn't exist
          MermaidStale      files the diagram references changed after the document did

        References to other repositories (a first path segment that doesn't exist here), URLs and
        placeholders (<name>, __Token__, *) are not checked. Code inside fenced blocks is not checked
        for paths. Diagrams are checked structurally; rendering them would need the Mermaid CLI.
    .EXAMPLE
        Test-GuildDocs -Path C:\repos\outage-report
    .EXAMPLE
        Test-GuildDocs -Owner architect
    #>
    [CmdletBinding()]
    param(
        [string] $Path = (Get-Location).Path,
        [ValidateSet('steward', 'architect')][string] $Owner
    )
    if (-not $PSBoundParameters.ContainsKey('InformationAction')) { $InformationPreference = 'Continue' }
    $root = Get-GuildScopeRoot -Scope Project -Path $Path
    $useGit = [bool](Get-Command git -ErrorAction SilentlyContinue) -and ((git -C $root rev-parse --is-inside-work-tree 2>$null) -eq 'true')
    $times = @{}
    $findings = [System.Collections.Generic.List[object]]::new()
    $add = { param($Who, $Kind, $File, $Line, $Detail) $findings.Add([pscustomobject]@{ Owner = $Who; Kind = $Kind; File = $File; Line = $Line; Detail = $Detail }) }

    foreach ($doc in Get-GuildDocFile -Root $root) {
        $relative = Get-GuildRelative $root $doc.FullName
        $directory = Split-Path $doc.FullName -Parent
        $proseReferences = [System.Collections.Generic.List[string]]::new()

        foreach ($line in Get-GuildMarkdownLine -Path $doc.FullName) {
            if ($line.Fence) { continue }
            $text = $line.Text
            foreach ($link in [regex]::Matches($text, '!?\[[^\]]*\]\((?<target>[^)\s]+)(?:\s+"[^"]*")?\)')) {
                $target = $link.Groups['target'].Value
                if ($target -match '^(?:[a-z][a-z0-9+.-]*:|#)' -or $target -match '[{}<>]|__') { continue }
                $target = [uri]::UnescapeDataString(($target -split '#')[0])
                if (-not $target) { continue }
                $full = [System.IO.Path]::GetFullPath((Join-Path $(if ($target.StartsWith('/')) { $root } else { $directory }) $target.TrimStart('/')))
                if (Test-Path -LiteralPath $full) { $proseReferences.Add($full) }
                else { & $add 'steward' 'BrokenLink' $relative $line.Number "Link to '$target', which does not exist." }
            }
            foreach ($span in [regex]::Matches(($text -replace '\[[^\]]*\]\([^)]*\)', ''), '`(?<code>[^`]+)`')) {
                $code = $span.Groups['code'].Value
                if (-not (Test-GuildPathCandidate -Text $code)) { continue }
                $full = Resolve-GuildLocalPath -Reference $code -Root $root -DocDirectory $directory
                if (-not $full) { continue }
                if (Test-Path -LiteralPath $full) { $proseReferences.Add($full) }
                else { & $add 'steward' 'MissingPath' $relative $line.Number "``$code`` does not exist in this repository." }
            }
        }

        $diagramReferences = [System.Collections.Generic.List[string]]::new()
        foreach ($block in Get-GuildMermaidBlock -Path $doc.FullName) {
            $content = @($block.Lines | Where-Object { $_.Text.Trim() -and $_.Text.Trim() -notmatch '^%%' })
            $firstWord = if ($content) { ($content[0].Text.Trim() -split '[\s;]+')[0] } else { '' }
            if ($firstWord -notin $script:GuildMermaidTypes) {
                & $add 'architect' 'MermaidSyntax' $relative $block.Line "Diagram starts with '$firstWord', not a Mermaid diagram type."
            }
            $unquoted = (($block.Lines | ForEach-Object { $_.Text }) -join "`n") -replace '"[^"]*"', ''
            foreach ($pair in @(@('[', ']'), @('(', ')'), @('{', '}'))) {
                $open = ($unquoted.ToCharArray() | Where-Object { $_ -eq $pair[0] }).Count
                $close = ($unquoted.ToCharArray() | Where-Object { $_ -eq $pair[1] }).Count
                if ($open -ne $close) { & $add 'architect' 'MermaidSyntax' $relative $block.Line "Unbalanced $($pair[0])$($pair[1]): $open opening, $close closing." }
            }
            $seen = [System.Collections.Generic.HashSet[string]]::new()
            foreach ($token in [regex]::Matches((($block.Lines | ForEach-Object { $_.Text }) -join "`n"), '[\w.-]+(?:/[\w.-]+)+\.[A-Za-z0-9]{1,8}')) {
                if (-not $seen.Add($token.Value) -or -not (Test-GuildPathCandidate -Text $token.Value)) { continue }
                $full = Resolve-GuildLocalPath -Reference $token.Value -Root $root -DocDirectory $directory
                if (-not $full) { continue }
                if (Test-Path -LiteralPath $full) { if (-not $diagramReferences.Contains($full)) { $diagramReferences.Add($full) } }
                else { & $add 'architect' 'MermaidReference' $relative $block.Line "Diagram names '$($token.Value)', which does not exist." }
            }
        }

        if ($useGit) {
            $docTime = Get-GuildCommitTime -Root $root -Path $doc.FullName -Cache $times
            if ($docTime) {
                foreach ($set in @(@{ Who = 'steward'; Kind = 'PossiblyStale'; References = $proseReferences; What = 'Referenced files' }, @{ Who = 'architect'; Kind = 'MermaidStale'; References = $diagramReferences; What = 'Files in its diagrams' })) {
                    $newer = @($set.References | Select-Object -Unique | Where-Object {
                            $time = Get-GuildCommitTime -Root $root -Path $_ -Cache $times
                            $time -and $time -gt $docTime
                        } | ForEach-Object { Get-GuildRelative $root $_ })
                    if ($newer) { & $add $set.Who $set.Kind $relative $null "$($set.What) changed after this document: $(($newer | Select-Object -First 5) -join ', ')$(if ($newer.Count -gt 5) { ", and $($newer.Count - 5) more" })." }
                }
            }
        }
    }

    $result = @($findings | Where-Object { -not $Owner -or $_.Owner -eq $Owner })
    Write-Information -MessageData ("Documentation: {0} finding(s) ({1} steward, {2} architect)." -f $result.Count, @($result | Where-Object Owner -EQ 'steward').Count, @($result | Where-Object Owner -EQ 'architect').Count)
    $result
}
