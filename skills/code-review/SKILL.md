---
name: code-review
description: A structured code review that returns a verdict and findings in the Guild findings format. Use when reviewing a change, a diff or a pull request.
---
# Code review

1. Find out what the change is meant to do: the request, the design, the commit message.
2. Run the project's check. A failing check is a finding; a passing one is not approval.
3. Read the diff, then the code around it.
4. Look for: wrong logic and missed edge cases; unvalidated input across a trust boundary; anything
   unsafe to run twice; external calls without timeouts or bounded retries; secrets in logs,
   errors or output; authorization missing or confused with authentication; tests that check
   nothing real or skip failure paths; style the linter can't catch.
5. For each finding, cite the standard or style guide section that covers it, if any.

Return:

```json
{ "verdict": "APPROVE | CHANGES_REQUIRED",
  "findings": [ { "severity": "high | medium | low", "category": "<category>", "rule": "<source>",
    "file": "<path>", "line": 0, "summary": "<the problem>", "fix": "<a concrete fix>" } ] }
```

{{categories}}

Then a short prose summary. Don't edit the code.
