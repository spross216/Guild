---
name: deliver
description: How the main session routes work across the Guild roles. Use at the start of any task that may change code, to decide whether to answer directly, design first, build, test independently or review.
---
# Delivering a change

The main session leads. There is no orchestrator agent; you decide who does what, and the human
grants authority.

## Route by decision impact and risk, not size

1. **A question** is answered directly. A question is not permission to change anything; a
   recommendation is an answer until the human asks for the change.
2. **A question about an existing design** is answered from the project's own architecture and
   decision records. Read them first; if they settle it, answer. If they are silent or
   contradictory, say so, and consult {{role:architect}} only if the uncertainty could lead to a
   wrong decision.
3. **More than one piece, or a change to an established design:** {{role:architect}} designs first.
4. **Substantial code:** {{role:builder}} writes it; {{role:reviewer}} reviews it. The one who
   writes is never the only one who approves.
5. **High risk, at any size** (see the high-risk list below): {{role:builder}} writes it, someone
   other than the author writes or runs independent tests (a second builder pass or the human),
   then {{role:reviewer}} reviews. The author's own tests don't count as independent.
6. **Routine, low-impact work** (a typo, a README line) is done directly. No ceremony.
7. **Documentation:** the builder updates the docs its change touches; {{role:steward}} keeps prose
   docs in sync (`Test-GuildDocs -Owner steward`); {{role:architect}} updates every Mermaid diagram a
   design change affects (`Test-GuildDocs -Owner architect`).
8. **Synthesizing standards** from named repositories or documents goes to {{role:steward}}. The result
   is drafts in a standards repository; only the human accepts a draft into a standard or creates the
   remote repository.

## Consistent steps

- Start each task with `Get-GuildContext -Path <project>`, and hand work to a role with
  `New-GuildBrief`, so every role starts from the same facts and the same sections.

## The review loop

{{review}}

- On `CHANGES_REQUIRED`, send the findings to {{role:builder}}, then back to {{role:reviewer}}.
- Record each review's JSON in the findings log. With Guild's PowerShell module:
  `Add-GuildFinding -Path <project> -Report <reviewer JSON>`. Otherwise append it to the log as
  one JSON line per finding.
- After the round limit with the same finding still open, stop and ask the human.

## Finishing

Report what was attempted, completed, verified (with the command) and failed. The human commits.

{{policy}}
