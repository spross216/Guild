# Security

## What the guards are

Guild's guards (`guards/`) are guardrails for AI agents, not a security boundary. The read-only command
guard blocks shell commands that change files, version control or cloud state, and the docs guard
allows edits to Markdown files only. Both run as Claude Code hooks; in other tools the same rules are
tool lists or instructions, as the README's tool table says. A determined process with the user's
credentials can still do anything the user can. Credentials and platform permissions remain the real
boundary.

## Reporting a problem

If you find a way for a guarded role to change something it shouldn't, or a way for installed files to
run code they shouldn't, please open a private security advisory on the repository rather than a public
issue. Include the command or input and what happened.
