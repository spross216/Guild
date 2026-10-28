## Guild tools

Deterministic helpers. When one fits, use it instead of doing the same steps by hand, so every task
starts and ends the same way. Load them with `Import-Module '{{guildmodule}}'`; if the module isn't
available, do the steps by hand and say so.

| Command | Available to | Use |
|---|---|---|
| `Get-GuildContext -Path <project>` | every role | Start every task here: languages, standards sources, the check, git state, docs, diagrams, decision records, findings |
| `New-GuildBrief -Role <role> -Goal <goal> -Path <project>` | every role | Write a hand-off with the standard sections (goal, standards, paths, constraints, done) |
| `New-GuildDecision -Path <project> -Title <title>` | write and docs roles | Create the next numbered decision record (a read-only role asks for one instead) |
| `Test-GuildDocs -Path <project>` | every role | Find documentation and diagram drift; each finding names its owner |
| `Get-GuildRepoSurvey -Path <repository>` | every role | A factual inventory of a repository (languages, tests, linting, CI, infrastructure, docs) |
| `Add-GuildFinding` | write roles and the main session | Record a review finding (a read-only role reports it in its answer, and the main session records it) |
| `Get-GuildFindingSummary` | every role | See what keeps recurring in the findings log |
| `New-GuildStandardsRepo` | write roles | Scaffold a local standards repository for a pack (steward, with the human's approval) |
