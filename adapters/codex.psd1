# OpenAI Codex custom agents (TOML). https://learn.chatgpt.com/docs/agent-configuration/subagents
@{
    Name                   = 'codex'
    DisplayName            = 'OpenAI Codex'
    Kind                   = 'agents'
    Format                 = 'codex'
    UserDirectory          = '~/.codex/agents'
    ProjectDirectory       = '.codex/agents'
    FileName               = '{name}.toml'
    NameSeparator          = '_'
    # Codex reads AGENTS.md in the repository.
    RoutingProjectFile     = 'AGENTS.md'
    Tools                  = @{ 'write' = @(); 'docs' = @(); 'read-only' = @() }
    ReadOnly               = 'Stated only. A custom agent cannot narrow the sandbox; run the parent session read-only before delegating to a read-only role.'
    DefaultModels          = @{}
    Detect                 = @{ Command = 'codex'; ProjectMarker = '.codex' }
    Notes                  = 'Codex spawns subagents only when asked: "have guild_reviewer review this".'
}
