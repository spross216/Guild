# The guard's rule data (guards/Test-GuildReadOnlyCommand.psd1) checked against the installed commands'
# own metadata, and the Bash and native-option rules checked by generated cases (docs/guard.md section 9).
# Nothing here is skipped: the modules the rules describe are required to be installed, as the build
# already requires Pester and PSScriptAnalyzer.

BeforeDiscovery { . (Join-Path $PSScriptRoot 'GuardRulesRows.ps1') }

BeforeAll {
    . (Join-Path $PSScriptRoot 'GuardHarness.ps1')
    Import-Module Pester -MinimumVersion 5.5.0
    Import-Module PSScriptAnalyzer
    Import-Module (Join-Path $PSScriptRoot '../Guild/Guild.psd1') -Force
    . (Join-Path $PSScriptRoot 'GuardRulesRows.ps1')

    $requests = foreach ($row in @($script:InsertRows) + @($script:PrefixRows)) { foreach ($text in $row.Texts) { @{ Command = $text; Tool = 'Bash' } } }
    Initialize-GuardBatch -Cases $requests
}

Describe 'Rule data against the commands'' own metadata' {
    It 'finds <CommandName> and every listed parameter on it, with the right switch shape' -ForEach $script:CommandRows {
        $entry = $script:RuleData.PowerShellCommands[$CommandName]
        $command = Get-Command $CommandName -ErrorAction SilentlyContinue
        $command | Should -Not -BeNullOrEmpty -Because "$CommandName must be installed for its rules to be checked"
        $problems = foreach ($name in $entry.Parameters.Keys) {
            $parameter = $command.Parameters[$name]
            if (-not $parameter) { $parameter = $command.Parameters.Values | Where-Object { $_.Aliases -contains $name } | Select-Object -First 1 }
            if (-not $parameter) { "-$name does not exist"; continue }
            $isSwitch = $parameter.ParameterType -eq [switch]
            if (($entry.Parameters[$name] -eq 'Switch') -ne $isSwitch) { "-$name is $(if ($isSwitch) { 'a switch' } else { 'not a switch' }) but the data says $($entry.Parameters[$name])" }
        }
        @($problems) | Should -BeNullOrEmpty
    }

    It 'binds positions and pipeline input of <CommandName> only to listed parameters, or ones the data explains' -ForEach $script:CommandRows {
        $entry = $script:RuleData.PowerShellCommands[$CommandName]
        $command = Get-Command $CommandName
        $listed = @($entry.Parameters.Keys)
        $explained = if ($script:RuleData.UnlistedParameters.ContainsKey($CommandName)) { @($script:RuleData.UnlistedParameters[$CommandName].Keys) } else { @() }
        $isCovered = { param($name) ($listed -contains $name) -or ($explained -contains $name) -or ($command.Parameters[$name].Aliases | Where-Object { $listed -contains $_ }) }
        $common = [System.Management.Automation.Cmdlet]::CommonParameters + [System.Management.Automation.Cmdlet]::OptionalCommonParameters
        $anyRemaining = $false
        $problems = foreach ($set in $command.ParameterSets) {
            foreach ($parameter in $set.Parameters) {
                if ($parameter.Name -in $common) { continue }
                $covered = & $isCovered $parameter.Name
                if ($parameter.Position -ge 0 -and $parameter.Position -lt @($entry.Positional).Count -and -not $covered) { "set $($set.Name): position $($parameter.Position) binds -$($parameter.Name)" }
                if ($parameter.ValueFromPipelineByPropertyName -and -not $covered) { "set $($set.Name): -$($parameter.Name) binds from a piped object's property" }
                if ($parameter.ValueFromRemainingArguments -and $covered) { $anyRemaining = $true }
            }
        }
        if ($entry.PositionalRest -and -not $anyRemaining) { $problems += 'PositionalRest is set but no listed parameter takes the remaining arguments' }
        @($problems) | Should -BeNullOrEmpty
    }

    It 'keeps the explained parameters of <CommandName> real, and not also listed' -ForEach $script:CommandRows {
        if (-not $script:RuleData.UnlistedParameters.ContainsKey($CommandName)) { return }
        $command = Get-Command $CommandName
        foreach ($name in $script:RuleData.UnlistedParameters[$CommandName].Keys) {
            $command.Parameters.ContainsKey($name) | Should -BeTrue -Because "-$name must exist on $CommandName"
            $script:RuleData.PowerShellCommands[$CommandName].Parameters.ContainsKey($name) | Should -BeFalse
        }
    }

    It 'names the parameter behind every positional slot of <CommandName>, as the command defines them' -ForEach $script:CommandRows {
        $entry = $script:RuleData.PowerShellCommands[$CommandName]
        $slots = @($entry.Positional).Count
        if ($slots -eq 0) { $script:RuleData.PositionalNames.ContainsKey($CommandName) | Should -BeFalse; return }
        $script:RuleData.PositionalNames.ContainsKey($CommandName) | Should -BeTrue -Because "$CommandName has positional arguments"
        $names = @($script:RuleData.PositionalNames[$CommandName])
        $names.Count | Should -Be $slots
        $command = Get-Command $CommandName
        for ($slot = 0; $slot -lt $slots; $slot++) {
            foreach ($name in @($names[$slot])) {
                $entry.Parameters.ContainsKey($name) | Should -BeTrue -Because "-$name must be a listed parameter"
                $real = $command.Parameters.Values | Where-Object { $_.Name -eq $name -or $_.Aliases -contains $name } | Select-Object -First 1
                $real | Should -Not -BeNullOrEmpty
                $positions = foreach ($set in $command.ParameterSets) { foreach ($parameter in $set.Parameters) { if ($parameter.Name -eq $real.Name) { $parameter.Position } } }
                $positions | Should -Contain $slot -Because "-$name must sit at position $slot"
            }
            @($names[$slot]).Count | Should -BeGreaterThan 0
        }
        # Every listed parameter that sits at one of these positions is named, so naming it frees its slot.
        $named = @($names | ForEach-Object { $_ })
        foreach ($set in $command.ParameterSets) {
            foreach ($parameter in $set.Parameters) {
                if ($parameter.Position -ge 0 -and $parameter.Position -lt $slots -and $entry.Parameters.ContainsKey($parameter.Name)) { $named | Should -Contain $parameter.Name -Because "-$($parameter.Name) fills position $($parameter.Position) in set $($set.Name)" }
            }
        }
    }

    It 'never lists a denied parameter of <CommandName> as allowed' -ForEach $script:CommandRows {
        $entry = $script:RuleData.PowerShellCommands[$CommandName]
        if (-not $entry.Denied) { return }
        foreach ($denied in @($entry.Denied.Keys)) { $entry.Parameters.ContainsKey($denied) | Should -BeFalse -Because "-$denied is denied" }
    }

    It 'resolves every static type and finds every listed member on <TypeName>' -ForEach $script:TypeRows {
        $type = $TypeName -as [type]
        $type | Should -Not -BeNullOrEmpty
        foreach ($member in $script:RuleData.StaticMembers[$TypeName]) {
            @($type.GetMember($member, [System.Reflection.BindingFlags]'Public,Static')).Count | Should -BeGreaterThan 0 -Because "$TypeName::$member must exist"
        }
    }

    It 'lists no instance method that changes files or processes' {
        $names = foreach ($typeName in 'System.IO.FileInfo', 'System.IO.DirectoryInfo', 'System.IO.FileSystemInfo', 'System.Diagnostics.Process', 'System.IO.FileStream') {
            foreach ($method in ($typeName -as [type]).GetMethods('Public,Instance')) { $method.Name }
        }
        $overlap = @($script:RuleData.InstanceMethods | Where-Object { $_ -notin 'ToString', 'Equals' -and $_ -in $names })
        $overlap | Should -BeNullOrEmpty
    }

    It 'denies reading ScriptBlock and the other internals of an object' {
        foreach ($name in 'PSObject', 'PSBase', 'ScriptBlock') { $script:RuleData.DeniedMembers | Should -Contain $name }
    }

    It 'reads the syntax tree properties newer PowerShell versions add only through a property-existence check' {
        $source = Get-Content -LiteralPath (Join-Path $PSScriptRoot '../guards/Test-GuildReadOnlyCommand.ps1') -Raw
        # CleanBlock and GenericTypeArguments exist from PowerShell 7.3; Guild.psd1 allows 7.2, so the guard must not
        # read them directly (under strict mode that would block every command on 7.2).
        $source | Should -Not -Match '\$\w+\.CleanBlock'
        $source | Should -Not -Match '\$\w+\.GenericTypeArguments'
        $source | Should -Match ([regex]::Escape('Get-AstProperty $Block ' + [char]39 + 'CleanBlock' + [char]39))
        $source | Should -Match ([regex]::Escape('Get-AstProperty $Expression ' + [char]39 + 'GenericTypeArguments' + [char]39))
    }

    It 'lists a probe name for every credential name a wildcard segment is compared with' {
        foreach ($name in $script:RuleData.SecretSegmentNames) {
            ($name -in $script:RuleData.SecretGlobProbes) | Should -BeTrue -Because "$name needs a probe for the wildcard check"
        }
    }

    It 'runs the guard in the strictest strict mode, so a typo or a missing key is an error that blocks' {
        Get-Content -LiteralPath (Join-Path $PSScriptRoot '../guards/Test-GuildReadOnlyCommand.ps1') -Raw | Should -Match '(?m)^Set-StrictMode -Version Latest$'
    }

    It 'reserves every variable a fresh engine defines, by the rule data alone' {
        $shell = [powershell]::Create()
        try { $names = @($shell.AddScript('Get-Variable | ForEach-Object Name').Invoke()) } finally { $shell.Dispose() }
        $names += @([System.Management.Automation.Runspaces.InitialSessionState]::CreateDefault2().Variables | ForEach-Object Name)
        $names += 'MaximumVariableCount', 'MaximumAliasCount', 'MaximumFunctionCount', 'MaximumDriveCount'
        $rules = $script:RuleData
        $open = foreach ($name in $names | Sort-Object -Unique) {
            if ($name -notmatch '^[A-Za-z_][A-Za-z0-9_]*$' -or $name -eq 'null') { continue }
            if ($name -in $rules.AssignablePreferences) { continue }
            if (-not (($name -in $rules.ReservedVariables) -or $name -like 'PS*' -or $name -like '*Preference')) { $name }
        }
        @($open) | Should -BeNullOrEmpty -Because 'these engine variables could be assigned'
    }

    It 'reserves every documented automatic and preference variable, even written in lower case' {
        # From about_Automatic_Variables and about_Preference_Variables (some are not listed by Get-Variable at all).
        $documented = 'args', 'ConsoleFileName', 'EnabledExperimentalFeatures', 'Error', 'Event', 'EventArgs', 'EventSubscriber', 'ExecutionContext', 'false', 'foreach', 'HOME', 'Host', 'input', 'IsCoreCLR', 'IsLinux', 'IsMacOS', 'IsWindows', 'LASTEXITCODE', 'Matches', 'MyInvocation', 'NestedPromptLevel', 'PID', 'PROFILE', 'PSBoundParameters', 'PSCmdlet', 'PSCommandPath', 'PSCulture', 'PSDebugContext', 'PSEdition', 'PSHOME', 'PSItem', 'PSScriptRoot', 'PSSenderInfo', 'PSUICulture', 'PSVersionTable', 'PWD', 'Sender', 'ShellId', 'StackTrace', 'switch', 'this', 'true',
        'ErrorView', 'FormatEnumerationLimit', 'LogCommandHealthEvent', 'LogCommandLifecycleEvent', 'LogEngineHealthEvent', 'LogEngineLifecycleEvent', 'LogProviderHealthEvent', 'LogProviderLifecycleEvent', 'MaximumAliasCount', 'MaximumDriveCount', 'MaximumErrorCount', 'MaximumFunctionCount', 'MaximumHistoryCount', 'MaximumVariableCount', 'OFS', 'OutputEncoding', 'PSDefaultParameterValues', 'PSEmailServer', 'PSModuleAutoLoadingPreference', 'PSNativeCommandArgumentPassing', 'PSSessionApplicationName', 'PSSessionConfigurationName', 'PSSessionOption', 'PSStyle', 'Transcript'
        $rules = $script:RuleData
        $open = foreach ($name in $documented) {
            foreach ($spelling in $name, $name.ToLowerInvariant()) {
                if (-not (($spelling -in $rules.ReservedVariables) -or $spelling -like 'PS*')) { $spelling }
            }
        }
        @($open) | Should -BeNullOrEmpty -Because 'these documented variables could be assigned'
        $rules.UserVariablePattern | Should -Be '^[a-z][A-Za-z0-9_]*$'
    }

    It 'keeps reserved variables and assignable preferences apart' {
        @($script:RuleData.ReservedVariables | Where-Object { $_ -in $script:RuleData.AssignablePreferences }) | Should -BeNullOrEmpty
    }

    It 'finds every Pester setting on a new configuration' {
        $configuration = New-PesterConfiguration
        foreach ($setting in $script:RuleData.ConfiguredObjects.pester.Settings) {
            $node = $configuration
            foreach ($segment in $setting -split '\.') {
                $node = $node.$segment
                $node | Should -Not -BeNullOrEmpty -Because "$setting must be a Pester setting ($segment)"
            }
        }
        $script:RuleData.ConfiguredObjects.pester.Settings | Where-Object { $_ -match '^(TestResult|CodeCoverage)\.' } | Should -BeNullOrEmpty
    }

    It 'knows the factory of every configured object as a listed command' {
        foreach ($key in $script:RuleData.ConfiguredObjects.Keys) { $script:RuleData.PowerShellCommands.ContainsKey($script:RuleData.ConfiguredObjects[$key].Factory) | Should -BeTrue }
    }

    It 'only uses argument shapes the guard knows' {
        $shapes = 'Switch', 'Value', 'ScriptBlock', 'Property', 'Config', 'Constant'
        foreach ($entry in $script:RuleData.PowerShellCommands.Values) {
            foreach ($shape in @($entry.Parameters.Values) + @($entry.Positional) + @($entry.PositionalRest | Where-Object { $_ })) { $shape | Should -BeIn $shapes }
        }
    }

    It 'lists only static members and conversion types that resolve' {
        foreach ($type in $script:RuleData.ConvertTypes) { ($type -as [type]) | Should -Not -BeNullOrEmpty -Because "$type must resolve" }
    }
}

Describe 'Bash grammar: a forbidden character at any position' {
    It 'blocks <Shown>' -ForEach $script:InsertRows {
        $allowed = @(foreach ($text in $Texts) { if ((Get-GuardExit -Command $text -Tool Bash) -ne 2) { $text } })
        $allowed.Count | Should -Be 0 -Because "these were allowed: $(($allowed | ForEach-Object { ConvertTo-Json -Compress -InputObject $_ }) -join ', ')"
    }
}

Describe 'Native option rules: denied options and every prefix of them' {
    It 'blocks every prefix for <Shown>' -ForEach $script:PrefixRows {
        $allowed = @(foreach ($text in $Texts) { if ((Get-GuardExit -Command $text -Tool Bash) -ne 2) { $text } })
        $allowed.Count | Should -Be 0 -Because "these were allowed: $($allowed -join ', ')"
    }
}
