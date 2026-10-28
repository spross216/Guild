# Rule data for guards/Test-GuildReadOnlyCommand.ps1 (docs/guard.md, section 3). Data only: it is
# loaded with Import-PowerShellDataFile. Everything not listed here is blocked. When you add an entry,
# read the command's documentation for options that write files or run programs, and leave those out.
#
# Shapes for PowerShell parameters: Switch, Value, ScriptBlock, Property, Config (docs/guard.md 4.5).
@{
    # Parameters every PowerShell command accepts. Switch and Value as for any other parameter.
    CommonParameters    = @{
        ErrorAction       = 'Value'
        WarningAction     = 'Value'
        InformationAction = 'Value'
        Verbose           = 'Switch'
    }

    # Parameters a command passed with -Allow never gets: they write a variable in the caller's scope.
    NeverParameters     = @('OutVariable', 'ErrorVariable', 'WarningVariable', 'InformationVariable', 'PipelineVariable', 'OutBuffer', 'ov', 'ev', 'wv', 'iv', 'pv', 'ob')

    # Local files that hold credentials, and environment variables that hold secrets (best effort: a
    # read-only role never reads them). A word or string that matches any pattern is refused, in both
    # grammars, whatever command reads it. Searching for the text of a name (rg '.env') is refused too.
    # Left out on purpose: *.pem, *.key and *.pfx (certificates and keys that are often public or test
    # fixtures), shell history, browser stores, terraform state and appsettings files (too common in
    # the repositories under review). Placeholder files (.env.example) are allowed.
    SecretPathPatterns  = @(
        '(^|[/\\:])\.ssh([/\\]|$)'
        '(^|[/\\:])\.aws([/\\]|$)'
        '(^|[/\\:])\.azure([/\\]|$)'
        '(^|[/\\:])\.kube[/\\]config'
        '(^|[/\\:])\.docker[/\\]config\.json'
        '(^|[/\\:])\.git-credentials$'
        '(^|[/\\:])\.netrc$'
        '(^|[/\\:])_netrc$'
        '(^|[/\\:])\.env(\.[^/\\]*)?$'
        '/proc/[^/]+/environ'
        '(^|[/\\:])id_(rsa|dsa|ecdsa|ed25519)$'
        '(^|[/\\:])\.(npmrc|pypirc)$'
        '(^|[/\\:])\.gnupg([/\\]|$)'
        '(^|[/\\:])gh[/\\]hosts\.yml$'
        '(^|[/\\:])local\.settings\.json$'
    )
    # Names a wildcard must not be able to reach (a serverless functions local settings file is in the list: it holds
    # real connection strings). SecretSegmentNames: a wildcard segment whose literal prefix starts one of these is
    # refused. SecretGlobProbes: the last segment, read as a wildcard, must match none of them (the dot-directories
    # are probed as names too). LeadingWildcardSkip: names that only the prefix rule covers, so *.json stays usable.
    SecretSegmentNames  = @('.ssh', '.aws', '.azure', '.kube', '.docker', '.gnupg', '.git-credentials', '.netrc', '_netrc', '.npmrc', '.pypirc', '.env', 'id_rsa', 'id_dsa', 'id_ecdsa', 'id_ed25519', 'local.settings.json')
    SecretGlobProbes    = @('.ssh', '.aws', '.azure', '.kube', '.docker', '.gnupg', '.git-credentials', '.netrc', '_netrc', '.npmrc', '.pypirc', '.env', '.env.local', '.env.production', '.env.development', '.env.test', '.env.staging', '.env.x', 'id_rsa', 'id_dsa', 'id_ecdsa', 'id_ed25519', 'local.settings.json', 'credentials')
    # Credentials paths of more than one segment, matched against the last segments of a wildcard path (~/*/credentials).
    SecretGlobTargets   = @('.aws/credentials', '.aws/config', '.kube/config', '.docker/config.json', '.ssh/id_rsa', '.ssh/config', '.config/gh/hosts.yml')
    # Placeholder files a wildcard may reach on its own (.env.exam*).
    EnvExampleNames     = @('.env.example', '.env.sample', '.env.template', '.env.dist')
    LeadingWildcardSkip = @('local.settings.json')
    # Reading commands that take their files from the pipeline when no path is written: a listing in the same command
    # is then read, so its arguments get the reader checks.
    PipelineReaders     = @('Get-Content', 'Select-String')
    # Options of rg, grep and git grep that take a value (to find the pattern word among the arguments).
    SearchValueOptions  = @('-A', '-B', '-C', '-m', '-g', '-t', '-d', '-D', '-j', '--glob', '--iglob', '--type', '--type-not', '--max-count', '--max-depth', '--max-filesize', '--threads', '--replace', '--encoding', '--include', '--exclude', '--exclude-dir', '--label', '--ignore-file', '--sort', '--sortr', '--pre-glob', '--context', '--after-context', '--before-context')
    # Value-taking options that only some tools have: GNU grep and git grep take --color=WHEN (one word), rg takes --color WHEN.
    SearchToolValueOptions = @{ rg = @('--color') }
    # Static methods that read a file's text: with an argument that isn't a constant, the file comes from somewhere the
    # guard can't see (like a reader with no path), so a listing in the same command is checked as a reader.
    StaticFileReaders   = @('ReadAllText', 'ReadAllLines')
    # Commands that only list names (a wildcard they match is not read), by their PowerShell or program name; every
    # other command reads content and gets the full wildcard check. git is a reader except for these sub-commands.
    ListingCommands     = @('Get-ChildItem', 'Get-Item', 'Get-ItemProperty', 'Test-Path', 'Resolve-Path', 'Split-Path', 'Join-Path', 'Set-Location', 'Push-Location', 'Pop-Location', 'ls', 'du', 'df', 'stat', 'find', 'tree', 'basename', 'dirname', 'realpath', 'which', 'pwd', 'cd')
    GitListingSubcommands = @('ls-files', 'ls-tree', 'status')
    # find options whose next word is a match pattern, not a path.
    FindPatternOptions  = @('-name', '-iname', '-path', '-ipath', '-wholename', '-regex', '-iregex')
    # Secret only when a file of that name is read (a folder called credentials can be listed): the AWS credentials file name.
    SecretReadPatterns  = @('(^|[/\\:])credentials$')
    SecretPathExceptions = @('\.env\.(example|sample|template|dist)$')
    # The environment drive: env: alone or with a wildcard dumps every variable; env:NAME is judged by name.
    # Also the provider-qualified spellings of the same drive: Environment:: and Microsoft.PowerShell.Core\Environment::.
    EnvDrivePattern     = '(?is)^[/\\]*(?:Microsoft\.PowerShell\.Core[/\\])?(?:env:|Environment::)[/\\]?(?<name>.*)\z'
    # What may follow the environment drive or provider: exactly one plain variable name (and not a secret one).
    # Anything else (empty, dots, several segments, separators, wildcards, colons, spaces) is refused.
    EnvNamePattern      = '^[A-Za-z_][A-Za-z0-9_]*\z'
    # If PowerShell cannot parse a word as a provider path, these spellings still look like the environment.
    EnvProviderFallbackPattern = '(?i)Environment::|(^|[^A-Za-z0-9])env:'
    # A path segment written as an 8.3 short name (GIT-CR~1 for .git-credentials, ID_ED2~1 for id_ed25519) beside a
    # path separator; ~/x (home) and HEAD~1 (a git revision, no separator) are not matched.
    ShortNamePattern    = '([/\\:][^~/\\:]{1,6}~[0-9]+(\.(?!pub$)[A-Za-z0-9]{0,3})?($|[/\\]))|(^[^~/\\:]{1,6}~[0-9]+(\.(?!pub$)[A-Za-z0-9]{0,3})?[/\\])'
    # The same name alone (cat ID_ED2~1): only names that look like a short name, not a revision (HEAD~1, main~2): a
    # hyphen, underscore or digit in it, or the stem of a well-known credentials folder or file. A public key (.pub) is allowed.
    ShortNameBarePattern = '^(?=[^~]{1,6}~)(?:[A-Za-z0-9]*[-_0-9][A-Za-z0-9_-]*|SSH|AWS|AZURE|KUBE|DOCKER|NETRC|NPMRC|PYPIRC|GNUPG|ENV)~[0-9]+(\.(?!pub$)[A-Za-z0-9]{0,3})?$'
    # TOKEN, SECRET, KEY, PASSWORD, PWD, CREDENTIAL, CONNECTION, COOKIE, SESSION, AUTHORIZATION, and PAT, AUTH or URL as a
    # whole word (GITHUB_PAT, DATABASE_URL, REDIS_URL), so PATH, GITHUB_PATH and GIT_AUTHOR_NAME stay readable.
    SecretNamePattern   = '(?i)(TOKEN|SECRET|KEY|PASSWORD|PWD|CREDENTIAL|CONNECTION|COOKIE|SESSION|AUTHORIZATION|(^|_)PAT(_|$)|(^|_)AUTH(_|$)|(^|_)[A-Z0-9]*URL(_|$))'

    # Words in the path of an az or gcloud command that mean a change (matched as the whole word, or
    # followed by a hyphen: run-command). A read verb is never found before one of these.
    CloudDeniedVerbs    = @('create', 'delete', 'update', 'set', 'add', 'remove', 'start', 'stop', 'restart', 'deallocate', 'scale', 'swap', 'deploy', 'upload', 'download', 'import', 'export', 'purge', 'assign', 'reset', 'rotate', 'regenerate', 'renew', 'restore', 'recover', 'login', 'logout', 'invoke', 'run', 'sync', 'move', 'copy', 'enable', 'disable', 'attach', 'detach', 'apply', 'approve', 'reject')

    # Parameters that are not listed for a command but can still be bound: by position (to another
    # parameter set), or from a piped object's property. Each has the reason it is harmless; the rule
    # data tests require every such parameter to be listed here, so a new one in a module update is noticed.
    UnlistedParameters  = @{
        'ForEach-Object'          = @{ MemberName = 'a word can''t be a script block, and the positional shape is ScriptBlock'; RemainingScripts = 'only script blocks bind here, and each is checked like the others' }
        'Get-Command'             = @{ FullyQualifiedModule = 'only narrows a search'; TotalCount = 'only limits output'; UseAbbreviationExpansion = 'only changes how a name is matched' }
        'Get-Content'             = @{ Credential = 'the file system provider ignores it' }
        'Get-Item'                = @{ Credential = 'the file system provider ignores it' }
        'Get-ItemProperty'        = @{ Credential = 'the file system provider ignores it' }
        'Join-Path'               = @{ Credential = 'the file system provider ignores it' }
        'Resolve-Path'            = @{ Credential = 'the file system provider ignores it' }
        'Split-Path'              = @{ Credential = 'the file system provider ignores it' }
        'Test-Path'               = @{ Credential = 'the file system provider ignores it' }
        'Get-FileHash'            = @{ InputStream = 'a stream object can''t be made with the listed commands' }
        'Get-Location'            = @{ PSProvider = 'only reads'; PSDrive = 'only reads'; StackName = 'only reads' }
        'Pop-Location'            = @{ StackName = 'only changes this session''s location stack' }
        'Push-Location'           = @{ StackName = 'only changes this session''s location stack' }
        'Set-Location'            = @{ StackName = 'only changes this session''s location stack' }
        'Get-Module'              = @{ FullyQualifiedName = 'only narrows a search' }
        'Import-Module'           = @{ FullyQualifiedName = 'takes a hashtable, which the Value shape rejects'; Assembly = 'an assembly object can''t be made with the listed commands'; ModuleInfo = 'takes a module object from Get-Module' }
        'Invoke-ScriptAnalyzer'   = @{ ScriptDefinition = 'analyzes the text it is given and changes nothing' }
        'Test-Json'               = @{ Path = 'only reads a file'; LiteralPath = 'only reads a file' }
        'Write-Error'             = @{ Exception = 'only writes an error record'; ErrorRecord = 'only writes an error record' }
    }

    # The parameter that fills each positional slot of a command, in order; a slot can be filled by any
    # of the names listed (parameter sets differ; a single slot is written @(,@(...)) so it stays nested). A positional argument binds to the next slot whose
    # parameter was not already given by name, so `Select-String -Path x TODO` puts TODO in Pattern.
    PositionalNames     = @{
        'Compare-Object' = @(@('ReferenceObject'), @('DifferenceObject'))
        'ConvertFrom-Json' = @(,@('InputObject'))
        'ConvertTo-Json' = @(,@('InputObject'))
        'ForEach-Object' = @(,@('Process'))
        'Format-List' = @(,@('Property'))
        'Format-Table' = @(,@('Property'))
        'Format-Wide' = @(,@('Property'))
        'Get-Alias' = @(,@('Name'))
        'Get-ChildItem' = @(@('Path'), @('Filter'))
        'Get-Command' = @(,@('Name'))
        'Get-Content' = @(,@('Path'))
        'Get-Date' = @(,@('Date'))
        'Get-FileHash' = @(,@('LiteralPath', 'Path'))
        'Get-GuildContext' = @(,@('Path'))
        'Get-GuildFindingSummary' = @(,@('Path'))
        'Get-GuildRepoSurvey' = @(,@('Path'))
        'Get-Help' = @(,@('Name'))
        'Get-Item' = @(,@('Path'))
        'Get-ItemProperty' = @(@('Path'), @('Name'))
        'Get-Member' = @(,@('Name'))
        'Get-Module' = @(,@('Name'))
        'Get-Variable' = @(,@('Name'))
        'Group-Object' = @(,@('Property'))
        'Import-Module' = @(,@('Name'))
        'Import-PowerShellDataFile' = @(,@('LiteralPath', 'Path'))
        'Invoke-Pester' = @(,@('Path'))
        'Invoke-ScriptAnalyzer' = @(,@('Path'))
        'Join-Path' = @(@('Path'), @('ChildPath'))
        'Measure-Command' = @(,@('Expression'))
        'Measure-Object' = @(,@('Property'))
        'Push-Location' = @(,@('Path'))
        'Resolve-Path' = @(,@('Path'))
        'Select-Object' = @(,@('Property'))
        'Select-String' = @(@('Pattern'), @('Path'))
        'Set-Location' = @(,@('Path'))
        'Sort-Object' = @(,@('Property'))
        'Split-Path' = @(,@('Path'))
        'Start-Sleep' = @(,@('Seconds', 'Duration'))
        'Test-GuildDocs' = @(,@('Path'))
        'Test-Json' = @(,@('Json'))
        'Test-Path' = @(,@('Path'))
        'Where-Object' = @(@('FilterScript', 'Property'), @('Value'))
        'Write-Error' = @(,@('Message'))
        'Write-Information' = @(,@('MessageData'))
        'Write-Verbose' = @(,@('Message'))
        'Write-Warning' = @(,@('Message'))
    }

    PowerShellCommands  = @{
        'Get-Content'             = @{
            Parameters = @{ Path = 'Value'; LiteralPath = 'Value'; TotalCount = 'Value'; Tail = 'Value'; Raw = 'Switch'; Encoding = 'Value'; Delimiter = 'Value'; ReadCount = 'Value'; Filter = 'Value'; Include = 'Value'; Exclude = 'Value'; AsByteStream = 'Switch'; Stream = 'Value' }
            Positional = @('Value')
        }
        'Get-ChildItem'           = @{
            Parameters = @{ Path = 'Value'; LiteralPath = 'Value'; Filter = 'Value'; Include = 'Value'; Exclude = 'Value'; Recurse = 'Switch'; Depth = 'Value'; Force = 'Switch'; Name = 'Switch'; File = 'Switch'; Directory = 'Switch'; Hidden = 'Switch'; ReadOnly = 'Switch'; System = 'Switch'; Attributes = 'Value'; FollowSymlink = 'Switch' }
            Positional = @('Value', 'Value')
        }
        'Get-Item'                = @{
            Parameters = @{ Path = 'Value'; LiteralPath = 'Value'; Force = 'Switch'; Filter = 'Value'; Include = 'Value'; Exclude = 'Value'; Stream = 'Value' }
            Positional = @('Value')
        }
        'Get-ItemProperty'        = @{
            Parameters = @{ Path = 'Value'; LiteralPath = 'Value'; Name = 'Value' }
            Positional = @('Value', 'Value')
        }
        'Test-Path'               = @{
            Parameters = @{ Path = 'Value'; LiteralPath = 'Value'; PathType = 'Value'; IsValid = 'Switch'; Filter = 'Value'; Include = 'Value'; Exclude = 'Value'; OlderThan = 'Value'; NewerThan = 'Value' }
            Positional = @('Value')
        }
        'Resolve-Path'            = @{
            Parameters = @{ Path = 'Value'; LiteralPath = 'Value'; Relative = 'Switch'; RelativeBasePath = 'Value' }
            Positional = @('Value')
        }
        'Join-Path'               = @{
            Parameters     = @{ Path = 'Value'; ChildPath = 'Value'; AdditionalChildPath = 'Value'; Resolve = 'Switch' }
            Positional     = @('Value', 'Value')
            PositionalRest = 'Value'
        }
        'Split-Path'              = @{
            Parameters = @{ Path = 'Value'; LiteralPath = 'Value'; Parent = 'Switch'; Leaf = 'Switch'; LeafBase = 'Switch'; Extension = 'Switch'; Qualifier = 'Switch'; NoQualifier = 'Switch'; IsAbsolute = 'Switch'; Resolve = 'Switch' }
            Positional = @('Value')
        }
        'Select-String'           = @{
            Parameters = @{ Pattern = 'Value'; Path = 'Value'; LiteralPath = 'Value'; InputObject = 'Value'; SimpleMatch = 'Switch'; CaseSensitive = 'Switch'; Context = 'Value'; AllMatches = 'Switch'; NotMatch = 'Switch'; List = 'Switch'; Quiet = 'Switch'; Raw = 'Switch'; Include = 'Value'; Exclude = 'Value'; Encoding = 'Value'; NoEmphasis = 'Switch'; Culture = 'Value' }
            Positional = @('Value', 'Value')
        }
        'Select-Object'           = @{
            Parameters = @{ Property = 'Property'; ExcludeProperty = 'Value'; ExpandProperty = 'Value'; First = 'Value'; Last = 'Value'; Skip = 'Value'; SkipLast = 'Value'; Unique = 'Switch'; Index = 'Value' }
            Positional = @('Property')
        }
        'Where-Object'            = @{
            Parameters = @{
                FilterScript = 'ScriptBlock'; Property = 'Value'; Value = 'Value'
                EQ = 'Switch'; NE = 'Switch'; GT = 'Switch'; GE = 'Switch'; LT = 'Switch'; LE = 'Switch'; Like = 'Switch'; NotLike = 'Switch'; Match = 'Switch'; NotMatch = 'Switch'; Contains = 'Switch'; NotContains = 'Switch'; In = 'Switch'; NotIn = 'Switch'; Is = 'Switch'; IsNot = 'Switch'
                CEQ = 'Switch'; CNE = 'Switch'; CGT = 'Switch'; CGE = 'Switch'; CLT = 'Switch'; CLE = 'Switch'; CLike = 'Switch'; CNotLike = 'Switch'; CMatch = 'Switch'; CNotMatch = 'Switch'; CContains = 'Switch'; CNotContains = 'Switch'; CIn = 'Switch'; CNotIn = 'Switch'
            }
            Positional = @('Property', 'Value')
        }
        'ForEach-Object'          = @{
            Parameters     = @{ Process = 'ScriptBlock'; Begin = 'ScriptBlock'; End = 'ScriptBlock' }
            Positional     = @('ScriptBlock')
            PositionalRest = 'ScriptBlock'
            Denied         = @{
                MemberName       = 'it calls a method by name'
                ArgumentList     = 'it passes arguments to a method it calls by name'
                Parallel         = 'it runs script blocks in parallel runspaces'
                ThrottleLimit    = 'it belongs to -Parallel'
                UseNewRunspace   = 'it belongs to -Parallel'
                RemainingScripts = 'it is not needed and widens what runs'
            }
        }
        'Sort-Object'             = @{
            Parameters = @{ Property = 'Property'; Descending = 'Switch'; Unique = 'Switch'; Top = 'Value'; Bottom = 'Value'; CaseSensitive = 'Switch'; Stable = 'Switch' }
            Positional = @('Property')
        }
        'Group-Object'            = @{
            Parameters = @{ Property = 'Property'; NoElement = 'Switch'; AsHashTable = 'Switch'; AsString = 'Switch'; CaseSensitive = 'Switch' }
            Positional = @('Property')
        }
        'Measure-Object'          = @{
            Parameters = @{ Property = 'Property'; Sum = 'Switch'; Average = 'Switch'; Maximum = 'Switch'; Minimum = 'Switch'; Line = 'Switch'; Word = 'Switch'; Character = 'Switch'; AllStats = 'Switch'; StandardDeviation = 'Switch' }
            Positional = @('Property')
        }
        'Format-Table'            = @{
            Parameters = @{ Property = 'Property'; GroupBy = 'Property'; AutoSize = 'Switch'; Wrap = 'Switch'; HideTableHeaders = 'Switch' }
            Positional = @('Property')
        }
        'Format-List'             = @{
            Parameters = @{ Property = 'Property'; GroupBy = 'Property' }
            Positional = @('Property')
        }
        'Format-Wide'             = @{
            Parameters = @{ Property = 'Property'; GroupBy = 'Property'; AutoSize = 'Switch'; Column = 'Value' }
            Positional = @('Property')
        }
        'Out-String'              = @{ Parameters = @{ Width = 'Value'; Stream = 'Switch'; NoNewline = 'Switch' }; Positional = @() }
        'Out-Null'                = @{ Parameters = @{}; Positional = @() }
        'Out-Host'                = @{ Parameters = @{}; Positional = @() }
        'Get-Location'            = @{ Parameters = @{}; Positional = @() }
        'Pop-Location'            = @{ Parameters = @{}; Positional = @() }
        'New-PesterConfiguration' = @{
            Parameters = @{}
            Positional = @()
            Denied     = @{ Hashtable = 'it can switch on result and coverage files' }
        }
        'ConvertFrom-Json'        = @{
            Parameters = @{ InputObject = 'Value'; AsHashtable = 'Switch'; Depth = 'Value'; NoEnumerate = 'Switch' }
            Positional = @('Value')
        }
        'ConvertTo-Json'          = @{
            Parameters = @{ InputObject = 'Value'; Depth = 'Value'; Compress = 'Switch'; AsArray = 'Switch'; EnumsAsStrings = 'Switch' }
            Positional = @('Value')
        }
        'Compare-Object'          = @{
            Parameters = @{ ReferenceObject = 'Value'; DifferenceObject = 'Value'; Property = 'Property'; IncludeEqual = 'Switch'; ExcludeDifferent = 'Switch'; PassThru = 'Switch'; SyncWindow = 'Value'; CaseSensitive = 'Switch' }
            Positional = @('Value', 'Value')
        }
        'Test-Json'               = @{
            Parameters = @{ Json = 'Value'; Schema = 'Value'; SchemaFile = 'Value' }
            Positional = @('Value')
        }
        'Get-FileHash'            = @{
            Parameters = @{ Path = 'Value'; LiteralPath = 'Value'; Algorithm = 'Value' }
            Positional = @('Value')
        }
        'Get-Date'                = @{
            Parameters = @{ Date = 'Value'; Format = 'Value'; UFormat = 'Value'; AsUTC = 'Switch' }
            Positional = @('Value')
        }
        'Set-Location'            = @{ Parameters = @{ Path = 'Value'; LiteralPath = 'Value' }; Positional = @('Value') }
        'Push-Location'           = @{ Parameters = @{ Path = 'Value'; LiteralPath = 'Value' }; Positional = @('Value') }
        'Write-Output'            = @{ Parameters = @{ InputObject = 'Value'; NoEnumerate = 'Switch' }; Positional = @(); PositionalRest = 'Value' }
        'Write-Host'              = @{ Parameters = @{ Object = 'Value'; NoNewline = 'Switch'; Separator = 'Value'; ForegroundColor = 'Value'; BackgroundColor = 'Value' }; Positional = @(); PositionalRest = 'Value' }
        'Write-Warning'           = @{ Parameters = @{ Message = 'Value' }; Positional = @('Value') }
        'Write-Verbose'           = @{ Parameters = @{ Message = 'Value' }; Positional = @('Value') }
        'Write-Error'             = @{ Parameters = @{ Message = 'Value' }; Positional = @('Value') }
        'Write-Information'       = @{ Parameters = @{ MessageData = 'Value'; Tags = 'Value' }; Positional = @('Value') }
        'Get-Command'             = @{
            Parameters = @{ Name = 'Value'; Module = 'Value'; CommandType = 'Value'; Noun = 'Value'; Verb = 'Value'; Syntax = 'Switch'; All = 'Switch'; ListImported = 'Switch' }
            Positional = @('Value')
        }
        'Get-Module'              = @{
            Parameters = @{ Name = 'Value'; ListAvailable = 'Switch'; All = 'Switch' }
            Positional = @('Value')
        }
        'Get-Help'                = @{
            Parameters = @{ Name = 'Value'; Full = 'Switch'; Examples = 'Switch'; Detailed = 'Switch'; Parameter = 'Value' }
            Positional = @('Value')
            Denied     = @{ Online = 'it opens a browser'; ShowWindow = 'it opens a window' }
        }
        'Get-Member'              = @{
            Parameters = @{ Name = 'Value'; MemberType = 'Value'; Static = 'Switch'; Force = 'Switch'; View = 'Value' }
            Positional = @('Value')
        }
        'Get-Variable'            = @{
            Parameters = @{ Name = 'Value'; ValueOnly = 'Switch'; Scope = 'Value'; Include = 'Value'; Exclude = 'Value' }
            Positional = @('Value')
        }
        'Get-Alias'               = @{
            Parameters = @{ Name = 'Value'; Definition = 'Value'; Scope = 'Value'; Exclude = 'Value' }
            Positional = @('Value')
        }
        'Import-Module'           = @{
            Parameters = @{ Name = 'Value'; Force = 'Switch'; PassThru = 'Switch'; DisableNameChecking = 'Switch' }
            Positional = @('Value')
            Denied     = @{ ArgumentList = 'it passes arguments to the module code' }
        }
        'Import-PowerShellDataFile' = @{
            Parameters = @{ Path = 'Value'; LiteralPath = 'Value'; SkipLimitCheck = 'Switch' }
            Positional = @('Value')
        }
        'Invoke-Pester'           = @{
            Parameters = @{ Path = 'Value'; ExcludePath = 'Value'; Output = 'Value'; PassThru = 'Switch'; Configuration = 'Config'; TagFilter = 'Value'; ExcludeTagFilter = 'Value'; FullNameFilter = 'Value' }
            Positional = @('Value')
            Denied     = @{
                CI                           = 'it writes result and coverage files'
                OutputFile                   = 'it writes a result file'
                OutputFormat                 = 'it writes a result file'
                CodeCoverage                 = 'it writes coverage data'
                CodeCoverageOutputFile       = 'it writes a coverage file'
                CodeCoverageOutputFileFormat = 'it writes a coverage file'
                EnableExit                   = 'it ends the host process'
                Script                       = 'it is the Pester 4 way to run arbitrary scripts'
            }
        }
        'Invoke-ScriptAnalyzer'   = @{
            Parameters = @{ Path = 'Value'; Settings = 'Constant'; Severity = 'Value'; Recurse = 'Switch'; IncludeRule = 'Value'; ExcludeRule = 'Value'; IncludeDefaultRules = 'Switch'; ReportSummary = 'Switch' }
            Positional = @('Value')
            Denied     = @{
                Fix                   = 'it rewrites files'
                CustomRulePath        = 'it runs rule code'
                RecurseCustomRulePath = 'it runs rule code'
                EnableExit            = 'it ends the host process'
                SaveDscDependency     = 'it downloads and saves modules'
            }
        }
        'Measure-Command'         = @{
            Parameters = @{ Expression = 'ScriptBlock' }
            Positional = @('ScriptBlock')
        }
        'Start-Sleep'             = @{
            Parameters = @{ Seconds = 'Value'; Milliseconds = 'Value'; Duration = 'Value' }
            Positional = @('Value')
        }
        'Get-GuildContext'        = @{ Parameters = @{ Path = 'Value'; AsMarkdown = 'Switch' }; Positional = @('Value') }
        'New-GuildBrief'          = @{
            Parameters = @{ Role = 'Value'; Goal = 'Value'; Path = 'Value'; Paths = 'Value'; Standards = 'Value'; Constraints = 'Value'; Done = 'Value'; HighRisk = 'Switch' }
            Positional = @()
        }
        'Test-GuildDocs'          = @{ Parameters = @{ Path = 'Value'; Owner = 'Value' }; Positional = @('Value') }
        'Get-GuildRepoSurvey'     = @{ Parameters = @{ Path = 'Value'; AsJson = 'Switch' }; Positional = @('Value') }
        'Get-GuildFindingSummary' = @{ Parameters = @{ Path = 'Value'; PromoteAfter = 'Value' }; Positional = @('Value') }
        'Get-GuildPack'           = @{ Parameters = @{ Pack = 'Value'; AsJson = 'Switch' }; Positional = @() }
        'Test-GuildInstall'       = @{
            Parameters = @{ Harness = 'Value'; Scope = 'Value'; Path = 'Value'; Pack = 'Value'; NoSkills = 'Switch'; NoRouting = 'Switch' }
            Positional = @()
            Denied     = @{ Model = 'it takes a hashtable' }
        }
        'New-GuildDecision'       = @{
            Parameters    = @{ Path = 'Value'; Title = 'Value'; Status = 'Value'; Directory = 'Value' }
            Positional    = @()
            RequiresAllow = $true
        }
    }

    # Pester configuration objects (docs/guard.md 4.9): build with the factory, then set listed values.
    ConfiguredObjects   = @{
        pester = @{
            Factory  = 'New-PesterConfiguration'
            Settings = @('Run.Path', 'Run.ExcludePath', 'Run.PassThru', 'Filter.Tag', 'Filter.ExcludeTag', 'Filter.FullName', 'Filter.Line', 'Output.Verbosity', 'Should.ErrorAction')
        }
    }

    # Static members by full type name. Methods and properties both count.
    StaticMembers       = @{
        'System.Math'                            = @('Max', 'Min', 'Abs', 'Round', 'Floor', 'Ceiling', 'Pow', 'Sqrt', 'Truncate')
        'System.String'                          = @('Join', 'IsNullOrEmpty', 'IsNullOrWhiteSpace', 'Format', 'Concat', 'Compare', 'Equals', 'Empty')
        'System.Text.RegularExpressions.Regex'   = @('Match', 'Matches', 'IsMatch', 'Escape', 'Unescape', 'Split', 'Replace')
        'System.IO.Path'                         = @('GetFileName', 'GetFileNameWithoutExtension', 'GetExtension', 'GetDirectoryName', 'GetFullPath', 'GetRelativePath', 'GetPathRoot', 'Combine', 'Join', 'IsPathRooted', 'HasExtension', 'ChangeExtension', 'DirectorySeparatorChar')
        'System.IO.File'                         = @('Exists', 'ReadAllText', 'ReadAllLines', 'GetLastWriteTime', 'GetLastWriteTimeUtc', 'GetAttributes')
        'System.IO.Directory'                    = @('Exists', 'GetFiles', 'GetDirectories', 'EnumerateFiles', 'EnumerateDirectories', 'GetCurrentDirectory')
        'System.Environment'                     = @('NewLine', 'MachineName', 'UserName', 'OSVersion', 'ProcessorCount', 'CurrentDirectory', 'GetEnvironmentVariable')
        'System.DateTime'                        = @('Now', 'UtcNow', 'Today', 'Parse', 'ParseExact', 'MinValue', 'MaxValue')
        'System.TimeSpan'                        = @('FromSeconds', 'FromMinutes', 'FromHours', 'FromDays', 'Parse')
        'System.Int32'                           = @('Parse', 'MinValue', 'MaxValue')
        'System.Int64'                           = @('Parse', 'MinValue', 'MaxValue')
        'System.Double'                          = @('Parse', 'MinValue', 'MaxValue')
        'System.Version'                         = @('Parse')
        'System.Guid'                            = @('Parse')
        'System.Convert'                         = @('ToBase64String', 'FromBase64String', 'ToInt32', 'ToInt64', 'ToString', 'ToBoolean')
    }

    # Instance methods any object may be asked for. Deliberately short: no Replace (FileInfo.Replace
    # replaces files), no Invoke, no .Where() or .ForEach() (they can call a method by name).
    InstanceMethods     = @('ToString', 'Trim', 'TrimStart', 'TrimEnd', 'ToLower', 'ToUpper', 'ToLowerInvariant', 'ToUpperInvariant', 'Substring', 'StartsWith', 'EndsWith', 'Split', 'IndexOf', 'Contains', 'ContainsKey', 'PadLeft', 'PadRight', 'Equals')

    # Property names never read: they open the object's internals.
    DeniedMembers       = @('PSObject', 'PSBase', 'PSAdapted', 'PSExtended', 'ScriptBlock', 'OnRemove')

    # Types allowed in [type] conversions and -as.
    ConvertTypes        = @('System.String', 'System.Char', 'System.Int32', 'System.Int64', 'System.Double', 'System.Decimal', 'System.Boolean', 'System.DateTime', 'System.Version', 'System.Object[]', 'System.Array', 'System.Management.Automation.PSObject', 'System.Collections.Specialized.OrderedDictionary')

    # Variables that are never assigned. A name is also reserved if it starts with PS, ends with
    # Preference, or exists in the guard's own global scope at startup.
    ReservedVariables   = @('_', 'args', 'input', 'this', 'foreach', 'switch', 'Matches', 'LASTEXITCODE', 'Error', 'Event', 'EventArgs', 'EventSubscriber', 'Sender', 'MyInvocation', 'StackTrace', 'OFS', 'Host', 'HOME', 'PWD', 'ExecutionContext', 'PROFILE', 'true', 'false', 'MaximumHistoryCount', 'FormatEnumerationLimit', 'Transcript', 'LogCommandHealthEvent', 'LogCommandLifecycleEvent', 'LogEngineHealthEvent', 'LogEngineLifecycleEvent', 'LogProviderHealthEvent', 'LogProviderLifecycleEvent', 'MaximumVariableCount', 'MaximumAliasCount', 'MaximumFunctionCount', 'MaximumDriveCount', 'EnabledExperimentalFeatures', 'ErrorView', 'ConsoleFileName', 'MaximumErrorCount', 'IsCoreCLR', 'IsLinux', 'IsMacOS', 'IsWindows', 'NestedPromptLevel', 'OutputEncoding', 'PID', 'ShellId')
    # Assignment is allowed only to names that start with a lowercase letter and are not reserved: every engine
    # variable is PascalCase or upper case, so an engine variable the lists miss is still refused.
    UserVariablePattern = '^[a-z][A-Za-z0-9_]*$'
    AssignablePreferences = @('ErrorActionPreference', 'ProgressPreference', 'WarningPreference', 'InformationPreference', 'VerbosePreference')

    # Native commands (docs/guard.md section 6), used from both shells. Matching of option names is
    # case-sensitive. Short = flags, ShortValue = flags that take a value, Long / LongValue likewise.
    NativeCommands      = @{
        cat      = @{ Mode = 'Any' }
        head     = @{ Mode = 'Any' }
        tail     = @{ Mode = 'Any' }
        wc       = @{ Mode = 'Any' }
        ls       = @{ Mode = 'Any' }
        du       = @{ Mode = 'Any' }
        df       = @{ Mode = 'Any' }
        stat     = @{ Mode = 'Any' }
        pwd      = @{ Mode = 'Any' }
        which    = @{ Mode = 'Any' }
        jq       = @{
            Mode              = 'Jq'
            # jq can read the process environment: env and $ENV (a field called .env is fine).
            FilterDeny        = '(?:\$ENV|(?<![A-Za-z0-9_.$])env(?![A-Za-z0-9_]))'
            Flags             = @('-n', '-r', '-c', '-e', '-s', '-R', '-S', '-C', '-M', '-a', '-j', '-0', '--tab', '--seq', '--stream', '--unbuffered', '--exit-status', '--raw-output', '--compact-output', '--null-input', '--slurp', '--raw-input', '--sort-keys', '--color-output', '--monochrome-output', '--ascii-output', '--join-output', '--args', '--jsonargs', '--raw-output0')
            ShortFlagChars    = 'nrcesRSCMaj0'
            ValueOptions      = @('--indent', '--arg', '--argjson', '--slurpfile', '--rawfile', '-L')
            # Options that take two words: a name, then a value (a file, for --slurpfile and --rawfile).
            TwoWordOptions    = @('--arg', '--argjson', '--slurpfile', '--rawfile')
        }
        diff     = @{ Mode = 'Any' }
        grep     = @{ Mode = 'Any' }
        egrep    = @{ Mode = 'Any' }
        fgrep    = @{ Mode = 'Any' }
        basename = @{ Mode = 'Any' }
        dirname  = @{ Mode = 'Any' }
        realpath = @{ Mode = 'Any' }
        cd       = @{ Mode = 'Any'; MaxPositional = 1 }
        sort     = @{
            Mode      = 'Allow'
            Short     = 'bdfghiMnRrVuz'
            SlashOptions = $true
            ShortValue = 'kt'
            Long      = @('reverse', 'numeric-sort', 'general-numeric-sort', 'human-numeric-sort', 'version-sort', 'month-sort', 'ignore-case', 'ignore-leading-blanks', 'dictionary-order', 'unique', 'stable', 'zero-terminated', 'random-sort')
            LongValue = @('key', 'field-separator')
        }
        uniq     = @{
            Mode          = 'Allow'
            Short         = 'cdDiuz'
            SlashOptions  = $true
            ShortValue    = 'fsw'
            Long          = @('count', 'repeated', 'unique', 'ignore-case', 'zero-terminated')
            LongValue     = @('skip-fields', 'skip-chars', 'check-chars')
            MaxPositional = 1
        }
        find     = @{
            Mode           = 'Words'
            Words          = @('-type', '-name', '-iname', '-path', '-ipath', '-regex', '-iregex', '-maxdepth', '-mindepth', '-newer', '-mtime', '-mmin', '-size', '-empty', '-print', '-print0', '-printf', '-ls', '-not', '-o', '-a', '-and', '-or', '-prune', '-L', '-H', '-P', '-user', '-group', '-perm', '-links', '-samefile', '-wholename', '-readable', '-writable', '-executable', '-depth', '-xdev', '-mount', '-quit', '-follow', '-daystart')
            WordsWithValue = @('-type', '-name', '-iname', '-path', '-ipath', '-regex', '-iregex', '-maxdepth', '-mindepth', '-newer', '-mtime', '-mmin', '-size', '-printf', '-user', '-group', '-perm', '-links', '-samefile', '-wholename')
        }
        rg       = @{ Mode = 'Deny'; DenyLong = @('pre', 'hostname-bin', 'search-zip'); DenyShort = 'z' }
        tree     = @{ Mode = 'Deny'; DenyShort = 'oR' }
        file     = @{ Mode = 'Deny'; DenyShort = 'C'; DenyLong = @('compile') }
        sed      = @{ Mode = 'SedPrint' }
        git      = @{
            Mode          = 'Git'
            GlobalOptions = @('--no-pager', '-P', '--no-optional-locks', '--literal-pathspecs', '--glob-pathspecs', '--noglob-pathspecs', '--icase-pathspecs', '--no-replace-objects')
            # Applies to every sub-command: --help opens a browser on some platforms.
            DenyLong      = @('help')
            Subcommands   = @{
                status       = @{ Mode = 'Deny'; DenyLong = @('output', 'ext-diff') }
                log          = @{ Mode = 'Deny'; DenyLong = @('output', 'ext-diff') }
                show         = @{ Mode = 'Deny'; DenyLong = @('output', 'ext-diff') }
                diff         = @{ Mode = 'Deny'; DenyLong = @('output', 'ext-diff') }
                shortlog     = @{ Mode = 'Deny'; DenyLong = @('output', 'ext-diff') }
                blame        = @{ Mode = 'Deny'; DenyLong = @('output', 'ext-diff') }
                'ls-files'   = @{ Mode = 'Deny'; DenyLong = @('output', 'ext-diff') }
                'ls-tree'    = @{ Mode = 'Deny'; DenyLong = @('output', 'ext-diff') }
                'rev-parse'  = @{ Mode = 'Deny'; DenyLong = @('output', 'ext-diff') }
                'rev-list'   = @{ Mode = 'Deny'; DenyLong = @('output', 'ext-diff') }
                'merge-base' = @{ Mode = 'Deny'; DenyLong = @('output', 'ext-diff') }
                describe     = @{ Mode = 'Deny'; DenyLong = @('output', 'ext-diff') }
                grep         = @{ Mode = 'Deny'; DenyShort = 'O'; DenyLong = @('open-files-in-pager', 'output', 'ext-diff') }
                'cat-file'   = @{ Mode = 'Deny'; DenyLong = @('textconv', 'filters') }
                branch       = @{
                    Mode              = 'Allow'
                    Short             = 'arvil'
                    Long              = @('list', 'all', 'remotes', 'verbose', 'show-current', 'ignore-case', 'color', 'no-color', 'column', 'no-column')
                    LongValue         = @('contains', 'no-contains', 'merged', 'no-merged', 'points-at', 'sort', 'format')
                    PositionalNeeds   = @('--list', 'l')
                }
                tag          = @{
                    Mode              = 'Allow'
                    Short             = 'li'
                    NumericShort      = 'n'
                    Long              = @('list', 'ignore-case', 'color', 'column', 'no-column')
                    LongValue         = @('contains', 'no-contains', 'merged', 'no-merged', 'points-at', 'sort', 'format')
                    PositionalNeeds   = @('--list', 'l')
                }
                remote       = @{ Mode = 'Remote' }
            }
        }
        gh       = @{
            Mode      = 'Gh'
            Pairs     = @('run list', 'run view', 'pr view', 'pr diff', 'pr list', 'pr checks', 'pr status', 'issue view', 'issue list', 'repo view', 'release list', 'release view', 'workflow list', 'workflow view')
            DenyLong  = @('web')
            DenyShort = 'w'
        }
        az       = @{
            Mode        = 'CloudPath'
            ReadVerbs   = @('^(show|list|version)$', '^show-[a-z0-9-]+$', '^list-[a-z0-9-]+$')
            # Options that make a read print secret values (prefix matching, as for any long option).
            DenyLong    = @('show-values', 'show-secrets', 'resolve-keyvault', 'include-value', 'include-values')
            # A path word like these names a secret-bearing resource: key, secret, credential, password,
            # token, connection string, app settings (az names them in the path: 'storage account keys list',
            # 'containerapp secret list', 'eventgrid topic key list', 'communication list-key').
            SecretWords = '(^|-)(key|keys|secret|secrets|credential|credentials|password|passwords|token|connection-string|connection-strings|appsettings)(-|$)'
            # Reads on those resources that return no secret value, so they stay allowed. Key Vault lists
            # return names and metadata only, and a key's show returns its public part.
            SafePaths   = @('^keyvault secret (list|list-versions|list-deleted)$', '^keyvault key (list|list-versions|list-deleted|show)$')
            # Reads that print secret values without a secret-bearing word in the path.
            DeniedPaths = @(
                '^keyvault (key|certificate) (download|backup)$'
                '^iot hub policy (list|show)$'
                '^iot hub device-identity show$'
                '^apim subscription show$'
                '^webapp deployment list-publishing-profiles$'
                '^acr credential show$'
            )
        }
        gcloud   = @{
            Mode        = 'CloudPath'
            ReadVerbs   = @('^list$', '^list-[a-z0-9-]+$')
            DeniedPaths = @('^secrets versions access$', '^auth print-', '^config config-helper$', '^kms .*decrypt$')
        }
        aws      = @{
            Mode              = 'Aws'
            OptionsBefore     = @('--profile', '--region', '--output', '--query', '--endpoint-url', '--color')
            FlagsBefore       = @('--no-cli-pager')
            # Options that make any read print secret values (prefix matching).
            # --debug logs request headers, which carry temporary credentials.
            DenyLong          = @('with-decryption', 'include-value', 'include-values', 'debug')
            # An operation whose name says it returns a token, password, credential or secret.
            SecretOperations  = '(token|password|credential|secret|login|access-details)'
            # Exceptions to that: each returns metadata or policy only, no secret value.
            SafeOperations    = @('secretsmanager list-secrets', 'secretsmanager describe-secret', 'secretsmanager list-secret-version-ids', 'iam get-account-password-policy', 'iam get-login-profile', 'iam get-credential-report', 'iam list-service-specific-credentials')
            # Pairs that write an output file, or print credentials and secret values the name does not show.
            DeniedPairs       = @('s3api get-object', 's3api get-object-torrent', 'ec2 get-password-data', 'cognito-idp describe-user-pool-client', 'configure get', 'appsync list-api-keys')
            # Reads whose output includes environment variables, which often hold secrets: a Lambda function's
            # configuration (get-function, get-function-configuration, and the lists that embed it), an ECS task
            # definition's container environment, a described task's overrides, a Batch job definition's container environment, an
            # Elastic Beanstalk environment's option settings, and an App Runner service's runtime environment variables. lambda list-aliases,
            # get-alias, get-policy and list-tags return no environment, so they stay allowed.
            EnvironmentPairs  = @('lambda get-function-configuration', 'lambda get-function', 'lambda list-functions', 'lambda list-versions-by-function', 'ecs describe-task-definition', 'ecs describe-tasks', 'batch describe-job-definitions', 'elasticbeanstalk describe-configuration-settings', 'apprunner describe-service', 'batch describe-jobs', 'glue get-job', 'glue get-jobs', 'amplify get-app', 'amplify list-apps', 'amplify get-branch', 'amplify list-branches', 'sagemaker describe-training-job', 'sagemaker describe-processing-job', 'sagemaker describe-transform-job', 'sagemaker describe-model', 'codebuild batch-get-projects', 'codebuild batch-get-builds', 'ec2 describe-launch-template-versions', 'ec2 get-launch-template-data', 'autoscaling describe-launch-configurations')
            # These print instance user data (often credentials) when asked for the userData attribute.
            DeniedWhenWord    = @{ 'ec2 describe-instance-attribute' = '(?i)^(--attribute=)?userdata$' }
            # These print a password unless the option is given.
            DeniedUnlessOption = @{ 'glue get-connection' = '--hide-password'; 'glue get-connections' = '--hide-password' }
            # Services whose commands take positional words (s3 ls takes a URI). Elsewhere a bare word that is
            # not an option's value is an output file: aws writes streaming results to it.
            PositionalServices = @('s3')
            # Options that take a value, so the bare word right after one is theirs. Any other option counts
            # as a flag: a bare word after it is an output file and blocks. A value written --name=value
            # needs no list. The pattern covers the usual names (--instance-ids, --max-items, --log-group-name).
            # Operations that write their result to a file named by a bare word: for these only an option on the exact
            # list below (plus ValueOptions) takes a value; the suffix pattern is not used, so a look-alike option
            # (--range-name, --include-all-instances) is a flag and the word after it blocks.
            OutfileOperations = @{
                'glacier get-job-output'               = @('--account-id', '--vault-name', '--job-id', '--range')
                'apigateway get-export'                = @('--rest-api-id', '--stage-name', '--export-type', '--parameters', '--accepts')
                'apigateway get-sdk'                   = @('--rest-api-id', '--stage-name', '--sdk-type', '--parameters')
                'iot-data get-thing-shadow'            = @('--thing-name', '--shadow-name')
                'appconfig get-configuration'          = @('--application', '--environment', '--configuration', '--client-id', '--client-configuration-version')
                'appconfigdata get-latest-configuration' = @('--configuration-token')
                'kinesis-video-media get-media'        = @('--stream-name', '--stream-arn', '--start-selector')
                'mediastore-data get-object'           = @('--path', '--range')
                'ebs get-snapshot-block'               = @('--snapshot-id', '--block-index', '--block-token')
                'lakeformation get-work-unit-results'  = @('--query-id', '--work-unit-id', '--work-unit-token')
                'codeartifact get-package-version-asset' = @('--domain', '--domain-owner', '--repository', '--format', '--namespace', '--package', '--package-version', '--asset', '--package-version-revision')
            }
            ValueOptions      = @('--profile', '--region', '--output', '--query', '--endpoint-url', '--color', '--filters', '--filter', '--ca-bundle', '--cli-read-timeout', '--cli-connect-timeout', '--page-size', '--max-items', '--starting-token')
            ValueOptionPattern = '^--([a-z0-9]+-)*(id|ids|name|names|arn|arns|key|keys|path|paths|filters?|query|region|profile|output|items|size|limit|status|type|types|version|versions|prefix|tag|tags|stage|bucket|group|groups|user|role|policy|domain|zone|state|selector|identifier|identifiers|timeout|token|count|period|time|namespace|scope|format|owner|owners|engine|account|principal|resource|resources|text|value|values|region-name|configuration|services|clusters|tasks|definition|cluster|service|task|qualifier|function|stream|table|queue|topic|instance|repository|jobs|queues|definitions|attribute)$'
        }
        kubectl  = @{
            Mode           = 'Kubectl'
            OptionsBefore  = @('-n', '--namespace', '--context', '--cluster', '--user', '--kubeconfig', '-s', '--server', '--as', '--as-group', '--request-timeout')
            FlagsBefore    = @('--insecure-skip-tls-verify')
            Subcommands    = @('get', 'describe', 'logs', 'version', 'top', 'explain', 'api-resources', 'api-versions')
            # get/describe of these resource types prints secret values (get with a value-revealing
            # output format, describe always: it names every key).
            SecretResources = '(^|,)secrets?(\.[A-Za-z0-9.-]*)?(/|,|$)'
            # For a secret (or with -f/-k) only these outputs are allowed; any other format, including one added later, may print values.
            AllowedSecretOutputs = @('name', 'wide')
            DenyLong        = @('raw')
            # With -f/-k the resource type comes from a file, so a value-revealing output is refused outright;
            # --template (any abbreviation) is a value-revealing output too.
            FileOptions     = @('-f', '--filename', '-k', '--kustomize')
            TemplateOption  = 'template'
        }
    }
}
