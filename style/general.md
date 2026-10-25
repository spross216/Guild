# General style

Applies to every language unless a language guide or the project says otherwise.

- Match the surrounding code: naming, layout, comment density, error handling. Consistency beats
  your preference.
- Use the language's common conventions and its standard linter. Whatever the linter checks, the
  linter owns.
- Names say what something is or does. Avoid abbreviations the reader has to decode.
- Small functions with one job. Business logic separate from I/O and transport.
- Errors say what failed and what to do about it, without leaking secrets or internals.
- Comments explain why, not what. Delete commented-out code.
- No new dependency without a reason that outweighs its maintenance and security cost.
- Tests describe behavior in their names and cover the failure paths.
