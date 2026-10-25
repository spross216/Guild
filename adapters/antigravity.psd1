# Google Antigravity CLI (replaced Gemini CLI on 2026-06-18). Instructions mode: role files plus a
# managed block in AGENTS.md (project) or ~/.gemini/GEMINI.md (user), both documented context files.
# Native subagents (.agents/agents) need an explicit tool list whose write-tool names aren't
# documented yet; switch Kind to 'agents' once they are.
# https://antigravity.google/docs/cli/gcli-migration, https://antigravity.google/docs/subagents
@{
    Name                    = 'antigravity'
    DisplayName             = 'Antigravity CLI'
    Kind                    = 'instructions'
    Format                  = 'plain'
    UserDirectory           = '~/.guild/roles'
    ProjectDirectory        = '.guild/roles'
    FileName                = '{name}.md'
    InstructionsUserFile    = '~/.gemini/GEMINI.md'
    InstructionsProjectFile = 'AGENTS.md'
    SkillsUserDirectory     = '~/.gemini/antigravity-cli/skills'
    SkillsProjectDirectory  = '.agents/skills'
    Tools                   = @{ 'write' = @(); 'docs' = @(); 'read-only' = @() }
    ReadOnly                = 'Stated only. The main agent plays each role in turn.'
    DefaultModels           = @{}
    Detect                  = @{ Command = 'agy', 'antigravity'; ProjectMarker = '.agents' }
    Notes                   = 'Instructions mode: one agent plays the roles in turn, so review is less independent.'
}
