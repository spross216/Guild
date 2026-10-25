# 0002: PowerShell for automation, TypeScript for web UIs

**Date:** 2026-01-20
**Status:** Accepted

## Context

Most of Acme's automation runs on Windows and Azure; its web front ends already use TypeScript.

## Decision

New automation is PowerShell. New web UIs are TypeScript. Anything else needs a decision record.

## Alternatives considered

- **Python for automation** - a second runtime to support on every server.

## Consequences

One language per kind of work; fewer toolchains to maintain.
