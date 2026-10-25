# GitHub Copilot custom agents (VS Code, Copilot CLI, cloud agent).
# https://docs.github.com/en/copilot/reference/custom-agents-configuration
@{
    Name                   = 'copilot'
    DisplayName            = 'GitHub Copilot'
    Kind                   = 'agents'
    Format                 = 'copilot'
    UserDirectory          = '~/.copilot/agents'
    ProjectDirectory       = '.github/agents'
    FileName               = '{name}.agent.md'
    SkillsUserDirectory    = '~/.copilot/skills'
    SkillsProjectDirectory = '.github/skills'
    # Repository-wide custom instructions, read by Copilot in the repository.
    RoutingProjectFile     = '.github/copilot-instructions.md'
    Tools                  = @{
        'write'     = @('read', 'search', 'edit', 'execute', 'todo')
        'docs'      = @('read', 'search', 'edit')
        'read-only' = @('read', 'search')
    }
    ReadOnly               = 'Tool list without edit or execute. Read-only roles cannot run commands; the main session runs checks for them. Docs roles get edit (Markdown only, stated in the role) but no execute.'
    DefaultModels          = @{}
    Detect                 = @{ Command = 'copilot'; ProjectMarker = '.github/agents' }
    Notes                  = 'User-level agents (~/.copilot/agents) win over repository agents with the same name.'
}
