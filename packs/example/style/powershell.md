# PowerShell style

PSScriptAnalyzer (the project's settings file) owns everything it checks. This covers the rest.

- Approved verbs, singular nouns unless the noun is a set on purpose.
- Advanced functions with `[CmdletBinding()]`; `SupportsShouldProcess` on anything that changes state.
- Parameters validated with attributes (`ValidateSet`, `ValidatePattern`) rather than code.
- Return objects, not formatted text. Format only at the edge.
- `$ErrorActionPreference = 'Stop'` in scripts; errors say what failed and which input caused it.
- Pester tests named for behavior: `It 'returns Invalid when the id is missing'`.
