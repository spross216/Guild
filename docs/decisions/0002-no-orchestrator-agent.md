# 0002: No orchestrator agent

**Date:** 2026-10-24
**Status:** Accepted

## Context

Many multi-agent setups put an orchestrator persona on top: an agent whose job is to read the request
and dispatch work to specialists. In the tools Guild targets, subagents can't start other subagents,
so the main session is already the only thing that can delegate.

## Decision

The main session leads. Routing lives in a skill (`deliver`) and in the routing block written into
each tool's always-read instructions file. Roles never delegate to each other.

## Alternatives considered

- **An orchestrator role.** It would be the main session with an extra prompt and one more file to
  keep in step with the routing rules, without adding any capability.
- **A workflow engine deciding the steps.** Worth it only for unattended runs; if those are needed,
  they belong in a script with fixed steps and checks, not in an agent choosing them.

## Consequences

- Routing reliability depends on the main session following its instructions, which is why the
  routing block sits in the file each tool always reads.
- Separation of duties comes from the roles' own rules and guards: the author is never the only
  approver, and high-risk work gets independent tests and review.
