<#
.SYNOPSIS
    Read-only guard for Guild's read-only and docs roles. A Claude Code PreToolUse hook on the Bash and
    PowerShell tools: reads the hook JSON from stdin, exits 0 to allow the command and 2 to block it
    (the reason goes to stderr, for the agent).

.DESCRIPTION
    A guardrail for a cooperative agent, not a security boundary (docs/decisions/0005). It fails closed:
    a command is allowed only when the guard understands every part of it and every part is listed in
    the rule data (Test-GuildReadOnlyCommand.psd1). The design is docs/guard.md.

    PowerShell commands are parsed with PowerShell's own parser and the syntax tree is checked against
    an allowlist of node types, commands, parameters, members and variables. Bash commands must fit a
    deliberately narrow grammar: a listed command, plain or quoted words, |, && and ||, and redirection
    to /dev/null. The grammar follows the tool name in the hook input; with no tool name the command
    must pass both. Native commands (git, rg, sort, ...) are judged by one set of option rules, whichever
    shell they come from.

.PARAMETER Command
    Judge this text instead of reading hook JSON from stdin (for people and tests).

.PARAMETER Tool
    With -Command, the grammar to use: Bash or PowerShell. Without it, -Command behaves as a hook input
    with no tool name: both grammars must allow.

.PARAMETER Allow
    Extra PowerShell commands, comma-separated, of the form Verb-Noun. The installer passes the commands
    a pack binds to Describe, Diagnose and Check, and New-GuildDecision for docs roles. Other entries are
    ignored. Allowed commands take plain values only: no script blocks, hashtables or splatting.
#>
[CmdletBinding()]
param([string] $Command, [string] $Allow, [string] $Tool)

# Names that exist in the global scope now, before this script defines anything: variables the agent
# may not assign.
$script:GlobalNames = @(Get-Variable -Scope Global -ErrorAction SilentlyContinue | ForEach-Object Name)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$script:BlockMarker = 'GUARD-BLOCK|'
$script:BashHint = 'Bash commands from a read-only role are limited to a listed command, plain or single-quoted arguments, |, &&, || and redirection to /dev/null; use the PowerShell tool for anything else'
$script:DefaultHint = "You don't change things; report what you needed instead"
$script:MaxLength = 8000
$script:MaxDepth = 64
$script:Rules = $null
$script:AliasMap = $null
$script:EngineVariables = $null
$script:Depth = 0
$script:Configured = @{}
$script:AllowNames = @()

function Stop-Guard {
    # Blocks: every walker ends a check by throwing, and the entry point turns it into exit 2.
    param([Parameter(Mandatory)][string] $Reason, [switch] $Bash)
    throw ($script:BlockMarker + $(if ($Bash) { 'B' } else { 'P' }) + '|' + $Reason)
}

function Get-AstProperty {
    # A property that newer PowerShell versions add to a syntax tree node (CleanBlock, GenericTypeArguments):
    # null where the property does not exist, so older versions are not blocked for something they cannot have.
    param($Node, [string] $Name)
    $property = $Node.PSObject.Properties[$Name]
    if ($property) { $property.Value }
}

function Test-Any {
    # True when a collection exists and has an item (@($null).Count is 1, so it can't be used directly).
    param($Collection)
    $null -ne $Collection -and @($Collection | Where-Object { $null -ne $_ }).Count -gt 0
}

function Get-Optional {
    # A key that is optional on purpose in the rule data (strict mode makes a missing key an error).
    param($Table, [string] $Key, $Default = $null)
    if ($null -ne $Table -and $Table.ContainsKey($Key)) { return $Table[$Key] }
    $Default
}

function Get-Snippet {
    # At most 60 characters of offending text, control characters removed.
    param([AllowNull()][string] $Text)
    if ($null -eq $Text) { return '' }
    $clean = $Text -replace '[\x00-\x1F\x7F]', ' '
    if ($clean.Length -gt 60) { $clean = $clean.Substring(0, 57) + '...' }
    $clean
}

function Get-RuleData {
    if ($script:Rules) { return $script:Rules }
    $path = Join-Path $PSScriptRoot 'Test-GuildReadOnlyCommand.psd1'
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { Stop-Guard 'the rule data file is missing, so the guard could not check this command' }
    $data = Import-PowerShellDataFile -LiteralPath $path
    foreach ($key in 'CommonParameters', 'NeverParameters', 'PowerShellCommands', 'ConfiguredObjects', 'StaticMembers', 'InstanceMethods', 'DeniedMembers', 'ConvertTypes', 'ReservedVariables', 'AssignablePreferences', 'NativeCommands', 'CloudDeniedVerbs') {
        if (-not $data.ContainsKey($key)) { Stop-Guard "the rule data file has no '$key', so the guard could not check this command" }
    }
    $script:Rules = $data
    $data
}

# ---------------------------------------------------------------------------------------------
# PowerShell grammar (docs/guard.md section 4)
# ---------------------------------------------------------------------------------------------

$script:NodeNames = @{
    SwitchStatementAst         = 'a switch statement'
    WhileStatementAst          = 'a while loop'
    DoWhileStatementAst        = 'a do/while loop'
    DoUntilStatementAst        = 'a do/until loop'
    TryStatementAst            = 'a try statement'
    FunctionDefinitionAst      = 'a function definition'
    ReturnStatementAst         = 'return'
    ThrowStatementAst          = 'throw'
    ExitStatementAst           = 'exit'
    TrapStatementAst           = 'a trap'
    DataStatementAst           = 'a data section'
    UsingStatementAst          = 'a using statement'
    TypeDefinitionAst          = 'a class or enum definition'
    ConfigurationDefinitionAst = 'a configuration'
    DynamicKeywordStatementAst = 'a dynamic keyword'
    BlockStatementAst          = 'a parallel or sequence block'
    UsingExpressionAst         = 'a $using: expression'
    AttributedExpressionAst    = 'an attributed expression'
    ErrorExpressionAst         = 'an incomplete expression'
}

function Get-NodeName {
    param($Node)
    $name = $Node.GetType().Name
    if ($script:NodeNames.ContainsKey($name)) { return $script:NodeNames[$name] }
    "a $($name -replace 'Ast$', '') node"
}

function Enter-Depth {
    $script:Depth++
    if ($script:Depth -gt $script:MaxDepth) { Stop-Guard 'the command is nested too deeply for the guard to check' }
}

function Get-AliasMap {
    # Built once, and only when a name is not in the rule data: name -> definition.
    if ($null -eq $script:AliasMap) {
        $map = @{}
        foreach ($alias in Get-Alias) { $map[$alias.Name] = [string]$alias.Definition }
        $script:AliasMap = $map
    }
    $script:AliasMap
}

function Get-TypeFullName {
    param($TypeName)
    $type = $null
    try { $type = $TypeName.GetReflectionType() } catch { $type = $null }
    if ($null -eq $type) { Stop-Guard "the type [$(Get-Snippet $TypeName.Name)] isn't known" }
    $type.FullName
}

function ConvertTo-GlobRegex {
    # One path segment, read as a wildcard (* ? [abc] [!abc]), as an anchored case-insensitive regex.
    param([string] $Segment)
    $regex = [System.Text.StringBuilder]::new('^')
    for ($k = 0; $k -lt $Segment.Length; $k++) {
        $char = $Segment[$k]
        if ($char -eq '*') { $null = $regex.Append('.*') }
        elseif ($char -eq '?') { $null = $regex.Append('.') }
        elseif ($char -eq '[' -and $Segment.IndexOf(']', $k + 1) -gt $k + 1) {
            $close = $Segment.IndexOf(']', $k + 1)
            $class = $Segment.Substring($k + 1, $close - $k - 1)
            if ($class.StartsWith('!')) { $class = '^' + $class.Substring(1) }
            $null = $regex.Append('[').Append($class.Replace('\', '\\')).Append(']')
            $k = $close
        }
        else { $null = $regex.Append([regex]::Escape([string]$char)) }
    }
    $null = $regex.Append('$')
    $regex.ToString()
}

function Test-GlobSegmentMatch {
    # Whether a wildcard segment can match a name. A shell does not expand a leading wildcard to a dot-file.
    param([string] $Segment, [string] $Name, [bool] $ShellExpands)
    if ($ShellExpands -and $Segment.Length -gt 0 -and $Segment[0] -in '*', '?', '[' -and $Name.StartsWith('.')) { return $false }
    [regex]::IsMatch($Name, (ConvertTo-GlobRegex -Segment $Segment), 'IgnoreCase')
}

function Get-GlobWildcardPattern { '[*?]|\[[^\]/\\]+\]' }

function Test-GlobExampleOnly {
    # A wildcard last segment that can match only placeholder files (.env.exam*): none of the probe names, at least one example.
    param([string] $Text, [bool] $ShellExpands)
    $rules = Get-RuleData
    $segments = @($Text -split '[/\\]' | Where-Object { $_ -ne '' })
    if ($segments.Count -eq 0 -or $segments[-1] -notmatch (Get-GlobWildcardPattern)) { return $false }
    $last = $segments[-1]
    foreach ($probe in @($rules.SecretGlobProbes)) { if (Test-GlobSegmentMatch -Segment $last -Name $probe -ShellExpands $ShellExpands) { return $false } }
    foreach ($example in @($rules.EnvExampleNames)) { if (Test-GlobSegmentMatch -Segment $last -Name $example -ShellExpands $ShellExpands) { return $true } }
    $false
}

function Test-GlobSecret {
    # A wildcard in a path word can reach a credentials file whose name the patterns spell out (.env*, .a?s/credentials,
    # id_r?a). Each segment's literal prefix (up to the first wildcard) is compared with the credential names; the last
    # segment, read as a wildcard, must match none of the probe names; and the last segments of the path must not match
    # a credentials path such as .aws/credentials.
    param([string] $Text, [bool] $ShellExpands, [bool] $Listing = $false)
    $rules = Get-RuleData
    $wildcard = Get-GlobWildcardPattern
    if ($Text -notmatch $wildcard) { return }
    $segments = @($Text -split '[/\\]' | Where-Object { $_ -ne '' })
    for ($i = 0; $i -lt $segments.Count; $i++) {
        $segment = $segments[$i]
        $first = [regex]::Match($segment, $wildcard)
        if (-not $first.Success) { continue }
        $prefix = $segment.Substring(0, $first.Index)
        if ($prefix.Length -gt 0 -and -not ($first.Value.StartsWith('[') -and $prefix -eq '.')) {
            foreach ($name in @($rules.SecretSegmentNames)) {
                if ($name.StartsWith($prefix, [System.StringComparison]::OrdinalIgnoreCase)) { Stop-Guard "the pattern '$(Get-Snippet $Text)' can match a credentials file or folder ($name), which isn't shown to a read-only role" }
            }
        }
    }
    $last = $segments[-1]
    if ($last -match $wildcard) {
        # A segment that is only wildcards (* or ?*) does not match a credentials name by itself (it matters only when the
        # folder before it is a credentials folder, which the name patterns catch). In PowerShell a bare wildcard also
        # reaches dot-files, so a command that reads files refuses it; a listing, or a shell (whose * skips dot-files), may.
        $literal = [regex]::Replace($last, $wildcard, '')
        $leading = $last[0] -in '*', '?', '['
        if ($literal -eq '' -and -not $Listing -and -not $ShellExpands) {
            # PowerShell wildcards match dot-files such as .env, so a reading command can't take a bare wildcard.
            Stop-Guard "the wildcard '$(Get-Snippet $Text)' in a command that reads files also matches dot-files such as .env; name an extension (for example src/*.ps1)"
        }
        if ($literal -ne '') {
            foreach ($probe in @($rules.SecretGlobProbes)) {
                if ($leading -and $Listing -and $probe -in @($rules.LeadingWildcardSkip)) { continue }
                if (Test-GlobSegmentMatch -Segment $last -Name $probe -ShellExpands $ShellExpands) { Stop-Guard "the pattern '$(Get-Snippet $Text)' can match a credentials file or folder ($probe), which isn't shown to a read-only role" }
            }
        }
    }
    foreach ($target in @($rules.SecretGlobTargets)) {
        $parts = @($target -split '/')
        if ($segments.Count -lt $parts.Count) { continue }
        $offset = $segments.Count - $parts.Count
        $all = $true
        for ($k = 0; $k -lt $parts.Count; $k++) {
            if (-not (Test-GlobSegmentMatch -Segment $segments[$offset + $k] -Name $parts[$k] -ShellExpands $ShellExpands)) { $all = $false; break }
        }
        if ($all) { Stop-Guard "the pattern '$(Get-Snippet $Text)' can match a credentials path ($target), which isn't shown to a read-only role" }
    }
}

function Test-SecretText {
    # A word or string naming a credentials file or the environment drive (see SecretPathPatterns in the rule data).
    # -Shell Bash: no environment drive exists there. -SkipEnvironment / -SkipGlob: the text is a search or regex pattern,
    # or an argument to a native program, not a path PowerShell resolves.
    param([AllowNull()][string] $Text, [string] $Shell = 'PowerShell', [switch] $SkipEnvironment, [switch] $SkipGlob, [switch] $SkipNames, [switch] $Listing)
    if ([string]::IsNullOrEmpty($Text)) { return }
    $rules = Get-RuleData
    # --option=value: the value is a path (or a pattern, if the option's word is exempt) in its own right.
    if ($Text -match '^-{1,2}[A-Za-z][A-Za-z0-9-]*=(?<value>.+)$') {
        Test-SecretText -Text $Matches['value'] -Shell $Shell -SkipEnvironment:$SkipEnvironment -SkipGlob:$SkipGlob -SkipNames:$SkipNames -Listing:$Listing
    }
    # -fVALUE, -m5, -f.env: a short option with its value attached; the value is a path (or a pattern, when the word is exempt).
    if ($Text -match '^-[A-Za-z](?<attached>[^=].*)$') {
        Test-SecretText -Text $Matches['attached'] -Shell $Shell -SkipEnvironment:$SkipEnvironment -SkipGlob:$SkipGlob -SkipNames:$SkipNames -Listing:$Listing
    }
    $nameText = $Text
    if (-not $SkipGlob -and (Test-GlobExampleOnly -Text $Text -ShellExpands ($Shell -eq 'Bash'))) {
        # .env.exam* can match only placeholder files; the folders before it are still checked.
        $nameText = ($Text -replace '[^/\\]*$', '')
    }
    if ($SkipNames) { $nameText = '' }
    foreach ($pattern in @($rules.SecretPathPatterns)) {
        if ($nameText -match $pattern) {
            $excepted = $false
            foreach ($exception in @(Get-Optional $rules 'SecretPathExceptions')) { if ($nameText -match $exception) { $excepted = $true } }
            if (-not $excepted) { Stop-Guard "'$(Get-Snippet $Text)' names a file that holds credentials or secrets, which isn't shown to a read-only role" }
        }
    }
    if (-not $Listing -and $nameText -ne '') {
        # Names that are only secret when a file of that name is read (a folder called credentials is fine to list).
        foreach ($pattern in @($rules.SecretReadPatterns)) {
            if ($nameText -match $pattern) { Stop-Guard "'$(Get-Snippet $Text)' names a file that holds credentials, which isn't shown to a read-only role" }
        }
    }
    if (-not $SkipGlob) { Test-GlobSecret -Text $Text -ShellExpands ($Shell -eq 'Bash') -Listing $Listing.IsPresent }
    if ($Text -match $rules.ShortNamePattern -or $Text -match $rules.ShortNameBarePattern) { Stop-Guard "'$(Get-Snippet $Text)' has an 8.3 short-name segment (NAME~1), which can reach a credentials file under another name" }
    if ($Shell -eq 'Bash' -or $SkipEnvironment) { return }
    # The environment: any spelling of its drive or provider (env:, Environment::, Microsoft.PowerShell.Core\Environment::).
    # PowerShell tolerates runs of separators (env:\, Core\\Environment::), so they are collapsed before matching, and
    # PowerShell is asked which provider the word resolves to (nothing is read: the path is only parsed).
    $collapsed = [regex]::Replace($Text, '[/\\]{2,}', '\')
    # What follows the drive or provider (after one optional separator) is the remainder. Only a single plain,
    # non-secret variable name may follow; every other remainder blocks, so no spelling of "all" gets through.
    $remainder = $null
    if ($collapsed -match $rules.EnvDrivePattern) { $remainder = $Matches['name'] }
    elseif ($Text.Contains(':')) {
        $provider = $null
        $drive = $null
        $parsed = $true
        try { $null = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($Text, [ref]$provider, [ref]$drive) } catch { $parsed = $false }
        if (-not $parsed) {
            # No answer from PowerShell: refuse anything that looks like the environment (std::string and C:\x do not).
            if ($Text -match $rules.EnvProviderFallbackPattern) { Stop-Guard "'$(Get-Snippet $Text)' looks like the environment drive or provider but can't be parsed, so it is refused" }
        }
        elseif ($null -ne $provider -and $provider.Name -eq 'Environment') {
            $index = $Text.IndexOf('::')
            $remainder = if ($index -ge 0) { $Text.Substring($index + 2) } else { $Text.Substring($Text.IndexOf(':') + 1) }
            $remainder = [regex]::Replace($remainder, '^[/\\]', '')
        }
    }
    if ($null -ne $remainder -and ($remainder -cnotmatch $rules.EnvNamePattern -or $remainder -match $rules.SecretNamePattern)) {
        Stop-Guard "'$(Get-Snippet $Text)' reads the environment other than as one plain, non-secret variable name (a dump, a wildcard, dots or a secret name), which isn't shown to a read-only role"
    }
}

function Assert-VariableRead {
    param($Variable)
    if ($Variable.Splatted) { Stop-Guard 'splatting (@variable) isn''t allowed' }
    $path = $Variable.VariablePath
    $ok = $path.IsUnqualified -or ($path.IsDriveQualified -and $path.DriveName -eq 'env') -or $path.IsGlobal -or $path.IsScript -or $path.IsLocal
    if (-not $ok) { Stop-Guard "reading '$(Get-Snippet $Variable.Extent.Text)' isn't allowed" }
    if ($path.IsDriveQualified -and $path.DriveName -eq 'env') {
        $variableName = $path.UserPath.Substring(4)
        if ($variableName -cnotmatch (Get-RuleData).EnvNamePattern -or $variableName -match (Get-RuleData).SecretNamePattern) {
            Stop-Guard "reading '$(Get-Snippet $Variable.Extent.Text)' isn't allowed (an environment variable must have a plain name and not hold a secret)"
        }
    }
}

function Get-EngineVariableName {
    # Variables a fresh engine defines (the guard's own global scope misses some, such as the Maximum*Count ones
    # the rule data lists). Built once, only when an assignment needs it.
    if ($null -eq $script:EngineVariables) {
        $shell = [powershell]::Create()
        try { $script:EngineVariables = @($shell.AddScript('Get-Variable | ForEach-Object Name').Invoke()) } finally { $shell.Dispose() }
        $script:EngineVariables += @([System.Management.Automation.Runspaces.InitialSessionState]::CreateDefault2().Variables | ForEach-Object Name)
    }
    $script:EngineVariables
}

function Assert-VariableWrite {
    param($Variable)
    $rules = Get-RuleData
    if ($Variable -isnot [System.Management.Automation.Language.VariableExpressionAst]) { Stop-Guard "assigning to '$(Get-Snippet $Variable.Extent.Text)' isn't allowed (only plain variables)" }
    if ($Variable.Splatted) { Stop-Guard 'splatting (@variable) isn''t allowed' }
    $path = $Variable.VariablePath
    if (-not $path.IsUnqualified -or $path.IsDriveQualified) { Stop-Guard "assigning to '$(Get-Snippet $Variable.Extent.Text)' isn't allowed (scoped, drive and environment variables can't be assigned)" }
    $name = $path.UserPath
    if ($name -notmatch '^[A-Za-z_][A-Za-z0-9_]*$') { Stop-Guard "assigning to '$(Get-Snippet $name)' isn't allowed" }
    if ($name -eq 'null') { return }
    if ($name -in $rules.AssignablePreferences) { return }
    if ($name -cnotmatch $rules.UserVariablePattern) { Stop-Guard "assigning to '`$$name' isn't allowed: assign only to variables that start with a lowercase letter (engine variables never do)" }
    $reserved = ($name -in $rules.ReservedVariables) -or ($name -like 'PS*') -or ($name -like '*Preference') -or ($name -in $script:GlobalNames) -or ($name -in (Get-EngineVariableName))
    if ($reserved) { Stop-Guard "assigning to the reserved variable '`$$name' isn't allowed" }
}

function Assert-Redirection {
    param($Redirections)
    foreach ($redirection in @($Redirections | Where-Object { $null -ne $_ })) {
        if ($redirection -is [System.Management.Automation.Language.MergingRedirectionAst]) { continue }
        if ($redirection -is [System.Management.Automation.Language.FileRedirectionAst]) {
            $location = $redirection.Location
            if ($location -is [System.Management.Automation.Language.VariableExpressionAst] -and $location.VariablePath.UserPath -eq 'null' -and $location.VariablePath.IsUnqualified) { continue }
            Stop-Guard "redirection to a file isn't allowed ('$(Get-Snippet $redirection.Extent.Text)'); only 2>&1 and redirection to `$null are"
        }
        Stop-Guard "a redirection of this kind isn't allowed ('$(Get-Snippet $redirection.Extent.Text)')"
    }
}

function Assert-StatementBlock {
    param($Block)
    if ($null -eq $Block) { return }
    if (Test-Any $Block.Traps) { Stop-Guard 'a trap isn''t allowed' }
    foreach ($statement in @($Block.Statements | Where-Object { $null -ne $_ })) { Assert-Statement -Statement $statement -Top $false }
}

function Assert-ScriptBlock {
    param($Block)
    if ($Block.ParamBlock -or $Block.DynamicParamBlock -or $Block.BeginBlock -or $Block.ProcessBlock -or (Get-AstProperty $Block 'CleanBlock')) {
        Stop-Guard 'a script block with a param, begin, process, clean or dynamicparam block isn''t allowed'
    }
    if ((Test-Any $Block.UsingStatements) -or $Block.ScriptRequirements) { Stop-Guard '#requires and using statements aren''t allowed' }
    if (Test-Any $Block.Attributes) { Stop-Guard 'attributes on a script block aren''t allowed' }
    Assert-StatementBlock -Block $Block.EndBlock
}

function Assert-Statement {
    param($Statement, [bool] $Top = $false)
    Enter-Depth
    try {
        $type = $Statement.GetType().Name
        switch ($type) {
            'PipelineAst' {
                if ($Statement.Background) { Stop-Guard 'running in the background (&) isn''t allowed' }
                foreach ($element in @($Statement.PipelineElements | Where-Object { $null -ne $_ })) {
                    if ($element -is [System.Management.Automation.Language.CommandAst]) { Assert-Command -CommandAst $element -Top $Top }
                    elseif ($element -is [System.Management.Automation.Language.CommandExpressionAst]) {
                        Assert-Expression -Expression $element.Expression
                        Assert-Redirection -Redirections $element.Redirections
                    }
                    else { Stop-Guard "$(Get-NodeName $element) isn't allowed in a pipeline" }
                }
            }
            'PipelineChainAst' {
                if ($Statement.Background) { Stop-Guard 'running in the background (&) isn''t allowed' }
                Assert-Statement -Statement $Statement.LhsPipelineChain -Top $Top
                Assert-Statement -Statement $Statement.RhsPipeline -Top $Top
            }
            'CommandExpressionAst' {
                Assert-Expression -Expression $Statement.Expression
                Assert-Redirection -Redirections $Statement.Redirections
            }
            'AssignmentStatementAst' { Assert-Assignment -Statement $Statement -Top $Top }
            'IfStatementAst' {
                foreach ($clause in @($Statement.Clauses | Where-Object { $null -ne $_ })) {
                    Assert-Statement -Statement $clause.Item1 -Top $false
                    Assert-StatementBlock -Block $clause.Item2
                }
                Assert-StatementBlock -Block $Statement.ElseClause
            }
            'ForEachStatementAst' {
                if ($Statement.Flags.ToString() -ne 'None' -or $Statement.ThrottleLimit) { Stop-Guard 'foreach -Parallel isn''t allowed' }
                Assert-VariableWrite -Variable $Statement.Variable
                Assert-Statement -Statement $Statement.Condition -Top $false
                Assert-StatementBlock -Block $Statement.Body
            }
            'ForStatementAst' {
                foreach ($part in $Statement.Initializer, $Statement.Condition, $Statement.Iterator) {
                    if ($part) { Assert-Statement -Statement $part -Top $false }
                }
                Assert-StatementBlock -Block $Statement.Body
            }
            { $_ -in 'BreakStatementAst', 'ContinueStatementAst' } {
                if ($Statement.Label) { Stop-Guard 'break and continue with a label aren''t allowed' }
            }
            default { Stop-Guard "$(Get-NodeName $Statement) isn't allowed" }
        }
    }
    finally { $script:Depth-- }
}

function Assert-Assignment {
    param($Statement, [bool] $Top)
    $allowedOperators = 'Equals', 'PlusEquals', 'MinusEquals', 'MultiplyEquals', 'DivideEquals', 'RemainderEquals', 'QuestionQuestionEquals'
    if ($Statement.Operator.ToString() -notin $allowedOperators) { Stop-Guard "the assignment operator '$($Statement.Operator)' isn't allowed" }
    $left = $Statement.Left
    $rules = Get-RuleData

    if ($left -is [System.Management.Automation.Language.VariableExpressionAst]) {
        Assert-VariableWrite -Variable $left
        Assert-Statement -Statement $Statement.Right -Top $false
        if ($Top) {
            # Remember a variable built by a configured-object factory (New-PesterConfiguration); any other assignment forgets it.
            $name = $left.VariablePath.UserPath
            $right = $Statement.Right
            $isFactory = $false
            if ($Statement.Operator.ToString() -eq 'Equals' -and $right -is [System.Management.Automation.Language.PipelineAst] -and @($right.PipelineElements).Count -eq 1 -and $right.PipelineElements[0] -is [System.Management.Automation.Language.CommandAst]) {
                $commandAst = $right.PipelineElements[0]
                if (@($commandAst.CommandElements).Count -eq 1) {
                    $factoryName = $commandAst.CommandElements[0].Extent.Text
                    foreach ($key in $rules.ConfiguredObjects.Keys) {
                        if ($rules.ConfiguredObjects[$key].Factory -eq $factoryName -and $script:WriteCounts[$name.ToLowerInvariant()] -eq 1) { $script:Configured[$name] = $key; $isFactory = $true }
                    }
                }
            }
            if (-not $isFactory) { $script:Configured.Remove($name) }
        }
        return
    }

    if ($left -is [System.Management.Automation.Language.MemberExpressionAst] -and $Top -and $Statement.Operator.ToString() -eq 'Equals') {
        $members = [System.Collections.Generic.List[string]]::new()
        $node = $left
        while ($node -is [System.Management.Automation.Language.MemberExpressionAst] -and -not $node.Static) {
            if ($node.Member -isnot [System.Management.Automation.Language.StringConstantExpressionAst] -or $node.Member.StringConstantType -ne 'BareWord') { Stop-Guard "assigning to '$(Get-Snippet $left.Extent.Text)' isn't allowed" }
            $members.Insert(0, $node.Member.Value)
            $node = $node.Expression
        }
        $configuredKey = $null
        if ($node -is [System.Management.Automation.Language.VariableExpressionAst] -and $node.VariablePath.IsUnqualified -and $script:Configured.ContainsKey($node.VariablePath.UserPath)) { $configuredKey = $script:Configured[$node.VariablePath.UserPath] }
        if (-not $configuredKey) { Stop-Guard "property assignment isn't allowed ('$(Get-Snippet $left.Extent.Text)'); only settings of an object built by New-PesterConfiguration in this command can be set" }
        $path = $members -join '.'
        if ($path -notin $rules.ConfiguredObjects[$configuredKey].Settings) { Stop-Guard "the setting '$path' isn't allowed (result and coverage files are never enabled)" }
        $right = $Statement.Right
        if ($right -is [System.Management.Automation.Language.PipelineAst] -and @($right.PipelineElements).Count -eq 1) { $right = $right.PipelineElements[0] }
        if ($right -isnot [System.Management.Automation.Language.CommandExpressionAst]) { Stop-Guard "the value of '$path' must be a plain value" }
        Assert-Expression -Expression $right.Expression
        return
    }
    Stop-Guard "assigning to '$(Get-Snippet $left.Extent.Text)' isn't allowed (only plain variables; no property, index, typed or multiple assignment)"
}

function Assert-Expression {
    param($Expression)
    Enter-Depth
    try {
        $rules = Get-RuleData
        $type = $Expression.GetType().Name
        switch ($type) {
            { $_ -in 'ConstantExpressionAst', 'StringConstantExpressionAst' } { }
            'ExpandableStringExpressionAst' { foreach ($nested in @($Expression.NestedExpressions | Where-Object { $null -ne $_ })) { Assert-Expression -Expression $nested } }
            'VariableExpressionAst' { Assert-VariableRead -Variable $Expression }
            'MemberExpressionAst' { Assert-Member -Expression $Expression }
            'InvokeMemberExpressionAst' { Assert-Member -Expression $Expression }
            'IndexExpressionAst' {
                Assert-Expression -Expression $Expression.Target
                Assert-Expression -Expression $Expression.Index
            }
            'ArrayLiteralAst' { foreach ($element in @($Expression.Elements | Where-Object { $null -ne $_ })) { Assert-Expression -Expression $element } }
            { $_ -in 'ArrayExpressionAst', 'SubExpressionAst' } { Assert-StatementBlock -Block $Expression.SubExpression }
            'ParenExpressionAst' { Assert-Statement -Statement $Expression.Pipeline -Top $false }
            'BinaryExpressionAst' { Assert-Binary -Expression $Expression }
            'UnaryExpressionAst' {
                $allowed = 'Not', 'Exclaim', 'Minus', 'Plus', 'Bnot', 'Join', 'Isplit', 'Csplit', 'Comma', 'PlusPlus', 'MinusMinus', 'PostfixPlusPlus', 'PostfixMinusMinus'
                $kind = $Expression.TokenKind.ToString()
                if ($kind -notin $allowed) { Stop-Guard "the operator '$(Get-Snippet $Expression.Extent.Text)' isn't allowed" }
                if ($kind -in 'PlusPlus', 'MinusMinus', 'PostfixPlusPlus', 'PostfixMinusMinus') { Assert-VariableWrite -Variable $Expression.Child }
                else { Assert-Expression -Expression $Expression.Child }
            }
            'TernaryExpressionAst' {
                Assert-Expression -Expression $Expression.Condition
                Assert-Expression -Expression $Expression.IfTrue
                Assert-Expression -Expression $Expression.IfFalse
            }
            'ConvertExpressionAst' {
                $full = Get-TypeFullName -TypeName $Expression.Type.TypeName
                if ($full -notin $rules.ConvertTypes) { Stop-Guard "a conversion to [$(Get-Snippet $Expression.Type.TypeName.Name)] isn't allowed" }
                $child = $Expression.Child
                if ($child -is [System.Management.Automation.Language.HashtableAst]) { Assert-PlainHashtable -Hashtable $child }
                else { Assert-Expression -Expression $child }
            }
            'ScriptBlockExpressionAst' { Stop-Guard 'script blocks are allowed only as arguments to listed commands' }
            'HashtableAst' { Stop-Guard 'a hashtable is allowed only as a property argument or under a conversion' }
            'TypeExpressionAst' { Stop-Guard "a type ('$(Get-Snippet $Expression.Extent.Text)') can't be used as a value" }
            default { Stop-Guard "$(Get-NodeName $Expression) isn't allowed" }
        }
    }
    finally { $script:Depth-- }
}

function Assert-PlainHashtable {
    # Constant keys, plain values: [pscustomobject]@{...}, [ordered]@{...}.
    param($Hashtable)
    foreach ($pair in $Hashtable.KeyValuePairs) {
        if ($pair.Item1 -isnot [System.Management.Automation.Language.StringConstantExpressionAst] -and $pair.Item1 -isnot [System.Management.Automation.Language.ConstantExpressionAst]) { Stop-Guard 'hashtable keys must be constant' }
        Assert-HashtableValue -Statement $pair.Item2 -AllowScriptBlock $false
    }
}

function Assert-HashtableValue {
    param($Statement, [bool] $AllowScriptBlock)
    $element = $Statement
    if ($element -is [System.Management.Automation.Language.PipelineAst] -and @($element.PipelineElements).Count -eq 1) { $element = $element.PipelineElements[0] }
    if ($element -isnot [System.Management.Automation.Language.CommandExpressionAst]) { Stop-Guard 'a hashtable value must be a plain expression' }
    $expression = $element.Expression
    if ($AllowScriptBlock) {
        # A calculated property (@{N=...;E=...}): the values are literals or literal script blocks, never a variable.
        if ($expression -is [System.Management.Automation.Language.ScriptBlockExpressionAst]) { Assert-ScriptBlock -Block $expression.ScriptBlock; return }
        if ($expression -isnot [System.Management.Automation.Language.StringConstantExpressionAst] -and $expression -isnot [System.Management.Automation.Language.ConstantExpressionAst]) {
            Stop-Guard "a calculated property value must be a literal or a script block written out, not '$(Get-Snippet $expression.Extent.Text)'"
        }
        return
    }
    Assert-Expression -Expression $expression
}

function Assert-Binary {
    param($Expression)
    $allowed = 'Plus', 'Minus', 'Multiply', 'Divide', 'Rem',
    'Ieq', 'Ine', 'Ige', 'Igt', 'Ilt', 'Ile', 'Ceq', 'Cne', 'Cge', 'Cgt', 'Clt', 'Cle',
    'Ilike', 'Inotlike', 'Clike', 'Cnotlike', 'Imatch', 'Inotmatch', 'Cmatch', 'Cnotmatch',
    'Icontains', 'Inotcontains', 'Ccontains', 'Cnotcontains', 'Iin', 'Inotin', 'Cin', 'Cnotin',
    'And', 'Or', 'Xor', 'Band', 'Bor', 'Bxor', 'Join', 'Isplit', 'Csplit', 'Ireplace', 'Creplace', 'Format',
    'DotDot', 'QuestionQuestion', 'Is', 'IsNot', 'As'
    $operator = $Expression.Operator.ToString()
    if ($operator -notin $allowed) { Stop-Guard "the operator '$operator' isn't allowed" }
    Assert-Expression -Expression $Expression.Left
    if ($operator -in 'Is', 'IsNot', 'As') {
        $right = $Expression.Right
        if ($right -isnot [System.Management.Automation.Language.TypeExpressionAst]) { Stop-Guard "the right side of -$($operator.ToLowerInvariant()) must be a type" }
        $full = Get-TypeFullName -TypeName $right.TypeName
        if ($operator -eq 'As' -and $full -notin (Get-RuleData).ConvertTypes) { Stop-Guard "-as [$(Get-Snippet $right.TypeName.Name)] isn't allowed" }
        return
    }
    if ($operator -in 'Ireplace', 'Creplace', 'Isplit', 'Csplit') {
        # A variable on the right can hold a script block, which -replace and -split would run.
        $parts = if ($Expression.Right -is [System.Management.Automation.Language.ArrayLiteralAst]) { @($Expression.Right.Elements) } else { @($Expression.Right) }
        foreach ($part in $parts) {
            if ($part -isnot [System.Management.Automation.Language.StringConstantExpressionAst] -and $part -isnot [System.Management.Automation.Language.ConstantExpressionAst] -and $part -isnot [System.Management.Automation.Language.ExpandableStringExpressionAst]) {
                Stop-Guard "the right side of -$($operator.ToLowerInvariant() -replace '^[ic]', '') must be written out (a string), not '$(Get-Snippet $part.Extent.Text)'"
            }
        }
    }
    Assert-Expression -Expression $Expression.Right
}

function Assert-Member {
    param($Expression)
    $rules = Get-RuleData
    $isInvoke = $Expression -is [System.Management.Automation.Language.InvokeMemberExpressionAst]
    $member = $Expression.Member
    if ($member -isnot [System.Management.Automation.Language.StringConstantExpressionAst]) {
        Stop-Guard "a member name must be a constant; '$(Get-Snippet $Expression.Extent.Text)' builds one at run time"
    }
    $name = $member.Value

    if ($Expression.Static) {
        if ($Expression.Expression -isnot [System.Management.Automation.Language.TypeExpressionAst]) { Stop-Guard 'a static member must be called on a type written out, not on a variable or expression' }
        $full = Get-TypeFullName -TypeName $Expression.Expression.TypeName
        if (-not $rules.StaticMembers.ContainsKey($full)) { Stop-Guard "static members of [$full] aren't allowed" }
        if ($name -notin $rules.StaticMembers[$full]) { Stop-Guard "[$full]::$name isn't allowed" }
        if ($full -eq 'System.Text.RegularExpressions.Regex' -and $name -in 'Replace', 'Split') {
            # After the input, the pattern and replacement must be written out: a variable could hold a script block.
            foreach ($argument in @($Expression.Arguments | Where-Object { $null -ne $_ } | Select-Object -Skip 1)) {
                if ($argument -isnot [System.Management.Automation.Language.StringConstantExpressionAst] -and $argument -isnot [System.Management.Automation.Language.ConstantExpressionAst] -and $argument -isnot [System.Management.Automation.Language.ExpandableStringExpressionAst]) {
                    Stop-Guard "[regex]::$name takes its pattern and replacement written out, not '$(Get-Snippet $argument.Extent.Text)'"
                }
            }
        }
        if ($full -eq 'System.Environment' -and $name -eq 'GetEnvironmentVariable') {
            $firstArgument = @($Expression.Arguments | Where-Object { $null -ne $_ } | Select-Object -First 1)
            if ($firstArgument.Count -ne 1 -or $firstArgument[0] -isnot [System.Management.Automation.Language.StringConstantExpressionAst] -or $firstArgument[0].Value -cnotmatch $rules.EnvNamePattern -or $firstArgument[0].Value -match $rules.SecretNamePattern) {
                Stop-Guard 'GetEnvironmentVariable is allowed only with a plain variable name written out that does not look like a secret'
            }
        }
    }
    else {
        Assert-Expression -Expression $Expression.Expression
        if ($isInvoke) {
            if ($name -notin $rules.InstanceMethods) { Stop-Guard "the method '.$(Get-Snippet $name)()' isn't allowed" }
            if (Test-Any (Get-AstProperty $Expression 'GenericTypeArguments')) { Stop-Guard 'generic method calls aren''t allowed' }
        }
        elseif ($name -in $rules.DeniedMembers) { Stop-Guard "reading '.$name' isn't allowed" }
    }
    if ($isInvoke) { foreach ($argument in @($Expression.Arguments | Where-Object { $null -ne $_ })) { Assert-Expression -Expression $argument } }
}

function Assert-ReadableProperty {
    # A property name that opens an object's internals (ScriptBlock, PSObject, ...) can't be asked for by name either.
    param($Argument)
    $parts = if ($Argument -is [System.Management.Automation.Language.ArrayLiteralAst]) { @($Argument.Elements) } else { @($Argument) }
    foreach ($part in $parts) {
        if ($part -isnot [System.Management.Automation.Language.StringConstantExpressionAst] -and $part -isnot [System.Management.Automation.Language.ConstantExpressionAst] -and $part -isnot [System.Management.Automation.Language.ScriptBlockExpressionAst] -and $part -isnot [System.Management.Automation.Language.HashtableAst]) {
            Stop-Guard "a property name must be written out, not '$(Get-Snippet $part.Extent.Text)'"
        }
        if ($part -is [System.Management.Automation.Language.StringConstantExpressionAst] -and $part.Value -in (Get-RuleData).DeniedMembers) {
            Stop-Guard "reading the property '$($part.Value)' isn't allowed"
        }
    }
}

function Assert-Shape {
    param($Argument, [string] $Shape, [bool] $Top, [string] $Context)
    switch ($Shape) {
        'Value' {
            if ($Argument -is [System.Management.Automation.Language.ScriptBlockExpressionAst]) { Stop-Guard "a script block isn't allowed here ($Context)" }
            if ($Context -in '-ExpandProperty', '-ExcludeProperty') { Assert-ReadableProperty -Argument $Argument }
            Assert-Expression -Expression $Argument
        }
        'ScriptBlock' {
            if ($Argument -isnot [System.Management.Automation.Language.ScriptBlockExpressionAst]) { Stop-Guard "$Context takes a script block" }
            Assert-ScriptBlock -Block $Argument.ScriptBlock
        }
        'Property' {
            Assert-ReadableProperty -Argument $Argument
            if ($Argument -is [System.Management.Automation.Language.ScriptBlockExpressionAst]) { Assert-ScriptBlock -Block $Argument.ScriptBlock }
            elseif ($Argument -is [System.Management.Automation.Language.HashtableAst]) {
                foreach ($pair in $Argument.KeyValuePairs) {
                    if ($pair.Item1 -isnot [System.Management.Automation.Language.StringConstantExpressionAst]) { Stop-Guard 'calculated property names must be constant' }
                    Assert-HashtableValue -Statement $pair.Item2 -AllowScriptBlock $true
                }
            }
            elseif ($Argument -is [System.Management.Automation.Language.ArrayLiteralAst]) {
                foreach ($element in @($Argument.Elements)) { Assert-Shape -Argument $element -Shape 'Property' -Top $Top -Context $Context }
            }
            elseif ($Argument -is [System.Management.Automation.Language.StringConstantExpressionAst] -or $Argument -is [System.Management.Automation.Language.ConstantExpressionAst]) { }
            else { Stop-Guard "a property ($Context) must be a name, a script block or a hashtable written out, not '$(Get-Snippet $Argument.Extent.Text)'" }
        }
        'Constant' {
            if ($Argument -isnot [System.Management.Automation.Language.StringConstantExpressionAst]) { Stop-Guard "$Context takes a path or name written out, not '$(Get-Snippet $Argument.Extent.Text)'" }
        }
        'Config' {
            if ($Argument -isnot [System.Management.Automation.Language.VariableExpressionAst] -or -not $Top -or -not $Argument.VariablePath.IsUnqualified -or -not $script:Configured.ContainsKey($Argument.VariablePath.UserPath)) {
                Stop-Guard "$Context takes a configuration object built with New-PesterConfiguration earlier in the same command"
            }
        }
        default { Stop-Guard "the rule data names an unknown argument shape '$Shape'" }
    }
}

function Resolve-PowerShellCommand {
    # Rule data, then alias, then -Allow, then native command; otherwise blocked.
    param([string] $Name)
    $rules = Get-RuleData
    if ($rules.PowerShellCommands.ContainsKey($Name)) {
        $entry = $rules.PowerShellCommands[$Name]
        if ((Get-Optional $entry 'RequiresAllow') -and $Name -notin $script:AllowNames) { Stop-Guard "'$Name' needs to be passed with -Allow for this role" }
        return @{ Kind = 'Data'; Name = $Name; Entry = $entry }
    }
    $aliases = Get-AliasMap
    if ($aliases.ContainsKey($Name)) {
        $definition = $aliases[$Name]
        if (-not $rules.PowerShellCommands.ContainsKey($definition)) { Stop-Guard "'$Name' is an alias of '$definition', which isn't on the read-only list" }
        $entry = $rules.PowerShellCommands[$definition]
        if ((Get-Optional $entry 'RequiresAllow') -and $definition -notin $script:AllowNames) { Stop-Guard "'$definition' needs to be passed with -Allow for this role" }
        return @{ Kind = 'Data'; Name = $definition; Entry = $entry }
    }
    if ($Name -in $script:AllowNames) { return @{ Kind = 'Allow'; Name = $Name; Entry = $null } }
    $native = $Name.ToLowerInvariant()
    if ($rules.NativeCommands.ContainsKey($native)) { return @{ Kind = 'Native'; Name = $native; Entry = $rules.NativeCommands[$native] } }
    Stop-Guard "'$(Get-Snippet $Name)' isn't on the read-only list"
}

function Assert-Command {
    param($CommandAst, [bool] $Top)
    if ($CommandAst.InvocationOperator.ToString() -eq 'Dot') { Stop-Guard 'dot-sourcing isn''t allowed' }
    if ($CommandAst.DefiningKeyword) { Stop-Guard 'a dynamic keyword isn''t allowed' }
    $elements = @($CommandAst.CommandElements)
    $first = $elements[0]
    if ($first -isnot [System.Management.Automation.Language.StringConstantExpressionAst] -or $first.StringConstantType -ne 'BareWord') {
        Stop-Guard "a command must be named by a plain word, not '$(Get-Snippet $first.Extent.Text)'"
    }
    $name = $first.Value
    if ($name -notmatch '^([A-Za-z][A-Za-z0-9._-]*|%|\?)$') { Stop-Guard "'$(Get-Snippet $name)' isn't a plain command name (no paths, drives or quotes)" }
    $resolved = Resolve-PowerShellCommand -Name $name
    Assert-Redirection -Redirections $CommandAst.Redirections
    $arguments = @($elements | Select-Object -Skip 1)

    foreach ($argument in $arguments) {
        if ($argument -is [System.Management.Automation.Language.VariableExpressionAst] -and $argument.Splatted) { Stop-Guard 'splatting (@variable) isn''t allowed' }
    }

    switch ($resolved.Kind) {
        'Native' { Test-NativeFromPowerShell -Name $resolved.Name -Entry $resolved.Entry -Elements $elements }
        'Allow' { Assert-GenericArguments -Name $name -Arguments $arguments }
        default { Assert-DataArguments -Name $resolved.Name -Entry $resolved.Entry -Arguments $arguments -Top $Top }
    }
}

function Assert-GenericArguments {
    # A command passed with -Allow (docs/guard.md 4.11).
    param([string] $Name, $Arguments)
    $rules = Get-RuleData
    foreach ($argument in $Arguments) {
        if ($argument -is [System.Management.Automation.Language.CommandParameterAst]) {
            $parameter = $argument.ParameterName
            if ($parameter -notmatch '^[A-Za-z][A-Za-z0-9]*$') { Stop-Guard "the parameter '$(Get-Snippet $argument.Extent.Text)' isn't allowed for $Name" }
            foreach ($never in $rules.NeverParameters) {
                if ($never.StartsWith($parameter, [System.StringComparison]::OrdinalIgnoreCase)) { Stop-Guard "the parameter '-$parameter' isn't allowed for $Name (it writes a variable)" }
            }
            if ($argument.Argument) { Assert-Shape -Argument $argument.Argument -Shape 'Value' -Top $false -Context "-$parameter" }
        }
        else { Assert-Shape -Argument $argument -Shape 'Value' -Top $false -Context $Name }
    }
}

function Assert-DataArguments {
    param([string] $Name, $Entry, $Arguments, [bool] $Top)
    $rules = Get-RuleData
    $parameters = $Entry.Parameters
    $positional = @(Get-Optional $Entry 'Positional')
    $denies = Get-Optional $Entry 'Denied'
    $restShape = Get-Optional $Entry 'PositionalRest'
    # A positional argument binds to the next positional parameter not already given by name.
    $named = @($Arguments | Where-Object { $_ -is [System.Management.Automation.Language.CommandParameterAst] } | ForEach-Object { $_.ParameterName })
    $slots = @()
    if ($positional.Count) {
        if (-not $rules.PositionalNames.ContainsKey($Name)) { Stop-Guard "the rule data has no PositionalNames for $Name" }
        $slotNames = $rules.PositionalNames[$Name]
        for ($slot = 0; $slot -lt $positional.Count; $slot++) {
            if (-not (@($slotNames[$slot]) | Where-Object { $_ -in $named })) { $slots += $slot }
        }
    }
    $index = 0
    $position = 0
    while ($index -lt $Arguments.Count) {
        $argument = $Arguments[$index]
        if ($argument -is [System.Management.Automation.Language.CommandParameterAst]) {
            $parameter = $argument.ParameterName
            if ($argument.Extent.Text -eq '--') { Stop-Guard "the end-of-parameters marker '--' isn't allowed for $Name" }
            $shape = $null
            if ($parameters -and $parameters.ContainsKey($parameter)) { $shape = $parameters[$parameter] }
            elseif ($rules.CommonParameters.ContainsKey($parameter)) { $shape = $rules.CommonParameters[$parameter] }
            if (-not $shape) {
                if ($denies) {
                    foreach ($denied in $denies.Keys) {
                        if ($denied.StartsWith($parameter, [System.StringComparison]::OrdinalIgnoreCase)) {
                            $note = if ($denied -eq $parameter) { '' } else { '; write parameter names in full' }
                            Stop-Guard "'-$parameter' isn't allowed for $Name ($($denies[$denied])$note)"
                        }
                    }
                }
                $known = @(@($parameters.Keys) + @($rules.CommonParameters.Keys) | Where-Object { $_.StartsWith($parameter, [System.StringComparison]::OrdinalIgnoreCase) })
                if ($known.Count) { Stop-Guard "'-$parameter' isn't allowed for $Name (write parameter names in full)" }
                Stop-Guard "the parameter '-$(Get-Snippet $parameter)' isn't allowed for $Name"
            }
            if ($shape -eq 'Switch') {
                if ($argument.Argument) {
                    $value = $argument.Argument
                    if ($value -isnot [System.Management.Automation.Language.VariableExpressionAst] -or $value.VariablePath.UserPath -notin 'true', 'false') { Stop-Guard "the switch '-$parameter' takes only `$true or `$false" }
                }
                $index++
                continue
            }
            if ($argument.Argument) { Assert-Shape -Argument $argument.Argument -Shape $shape -Top $Top -Context "-$parameter"; $index++; continue }
            if ($index + 1 -ge $Arguments.Count -or $Arguments[$index + 1] -is [System.Management.Automation.Language.CommandParameterAst]) { Stop-Guard "'-$parameter' needs a value" }
            Assert-Shape -Argument $Arguments[$index + 1] -Shape $shape -Top $Top -Context "-$parameter"
            $index += 2
            continue
        }
        $shape = if ($position -lt $slots.Count) { $positional[$slots[$position]] } elseif ($restShape) { $restShape } else { $null }
        if (-not $shape) { Stop-Guard "too many positional arguments for $Name" }
        Assert-Shape -Argument $argument -Shape $shape -Top $Top -Context $Name
        $position++
        $index++
    }
}

function Test-NativeFromPowerShell {
    # Native commands called from PowerShell take plain words only (docs/guard.md 4.10).
    param([string] $Name, $Entry, $Elements)
    $words = [System.Collections.Generic.List[string]]::new()
    $previousEnd = $Elements[0].Extent.EndOffset
    foreach ($element in @($Elements | Select-Object -Skip 1)) {
        if ($element.Extent.StartOffset -le $previousEnd) { Stop-Guard "native commands from PowerShell need a space between arguments ('$(Get-Snippet $element.Extent.Text)')" }
        $previousEnd = $element.Extent.EndOffset
        if ($element -is [System.Management.Automation.Language.StringConstantExpressionAst]) {
            $value = $element.Value
            if ($value.Length -eq 0 -or $value.Contains('"')) { Stop-Guard "native commands from PowerShell don't take an empty argument or one containing a double quote ('$(Get-Snippet $element.Extent.Text)')" }
            if ($element.StringConstantType -eq 'BareWord' -and $value -match '^-.*[*?\[]') { Stop-Guard "a glob that can expand to an option isn't allowed ('$(Get-Snippet $element.Extent.Text)')" }
            if ($element.StringConstantType -eq 'BareWord' -and $element.Extent.Text -cne $value) { Stop-Guard "quote the whole argument, not part of it ('$(Get-Snippet $element.Extent.Text)')" }
            $words.Add($value)
        }
        elseif ($element -is [System.Management.Automation.Language.ConstantExpressionAst]) { $words.Add($element.Extent.Text) }
        elseif ($element -is [System.Management.Automation.Language.CommandParameterAst] -and -not $element.Argument) {
            if ($element.Extent.Text -match '[*?\[]') { Stop-Guard "a glob in an option isn't allowed ('$(Get-Snippet $element.Extent.Text)'); quote it" }
            $words.Add($element.Extent.Text)
        }
        else { Stop-Guard "native commands from PowerShell take only plain arguments, not '$(Get-Snippet $element.Extent.Text)'" }
    }
    Test-NativeCommand -Name $Name -Entry $Entry -Words $words.ToArray()
}

function Test-PatternPosition {
    # A string that is a search or regex pattern: Select-String's -Pattern (or first positional), or the right side of
    # -match, -notmatch, -replace or -split.
    param($Node)
    $parent = $Node.Parent
    if ($parent -is [System.Management.Automation.Language.CommandParameterAst]) { return ($parent.ParameterName -eq 'Pattern') }
    if ($parent -is [System.Management.Automation.Language.BinaryExpressionAst]) {
        return ($parent.Right -eq $Node -and $parent.Operator.ToString() -in 'Imatch', 'Cmatch', 'Inotmatch', 'Cnotmatch', 'Ireplace', 'Creplace', 'Isplit', 'Csplit')
    }
    if ($parent -is [System.Management.Automation.Language.ArrayLiteralAst] -and $parent.Parent -is [System.Management.Automation.Language.BinaryExpressionAst]) {
        return ($parent.Parent.Right -eq $parent -and $parent.Parent.Operator.ToString() -in 'Ireplace', 'Creplace', 'Isplit', 'Csplit')
    }
    if ($parent -isnot [System.Management.Automation.Language.CommandAst]) { return $false }
    $elements = @($parent.CommandElements)
    if ($elements[0] -isnot [System.Management.Automation.Language.StringConstantExpressionAst] -or $elements[0].Value -notin 'Select-String', 'sls') { return $false }
    $index = [array]::IndexOf($elements, $Node)
    if ($index -gt 1 -and $elements[$index - 1] -is [System.Management.Automation.Language.CommandParameterAst] -and $elements[$index - 1].ParameterName -eq 'Pattern') { return $true }
    # The first positional argument of Select-String is the pattern (unless -Pattern is given by name).
    $named = @($elements | Where-Object { $_ -is [System.Management.Automation.Language.CommandParameterAst] -and $_.ParameterName -eq 'Pattern' })
    if ($named.Count -gt 0) { return $false }
    for ($k = 1; $k -lt $index; $k++) {
        if ($elements[$k] -isnot [System.Management.Automation.Language.CommandParameterAst] -and ($k -eq 1 -or $elements[$k - 1] -isnot [System.Management.Automation.Language.CommandParameterAst])) { return $false }
    }
    $true
}

function Get-CommandNameOfNode {
    # The command a string is an argument of (after alias resolution), or $null.
    param($Node)
    $parent = $Node.Parent
    if ($parent -is [System.Management.Automation.Language.CommandParameterAst]) { $parent = $parent.Parent }
    if ($parent -is [System.Management.Automation.Language.ArrayLiteralAst]) { $parent = $parent.Parent }
    if ($parent -isnot [System.Management.Automation.Language.CommandAst]) { return $null }
    $first = @($parent.CommandElements)[0]
    if ($first -isnot [System.Management.Automation.Language.StringConstantExpressionAst] -or $first -eq $Node) { return $null }
    $rules = Get-RuleData
    $name = $first.Value
    if ($rules.PowerShellCommands.ContainsKey($name)) { return $name }
    $aliases = Get-AliasMap
    if ($aliases.ContainsKey($name)) { return $aliases[$name] }
    $name.ToLowerInvariant()
}

function Test-ListingFilterPosition {
    # A name filter of Get-ChildItem (-Filter, -Include, -Exclude, or the second positional): it selects names to list,
    # it is not a path being read.
    param($Node)
    $parent = $Node.Parent
    if ($parent -is [System.Management.Automation.Language.CommandParameterAst]) {
        if ($parent.ParameterName -notin 'Filter', 'Include', 'Exclude') { return $false }
        return ((Get-CommandNameOfNode -Node $Node) -eq 'Get-ChildItem')
    }
    if ($parent -isnot [System.Management.Automation.Language.CommandAst]) { return $false }
    if ((Get-CommandNameOfNode -Node $Node) -ne 'Get-ChildItem') { return $false }
    $elements = @($parent.CommandElements)
    $index = [array]::IndexOf($elements, $Node)
    if ($index -gt 1 -and $elements[$index - 1] -is [System.Management.Automation.Language.CommandParameterAst] -and $elements[$index - 1].ParameterName -in 'Filter', 'Include', 'Exclude') { return $true }
    $false
}

function Test-JqFilterPosition {
    # jq's filter is a program, not a path: a field called .env is not a credentials file.
    param($Node)
    $parent = $Node.Parent
    if ($parent -isnot [System.Management.Automation.Language.CommandAst]) { return $false }
    $elements = @($parent.CommandElements)
    if ($elements[0] -isnot [System.Management.Automation.Language.StringConstantExpressionAst] -or $elements[0].Value -cne 'jq') { return $false }
    $words = @($elements | Select-Object -Skip 1 | ForEach-Object { $_.Extent.Text })
    $index = Get-JqFilterIndex -Entry (Get-RuleData).NativeCommands.jq -Words $words
    $index -ge 0 -and $elements[$index + 1] -eq $Node
}

function Get-SearchPatternWordIndex {
    # Which words of rg, grep, egrep, fgrep or git grep are the pattern (text to match, never opened). The pattern is the
    # value of -e/--regexp, or else the first plain word; -f/--file values are pattern FILES and are read like any path.
    param([string] $Name, [string[]] $Words)
    $rules = Get-RuleData
    $found = [System.Collections.Generic.List[int]]::new()
    $start = 0
    if ($Name -eq 'git') {
        $start = [array]::IndexOf($Words, 'grep') + 1
        if ($start -le 0) { return @() }
    }
    $valueOptions = @($rules.SearchValueOptions)
    if ($rules.SearchToolValueOptions.ContainsKey($Name)) { $valueOptions += @($rules.SearchToolValueOptions[$Name]) }
    $given = $false
    $afterSeparator = $false
    $positionalOnly = $false
    $i = $start
    while ($i -lt $Words.Count) {
        $word = $Words[$i]
        if ($afterSeparator) { $i++; continue }
        if ($positionalOnly) {
            # After -- every word is a plain word: the first is the pattern (unless given), the rest are files.
            if (-not $given) { $found.Add($i); $given = $true }
            $i++
            continue
        }
        if ($word -ceq '--') { if ($Name -eq 'git') { $afterSeparator = $true } else { $positionalOnly = $true }; $i++; continue }
        if ($word -cin '-e', '--regexp') { if ($i + 1 -lt $Words.Count) { $found.Add($i + 1) }; $given = $true; $i += 2; continue }
        if ($word.StartsWith('--regexp=', [System.StringComparison]::Ordinal)) { $found.Add($i); $given = $true; $i++; continue }
        if ($word -cin '-f', '--file') { $given = $true; $i += 2; continue }
        if ($word.StartsWith('--file=', [System.StringComparison]::Ordinal)) { $given = $true; $i++; continue }
        if ($word -cmatch '^-e.+') { $found.Add($i); $given = $true; $i++; continue }
        if ($word -cmatch '^-f.+') { $given = $true; $i++; continue }
        if ($word -cin $valueOptions) { $i += 2; continue }
        if ($word.StartsWith('-', [System.StringComparison]::Ordinal) -and $word.Length -gt 1) { $i++; continue }
        if (-not $given) { $found.Add($i); $given = $true }
        $i++
    }
    $found.ToArray()
}

function Get-CommandAstName {
    # The name a command resolves to (data name, alias definition, or the program name), or $null for a dynamic name.
    param($Command)
    $first = @($Command.CommandElements)[0]
    if ($first -isnot [System.Management.Automation.Language.StringConstantExpressionAst]) { return $null }
    $rules = Get-RuleData
    $name = $first.Value
    if ($rules.PowerShellCommands.ContainsKey($name)) { return $name }
    $aliases = Get-AliasMap
    if ($aliases.ContainsKey($name)) { return $aliases[$name] }
    $name.ToLowerInvariant()
}

function Test-ReaderHasLiteralPath {
    # Whether a reading command (Get-Content, Select-String) names the file it reads with a constant. When it doesn't, its
    # paths come from the pipeline or a variable, and the guard can't see them.
    param($Command, [string] $Name)
    $entry = (Get-RuleData).PowerShellCommands[$Name]
    $pathSlot = if ($Name -eq 'Select-String') { 1 } else { 0 }
    $positional = 0
    $pending = $null
    foreach ($element in @($Command.CommandElements | Select-Object -Skip 1)) {
        if ($element -is [System.Management.Automation.Language.CommandParameterAst]) {
            $pending = $null
            $parameter = $element.ParameterName
            if ($element.Argument) {
                if (($parameter -in @('Path', 'LiteralPath')) -and $element.Argument -is [System.Management.Automation.Language.StringConstantExpressionAst]) { return $true }
                continue
            }
            $shape = if ($entry.Parameters.ContainsKey($parameter)) { $entry.Parameters[$parameter] } else { $null }
            if ($shape -ne 'Switch') { $pending = $parameter }
            continue
        }
        if ($null -ne $pending) {
            if (($pending -in @('Path', 'LiteralPath')) -and $element -is [System.Management.Automation.Language.StringConstantExpressionAst]) { return $true }
            $pending = $null
            continue
        }
        if ($positional -eq $pathSlot -and $element -is [System.Management.Automation.Language.StringConstantExpressionAst]) { return $true }
        $positional++
    }
    $false
}

function Get-NativeWordContext {
    # For the argument of a native find or git called from PowerShell: whether it is a match pattern (find -name,
    # git branch/tag arguments) and whether the git sub-command only lists names (ls-files, ls-tree, status).
    param($Node)
    $result = @{ Pattern = $false; Listing = $false }
    $parent = $Node.Parent
    if ($parent -isnot [System.Management.Automation.Language.CommandAst]) { return $result }
    $elements = @($parent.CommandElements)
    if ($elements[0] -isnot [System.Management.Automation.Language.StringConstantExpressionAst]) { return $result }
    $rules = Get-RuleData
    $index = [array]::IndexOf($elements, $Node)
    if ($index -lt 1) { return $result }
    $name = $elements[0].Value
    if ($name -ceq 'find') {
        if ($elements[$index - 1].Extent.Text -cin @($rules.FindPatternOptions)) { $result.Pattern = $true }
    }
    elseif ($name -cin 'rg', 'grep', 'egrep', 'fgrep') {
        $words = @($elements | Select-Object -Skip 1 | ForEach-Object { if ($_ -is [System.Management.Automation.Language.StringConstantExpressionAst]) { $_.Value } else { $_.Extent.Text } })
        if (($index - 1) -in @(Get-SearchPatternWordIndex -Name $name -Words $words)) { $result.Pattern = $true }
    }
    elseif ($name -ceq 'git') {
        $subIndex = -1
        for ($k = 1; $k -lt $elements.Count; $k++) {
            if (-not $elements[$k].Extent.Text.StartsWith('-', [System.StringComparison]::Ordinal)) { $subIndex = $k; break }
        }
        if ($subIndex -ge 1) {
            $sub = $elements[$subIndex].Extent.Text
            if ($sub -cin @($rules.GitListingSubcommands)) { $result.Listing = $true }
            if (($sub -cin @('branch', 'tag')) -and $index -gt $subIndex) { $result.Pattern = $true }
            if ($sub -ceq 'grep') {
                $words = @($elements | Select-Object -Skip 1 | ForEach-Object { if ($_ -is [System.Management.Automation.Language.StringConstantExpressionAst]) { $_.Value } else { $_.Extent.Text } })
                if (($index - 1) -in @(Get-SearchPatternWordIndex -Name 'git' -Words $words)) { $result.Pattern = $true }
            }
        }
    }
    $result
}

function Test-NativeArgumentPosition {
    # A string that is an argument of a native program (not an alias of a cmdlet): no provider paths there.
    param($Node)
    $parent = $Node.Parent
    if ($parent -is [System.Management.Automation.Language.CommandParameterAst]) { $parent = $parent.Parent }
    if ($parent -isnot [System.Management.Automation.Language.CommandAst]) { return $false }
    $first = @($parent.CommandElements)[0]
    if ($first -isnot [System.Management.Automation.Language.StringConstantExpressionAst] -or $first -eq $Node) { return $false }
    $rules = Get-RuleData
    $name = $first.Value
    if ($rules.PowerShellCommands.ContainsKey($name) -or -not $rules.NativeCommands.ContainsKey($name.ToLowerInvariant())) { return $false }
    -not (Get-AliasMap).ContainsKey($name)
}

function Test-PowerShellText {
    param([string] $Text)
    if ($Text -match '[\x00-\x08\x0B\x0C\x0E-\x1F]') { Stop-Guard 'a control character in a PowerShell command' }
    $tokens = $null
    $errors = $null
    $ast = [System.Management.Automation.Language.Parser]::ParseInput($Text, [ref]$tokens, [ref]$errors)
    if (Test-Any $errors) { Stop-Guard "PowerShell can't parse this command ($(Get-Snippet $errors[0].Message))" }
    if (@($tokens | Where-Object { $_.Text -eq '--%' }).Count) { Stop-Guard 'the stop-parsing token (--%) isn''t allowed' }
    # Any string or bareword that names a credentials file or the environment drive, wherever it sits. A search or
    # regex pattern (Select-String's pattern, the right side of -match and -replace) and an argument to a native
    # program are not provider paths, so the environment and wildcard rules skip them; the names still apply.
    # A reading command with no literal path (its files come from the pipeline or a variable) reads whatever a listing
    # in the same command produces, so every listing command's arguments get the reader checks (names, wildcards,
    # bare wildcards) instead of the listing exemptions.
    $readerFed = $false
    foreach ($commandAst in $ast.FindAll({ param($node) $node -is [System.Management.Automation.Language.CommandAst] }, $true)) {
        $readerName = Get-CommandAstName -Command $commandAst
        if ($null -ne $readerName -and $readerName -in @((Get-RuleData).PipelineReaders) -and -not (Test-ReaderHasLiteralPath -Command $commandAst -Name $readerName)) { $readerFed = $true; break }
    }
    if (-not $readerFed) {
        foreach ($call in $ast.FindAll({ param($node) $node -is [System.Management.Automation.Language.InvokeMemberExpressionAst] }, $true)) {
            if (-not $call.Static -or $call.Expression -isnot [System.Management.Automation.Language.TypeExpressionAst]) { continue }
            if ($call.Member -isnot [System.Management.Automation.Language.StringConstantExpressionAst] -or $call.Member.Value -notin @((Get-RuleData).StaticFileReaders)) { continue }
            if ($call.Expression.TypeName.Name -notin 'System.IO.File', 'IO.File', 'File') { continue }
            $firstArgument = @($call.Arguments | Where-Object { $null -ne $_ } | Select-Object -First 1)
            if ($firstArgument.Count -eq 0 -or $firstArgument[0] -isnot [System.Management.Automation.Language.StringConstantExpressionAst]) { $readerFed = $true; break }
        }
    }
    $strings = $ast.FindAll({ param($node) $node -is [System.Management.Automation.Language.StringConstantExpressionAst] -or $node -is [System.Management.Automation.Language.ExpandableStringExpressionAst] }, $true)
    foreach ($string in $strings) {
        $skipPattern = Test-PatternPosition -Node $string
        $skipNative = (-not $skipPattern) -and (Test-NativeArgumentPosition -Node $string)
        $skipJq = Test-JqFilterPosition -Node $string
        $nativeContext = Get-NativeWordContext -Node $string
        $skipFilter = (-not $readerFed) -and (Test-ListingFilterPosition -Node $string)
        $commandName = Get-CommandNameOfNode -Node $string
        $isListing = ($null -ne $commandName -and $commandName -in @((Get-RuleData).ListingCommands)) -or $nativeContext.Listing
        if ($readerFed) { $isListing = $false }
        Test-SecretText -Text $(if ($string -is [System.Management.Automation.Language.StringConstantExpressionAst]) { $string.Value } else { $string.Extent.Text }) -SkipEnvironment:($skipPattern -or $skipNative) -SkipGlob:($skipPattern -or $skipJq -or $skipFilter -or $nativeContext.Pattern) -SkipNames:($skipJq -or $skipFilter -or $skipPattern -or $nativeContext.Pattern) -Listing:$isListing -Shell $(if ($skipNative) { 'Bash' } else { 'PowerShell' })
    }
    $script:Depth = 0
    $script:Configured = @{}
    # A native program's option with its value attached (-fid_rsa, -f.env) is a parameter node, not a string.
    foreach ($parameter in $ast.FindAll({ param($node) $node -is [System.Management.Automation.Language.CommandParameterAst] -and -not $node.Argument }, $true)) {
        if ($parameter.Extent.Text -match '^-[A-Za-z].+$') { Test-SecretText -Text $parameter.Extent.Text -SkipEnvironment -SkipGlob }
    }
    # Every write to every variable, at any depth (assignments, foreach variables, ++ and --): a
    # configuration object is trusted only when its variable is written exactly once.
    $script:WriteCounts = @{}
    $incrementKinds = 'PlusPlus', 'MinusMinus', 'PostfixPlusPlus', 'PostfixMinusMinus'
    $writers = $ast.FindAll({ param($node) $node -is [System.Management.Automation.Language.AssignmentStatementAst] -or $node -is [System.Management.Automation.Language.ForEachStatementAst] -or $node -is [System.Management.Automation.Language.UnaryExpressionAst] }, $true)
    foreach ($node in $writers) {
        $written = $null
        if ($node -is [System.Management.Automation.Language.AssignmentStatementAst]) { $written = $node.Left }
        elseif ($node -is [System.Management.Automation.Language.ForEachStatementAst]) { $written = $node.Variable }
        elseif ($node.TokenKind.ToString() -in $incrementKinds) { $written = $node.Child }
        if ($written -is [System.Management.Automation.Language.VariableExpressionAst]) {
            $variableName = $written.VariablePath.UserPath.ToLowerInvariant()
            $script:WriteCounts[$variableName] = 1 + $(if ($script:WriteCounts.ContainsKey($variableName)) { $script:WriteCounts[$variableName] } else { 0 })
        }
    }
    if ($ast.ParamBlock -or $ast.DynamicParamBlock -or $ast.BeginBlock -or $ast.ProcessBlock -or (Get-AstProperty $ast 'CleanBlock')) { Stop-Guard 'a param, begin, process, clean or dynamicparam block isn''t allowed' }
    if ((Test-Any $ast.UsingStatements) -or $ast.ScriptRequirements) { Stop-Guard '#requires and using statements aren''t allowed' }
    if (Test-Any $ast.Attributes) { Stop-Guard 'attributes on a script aren''t allowed' }
    if ($ast.EndBlock) {
        if (Test-Any $ast.EndBlock.Traps) { Stop-Guard 'a trap isn''t allowed' }
        foreach ($statement in @($ast.EndBlock.Statements)) { Assert-Statement -Statement $statement -Top $true }
    }
}

# ---------------------------------------------------------------------------------------------
# Native command rules (docs/guard.md section 6), shared by both grammars
# ---------------------------------------------------------------------------------------------

function Test-DenyOptions {
    # Deny mode: GNU-style long options may be abbreviated, so a typed name that is a prefix of a
    # denied option is denied. Every word is checked, including words after --.
    param([string[]] $Words, [string[]] $DenyLong, [string] $DenyShort, [string] $Label, [string] $Why = 'it writes a file, runs a program or opens a browser')
    foreach ($word in $Words) {
        if ($word.StartsWith('--', [System.StringComparison]::Ordinal)) {
            $name = $word.Substring(2)
            $equals = $name.IndexOf('=')
            if ($equals -ge 0) { $name = $name.Substring(0, $equals) }
            if ($name.Length -eq 0) { continue }
            foreach ($denied in @($DenyLong)) {
                if ($denied.StartsWith($name, [System.StringComparison]::Ordinal)) { Stop-Guard "'$Label $(Get-Snippet $word)' isn't allowed ($Why)" }
            }
        }
        elseif ($word.StartsWith('-', [System.StringComparison]::Ordinal) -and $word.Length -gt 1) {
            foreach ($char in $word.Substring(1).ToCharArray()) {
                if ($DenyShort -and $DenyShort.Contains([string]$char)) { Stop-Guard "'$Label $(Get-Snippet $word)' isn't allowed (-$char writes a file or runs a program)" }
            }
        }
    }
}

function Test-AllowOptions {
    # Allow mode: every option must be listed. Returns the positional words and the options seen.
    param([string[]] $Words, $Entry, [string] $Label)
    $positional = [System.Collections.Generic.List[string]]::new()
    $seen = [System.Collections.Generic.List[string]]::new()
    $long = @(Get-Optional $Entry 'Long')
    $longValue = @(Get-Optional $Entry 'LongValue')
    $short = [string](Get-Optional $Entry 'Short')
    $shortValue = [string](Get-Optional $Entry 'ShortValue')
    $numeric = [string](Get-Optional $Entry 'NumericShort')
    $endOfOptions = $false
    $i = 0
    while ($i -lt $Words.Count) {
        $word = $Words[$i]
        if ($Entry.ContainsKey('SlashOptions') -and $word -cmatch '^/[A-Za-z?+][^/]*$') { Stop-Guard "'$Label $(Get-Snippet $word)' looks like a Windows-style option (/X)" }
        if ($endOfOptions -or $word -eq '-' -or -not $word.StartsWith('-', [System.StringComparison]::Ordinal)) { $positional.Add($word); $i++; continue }
        if ($word -ceq '--') { $endOfOptions = $true; $i++; continue }
        if ($word.StartsWith('--', [System.StringComparison]::Ordinal)) {
            $name = $word.Substring(2)
            $hasValue = $false
            $equals = $name.IndexOf('=')
            if ($equals -ge 0) { $name = $name.Substring(0, $equals); $hasValue = $true }
            if ($long -ccontains $name) { $seen.Add("--$name"); $i++; continue }
            if ($longValue -ccontains $name) {
                $seen.Add("--$name")
                if (-not $hasValue) {
                    if ($i + 1 -ge $Words.Count) { Stop-Guard "'$Label --$name' needs a value" }
                    $i++
                }
                $i++
                continue
            }
            Stop-Guard "'$Label $(Get-Snippet $word)' isn't an allowed option"
        }
        $cluster = $word.Substring(1)
        if ($numeric -and $cluster.Length -gt 0 -and $cluster.Substring(0, 1) -ceq $numeric -and $cluster.Substring(1) -match '^\d*$') { $i++; continue }
        $consumedNext = $false
        for ($j = 0; $j -lt $cluster.Length; $j++) {
            $char = [string]$cluster[$j]
            if ($short.Contains($char)) { $seen.Add($char); continue }
            if ($shortValue.Contains($char)) {
                $seen.Add($char)
                if ($j + 1 -ge $cluster.Length) {
                    if ($i + 1 -ge $Words.Count) { Stop-Guard "'$Label -$char' needs a value" }
                    $consumedNext = $true
                }
                break
            }
            Stop-Guard "'$Label $(Get-Snippet $word)' isn't an allowed option (-$char)"
        }
        $i += if ($consumedNext) { 2 } else { 1 }
    }
    @{ Positional = $positional.ToArray(); Seen = $seen.ToArray() }
}

function Test-GitCommand {
    param($Entry, [string[]] $Words)
    $i = 0
    while ($i -lt $Words.Count) {
        $word = $Words[$i]
        if ($word -ceq '-C') {
            if ($i + 1 -ge $Words.Count) { Stop-Guard "'git -C' needs a path" }
            $i += 2
            continue
        }
        if (-not $word.StartsWith('-', [System.StringComparison]::Ordinal)) { break }
        if (@($Entry.GlobalOptions) -ccontains $word) { $i++; continue }
        Stop-Guard "'$(Get-Snippet $word)' isn't an allowed git global option"
    }
    if ($i -ge $Words.Count) { Stop-Guard 'git needs a read-only sub-command' }
    $sub = $Words[$i]
    $rest = @($Words | Select-Object -Skip ($i + 1))
    if (-not $Entry.Subcommands.ContainsKey($sub) -or $sub -cne $sub.ToLowerInvariant()) { Stop-Guard "'git $(Get-Snippet $sub)' isn't a known read-only git command" }
    $subEntry = $Entry.Subcommands[$sub]
    switch ($subEntry.Mode) {
        'Deny' { Test-DenyOptions -Words $rest -DenyLong (@(Get-Optional $subEntry 'DenyLong') + @($Entry.DenyLong)) -DenyShort ([string](Get-Optional $subEntry 'DenyShort')) -Label "git $sub" }
        'Allow' {
            Test-DenyOptions -Words $rest -DenyLong @($Entry.DenyLong) -DenyShort '' -Label "git $sub"
            $result = Test-AllowOptions -Words $rest -Entry $subEntry -Label "git $sub"
            $needs = @(Get-Optional $subEntry 'PositionalNeeds')
            if ($result.Positional.Count -gt 0 -and -not (@($result.Seen | Where-Object { $_ -in $needs }).Count)) {
                Stop-Guard "'git $sub $(Get-Snippet $result.Positional[0])' would create or change a $sub (use --list to filter)"
            }
        }
        'Remote' {
            Test-DenyOptions -Words $rest -DenyLong @($Entry.DenyLong) -DenyShort '' -Label 'git remote'
            $ok = $false
            if ($rest.Count -eq 0 -or -not (@($rest | Where-Object { $_ -cnotin '-v', '--verbose' }).Count)) { $ok = $true }
            elseif ($rest[0] -ceq 'show') {
                $others = @($rest | Select-Object -Skip 1 | Where-Object { $_ -cne '-n' })
                if ($others.Count -eq 1 -and -not $others[0].StartsWith('-', [System.StringComparison]::Ordinal)) { $ok = $true }
            }
            elseif ($rest[0] -ceq 'get-url') {
                $others = @($rest | Select-Object -Skip 1 | Where-Object { $_ -cnotin '--push', '--all' })
                if ($others.Count -eq 1 -and -not $others[0].StartsWith('-', [System.StringComparison]::Ordinal)) { $ok = $true }
            }
            if (-not $ok) { Stop-Guard "'git remote $(Get-Snippet ($rest -join ' '))' isn't allowed (only -v, show NAME and get-url NAME)" }
        }
        default { Stop-Guard "the rule data names an unknown git mode '$($subEntry.Mode)'" }
    }
}

function Test-GhCommand {
    param($Entry, [string[]] $Words)
    if ($Words.Count -lt 2 -or $Words[0].StartsWith('-', [System.StringComparison]::Ordinal) -or $Words[1].StartsWith('-', [System.StringComparison]::Ordinal)) { Stop-Guard 'gh needs a read-only command such as "pr view"' }
    $pair = "$($Words[0]) $($Words[1])"
    if (@($Entry.Pairs) -cnotcontains $pair) { Stop-Guard "'gh $(Get-Snippet $pair)' isn't a known read-only gh command" }
    Test-DenyOptions -Words @($Words | Select-Object -Skip 2) -DenyLong @($Entry.DenyLong) -DenyShort ([string]$Entry.DenyShort) -Label "gh $pair"
}

function Test-CloudPathCommand {
    param([string] $Name, $Entry, [string[]] $Words)
    $rules = Get-RuleData
    $path = [System.Collections.Generic.List[string]]::new()
    foreach ($word in $Words) {
        if ($word.StartsWith('-', [System.StringComparison]::Ordinal)) { break }
        $path.Add($word.ToLowerInvariant())
    }
    if ($path.Count -eq 0) { Stop-Guard "'$Name' needs a read-only command such as 'list' or 'show'" }
    $readVerbs = @($Entry.ReadVerbs)
    $isRead = {
        param($word)
        foreach ($pattern in $readVerbs) { if ($word -cmatch $pattern) { return $true } }
        $false
    }
    $joined = $path -join ' '
    if (-not (& $isRead $path[$path.Count - 1])) { Stop-Guard "'$Name $(Get-Snippet $joined)' isn't a read-only command (the last word must be a read verb such as list or show)" }
    for ($i = 0; $i -lt $path.Count; $i++) {
        if ($i -lt $path.Count - 1 -and (& $isRead $path[$i])) { Stop-Guard "'$Name $(Get-Snippet $joined)' has a read verb before the real command" }
        # Every word, the last included, by hyphen-separated part: show-delete and run-command name a change.
        foreach ($part in ($path[$i] -split '-')) {
            if (@($rules.CloudDeniedVerbs) -ccontains $part) { Stop-Guard "'$Name $(Get-Snippet $joined)' contains '$part'" }
        }
    }
    foreach ($pattern in @($Entry.DeniedPaths)) {
        if ($joined -cmatch $pattern) { Stop-Guard "'$Name $(Get-Snippet $joined)' prints secret values" }
    }
    if ($Entry.ContainsKey('DenyLong')) { Test-DenyOptions -Words $Words -DenyLong @($Entry.DenyLong) -DenyShort '' -Label $Name -Why 'it prints secret values' }
    if ($Entry.ContainsKey('SecretWords')) {
        $safe = $false
        foreach ($pattern in @($Entry.SafePaths)) { if ($joined -cmatch $pattern) { $safe = $true } }
        if (-not $safe) {
            foreach ($word in $path) {
                if ($word -cmatch $Entry.SecretWords) { Stop-Guard "'$Name $(Get-Snippet $joined)' reads a key, secret, credential, password or token, which isn't shown to a read-only role" }
            }
        }
    }
}

function Test-AwsCommand {
    param($Entry, [string[]] $Words)
    $i = 0
    while ($i -lt $Words.Count) {
        $word = $Words[$i]
        if (-not $word.StartsWith('-', [System.StringComparison]::Ordinal)) { break }
        $name = $word
        $hasValue = $false
        $equals = $word.IndexOf('=')
        if ($equals -ge 0) { $name = $word.Substring(0, $equals); $hasValue = $true }
        if (@($Entry.OptionsBefore) -ccontains $name) {
            if (-not $hasValue) {
                if ($i + 1 -ge $Words.Count) { Stop-Guard "'aws $name' needs a value" }
                $i++
            }
            $i++
            continue
        }
        if (@($Entry.FlagsBefore) -ccontains $name) { $i++; continue }
        Stop-Guard "'aws $(Get-Snippet $word)' isn't an allowed option before the operation"
    }
    if ($i + 1 -ge $Words.Count) { Stop-Guard 'aws needs a service and a read-only operation' }
    $service = $Words[$i]
    $operation = $Words[$i + 1]
    $pair = "$service $operation"
    if ($pair -cne 's3 ls' -and $operation -cnotmatch '^(describe|list|get)(-[a-z0-9]+)*$') { Stop-Guard "'aws $(Get-Snippet $pair)' isn't a read-only operation" }
    if (@($Entry.DeniedPairs) -ccontains $pair) { Stop-Guard "'aws $pair' isn't allowed (it writes a file or prints credentials or secret values)" }
    if (@($Entry.EnvironmentPairs) -ccontains $pair) { Stop-Guard "'aws $pair' isn't allowed (it prints secret values: environment variables, user data or settings of the function, task, job or project)" }
    if (@($Entry.SafeOperations) -cnotcontains $pair -and $operation -cmatch $Entry.SecretOperations) { Stop-Guard "'aws $pair' returns a token, password, credential or secret, which isn't shown to a read-only role" }
    $after = @($Words | Select-Object -Skip ($i + 2))
    # Options that print secrets apply to every operation, not just the ones known to have them.
    Test-DenyOptions -Words $after -DenyLong @($Entry.DenyLong) -DenyShort '' -Label "aws $pair" -Why 'it prints secret values'
    foreach ($key in $Entry.DeniedWhenWord.Keys) {
        if ($pair -ceq $key) {
            foreach ($word in $after) { if ($word -match $Entry.DeniedWhenWord[$key]) { Stop-Guard "'aws $pair $(Get-Snippet $word)' prints secret values (instance user data often holds credentials)" } }
        }
    }
    foreach ($key in $Entry.DeniedUnlessOption.Keys) {
        if ($pair -ceq $key -and @($after | Where-Object { $_ -ceq $Entry.DeniedUnlessOption[$key] }).Count -eq 0) { Stop-Guard "'aws $pair' prints a password unless $($Entry.DeniedUnlessOption[$key]) is given" }
    }
    # Outside s3, aws takes a bare word only as the file to write a streaming result to (glacier
    # get-job-output, apigateway get-export, ...): a bare word must be the value of the option before it.
    if (@($Entry.PositionalServices) -cnotcontains $service) {
        $expectValue = $false
        foreach ($word in $after) {
            if ($word.StartsWith('--', [System.StringComparison]::Ordinal)) {
                # Only an option known to take a value (and written without =) makes the next word its value.
                $optionName = ($word -split '=', 2)[0]
                $exactOptions = @($Entry.ValueOptions)
                $usePattern = $true
                if ($Entry.OutfileOperations.ContainsKey($pair)) { $exactOptions += @($Entry.OutfileOperations[$pair]); $usePattern = $false }
                $expectValue = (-not $word.Contains('=')) -and ($exactOptions -ccontains $optionName -or ($usePattern -and $optionName -cmatch $Entry.ValueOptionPattern))
            }
            elseif ($word.StartsWith('-', [System.StringComparison]::Ordinal) -and $word.Length -gt 1) { $expectValue = $false }
            elseif ($expectValue) { $expectValue = $false }
            else { Stop-Guard "'aws $pair' with a bare word ('$(Get-Snippet $word)') may write to a file; give one value per option (--name value)" }
        }
    }
}

function Test-KubectlCommand {
    param($Entry, [string[]] $Words)
    $i = 0
    while ($i -lt $Words.Count) {
        $word = $Words[$i]
        if (-not $word.StartsWith('-', [System.StringComparison]::Ordinal)) { break }
        $name = $word
        $hasValue = $false
        $equals = $word.IndexOf('=')
        if ($equals -ge 0) { $name = $word.Substring(0, $equals); $hasValue = $true }
        if (@($Entry.OptionsBefore) -ccontains $name) {
            if (-not $hasValue) {
                if ($i + 1 -ge $Words.Count) { Stop-Guard "'kubectl $name' needs a value" }
                $i++
            }
            $i++
            continue
        }
        if (@($Entry.FlagsBefore) -ccontains $name) { $i++; continue }
        Stop-Guard "'kubectl $(Get-Snippet $word)' isn't an allowed option before the sub-command"
    }
    if ($i -ge $Words.Count) { Stop-Guard 'kubectl needs a read-only sub-command' }
    $sub = $Words[$i]
    $rest = @($Words | Select-Object -Skip ($i + 1))
    if (@($Entry.Subcommands) -cnotcontains $sub) { Stop-Guard "'kubectl $(Get-Snippet $sub)' isn't a known read-only kubectl command" }
    Test-DenyOptions -Words $rest -DenyLong @($Entry.DenyLong) -DenyShort '' -Label "kubectl $sub"
    if ($sub -in 'get', 'describe') {
        $secret = $false
        foreach ($word in $rest) { if (-not $word.StartsWith('-', [System.StringComparison]::Ordinal) -and $word -match $Entry.SecretResources) { $secret = $true } }
        if ($secret -and $sub -eq 'describe') { Stop-Guard "'kubectl describe' of a secret isn't allowed (secret values aren't shown to a read-only role)" }
        if ($sub -eq 'get') {
            $outputs = [System.Collections.Generic.List[string]]::new()
            $usesFile = $false
            for ($j = 0; $j -lt $rest.Count; $j++) {
                $word = $rest[$j]
                $longName = if ($word.StartsWith('--', [System.StringComparison]::Ordinal)) { ($word.Substring(2) -split '=', 2)[0] } else { $null }
                if ($word -ceq '-o' -or ($longName -and 'output'.StartsWith($longName, [System.StringComparison]::Ordinal) -and -not $word.Contains('='))) {
                    # -o, --output, or any abbreviation of it, with the value as the next word
                    $outputs.Add($(if ($j + 1 -lt $rest.Count) { $rest[$j + 1] } else { '' }))
                }
                elseif (($longName -and 'output'.StartsWith($longName, [System.StringComparison]::Ordinal) -and $word.Contains('=')) -or $word -cmatch '^-o=?(?<v>.+)$') {
                    $outputs.Add($(if ($word.StartsWith('--', [System.StringComparison]::Ordinal)) { ($word -split '=', 2)[1] } else { $Matches.v }))
                }
                if ($word.StartsWith('--', [System.StringComparison]::Ordinal) -and $word.Length -gt 2 -and ([string]$Entry.TemplateOption).StartsWith(($word.Substring(2) -split '=', 2)[0], [System.StringComparison]::Ordinal)) { $outputs.Add($Entry.TemplateOption) }
                if (@($Entry.FileOptions) -ccontains $word -or $word -cmatch '^--(filename|kustomize)=' -or $word -cmatch '^-[fk].') { $usesFile = $true }
            }
            # For a secret only the outputs known not to print values are allowed (the table, name, wide); any
            # other format, including one added in a later kubectl, is refused. The same when -f/-k hides the type.
            $revealing = @($outputs | Where-Object { @($Entry.AllowedSecretOutputs) -cnotcontains $_ })
            if ($revealing.Count -and $secret) { Stop-Guard "'kubectl get' of a secret with an output other than name or wide ('$(Get-Snippet $revealing[0])') may print its values" }
            if ($revealing.Count -and $usesFile) { Stop-Guard "'kubectl get -f/-k' with an output other than name or wide can print secret values (the resource type comes from a file)" }
        }
    }
}

function Get-JqFilterIndex {
    # The index of jq's filter among its arguments (the first plain word that is not an option's value), or -1.
    param($Entry, [string[]] $Words)
    $i = 0
    while ($i -lt $Words.Count) {
        $word = $Words[$i]
        if ($word -ceq '--') { $i++; continue }
        if (@($Entry.TwoWordOptions) -ccontains $word) { $i += 3; continue }
        if (@($Entry.ValueOptions) -ccontains $word) { $i += 2; continue }
        if ($word.StartsWith('-', [System.StringComparison]::Ordinal) -and $word.Length -gt 1) { $i++; continue }
        return $i
    }
    -1
}

function Test-JqCommand {
    # jq reads files, and its filter language can read the environment (env, $ENV) and import modules by path. The
    # filter is checked for those; -f/--from-file (a program read from a file the guard cannot see) is refused;
    # --slurpfile, --rawfile and -L values get the secret-path check with every other word.
    param($Entry, [string[]] $Words)
    $i = 0
    while ($i -lt $Words.Count) {
        $word = $Words[$i]
        if ($word -ceq '--') { $i++; continue }
        if ($word -in '-f', '--from-file') { Stop-Guard "'jq $word' runs a program from a file the guard cannot read; write the filter on the command line" }
        if ($word.StartsWith('--', [System.StringComparison]::Ordinal)) {
            if (@($Entry.TwoWordOptions) -ccontains $word) { $i += 3; continue }
            if (@($Entry.ValueOptions) -ccontains $word) { $i += 2; continue }
            if (@($Entry.Flags) -ccontains $word) { $i++; continue }
            Stop-Guard "'jq $(Get-Snippet $word)' isn't an allowed option"
        }
        if ($word.StartsWith('-', [System.StringComparison]::Ordinal) -and $word.Length -gt 1) {
            if (@($Entry.ValueOptions) -ccontains $word) { $i += 2; continue }
            foreach ($char in $word.Substring(1).ToCharArray()) {
                if (([string]$Entry.ShortFlagChars).IndexOf($char) -lt 0) { Stop-Guard "'jq $(Get-Snippet $word)' isn't an allowed option" }
            }
            $i++
            continue
        }
        break
    }
    $index = Get-JqFilterIndex -Entry $Entry -Words $Words
    if ($index -ge 0) {
        $filter = $Words[$index]
        if ($filter -match $Entry.FilterDeny) { Stop-Guard "the jq filter '$(Get-Snippet $filter)' reads the environment (env or `$ENV), which isn't shown to a read-only role" }
        foreach ($module in [regex]::Matches($filter, '(?:import|include)\s+"([^"]*)"')) { Test-SecretText -Text $module.Groups[1].Value -Shell Bash }
    }
}

function Test-SedCommand {
    param([string[]] $Words)
    $address = '(\d+|\$|/[^/\\]*/)'
    if ($Words.Count -lt 2 -or $Words[0] -cnotin '-n', '--quiet', '--silent' -or $Words[1] -cnotmatch "^$address(,$address)?p$") {
        Stop-Guard "'sed' is allowed only as: sed -n 'N,Mp' FILE (print forms)"
    }
    foreach ($word in @($Words | Select-Object -Skip 2)) {
        if ($word.StartsWith('-', [System.StringComparison]::Ordinal) -and $word -ne '-') { Stop-Guard "'sed $(Get-Snippet $word)' isn't allowed after the print script" }
    }
}

function Test-NativeCommand {
    # Judge a native command by its argument values.
    param([string] $Name, $Entry, [string[]] $Words)
    $Words = @($Words)
    foreach ($word in $Words) {
        # En and em dashes and look-alikes: PowerShell reads them as hyphens, a native program doesn't, so the word is not what it seems.
        if ($word -match '^[\u2010-\u2015\u2212\uFE58\uFE63\uFF0D]') { Stop-Guard "'$Name $(Get-Snippet $word)' starts with a dash character that is not an ASCII hyphen" }
    }
    switch ($Entry.Mode) {
        'Any' {
            $maxPositional = Get-Optional $Entry 'MaxPositional'
            if ($maxPositional) {
                $count = @($Words | Where-Object { -not $_.StartsWith('-', [System.StringComparison]::Ordinal) -or $_ -eq '-' }).Count
                if ($count -gt $maxPositional) { Stop-Guard "'$Name' takes at most $maxPositional argument(s) here" }
            }
        }
        'Allow' {
            $result = Test-AllowOptions -Words $Words -Entry $Entry -Label $Name
            $maxPositional = Get-Optional $Entry 'MaxPositional'
            if ($maxPositional -and $result.Positional.Count -gt $maxPositional) { Stop-Guard "'$Name' with more than $maxPositional file argument(s) writes the last one" }
        }
        'Deny' { Test-DenyOptions -Words $Words -DenyLong @(Get-Optional $Entry 'DenyLong') -DenyShort ([string](Get-Optional $Entry 'DenyShort')) -Label $Name }
        'Words' {
            $i = 0
            while ($i -lt $Words.Count) {
                $word = $Words[$i]
                if ($word.StartsWith('-', [System.StringComparison]::Ordinal) -and $word -ne '-') {
                    if (@($Entry.Words) -cnotcontains $word) { Stop-Guard "'$Name $(Get-Snippet $word)' isn't an allowed option (it may delete, write or run a command)" }
                    if (@($Entry.WordsWithValue) -ccontains $word) {
                        if ($i + 1 -ge $Words.Count) { Stop-Guard "'$Name $word' needs a value" }
                        $i++
                    }
                }
                $i++
            }
        }
        'SedPrint' { Test-SedCommand -Words $Words }
        'Jq' { Test-JqCommand -Entry $Entry -Words $Words }
        'Git' { Test-GitCommand -Entry $Entry -Words $Words }
        'Gh' { Test-GhCommand -Entry $Entry -Words $Words }
        'CloudPath' { Test-CloudPathCommand -Name $Name -Entry $Entry -Words $Words }
        'Aws' { Test-AwsCommand -Entry $Entry -Words $Words }
        'Kubectl' { Test-KubectlCommand -Entry $Entry -Words $Words }
        default { Stop-Guard "the rule data names an unknown mode '$($Entry.Mode)' for $Name" }
    }
}

# ---------------------------------------------------------------------------------------------
# Bash grammar (docs/guard.md section 5)
# ---------------------------------------------------------------------------------------------

function Read-BashWord {
    # One word: bare text, 'single quoted' and "double quoted" parts joined. Returns the value and the end index.
    param([string] $Text, [int] $Start)
    $value = [System.Text.StringBuilder]::new()
    $i = $Start
    $length = $Text.Length
    while ($i -lt $length) {
        $char = $Text[$i]
        if ($char -eq "'") {
            $end = $Text.IndexOf("'", $i + 1)
            if ($end -lt 0) { Stop-Guard 'an unclosed single quote' -Bash }
            $null = $value.Append($Text.Substring($i + 1, $end - $i - 1))
            $i = $end + 1
        }
        elseif ($char -eq '"') {
            $end = $Text.IndexOf('"', $i + 1)
            if ($end -lt 0) { Stop-Guard 'an unclosed double quote' -Bash }
            $inner = $Text.Substring($i + 1, $end - $i - 1)
            if ($inner -match '[$`\\!]') { Stop-Guard "a double-quoted string containing `$, a backtick, a backslash or ! ('$(Get-Snippet $inner)'); use single quotes" -Bash }
            $null = $value.Append($inner)
            $i = $end + 1
        }
        elseif ($char -in ' ', "`t", '|', '&') { break }
        elseif ($char -in ';', '<', '>', '(', ')', '{', '}', '`', '$', '\', '#', '!') { Stop-Guard "the character '$char' isn't allowed in a Bash command here (near '$(Get-Snippet $Text.Substring($Start))')" -Bash }
        else {
            # A glob can expand to a name that starts with '-' (which a command reads as an option) when
            # nothing precedes it, or what precedes it already starts with '-'.
            if ($char -in '*', '?', '[' -and ($value.Length -eq 0 -or $value[0] -eq '-')) { Stop-Guard "a glob at the start of a word, or in an option ('$(Get-Snippet $Text.Substring($Start))')" -Bash }
            $null = $value.Append($char)
            $i++
        }

    }
    @{ Value = $value.ToString(); End = $i }
}

function Test-BashText {
    param([string] $Text)
    if ($Text -match '[\x00-\x08\x0A-\x1F]') { Stop-Guard 'a line break or control character in a Bash command' -Bash }
    $rules = Get-RuleData
    $length = $Text.Length
    $i = 0
    $redirect = [regex]::new('\G(2>&1|(?:2>|1>|&>|>)[ \t]*/dev/null)(?=[ \t]|\||&&|$)')
    $nameRegex = [regex]::new('\G[A-Za-z0-9][A-Za-z0-9._+\-]*')
    while ($i -lt $length -and $Text[$i] -in ' ', "`t") { $i++ }
    while ($true) {
        $match = $nameRegex.Match($Text, $i)
        if (-not $match.Success) { Stop-Guard "a Bash command must start with a plain name (near '$(Get-Snippet $Text.Substring([Math]::Min($i, $length)))')" -Bash }
        $name = $match.Value.ToLowerInvariant()
        $i += $match.Length
        if ($i -lt $length -and $Text[$i] -notin ' ', "`t", '|', '&') { Stop-Guard "unexpected '$($Text[$i])' after the command name '$name'" -Bash }
        $words = [System.Collections.Generic.List[string]]::new()
        while ($true) {
            while ($i -lt $length -and $Text[$i] -in ' ', "`t") { $i++ }
            if ($i -ge $length -or $Text[$i] -eq '|') { break }
            $redirection = $redirect.Match($Text, $i)
            if ($redirection.Success) { $i += $redirection.Length; continue }
            if ($Text[$i] -eq '&') { break }
            $word = Read-BashWord -Text $Text -Start $i
            $words.Add($word.Value)
            $i = $word.End
        }
        # What each word is: a search pattern, jq's filter, a find match pattern or a git ref pattern is not a path being
        # read, so the wildcard rule skips it. A listing command (ls, find, git ls-files) does not read what it matches.
        $rules = Get-RuleData
        $patternIndex = -1
        $jqFilterIndex = -1
        $exempt = [System.Collections.Generic.HashSet[int]]::new()
        $patternWords = [System.Collections.Generic.HashSet[int]]::new()
        $positionals = @(for ($w = 0; $w -lt $words.Count; $w++) { if (-not $words[$w].StartsWith('-', [System.StringComparison]::Ordinal)) { $w } })
        $listing = $name -in @($rules.ListingCommands)
        if ($name -eq 'jq') { $jqFilterIndex = Get-JqFilterIndex -Entry $rules.NativeCommands.jq -Words $words.ToArray(); $patternIndex = $jqFilterIndex }
        elseif ($name -in @('rg', 'grep', 'egrep', 'fgrep')) { foreach ($position in @(Get-SearchPatternWordIndex -Name $name -Words $words.ToArray())) { $null = $patternWords.Add($position) } }
        elseif ($name -eq 'git' -and $positionals.Count -gt 1 -and $words[$positionals[0]] -ceq 'grep') { foreach ($position in @(Get-SearchPatternWordIndex -Name 'git' -Words $words.ToArray())) { $null = $patternWords.Add($position) } }
        elseif ($name -eq 'git' -and $positionals.Count -gt 0) {
            if ($words[$positionals[0]] -cin @($rules.GitListingSubcommands)) { $listing = $true }
            if ($words[$positionals[0]] -cin 'branch', 'tag') { foreach ($position in @($positionals | Select-Object -Skip 1)) { $null = $exempt.Add($position) } }
        }
        elseif ($name -eq 'find') {
            for ($w = 0; $w -lt $words.Count - 1; $w++) { if ($words[$w] -cin @($rules.FindPatternOptions)) { $null = $exempt.Add($w + 1) } }
        }
        for ($w = 0; $w -lt $words.Count; $w++) {
            Test-SecretText -Text $words[$w] -Shell Bash -SkipGlob:($w -eq $patternIndex -or $patternWords.Contains($w) -or $exempt.Contains($w)) -SkipNames:(($w -eq $jqFilterIndex) -or $patternWords.Contains($w) -or ($name -eq 'find' -and $exempt.Contains($w))) -Listing:$listing
        }
        $key = $name
        if (-not $rules.NativeCommands.ContainsKey($key)) { Stop-Guard "'$name' isn't on the read-only list" -Bash }
        Test-NativeCommand -Name $key -Entry $rules.NativeCommands[$key] -Words $words.ToArray()
        if ($i -ge $length) { return }
        $rest = $Text.Substring($i)
        if ($rest.StartsWith('&&', [System.StringComparison]::Ordinal) -or $rest.StartsWith('||', [System.StringComparison]::Ordinal)) { $i += 2 }
        elseif ($Text[$i] -eq '|') { $i++ }
        else { Stop-Guard "a single '&' isn't allowed (near '$(Get-Snippet $rest)')" -Bash }
        while ($i -lt $length -and $Text[$i] -in ' ', "`t") { $i++ }
        if ($i -ge $length) { Stop-Guard 'a command is missing after the operator' -Bash }
    }
}

# ---------------------------------------------------------------------------------------------
# Entry points
# ---------------------------------------------------------------------------------------------

function Test-GuildCommandText {
    # Returns $null when allowed, otherwise the full message. Never throws.
    param([AllowNull()] $Text, [AllowNull()] $ToolName, [string[]] $AllowList)
    try {
        $script:AllowNames = @($AllowList | Where-Object { $_ -match '^[A-Za-z]+-[A-Za-z0-9]+$' })
        if ($Text -isnot [string] -or $Text.Trim().Length -eq 0) { Stop-Guard 'the hook input has no command to check' }
        if ($Text.Length -gt $script:MaxLength) { Stop-Guard "the command is longer than $script:MaxLength characters" }
        if ($null -ne $ToolName -and $ToolName -isnot [string]) { Stop-Guard 'the guard only judges the Bash and PowerShell tools' }
        if ($null -eq $ToolName) { $grammars = @('Bash', 'PowerShell') }
        elseif ($ToolName -ceq 'PowerShell') { $grammars = @('PowerShell') }
        elseif ($ToolName -ceq 'Bash') { $grammars = @('Bash') }
        else { Stop-Guard "the guard only judges the Bash and PowerShell tools, not '$(Get-Snippet $ToolName)'" }

        $reasons = @()
        foreach ($grammar in $grammars) {
            try {
                if ($grammar -eq 'Bash') { Test-BashText -Text $Text } else { Test-PowerShellText -Text $Text }
            }
            catch {
                $message = $_.Exception.Message
                if (-not $message.StartsWith($script:BlockMarker, [System.StringComparison]::Ordinal)) { throw }
                if ($grammars.Count -eq 1) { throw }
                $reasons += "$grammar grammar: " + $message.Substring($script:BlockMarker.Length + 2)
            }
        }
        if ($reasons.Count -gt 0) { Stop-Guard $reasons[0] }
        return $null
    }
    catch {
        $message = $_.Exception.Message
        if ($message.StartsWith($script:BlockMarker, [System.StringComparison]::Ordinal)) {
            $parts = $message.Substring($script:BlockMarker.Length).Split('|', 2)
            $hint = if ($parts[0] -eq 'B') { $script:BashHint } else { $script:DefaultHint }
            return "Read-only role: blocked: $($parts[1]). $hint."
        }
        return "Read-only role: blocked: the guard could not check this command ($(Get-Snippet $message)). $script:DefaultHint."
    }
}

function Read-StandardInput {
    # Hook input is UTF-8 JSON. [Console]::In would decode it with the console code page, which turns a
    # character such as an en dash into several others and hides what a command really contains.
    $reader = [System.IO.StreamReader]::new([Console]::OpenStandardInput(), [System.Text.UTF8Encoding]::new($false))
    try { $reader.ReadToEnd() } finally { $reader.Dispose() }
}

function Test-DuplicateJsonKey {
    # JSON with the same key twice in one object is ambiguous (parsers differ on which wins), so it is refused.
    param([string] $Json)
    $document = [System.Text.Json.JsonDocument]::Parse($Json)
    try {
        $pending = [System.Collections.Generic.Stack[System.Text.Json.JsonElement]]::new()
        $pending.Push($document.RootElement)
        while ($pending.Count -gt 0) {
            $element = $pending.Pop()
            if ($element.ValueKind -eq [System.Text.Json.JsonValueKind]::Object) {
                $names = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::Ordinal)
                foreach ($property in $element.EnumerateObject()) {
                    if (-not $names.Add($property.Name)) { return $true }
                    $pending.Push($property.Value)
                }
            }
            elseif ($element.ValueKind -eq [System.Text.Json.JsonValueKind]::Array) {
                foreach ($item in $element.EnumerateArray()) { $pending.Push($item) }
            }
        }
        $false
    }
    finally { $document.Dispose() }
}

function ConvertTo-AllowList {
    param([AllowNull()][string] $Text)
    @($Text -split ',' | ForEach-Object { $_.Trim() } | Where-Object { $_ })
}

# Dot-sourced (the test wrapper does this to reuse the functions), the script only defines them.
if ($MyInvocation.InvocationName -eq '.') { return }

$verdict = $null
try {
    if ($PSBoundParameters.ContainsKey('Command')) {
        $text = $Command
        $toolName = $null
        if ($PSBoundParameters.ContainsKey('Tool') -and $Tool) {
            $toolName = switch ($Tool) { 'bash' { 'Bash' } 'powershell' { 'PowerShell' } default { $Tool } }
        }
    }
    else {
        try {
            # One JSON object, read without unwrapping arrays: ["Bash"] or [ { ... } ] must not pass as Bash or as a hook.
            $rawInput = Read-StandardInput
            if (Test-DuplicateJsonKey -Json $rawInput) { throw 'the hook input repeats a key' }
            $hookInput = ConvertFrom-Json -InputObject $rawInput -NoEnumerate
            if ($hookInput -isnot [System.Management.Automation.PSCustomObject]) { throw 'the hook input is not a JSON object' }
            $text = $null
            $toolInput = $hookInput.PSObject.Properties['tool_input']
            if ($toolInput -and $toolInput.Value -is [System.Management.Automation.PSCustomObject]) {
                $commandProperty = $toolInput.Value.PSObject.Properties['command']
                if ($commandProperty) { $text = $commandProperty.Value }
            }
            $toolName = $null
            $toolNameProperty = $hookInput.PSObject.Properties['tool_name']
            if ($toolNameProperty) { $toolName = $toolNameProperty.Value }
        }
        catch {
            [Console]::Error.WriteLine('Read-only role: blocked: the hook input could not be read, so the command is blocked.')
            exit 2
        }
    }
    $verdict = Test-GuildCommandText -Text $text -ToolName $toolName -AllowList (ConvertTo-AllowList $Allow)
}
catch {
    $verdict = "Read-only role: blocked: the guard could not check this command ($(Get-Snippet $_.Exception.Message)). $script:DefaultHint."
}
if ($verdict) {
    [Console]::Error.WriteLine($verdict)
    exit 2
}
exit 0
