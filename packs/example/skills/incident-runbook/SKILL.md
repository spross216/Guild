---
name: incident-runbook
description: Use when writing or updating an incident runbook for a service - what to check, in what order, and when to escalate.
---
# Incident runbook

1. Name the service, its owner and how to reach the on-call engineer.
2. List the symptoms someone will see, each with the first check to run (a health endpoint, a log
   query, a dashboard).
3. For each likely cause, give the read-only command that confirms it and the safe fix.
4. Say when to stop and escalate, and to whom.
5. Keep commands copy-pasteable and free of secrets.
