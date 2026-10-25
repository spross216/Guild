# 0004: Write routing into the files each tool always reads

**Date:** 2026-10-24
**Status:** Accepted

## Context

Installed agents are available in every session, but whether the main session delegates to them is
the model's judgement, based on each agent's description. Routing rules kept only in a skill are loaded
when the model decides they apply, which is not every time.

## Decision

For tools with subagents, the install writes a managed "Agent routing" block into the instructions file
the tool reads at the start of every session (`CLAUDE.md`, `.github/copilot-instructions.md`,
`AGENTS.md` for Codex). It maps topics to agents, from each role's `use-for` list, and tells the main
session to delegate every matching request. Claude Code descriptions also end with "Use proactively
for: ...". Managed blocks carry ids, so several can share one file; the rest of the file is never
touched, and uninstalling removes only the block.

## Alternatives considered

- **Descriptions only.** Delegation stays a guess for anything ambiguous.
- **A hook that forces delegation.** No tool exposes a reliable way to do that today.

## Consequences

- Delegation becomes a standing instruction rather than an inference; it is still an instruction,
  and `@agent` or `--agent` remain the way to force one.
- Tools whose always-read file isn't confirmed get no routing block until it is.
