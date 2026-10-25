<#
.SYNOPSIS
    File-edit guard for Guild's docs roles. A Claude Code PreToolUse hook on Edit, Write and
    MultiEdit: reads the hook JSON from stdin, exits 0 to allow an edit to a Markdown file and 2 to
    block anything else (stderr goes to the agent).

.DESCRIPTION
    A docs role (the architect) may change documentation, diagrams and decision records, never code
    or configuration. A guardrail, not a security boundary. Run with -Path to test a path directly.
#>
[CmdletBinding()]
param([string] $Path)

$ErrorActionPreference = 'Stop'

if (-not $PSBoundParameters.ContainsKey('Path')) {
    try {
        $hookInput = [Console]::In.ReadToEnd() | ConvertFrom-Json
        $Path = [string]$hookInput.tool_input.file_path
        if (-not $Path) { $Path = [string]$hookInput.tool_input.notebook_path }
    }
    catch {
        [Console]::Error.WriteLine('Docs guard: could not read the hook input, so the edit is blocked.')
        exit 2
    }
}

if ($Path -match '(?i)\.(md|markdown|mmd)$') { exit 0 }
[Console]::Error.WriteLine("Docs role: '$Path' is not a Markdown file. You change documentation, diagrams and decision records only; hand code and configuration changes to the builder.")
exit 2
