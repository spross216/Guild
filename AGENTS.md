# Agent instructions

Guild is a framework of portable agent roles. Read `README.md` first, then `docs/spec.md`.

The principle: **AI interprets ambiguity; software enforces invariants; humans grant authority.**
Never commit, push or publish on the human's behalf.

## Changing Guild

- The check is `./build.ps1`. It must pass with no PSScriptAnalyzer findings and no skipped tests.
- Guild stays neutral: no company, product or cloud names in roles, core rules, capabilities,
  skills, adapters, packs, the module or the docs. A test enforces this. Company and tool details
  belong in packs that live elsewhere.
- Roles are tool-neutral markdown (frontmatter: name, description, access, tier). Harness-specific
  headers belong in `Guild/Private/Adapters.ps1` (a new format) or `adapters/` (a new harness).
  Rendered bodies must stay identical across harnesses.
- Check a harness's current documentation before adding or changing its adapter, and cite it at the
  top of the adapter file. Don't write a format from memory.
- Keep each role around a page. When a rule becomes a check, remove it from the role.
- Roles name capabilities and knowledge kinds, never tools. Every capability needs a `.tool.md` and
  a `.none.md` snippet.
- A pack contract change bumps `Contract` support in `Guild/Private/Pack.ps1` and is recorded in
  `docs/decisions/`.
- Bump `ModuleVersion` in `Guild/Guild.psd1` when generated output changes.
