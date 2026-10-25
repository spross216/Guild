# A worked example: the pack a fictional company, Acme, would keep in its own repository.
# Copy it, rename it, and point it at your own standards. Paths are relative to this file, or use
# {pack} and {env:NAME}; absolute paths are rejected so the pack works on any machine.
@{
    Name         = 'example'
    Version      = '1.0.0'
    Contract     = '1'
    Description  = 'Acme engineering standards: knowledge sources, a check, a security role, an incident skill.'
    Prefix       = 'acme'

    # Standards sources, highest precedence first. Kinds: decisions, standards, patterns, skills.
    Knowledge    = @(
        @{ Name = 'decisions'; Kind = 'decisions'; Path = 'standards/decisions' }
        @{ Name = 'engineering'; Kind = 'standards'; Path = 'standards/engineering.md' }
    )
    AdrTemplate  = 'standards/decisions/0001-record-decisions.md'

    Languages    = @{
        Default    = 'powershell'
        ByWorkload = @{ 'automation' = 'powershell'; 'web-ui' = 'typescript' }
        Rationale  = 'standards/decisions/0002-languages.md'
    }

    Style        = @(
        @{ Language = 'powershell'; Guide = 'style/powershell.md'; Linter = 'PSScriptAnalyzerSettings.psd1' }
    )

    # A capability bound to a real command: every role verifies with it, and read-only roles may run it.
    Capabilities = @{
        Check = @{
            Command = 'Test-AcmeProject -Path <project>'
            Module  = 'checks/AcmeChecks.psd1'
            Notes   = 'It runs the project''s own tests and Acme''s repository rules.'
        }
    }

    # A role Guild doesn't ship, and a skill for it.
    Roles        = @('roles/security.md')
    Skills       = @(@{ Path = 'skills'; Root = '.' })

    RoleAddenda  = @{
        reviewer = 'addenda/reviewer.md'
        deliver  = 'addenda/deliver.md'
    }

    Policy       = @{
        NeverInvent = @('cloud resource names', 'schedules', 'secret names')
        HighRisk    = @('payment flows')
    }

    Review       = @{ Categories = @('performance') }

    Models       = @{
        claude = @{ Tiers = @{ top = 'opus'; mid = 'sonnet' }; Roles = @{ security = 'opus' } }
    }
}
