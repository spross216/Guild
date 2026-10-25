## Guild tools

Deterministic helpers. When one fits, use it instead of doing the same steps by hand, so every task
starts and ends the same way. Load them with `Import-Module '{{guildmodule}}'`; if the module isn't
available, do the steps by hand and say so.

| Command | Use |
|---|---|
| `Get-GuildContext -Path <project>` | Start every task here: languages, standards sources, the check, git state, docs, diagrams, decision records, findings |
| `New-GuildBrief -Role <role> -Goal <goal> -Path <project>` | Write a hand-off with the standard sections (goal, standards, paths, constraints, done) |
| `New-GuildDecision -Path <project> -Title <title>` | Create the next numbered decision record |
| `Test-GuildDocs -Path <project>` | Find documentation and diagram drift; each finding names its owner |
| `Get-GuildRepoSurvey -Path <repository>` | A factual inventory of a repository (languages, tests, linting, CI, infrastructure, docs) |
| `Add-GuildFinding` / `Get-GuildFindingSummary` | Record review findings; see what keeps recurring |
| `New-GuildStandardsRepo` | Scaffold a local standards repository for a pack (steward, with the human's approval) |
