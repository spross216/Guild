# Example pack: Acme

A complete pack for a fictional company, showing every kind of setting a pack can hold.

| File | Shows |
|---|---|
| `example.pack.psd1` | Knowledge sources, language policy, style guide, a bound capability, an extra role and skill, addenda, policy, review categories, models |
| `standards/` | The standards and decision records the pack points at (in real life, usually a separate repository) |
| `checks/AcmeChecks.psd1` | The module behind the `Check` capability |
| `roles/security.md` | A role Guild doesn't ship |
| `skills/incident-runbook/` | A skill installed alongside Guild's |
| `addenda/` | Company notes appended to the reviewer and to the main session's routing |

Try it without installing anything into your tools:

```powershell
Get-GuildPack -Pack ./packs/example/example.pack.psd1
Install-GuildAgents -Harness generic -Scope Project -Path $env:TEMP/acme-demo -Pack ./packs/example/example.pack.psd1 -WhatIf
```
