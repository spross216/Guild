# 0003: A docs access level, and who owns which documentation

**Date:** 2026-10-24
**Status:** Accepted

## Context

Documentation drifts from code, and architecture diagrams drift fastest. The architect was read-only,
so it could design but not keep diagrams current; if one role owned all documentation, the builder
would stop updating docs its own changes affect.

## Decision

- A third access level, `docs`: edit Markdown only. Enforced in Claude Code by a hook on file edits,
  asked per edit in OpenCode, given the edit tool without execute in Copilot, stated elsewhere.
- The architect has docs access and owns every Mermaid diagram; it also writes decision records.
- The steward keeps prose documentation in sync. The builder still updates the docs its change touches.
- `Test-GuildDocs` finds drift deterministically and tags each finding with its owner.

## Alternatives considered

- **Architect stays read-only and returns diagram changes.** Slower, and changes get dropped.
- **Full write access for the architect.** Lets design reach into code, weakening the separation
  between design and build.

## Consequences

- Diagrams are checked structurally (type, brackets, referenced files, staleness from git history),
  not rendered; rendering would need the Mermaid CLI.
- The Markdown-only rule is a hard guard only in Claude Code.
