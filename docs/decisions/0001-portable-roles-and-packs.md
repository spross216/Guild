# 0001: Portable roles, configured by data-only packs

**Date:** 2026-10-24
**Status:** Accepted

## Context

Agent roles tend to be written for one tool, one company and one way of building: role text names
specific commands, paths to a standards repository, and a single harness's file format. They then
can't move to another project, employer or tool without a rewrite. Two working styles also need
supporting: agents that write everything from prose standards, and agents that work alongside
scaffolding and checking tools.

## Decision

- Four tool-neutral roles (architect, builder, reviewer, steward) with no company, product or cloud
  names, enforced by a test.
- Everything specific comes from packs: PowerShell data files, loaded without running code, that
  layer from framework defaults through company to project.
- Roles ask for capabilities, not tools. Each capability has a fallback, so the roles work with no
  tooling at all; a pack binding a capability makes them use the tool instead.
- One data file per harness describes where files go and how read-only roles are enforced; header
  formats are a small set of writers. Native subagents where the harness has them, an instructions
  block where it doesn't.
- Reviews produce structured findings, logged per project, so recurring findings can be promoted
  into checks with the human's approval.
- No orchestrator agent; the main session leads with a delivery procedure shipped as a skill.

## Alternatives considered

- **One harness first, others later.** Locks the role text to that harness's assumptions.
- **JSON or YAML packs.** Readable by more languages, but `.psd1` gives comments and data-only
  loading in the language the installer is written in; the merged pack is also written as JSON.
- **An orchestrator persona.** Current harnesses don't let subagents delegate, so it would be the
  main session with extra prompt and another file to keep in step.

## Consequences

- Bare mode has weaker invariants: nothing deterministic enforces structure or coverage, so the
  reviewer and the human carry more. Recurring findings are the signal to add tooling.
- Instructions-mode harnesses get one agent playing every role, so review is less independent.
- Adapters must be checked against each harness's documentation as those tools change.
