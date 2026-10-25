# Any tool that reads AGENTS.md. Project scope only: role files plus a managed block in AGENTS.md.
@{
    Name                    = 'agents-md'
    DisplayName             = 'AGENTS.md (any tool)'
    Kind                    = 'instructions'
    Format                  = 'plain'
    ProjectDirectory        = '.guild/roles'
    FileName                = '{name}.md'
    InstructionsProjectFile = 'AGENTS.md'
    SkillsProjectDirectory  = '.guild/skills'
    Tools                   = @{ 'write' = @(); 'docs' = @(); 'read-only' = @() }
    ReadOnly                = 'Stated only. The main agent plays each role in turn.'
    DefaultModels           = @{}
    Detect                  = @{}
    Notes                   = 'Use when a tool has no native subagents but reads AGENTS.md.'
}
