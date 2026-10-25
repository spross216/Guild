# OpenCode agents. https://opencode.ai/docs/agents/
@{
    Name                   = 'opencode'
    DisplayName            = 'OpenCode'
    Kind                   = 'agents'
    Format                 = 'opencode'
    UserDirectory          = '~/.config/opencode/agents'
    ProjectDirectory       = '.opencode/agents'
    FileName               = '{name}.md'
    Tools                  = @{ 'write' = @(); 'docs' = @(); 'read-only' = @() }
    ReadOnly               = 'permission: edit denied; shell commands ask, except read-only git commands.'
    DefaultModels          = @{}
    Detect                 = @{ Command = 'opencode'; ProjectMarker = '.opencode' }
    Notes                  = 'Models use provider/model-id, e.g. anthropic/claude-sonnet-5-5.'
}
