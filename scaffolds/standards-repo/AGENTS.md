# Agent instructions

This is a standards repository for Guild. Read `README.md` and `standards/README.md` first.

- New material from synthesis goes in `drafts/` with `**Status:** Draft` and a `## Sources` section.
  Only a person moves a draft into `standards/` (status `Accepted`).
- Every standard cites its sources: the repositories or documents, and the surveys in `evidence/`. A
  practice seen in fewer than two sources is a convention, not a standard; say so.
- Describe what systems do separately from how a new system should get there.
- Never copy raw content from sources: no secrets, customer or tenant identifiers, incident details.
  Surveys hold facts only.
- A conflict with an accepted standard is flagged in the draft, never resolved by overwriting.
- The check is `./build.ps1`. Never commit, push or create the remote repository; the human does.
