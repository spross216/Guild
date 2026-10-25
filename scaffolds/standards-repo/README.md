# __Name__

__Description__

Engineering standards for Guild agents, synthesized from evidence and accepted by a person. A Guild
pack in `guild/` points agent roles at the accepted standards.

| Folder | What it holds |
|---|---|
| `standards/` | Accepted standards. The only standards the pack gives to agents. |
| `drafts/` | Synthesized proposals awaiting a decision. Agents never load these. |
| `decisions/` | Why the standards are what they are |
| `evidence/` | Repository surveys (`Get-GuildRepoSurvey -AsJson`), facts only |
| `docs/provenance.md` | Each standard, the sources it came from, and its status |
| `guild/__Name__.pack.psd1` | The Guild pack |

## Accepting a draft

1. Read the draft and its sources in `docs/provenance.md`.
2. Change its `**Status:**` to `Accepted`, move it from `drafts/` to `standards/`, and update its row in
   `docs/provenance.md`.
3. Run `./build.ps1`, commit, and re-run `Install-GuildAgents` with this pack.

## Use

```powershell
Install-GuildAgents -Harness claude -Pack <this repository>/guild/__Name__.pack.psd1
```

Created by `New-GuildStandardsRepo` on __Date__.
