# Contributing

Thanks for helping. A few rules keep Guild portable and safe.

## The check

`./build.ps1` lints with PSScriptAnalyzer and runs the Pester tests. It must pass with no findings and
no skipped tests, on Windows and Linux (CI runs both).

## Rules

- **Stay neutral.** No company, product or cloud names in roles, core rules, capabilities, skills,
  adapters, the module or the docs; a test enforces it. Company specifics belong in packs.
- **Roles are tool-neutral Markdown** (frontmatter: `name`, `description`, `use-for`, `access`, `tier`).
  Tool-specific headers belong in an adapter (`adapters/*.psd1`) or a header writer in
  `Guild/Private/Adapters.ps1`. Rendered bodies stay identical across tools.
- **Adapters cite documentation.** When adding or changing one, check the tool's current docs and cite
  them at the top of the adapter file. Don't write a format from memory.
- **Every capability has two snippets**, `capabilities/<name>.tool.md` and `<name>.none.md`.
- **Keep roles around a page.** When a rule becomes a check, take it out of the role.
- **Decisions** that are hard to reverse get a record in `docs/decisions/`.

## Adding a tool

1. Add `adapters/<name>.psd1` (where files go, header format, how read-only is enforced, detection).
2. If no existing header format fits, add one to `New-GuildRoleFile`.
3. Add install tests, and a row to the README's tool table.
