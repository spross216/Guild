# Framework defaults: the first layer under every pack. Only this file may use {guild}.
@{
    Name         = 'guild-defaults'
    Version      = '0.3.0'
    Contract     = '1'
    Prefix       = 'guild'
    Knowledge    = @()
    Style        = @(
        @{ Language = '*'; Guide = '{guild}/style/general.md' }
    )
    Capabilities = @{}
    RoleAddenda  = @{}
    Policy       = @{
        NeverInvent = @('credentials or secret values', 'names of resources you have not seen', 'APIs or options you have not verified')
        HighRisk    = @('deployment control', 'authentication', 'authorization', 'security boundaries', 'data integrity')
    }
    Review       = @{
        MaxRounds    = 3
        PromoteAfter = 2
        FindingsLog  = '.guild/findings.jsonl'
        Categories   = @('correctness', 'security', 'idempotency', 'error-handling', 'testing', 'style', 'docs', 'other')
    }
    Models       = @{}
}
