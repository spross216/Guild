function Get-GuildReviewSetting {
    # Review settings for a project: its installed pack, else the user-scope pack, else the defaults.
    [CmdletBinding()]
    [OutputType([hashtable])]
    param([Parameter(Mandatory)][string] $Root)
    foreach ($candidate in (Join-Path $Root '.guild/pack.json'), (Join-Path (Get-GuildHome) '.guild/pack.json')) {
        if (Test-Path -LiteralPath $candidate) {
            $pack = Get-Content -LiteralPath $candidate -Raw | ConvertFrom-Json -AsHashtable
            if ($pack.Review) { return $pack.Review }
        }
    }
    (Resolve-GuildPack).Review
}

function ConvertTo-GuildLowerKey {
    # Reviewer JSON may use any key casing; normalize to lowercase keys.
    [CmdletBinding()]
    [OutputType([hashtable])]
    param([Parameter(Mandatory)][object] $Value)
    $table = @{}
    $pairs = if ($Value -is [System.Collections.IDictionary]) { $Value.GetEnumerator() | ForEach-Object { @{ Key = $_.Key; Value = $_.Value } } }
    else { $Value.PSObject.Properties | ForEach-Object { @{ Key = $_.Name; Value = $_.Value } } }
    foreach ($pair in $pairs) { $table[([string]$pair.Key).ToLowerInvariant()] = $pair.Value }
    $table
}

function ConvertFrom-GuildReport {
    # Accepts the reviewer's JSON (alone, or inside a ```json fence in its prose) or an object.
    [CmdletBinding()]
    [OutputType([hashtable])]
    param([Parameter(Mandatory)][object] $Report)
    if ($Report -is [string]) {
        $json = if ($Report -match '(?s)```json\s*(?<json>\{.*?\})\s*```') { $Matches.json } else { $Report.Trim() }
        try { $Report = $json | ConvertFrom-Json -AsHashtable } catch { throw "The review report is not valid JSON: $($_.Exception.Message)" }
    }
    $report = ConvertTo-GuildLowerKey -Value $Report
    $report['findings'] = @(foreach ($finding in @($report['findings'] | Where-Object { $_ })) { ConvertTo-GuildLowerKey -Value $finding })
    $report
}
