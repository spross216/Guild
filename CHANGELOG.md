# Changelog

## 0.5.1

- The read-only command guard fails closed: PowerShell is parsed and checked against an allowlist of
  commands, parameters and syntax kept in `guards/Test-GuildReadOnlyCommand.psd1`; Bash is limited to
  a narrow subset; reads that print secret values are denied on a best-effort basis. Design in
  `docs/guard.md`, decision 0005.
- Claude Code read-only and docs roles get the PowerShell tool as well as Bash, with the guard hook on
  both (`Bash|PowerShell`, `onFailure: block`).
- `Test-GuildInstall` reports guard scripts and rule data (Kind `Guard`) and, for `claude`, the
  Claude Code version (Kind `Claude`; 2.1.295 or later).
- The first end-to-end trial is written up in `docs/evaluations/2026-10-first-trial.md`.

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
