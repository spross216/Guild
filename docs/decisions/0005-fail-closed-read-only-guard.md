# 0005: A fail-closed read-only guard: parse the command, then allow only what is listed

**Date:** 2026-10-26
**Status:** Accepted (2026-10-26)

## Context

Read-only and docs roles get the Bash and PowerShell tools behind one guard,
`guards/Test-GuildReadOnlyCommand.ps1`. It's a PreToolUse hook with the matcher `Bash|PowerShell`.
It reads `tool_input.command` from the hook JSON on stdin and exits 0 to allow or 2 to block.

Until now the guard has scanned the command text. It splits the text on separators, masks quoted
strings, and matches regular expressions for commands and verbs that change things. Two rounds of
independent testing found that this approach keeps leaking:

- **Round 1** found 7 high-severity bypasses: a single `&`, quoted command names, commands named by a
  variable, backtick substitution, a type held in a variable, `Invoke-ScriptAnalyzer -Fix`, and
  read-only commands that write through an option. The rewrite fixed all 7.
- **Round 2** found 22 new bypasses in the rewrite's own quote, escape and option parsing:
  - backslash-escaped quotes that hide a `;`
  - an apostrophe that hides a `$( )`
  - `"rm".exe`
  - member names built from strings: `.("Dele"+"te")()`
  - property assignment: `$f.IsReadOnly = $true`
  - parameter abbreviations: `-Fi` binds to `-Fix`
  - GNU long-option prefixes: `--out` means `--output`
  - global options whose value hides the real sub-command: `git --namespace status push`
  - commands after `do` and `else`
  - a recursion limit that allowed whatever was nested past it

Each fix adds another case to a hand-written approximation of two languages. A text scanner allows
whatever it doesn't recognise, so every gap in the approximation is a bypass. The human chose to
replace the approach rather than patch it a third time.

These facts were verified by reading the guard, its tests (`tests/Guard*.Tests.ps1`) and the two
independent suites. The design that follows from them is in [guard.md](../guard.md).

### Threat model

- **In scope:** *accidental* changes by a cooperative agent working in a read-only role. For example, a
  reviewer that reaches for `sed -i`, `git checkout`, `Invoke-ScriptAnalyzer -Fix` or a script that
  writes a file, without meaning to break the role's rules.
- **Out of scope:** defeating a deliberately evasive agent. That needs controls the agent can't reach,
  which belong to the operating system and the harness: endpoint protection, application control, a
  read-only file system or sandbox, and harness-managed permission settings. The guard is a guardrail,
  not a security boundary, and the docs say so.
- **Accepted gap:** some allowed commands run project code by design. These are `Invoke-Pester` (the
  project's tests), `Import-Module <path>` (the module's code), the pack's check command passed with
  `-Allow`, and `Invoke-ScriptAnalyzer -Settings <file>` (a settings file can name custom rule
  modules). If the project's code changes files when it runs, the guard doesn't stop it. The reviewer
  is expected to run them, and what they run is the code under review.

## Decision

1. **Fail closed.** The guard allows a command only when it fully understands it and every part is
   on an allowlist. Anything else is blocked:
   - a parse error
   - an unknown syntax node
   - an unknown command, parameter or option
   - an unknown hook tool
   - unreadable input
   - an internal error
2. **Choose the grammar by tool.** Use the hook input's `tool_name`: `PowerShell` gets the PowerShell
   grammar and `Bash` gets the Bash grammar. When `tool_name` is absent, the command must pass both
   grammars. Any other value is blocked.
3. **PowerShell commands are parsed by PowerShell's own parser** (`Parser.ParseInput`). The guard
   then walks the syntax tree with an allowlist of node types and shapes:
   - commands must be bareword names on the list
   - parameters must be listed and written in full; abbreviations are blocked
   - argument shapes are constrained, and script blocks are allowed only where a listed parameter
     takes one
   - property reads use constant names only
   - methods come from a short list
   - static members are listed by type
   - only plain, non-reserved variables may be assigned
   - property assignment is allowed only on a `New-PesterConfiguration` object built in the same
     command, for listed settings
4. **Bash commands use a deliberately narrow subset**, tokenised by a small, precisely specified
   grammar:
   - a listed command name
   - plain words, single-quoted strings, and double-quoted strings with nothing that expands
   - `|`, `&&` and `||`
   - redirection to `/dev/null` and `2>&1` only

   Everything else is blocked with a message telling the agent to use the PowerShell tool:
   - backslashes and backticks
   - `$`
   - `;`
   - a single `&`
   - other redirection
   - a quoted command name
   - globs at the start of a word
5. **Native command options use one rule set** for both grammars. Each listed native command has an
   option mode: any option, an allowlist, a denylist, or a dedicated handler:
   - **Denylists:** a long option is blocked when the text typed is a prefix of a denied option
     (GNU-style abbreviation).
   - **git:** an allowlist of global options (including their value-taking forms) and of
     sub-commands.
   - **kubectl:** allowlisted global options, then an allowlisted sub-command.
   - **gh and aws:** a fixed command position.
   - **az and gcloud:** a fixed path rule.
6. **Data-driven.** Commands, parameters, shapes, options, static members, methods and reserved
   variables live in `guards/Test-GuildReadOnlyCommand.psd1`, loaded with
   `Import-PowerShellDataFile`. Tests check the data against the installed commands' own metadata.
7. **`-Allow` keeps working for PowerShell command names** of the form `Verb-Noun`. An allowed
   command may take any named or positional argument whose value is a plain value: no script block,
   hashtable or splatting, and none of the common parameters that write variables. Built-in rules win
   over `-Allow` for names already in the data. Other `-Allow` entries are ignored.
8. **Project-declared safe commands are deferred.** A file inside the project would let the change
   under review widen its own reviewer's guard. If they're needed, they should come through a pack
   (human-controlled), in a later pack contract.
9. **Hook contract is unchanged:**
   - stdin JSON with `tool_input.command`
   - exit 0 to allow, or 2 to block with the reason on stderr
   - `-Command` and `-Allow` for direct runs

   A new optional `-Tool` parameter (`Bash` or `PowerShell`) sets the grammar for direct runs.

## Alternatives considered

- **Patch the text scanner again.** Two rounds show each fix opens new gaps. The scanner allows by
  default, so it can't be made to fail closed.
- **Rely on the harness's permission rules (allow and deny patterns) alone.** They are also pattern
  matches on text. They aren't portable across harnesses, and they can't see inside PowerShell script
  blocks or member calls. Packs and humans can still add them as an extra layer.
- **Remove the shell tools from read-only roles.** A reviewer must run tests, linters and `git log`.
  Without a shell, reviews depend on the author's own claims.
- **Run the agent's PowerShell in a constrained endpoint** (constrained language mode, or a restricted
  runspace). The hook can't change how the harness runs a tool. Constrained language mode also still
  allows `Remove-Item`.
- **A full Bash parser.** None is available in PowerShell without a dependency, and a faithful one
  would still need an allowlist on top. A narrow subset that blocks everything else is smaller and
  easier to test. The PowerShell tool is there for anything richer.
- **Allowlist every option of every native command.** This is fail-closed, but `git log` alone has
  hundreds of options, and false positives would push agents towards workarounds. Allowlists are used
  where they are small: `sort`, `uniq`, `find`, `git branch`, `git tag`, the global options of git
  and kubectl, and sub-commands. Denylists with the prefix rule are used where a command's write and
  run options are few and documented.
- **A file of safe commands inside the project.** This was deferred, for the reason given in item 8
  of the decision.

## Consequences

- **The guard blocks more legitimate commands.**
  - Through the Bash tool these are blocked: PowerShell syntax, `"cat" README.md`, `echo` and
    `echo $(...)`, `wc -l $(git ls-files)`, a double-quoted pattern containing `\` or `$` (single
    quotes work), and `gcloud ... describe NAME`.
  - Through the PowerShell tool these are blocked: `git blame -L 1,10` (an unquoted array), static
    calls on unlisted types, and `try`, `switch` and `while`.

  Messages say what to do instead. [guard.md](../guard.md) lists every changed verdict.
- **Tests must say which tool sent each case.** The repository harness gains a `-Tool` parameter, and
  every block case is asserted under `Bash`, `PowerShell` and an absent `tool_name`. The independent
  suites outside the repository send `tool_name = 'Bash'` for PowerShell-syntax cases. Their allow
  cases written in PowerShell syntax need re-pointing to `PowerShell`; the human decides whether to
  adopt that.
- **Someone has to maintain the data file.** Adding a command means listing its parameters or options
  and checking its documentation for options that write files or run programs. Metadata tests catch
  some mistakes in PowerShell entries; native entries rely on review.
- **The `-Allow` change affects existing packs.** A check command that isn't a PowerShell `Verb-Noun`
  name (a build tool, a script path) is no longer allowed. Most of these were already blocked by the
  old verb and tool scan.
- **The guard's prose in `docs/spec.md` and `README.md` needs rewriting** once this is built. The
  steward does that.
- **The guard's stated limits stay.** It is a guardrail for cooperative agents. Stronger isolation is
  the operating system's and the harness's job.

## Implementation notes (2026-10-26)

Added after acceptance, with the human's approval. The decision and the status above are unchanged.
The design is in [guard.md](../guard.md).

- **Hook wiring.** Read-only and docs roles get the PreToolUse hook with the matcher `Bash|PowerShell`.
  Each guard hook has `timeout: 30` and `onFailure: block`, so a hook that can't start, exits with a code
  other than 0 or 2, or times out blocks the command. `onFailure` needs Claude Code 2.1.295 or later. A
  `|| exit 2` shell wrapper was rejected: Git Bash and Windows PowerShell 5.1 treat it differently. That
  `onFailure` works in a subagent's frontmatter is inferred from the hooks reference, not confirmed in a
  live session.
- **Module links removed.** Guild no longer links itself into the user's module directory. That folder is
  synced by a cloud-sync client, and the sync behaviour of links there was not verified. Generated agents load the
  module with an absolute `Import-Module '<path>'` line instead.
- **Secret reads are best-effort (human decision, 2026-10-26).** The guard denies reads that print secret
  values, but only the forms it names. Denied: cloud reads that print secrets (for example
  `az keyvault secret show`, `aws secretsmanager get-secret-value`, `az apim subscription show`); aws reads
  that print environment variables (lambda and ecs: `lambda get-function-configuration`, `get-function`,
  `list-functions`, `list-versions-by-function`; `ecs describe-task-definition` and `describe-tasks`; and
  `batch describe-job-definitions`, `elasticbeanstalk describe-configuration-settings`, `apprunner
  describe-service`), which embed environment variables that often hold secrets; kubectl
  reads of secrets with any output other than `name` or `wide`; local credential files (for example
  `~/.aws`, `~/.ssh`, `.env` other than the example files); and environment dumps and secret-named
  environment variables. Left out on purpose: `*.pem`, `*.key` and `*.pfx` files, shell history, browser
  stores, Terraform state and `appsettings*.json`, for the reasons in `guards/Test-GuildReadOnlyCommand.psd1`.
  These denies do not make the guard a security boundary, and the threat model above still applies.
- **Variables and the environment (round 5).** Assignment is allowed only to variables whose names start
  with a lowercase letter, and aren't reserved. The reserved names are matched case-insensitively. The guard
  can't list every engine variable, so the lowercase-first rule is the backstop. Secret-named environment
  variables follow one allowlist: after `env:`, `Environment::` or `Microsoft.PowerShell.Core\Environment::` and
  one optional separator, exactly one plain, non-secret name may follow. `SecretNamePattern` adds cookie, session,
  authorization, and PAT, AUTH and URL as whole words. A `:` counts as a path separator for credential files.
  Old DOS short-form names (`NAME~1`) are refused where they follow a separator, and as bare words when the
  stem contains `-`, `_` or a digit or is a known credentials stem. Plain-letter revisions such as `HEAD~1`
  stay allowed. The rule is a known false-positive cost, documented in the guard's design (§4.14, §8.3).
- **Install check (round 6).** `Test-GuildInstall` reports a Kind `Claude` row for the `claude` harness: Current
  from Claude Code 2.1.295 (where `onFailure: block` was added), Outdated below it, Unknown when `claude` isn't
  on the PATH.
- **Wildcard limit (round 6, narrowed in round 7).** A wildcard is judged against a fixed probe list. Listing
  commands may use `*.json`, which lists `local.settings.json` as a name; reading commands can't (`Get-Content
  *.json` and `cat docs/*.json` block). A no-literal wildcard can open an unnamed folder, which the guard doesn't
  judge. These are accepted limits of the guardrail, recorded for review.
- **Minimum host (round 6).** The guard assumes PowerShell 7.3 or later argument passing for native commands;
  syntax-tree properties that only newer hosts have are read through an existence check.
- **Search patterns and listings (round 8).** A search pattern only matches text, so the credential-name and
  wildcard checks skip it (`rg`, `grep`, `git grep`, `Select-String -Pattern`, the `find` pattern options, the jq
  filter). Paths given as `--file`, `--ignore-file` or `--option=value` values are still checked. A listing fed to
  a reader is judged as a reader when the reader has no literal path; the scan searches nested script blocks, so a
  reader inside a script block counts too. Listings kept in a variable are an accepted gap.
- **Recursive searches (human decision, 2026-10-27).** `grep -rn` and `rg -uu` over a parent folder can print
  matching lines from local secret files such as `local.settings.json` or `.env`. Blocking recursive `grep` and
  `rg` would cripple review, so this is an accepted gap. The OS controls are the real boundary, and the guard is a
  guardrail, not a security boundary.
- **Attached short values (B-1, fixed).** `-f.env` and `-fid_rsa` in `rg` and `grep` are read as `-f` with that
  value, which is path-checked. PowerShell splits `-ffile.txt` at the dot, so PowerShell callers write `-f file.txt`.
- **Live check passed (2026-10-27).** `onFailure: block` confirmed in subagent frontmatter: a hook that can't
  start, exits 1 or times out blocks both tools (Claude Code 2.1.310). The eight-step check is recorded in guard.md §11.
- **Open, pending a human decision.** Built-string evasion (a command assembled at run time from pieces) is
  out of scope for a text rule. Other aws services that return environment variables may exist and are not
  listed. `codebuild batch-get-projects` is blocked today by the operation-name rule, not by the environment
  rule.
