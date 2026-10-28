# Claude Code subagents. https://code.claude.com/docs/en/sub-agents
# Checked against the Claude Code documentation on 2026-10-26:
# - 'PowerShell' is the exact tool name for a subagent's `tools:` list and for hook matchers
#   (https://code.claude.com/docs/en/tools-reference.md). The tool is still labelled preview.
# - A PreToolUse hook receives the command at tool_input.command for both Bash and PowerShell, with the
#   same fields (https://code.claude.com/docs/en/hooks.md). The docs recommend the matcher
#   'Bash|PowerShell' for hooks that inspect shell commands. Exit code 2 blocks the call and sends
#   stderr to the agent.
# - Hooks in a subagent's frontmatter use the same format as hooks in settings
#   (https://code.claude.com/docs/en/sub-agents.md).
# - By default a hook that can't start, exits with any code other than 0 or 2, or times out does NOT block:
#   the tool runs. A command hook can set `onFailure: block` (Claude Code v2.1.295 or later) so those cases
#   block. Every guard hook sets it, with an explicit `timeout` (seconds; the default is 600). The docs don't
#   spell out `onFailure` in a subagent's frontmatter; it is taken from "same format as settings hooks".
#   https://code.claude.com/docs/en/hooks.md, checked 2026-10-26. Test-GuildInstall reports a guard script
#   that no longer exists. A `|| exit 2` shell wrapper is deliberately not used: Git Bash and Windows
#   PowerShell 5.1 treat it differently, and on Windows the hook command runs in Git Bash by default.
# Bash on Windows is Git Bash, where Guild's and a pack's PowerShell commands are not commands, so the
# docs and read-only roles also get the PowerShell tool, covered by the same guard.
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
        'docs'      = @('Read', 'Grep', 'Glob', 'Edit', 'Write', 'Bash', 'PowerShell')
        'read-only' = @('Read', 'Grep', 'Glob', 'Bash', 'PowerShell')
    }
    ReadOnly               = 'Tool list without Edit/Write, plus a PreToolUse hook on Bash and PowerShell that blocks commands that change things.'
    DefaultModels          = @{ top = 'opus'; mid = 'sonnet' }
    Detect                 = @{ Command = 'claude'; ProjectMarker = '.claude' }
    Notes                  = 'Restart Claude Code once after the agents directory is first created.'
}
