# Guild specification

**Contract:** 1. **Status:** Draft; the parts marked *later* are not built.

## Goals

- Agent roles, skills and guards that work in any agent harness and at any employer.
- Useful with nothing but a model writing code. Better with company standards. Better again with
  tooling.
- No company content in the framework. Companies, teams and projects plug in through packs.
- AI interprets ambiguity; software enforces invariants; humans grant authority. Agents never
  commit, merge, deploy or approve on the human's behalf.

**Not goals:** a hosted service, an orchestrator persona, a standards library. Guild points at
standards; it doesn't hold them.

## Three ways to run

| Mode | Installed | Who enforces invariants |
|---|---|---|
| **Bare** | Guild only | The project's own tests and linter, the reviewer, the human |
| **Standards** | + a company pack | Same, grounded in the company's standards and decisions |
| **Tooling** | + a tooling pack | Templates and checks for the repeated work; agents handle judgement |

The same role sources are used in all three. Only the rendered text differs.

## Roles

| Role | Job | Access | Tier |
|---|---|---|---|
| **architect** | Designs (pieces, connections, identities, ownership, open questions); owns every Mermaid diagram in project docs; writes decision records | Docs | top |
| **builder** | Writes code and tests, test-first, using Scaffold when bound; updates docs its change touches | Write | mid |
| **reviewer** | Independent review (APPROVE / CHANGES_REQUIRED) and debugging | Read-only | top |
| **steward** | Keeps standards and checks; keeps prose docs in sync; synthesizes draft standards from named repositories into standards repositories | Write | mid |

Access levels: **write** (code and docs), **docs** (Markdown only: enforced in Claude Code by a hook on
file edits, asked per edit in OpenCode, stated elsewhere; shell limited like read-only), **read-only**
(no edits; shell guarded).

## Commands for agents

Deterministic steps the roles use (each role file includes the table and the import line):
`Get-GuildContext`, `New-GuildBrief`, `New-GuildDecision`, `Test-GuildDocs`, `Get-GuildRepoSurvey`,
`New-GuildStandardsRepo`, `Add-GuildFinding`, `Get-GuildFindingSummary`. The read-only ones are always
on the guard's allow list; `New-GuildDecision` is allowed for docs roles.

### Synthesized standards

`New-GuildStandardsRepo` creates `standards/` (accepted, the only folder the pack loads), `drafts/`
(synthesized, `**Status:** Draft`, with `## Sources`), `evidence/` (surveys, facts only),
`docs/provenance.md`, `decisions/`, and a consistency test. A draft becomes a standard only when a
person accepts it. The steward never creates the remote repository, commits or pushes.

- Source frontmatter: `name`, `description`, `access` (write, docs, read-only), `tier`, and optional
  `use-for` (comma-separated topics that always go to this role). Nothing harness-specific.
- Routing: for `agents` harnesses with a `RoutingUserFile` or `RoutingProjectFile`, the install writes
  a `guild-routing` block (topics from `use-for`, delegation and risk rules) into that always-read file.
  Instructions-mode harnesses get the `guild` block instead. Both block kinds can share one file.
- Installed name: `<Prefix><separator><role>`. The pack sets `Prefix` (default `guild`); the
  adapter sets the separator (`-`, or `_` for Codex).
- Roles name capabilities and knowledge kinds, never tools, companies or clouds.
- Every role gets `core/rules.md` appended, and the pack's addendum for that role if it has one.

### Tokens

| Token | Becomes |
|---|---|
| `{{knowledge}}` | A table of the pack's standards sources, or the fallback (use the project's own docs) |
| `{{style}}` | The style guides for the project's languages plus general ones, with linter configs |
| `{{languages}}` | The language policy, or the fallback (recommend one, say it's judgement) |
| `{{policy}}` | The never-invent and high-risk lists |
| `{{review}}` | Round limit, findings log path, promotion threshold |
| `{{categories}}` | The finding categories |
| `{{adr}}` | The decision record format to use |
| `{{role:<id>}}` | The installed name of a role |
| `{{capability:<Name>}}` | The bound or fallback snippet for a capability |

An unknown token fails the install.

## Packs

A `.psd1` read with `Import-PowerShellDataFile`: data only, no code runs. Holds pointers and
settings, never copied standards text.

### Layering

Framework defaults (`Guild/defaults.pack.psd1`), then each pack given, each preceded by what it
`Extends`. Later wins.

- Scalars: replaced.
- Hashtables: merged by key, recursively.
- Lists (`Knowledge`, `Style`, `Roles`, `Skills`, `Policy.NeverInvent`, `Policy.HighRisk`, `Review.Categories`):
  accumulated, later pack first, duplicates dropped, so they read in precedence order.

`Extends` entries are a path ending in `.psd1` (relative to the extending pack) or a pack name,
found as `<name>.pack.psd1` or `<name>/<name>.pack.psd1` next to the extending pack or in a
directory on `$env:GUILD_PACK_PATH`. Cycles fail.

The merged result is written to `.guild/pack.json` in the scope root on install, for tools that
can't read `.psd1` and for the findings commands.

### Paths

Relative to the pack file, or with `{pack}` and `{env:NAME}`. Absolute paths fail, so a pack works
on any machine. A path that doesn't exist fails, naming the key. `Style[].Linter` is a path inside
the target project and is cited, not resolved. In a project install, paths inside the project are
written relative to it so the generated files can be committed.

### Keys

| Key | Type | Purpose |
|---|---|---|
| `Name`, `Version`, `Contract` | string | Required. `Contract` must be one Guild supports (`1`) |
| `Description` | string | Free text |
| `Extends` | string[] | Packs applied before this one |
| `Prefix` | string | Role name prefix: lowercase letters and digits |
| `Knowledge` | hashtable[] | `Name`, `Kind` (`decisions`, `standards`, `patterns`, `skills`), `Path` |
| `AdrTemplate` | string | Decision record format for the architect |
| `Languages` | hashtable | `Default`, `ByWorkload` (workload = language), `Rationale` (path) |
| `Style` | hashtable[] | `Language` (or `*`), `Guide` (path), optional `Linter` |
| `Capabilities` | hashtable | Capability = `@{ Command = string or string[]; Module; Notes }` |
| `Roles` | string[] | Role files to add to the roster (same frontmatter as Guild's roles; names must be new). Lists accumulate across packs. |
| `Skills` | hashtable[] | `Path` (a skill directory, or a directory of them) and optional `Root` (what the skill's relative paths are relative to). A pack skill replaces a Guild skill of the same name; the highest-precedence pack wins. Pack skills are installed as written, with a note naming `Root`; skills without frontmatter get a description from their first plain paragraph. |
| `RoleAddenda` | hashtable | Role = path of markdown appended to that role. `deliver` appends to the main session's delivery procedure (the `deliver` skill and the instructions block). Keys are checked against the merged roster. |
| `Policy` | hashtable | `NeverInvent`, `HighRisk` (string lists) |
| `Review` | hashtable | `MaxRounds`, `PromoteAfter` (whole numbers, at least 1), `FindingsLog` (project-relative), `Categories` |
| `Models` | hashtable | Harness = `@{ Tiers = @{ top; mid }; Roles = @{ <role> = model } }` |

Unknown keys at any level fail, naming the file and key.

## Capabilities

| Capability | Bound | Unbound fallback |
|---|---|---|
| **Scaffold** | Render a project from a template | Builder writes the structure from the standards and style guide |
| **Describe** | List templates and their questions | Architect asks the human |
| **Check** | One command: lint, tests, coverage | The project's own test and lint commands; if none, say nothing verified it |
| **Diagnose** | Logs, health, deploy status | Read-only inspection and local reproduction |
| **Update** | Merge a newer template into a project | A reviewed manual change |
| **Infra** | Write the infrastructure entry | Infrastructure as code from the platform standards |
| **Promote** | Add a build check or template change | Propose a linter rule or test for the human |

Each has `capabilities/<name>.tool.md` and `<name>.none.md`. A bound snippet also tells the agent
to fall back if the command isn't available. Commands bound to Describe, Diagnose and Check are
added to the read-only guard's allow list.

## Languages and style

- Language choices are decisions the architect uses for new pieces.
- Style guides are what the builder writes to and the reviewer checks against. A project install
  includes guides whose `Language` matches the project's files, plus every `*` guide; a user install
  includes all of them.
- The linter owns whatever it can check. Guides cover what needs judgement.

## Review loop

- **Fix loop:** reviewer, then builder for fixes, then reviewer again. After `MaxRounds` with the same
  finding open, the human decides.
- **Findings:** the reviewer returns JSON: `verdict`, and `findings` with `severity` (high, medium,
  low), `category`, `rule` (the standard or guide section, when one applies), `file`, `line`,
  `summary`, `fix`.
- **Log:** the reviewer is read-only, so the session records the report with `Add-GuildFinding`
  (or appends it by hand): one JSON line per finding, with time, verdict, role and model.
- **Promotion:** `Get-GuildFindingSummary` groups by category and rule and flags groups that reach
  `PromoteAfter`. The steward proposes, in order: a check, a template change, a style guide entry,
  role text. The human approves each.

## Delivery

No orchestrator agent. Subagents in current harnesses can't delegate further, so an orchestrator
would be the main session with extra prompt. The `deliver` skill holds the routing: answer
questions directly; design first for more than one piece; the author is never the only reviewer;
risk, not size, decides (anything on `Policy.HighRisk` gets independent tests and review). If
unattended multi-step runs are needed, they belong in a workflow script with fixed steps, not an
agent choosing them.

## Adapters

One data file per harness in `adapters/`, citing the documentation it follows.

| Key | Meaning |
|---|---|
| `Kind` | `agents` (native agent files), `instructions` (role files plus a managed block in an instructions file), `plain` (role files only) |
| `Format` | Header writer: `claude`, `copilot`, `codex`, `opencode`, `plain` |
| `UserDirectory`, `ProjectDirectory`, `FileName` | Where role files go (`~` is the home directory) |
| `SkillsUserDirectory`, `SkillsProjectDirectory` | Where skills go, if the harness has them |
| `InstructionsUserFile`, `InstructionsProjectFile` | For `instructions` mode |
| `RoutingUserFile`, `RoutingProjectFile` | The always-read file that gets the routing block, for `agents` mode |
| `NameSeparator` | Between prefix and role (default `-`) |
| `Tools` | Tool list per access level, for formats that take one |
| `ReadOnly` | How read-only roles are enforced, in words |
| `DefaultModels` | Model per tier when no pack sets one |
| `Detect` | `Command` (user scope) and `ProjectMarker` (project scope) for `-Harness auto` |

Generated files carry a `managed-by: guild` marker. The manifest (`.guild/manifest.json` in the
home directory or project) records each file's hash, source and the harnesses using it. Guild never
overwrites a file it didn't write, won't replace a hand-edited one without `-Force`, removes files no
longer produced, and keeps shared files until no harness uses them. `$env:GUILD_HOME` replaces the
home directory for user scope (tests, sandboxes).

## Models

Model choice is pack data; roles never name a model. For a role in a harness: `-Model` by role, then
`-Model` by tier, then the pack's `Models.<harness>.Roles`, then `Tiers`, then the adapter's
`DefaultModels`, else the harness's own default.

### Benchmarking (later)

Goal: per harness, the cheapest model that does each role well enough, from evidence.

- Suites in `bench/<role>/<case>/`: a fixture repository, a brief, the expected outcome. New cases
  come from the findings log.
- Deterministic graders first: reviewer verdict and seeded defects found, no false
  CHANGES_REQUIRED, stayed read-only; builder's check passes and nothing out of scope changed;
  architect asked the required questions and invented no names. A model-graded rubric only for the
  rest, graded by a different model than the one under test.
- Safety violations fail a case outright: writing in a read-only role, committing, inventing a
  name, following instructions found in data.
- Each case runs several times per harness and model, headless through the harness's CLI. Recorded:
  pass rate, violations, tokens, cost, time.
- Output: a report recommending the cheapest model above the threshold per role. The human copies
  it into `Models`; nothing updates a pack automatically.

## Acceptance

1. With no pack, every adapter installs working roles with fallbacks.
2. With a company pack only, roles cite its sources and guides; no capability is bound.
3. With a tooling pack, the same sources produce text naming its commands.
4. No shipped file names a company, product or cloud provider.
5. Invalid packs fail naming the key.
6. Rendered bodies are identical across adapters, apart from the name separator.
7. The guard blocks changing commands from read-only roles.

All seven are covered by `tests/`.
