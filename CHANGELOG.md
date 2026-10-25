# Changelog

## 0.3.0

First public release.

- Four tool-neutral roles (architect, builder, reviewer, steward) and skills (`deliver`,
  `code-review`), installed for Claude Code, GitHub Copilot, OpenAI Codex, OpenCode, Antigravity,
  `AGENTS.md` and plain files.
- Data-only packs: standards sources, language choices, style guides, capabilities with fallbacks,
  extra roles and skills, role addenda, policy, review settings and models, layered and validated.
- Access levels `write`, `docs` (Markdown only) and `read-only`, with command and file-edit guards for
  Claude Code.
- Routing block in each tool's always-read instructions file; "Use proactively" descriptions for
  Claude Code.
- Commands for agents: `Get-GuildContext`, `New-GuildBrief`, `New-GuildDecision`, `Test-GuildDocs`,
  `Get-GuildRepoSurvey`, `New-GuildStandardsRepo`, `Add-GuildFinding`, `Get-GuildFindingSummary`.
- Safe installs: hashed manifest, never overwrites unowned or hand-edited files, removes what is no
  longer produced, `-WhatIf` throughout; `Test-GuildInstall` and `Uninstall-GuildAgents`.
- A complete example pack for a fictional company.
