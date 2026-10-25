# Claude Code subagents. https://code.claude.com/docs/en/sub-agents
@{
    Name                   = 'claude'
    DisplayName            = 'Claude Code'
    Kind                   = 'agents'
    Format                 = 'claude'
    UserDirectory          = '~/.claude/agents'
    ProjectDirectory       = '.claude/agents'
    FileName               = '{name}.md'
    SkillsUserDirectory    = '~/.claude/skills'
    SkillsProjectDirectory = '.claude/skills'
    # Read at the start of every session: the routing block goes here.
    RoutingUserFile        = '~/.claude/CLAUDE.md'
    RoutingProjectFile     = 'CLAUDE.md'
    Tools                  = @{
        'write'     = @('Read', 'Grep', 'Glob', 'Edit', 'Write', 'Bash')
        'docs'      = @('Read', 'Grep', 'Glob', 'Edit', 'Write', 'Bash')
        'read-only' = @('Read', 'Grep', 'Glob', 'Bash')
    }
    ReadOnly               = 'Tool list without Edit/Write, plus a PreToolUse hook that blocks shell commands that change things.'
    DefaultModels          = @{ top = 'opus'; mid = 'sonnet' }
    Detect                 = @{ Command = 'claude'; ProjectMarker = '.claude' }
    Notes                  = 'Restart Claude Code once after the agents directory is first created.'
}
