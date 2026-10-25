BeforeAll {
    Import-Module (Join-Path $PSScriptRoot '../Guild/Guild.psd1') -Force
}

Describe 'Findings log' {
    BeforeEach {
        $script:Project = Join-Path $TestDrive "project-$([guid]::NewGuid().ToString('N').Substring(0, 8))"
        New-Item -ItemType Directory $Project | Out-Null
        $env:GUILD_HOME = Join-Path $TestDrive 'empty-home'
    }
    AfterEach { Remove-Item Env:GUILD_HOME -ErrorAction SilentlyContinue }

    It 'records the reviewer''s JSON from inside its prose' {
        $output = @'
Here is my review.

```json
{ "Verdict": "CHANGES_REQUIRED", "Role": "guild-reviewer",
  "Findings": [ { "Severity": "high", "Category": "idempotency", "Rule": "standards/principles.md#idempotency",
    "File": "src/job.ps1", "Line": 42, "Summary": "Redelivery creates a duplicate", "Fix": "Key on the message ID" } ] }
```

Summary: one blocking issue.
'@
        $result = Add-GuildFinding -Path $Project -Report $output -Model 'opus'
        $result.Findings | Should -Be 1
        $line = Get-Content (Join-Path $Project '.guild/findings.jsonl') | ConvertFrom-Json
        $line.verdict | Should -Be 'CHANGES_REQUIRED'
        $line.category | Should -Be 'idempotency'
        $line.model | Should -Be 'opus'
        $line.role | Should -Be 'guild-reviewer'
    }

    It 'records an approval with no findings as one line' {
        @{ verdict = 'APPROVE'; findings = @() } | Add-GuildFinding -Path $Project | Out-Null
        (Get-Content (Join-Path $Project '.guild/findings.jsonl')).Count | Should -Be 1
    }

    It 'rejects <Case>' -ForEach @(
        @{ Case = 'a bad verdict'; Report = @{ verdict = 'LGTM' }; Message = '*APPROVE or CHANGES_REQUIRED*' }
        @{ Case = 'a bad severity'; Report = @{ verdict = 'APPROVE'; findings = @(@{ severity = 'urgent'; category = 'security'; summary = 'x' }) }; Message = '*severity*' }
        @{ Case = 'an unknown category'; Report = @{ verdict = 'APPROVE'; findings = @(@{ severity = 'low'; category = 'vibes'; summary = 'x' }) }; Message = '*category must be one of*' }
        @{ Case = 'invalid JSON'; Report = '{ not json'; Message = '*not valid JSON*' }
    ) {
        { Add-GuildFinding -Path $Project -Report $Report } | Should -Throw -ExpectedMessage $Message
    }

    It 'flags a finding for promotion once it recurs' {
        $finding = @{ severity = 'medium'; category = 'error-handling'; rule = 'style/general.md#errors'; summary = 'Error hides the cause' }
        @{ verdict = 'CHANGES_REQUIRED'; findings = @($finding) } | Add-GuildFinding -Path $Project | Out-Null
        @{ verdict = 'CHANGES_REQUIRED'; findings = @(@{ severity = 'low'; category = 'docs'; summary = 'Typo' }) } | Add-GuildFinding -Path $Project | Out-Null
        (Get-GuildFindingSummary -Path $Project | Where-Object Promote) | Should -BeNullOrEmpty

        @{ verdict = 'CHANGES_REQUIRED'; findings = @($finding) } | Add-GuildFinding -Path $Project | Out-Null
        $promote = @(Get-GuildFindingSummary -Path $Project | Where-Object Promote)
        $promote | Should -HaveCount 1
        $promote[0].Rule | Should -Be 'style/general.md#errors'
        $promote[0].Count | Should -Be 2
    }

    It 'uses the installed pack''s log path and categories' {
        $packDir = Join-Path $TestDrive 'review-pack'
        New-Item -ItemType Directory $packDir -Force | Out-Null
        Set-Content "$packDir/r.pack.psd1" "@{ Name = 'r'; Version = '1.0.0'; Contract = '1'; Review = @{ FindingsLog = 'review/log.jsonl'; Categories = @('naming') } }"
        Install-GuildAgents -Harness generic -Scope Project -Path $Project -Pack "$packDir/r.pack.psd1" -InformationAction SilentlyContinue | Out-Null
        @{ verdict = 'CHANGES_REQUIRED'; findings = @(@{ severity = 'low'; category = 'naming'; summary = 'Unclear name' }) } | Add-GuildFinding -Path $Project | Out-Null
        Join-Path $Project 'review/log.jsonl' | Should -Exist
    }
}
