# Plain role files for anything else. Point your tool's instructions at the directory.
@{
    Name                   = 'generic'
    DisplayName            = 'Generic (plain files)'
    Kind                   = 'plain'
    Format                 = 'plain'
    UserDirectory          = '~/.guild/roles'
    ProjectDirectory       = '.guild/roles'
    FileName               = '{name}.md'
    SkillsUserDirectory    = '~/.guild/skills'
    SkillsProjectDirectory = '.guild/skills'
    Tools                  = @{ 'write' = @(); 'docs' = @(); 'read-only' = @() }
    ReadOnly               = 'Stated only.'
    DefaultModels          = @{}
    Detect                 = @{}
    Notes                  = 'Tell your tool: "Roles are in <directory>; to review, follow guild-reviewer.md."'
}
