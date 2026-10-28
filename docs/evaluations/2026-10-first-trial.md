# First end-to-end trial of Guild

**Trial dates:** 2026-10-24 to 2026-10-27. **Statuses checked:** 2026-10-27.

This records what the first end-to-end trial of Guild taught, and what to change before giving it
larger projects. It does not change Guild. Each finding has a status: **Keep** (worked, leave it),
**Fixed** (changed during the trial), **Open** (still to do), or **Process recommendation** (a change
to how the work is run, not yet adopted). The section on checks at the end says which statuses were
re-checked on 2026-10-27 and which come from the trial record.

## The trial

The trial had two parts.

1. **A small PowerShell command-line tool**, a temperature converter with object and JSON output and
   input validation. It went through the full role flow: architect, builder, reviewer. Review took
   three rounds and ended in approval.
2. **A change to Guild itself**: the fail-closed read-only guard, [decision 0005](../decisions/0005-fail-closed-read-only-guard.md)
   and [guard.md](../guard.md). The trial showed that read-only roles could not run the checks their
   roles require, so the guard had to change. That change was high-risk. It went builder, then an
   independent tester (about ten QA rounds), then reviewer and security (three review rounds), then
   install and a live hook check that passed all eight steps.

Numbers, as the coordinator recorded them during the trial:

- Trial tool: 159 tests at the first build, 189 at the end, with 100% coverage.
- Guard: 1,777 tests at the end. Independent QA ran roughly 2,000 case invocations in its final passes.

## Summary

| Status | Findings |
|---|---|
| Keep | 1, 2, 3, 4 |
| Fixed | 5, 6, 7, 8, 9, 10, 14, 16 |
| Open | 11, 12, 13, 15, 28 |
| Process recommendation | 17 to 27 |

The open items in Guild itself (11, 12, 13, 15) are small. Item 28 is for the pack and for wider use.

## A. What worked

**1. Role separation found what the tests missed.** The trial tool had 159 passing tests at its first
build. The independent reviewer's first round found two real bugs that every test had missed: a
same-unit conversion that rounded a midpoint wrongly through an intermediate unit, and a mistyped
option that was converted as a data value. A passing suite was not evidence that the behaviour was
right. **Status:** Keep. **Recommendation:** Keep the reviewer separate from the author on every
change, as the routing order already requires.

**2. The independent tester was the most valuable role on high-risk work.** Across the guard's rounds
it found every high-severity bypass: 7 in the first rewrite of the text scanner and 22 in the second
([decision 0005](../decisions/0005-fail-closed-read-only-guard.md), Context), then narrower ones. The
builder's own suite of over 1,000 tests caught none of them. The tester also kept a false-positive suite
of everyday reviewer commands, which caught usability regressions, such as `src/*` and `feat/*` being
blocked for a short time. **Status:** Keep. **Recommendation:** Ask the tester for both a bypass suite
and a false-positive suite on every guard or security change (see 26).

**3. The review limit, the findings log and decision records worked as intended.** The three-round
review limit held. `Add-GuildFinding` and `Get-GuildFindingSummary` kept findings in one place, and
decision records 0001 and 0005 captured the choices the work depended on. On 2026-10-27 the log at
`.guild/findings.jsonl` held 42 entries. **Status:** Keep. **Recommendation:** Keep it. The promotion
candidates are listed under Next steps.

**4. Complete briefs made recovery cheap.** A brief complete enough to hand to a fresh agent let the
coordinator recover from stalls and stopped agents by starting again with the same brief. **Status:**
Keep. **Recommendation:** Keep the standard brief sections. See 25.

## B. Fixed during the trial

**5. Read-only roles could not run the checks their roles require.** Read-only roles had only the Bash
tool, but the guard's allowlist covered PowerShell commands, and the guard blocked `pwsh` itself. The
reviewer and architect could not run the pack's check command, `Test-GuildDocs` or `New-GuildDecision`.
Every behavioural review finding came back as suspected, so the coordinator ran all the probes. Two of
the six round-one claims turned out to be wrong. **Status:** Fixed. Read-only and docs roles now get the
PowerShell tool, and the hook matcher is `Bash|PowerShell` ([README](../../README.md), Commands for the
agents). Verified live: the reviewer ran the check command, and the architect ran `Test-GuildDocs`.
**Recommendation:** Treat any guard tightening as a change to the tools roles can use (see 24).

**6. Word matching blocked reads.** The guard matched words anywhere in the command text, so
`cat scripts/Invoke-Build.ps1` was blocked as if it changed something. **Status:** Fixed by the
redesign in decision 0005, which parses the command. **Recommendation:** None beyond the redesign.

**7. A text-scanning guard could not converge.** Each round of fixes added parsing with new holes:
escaped quotes, apostrophes, `"rm".exe`, dynamic member names, option values read as subcommands,
parameter prefixes, separator runs and trailing dots. Every late hole was a deny list. Where the guard
matched spellings, an unusual spelling got through. Where it asked the real parser or resolver, the
holes stopped. Inverting the deny list into an allowlist was the fix each time. **Status:** Fixed by
decision 0005. PowerShell is parsed with its own parser and checked against an allowlist. Bash is held
to a narrow grammar. Anything unlisted is blocked. **Recommendation:** Start a guard from an allowlist,
and ask the parser or resolver rather than the text.

**8. The hook failed open.** Only exit code 2 blocked a tool call, so a missing script, a crash or a
timeout let the call run. **Status:** Fixed. Every guard hook has `timeout: 30` and `onFailure: block`.
`Test-GuildInstall` reports missing guard files and the harness version. The live check
([guard.md §11](../guard.md#11-verification-record)) passed all eight steps, including a missing script,
exit 1, a timeout and a background call, each blocked. **Recommendation:** Keep the live check as part
of any change to the hooks.

**9. Guild commands could not be imported by name.** The PowerShell tool keeps no state between calls,
so an agent has to import the module in the same call. An attempted fix placed junctions in the user's
module folder, which is a synced cloud folder. That is a data-integrity risk, and the attempt was
removed. Generated agents now carry the absolute `Import-Module` line (`core/tools.md`, `{{guildmodule}}`).
**Status:** Fixed. **Recommendation:** Keep the module path in generated text. Never link into a synced
folder.

**10. Generated agents named tools their guard blocks.** The generated text told read-only roles they
could use tools the guard blocked. **Status:** Fixed. The tools table in `core/tools.md` has an
"Available to" column (checked 2026-10-27). **Recommendation:** None.

## C. Open issues in Guild

**11. Two commands leak a git exit code outside a repository.** `Get-GuildContext` and `Test-GuildDocs`
return exit code 128 when the path is not a git repository. Their output is correct, but a caller that
checks the exit code sees a failure. Checked 2026-10-27 in an empty folder: both exit 128. **Status:**
Open. **Recommendation:** Exit 0 when the path is not a repository and the output is complete, and add a
test for the exit code.

**12. `New-GuildBrief` doubles the role prefix.** A role passed with the prefix already on it renders the
prefix twice: `<prefix>-builder` comes out as `<prefix>-<prefix>-builder`. Checked 2026-10-27 with the
installed pack. **Status:** Open. **Recommendation:** Accept either the bare role or the full name, and
render the prefix once.

**13. `Test-GuildDocs` flags paths the installer generates.** On the Guild repository it reports six
MissingPath findings, all for the installed pack file, the install manifest or the provenance file. The
installer and the standards repository create those files, not Guild itself, so the documents are right
and the check is wrong. The trial also reported build output folders. **Status:** Open. **Recommendation:**
Add an ignore list for generated paths, and read `.gitignore` before flagging a path as missing.

**14. The reviewer prompt did not list the allowed categories.** `Add-GuildFinding` rejected categories
outside the pack's list, but the reviewer prompt did not show the list, so reviewers kept using rejected
ones. **Status:** Fixed in the current build. The reviewer text has a `{{categories}}` token that renders
the pack's list ("Category is one of: ..."). The installed reviewer prompt carries the pack's list, which
does not include "performance" (checked 2026-10-27). Not checked: the reviewer prompt when no pack sets
categories. **Recommendation:** Add a test that the rendered reviewer prompt matches the pack's categories.

**15. Nothing prompts the human to accept proposed decisions.** A decision record created during a
delivery stays Proposed unless someone changes it. The deliver skill has no step that asks for it.
Checked 2026-10-27: `skills/deliver/SKILL.md`, `core/rules.md` and the roles say nothing about accepting
Proposed records. **Status:** Open. **Recommendation:** Add a closing step to the deliver skill: list each
Proposed record and ask the human to accept or reject it.

**16. The guard's known gaps need a plain statement.** Recursive reads through a listing that is not
itself secret, built paths and best-effort secret names are gaps the guard does not close.
**Status:** Fixed. [guard.md §10](../guard.md#10-accepted-gaps) lists them. The README (Commands for the
agents), guard.md §1 and decision 0005 (threat model) all say the guard is a guardrail, not a security
boundary, and name the operating system and harness controls as the boundary. **Recommendation:** Keep
§10 current when the guard changes.

## D. Process recommendations

Nothing in this section is in the deliver skill or the role text yet (checked 2026-10-27). Each is a
**Process recommendation**.

**17. No stopping rule for QA rounds.** The review loop stops after three rounds, but the tester-to-builder
loop before review has no limit. The guard's final rounds ran about ten. **Recommendation:** After a set
number of rounds, block only on high-severity findings that could plausibly happen by accident. Record
the rest as known gaps with a reproduction, as guard.md §10 does.

**18. Agents stall while waiting for background work.** Three runs stalled, each waiting for a background
run's notification, and the watchdog ended each one after ten minutes with no progress. **Recommendation:**
Require explicit timeouts, foreground runs for test suites, and polling of output files with short,
bounded commands. The deliver skill should say what to do after a stall: inspect the working tree, then
resume the work with a fresh agent and the same brief (see 25).

**19. A builder's report was lost, and one run took about 32 hours.** One builder's hand-off report was
lost. Another builder ran for about 32 hours of wall time. **Recommendation:** Builders put the full report
in their final message. The coordinator checks the working tree independently before trusting a report.

**20. Test-first was not enforced.** The builder twice skipped writing failing tests first, and said so.
Later rounds followed the practice well once it was asked for. **Recommendation:** Require a "Red first"
section in the builder's report: the test name and its failing output.

**21. Design drift.** The builder's deviations did not reach the architect. The architect once updated a
design from the coordinator's description without reading the code, and once put a hand-worked example
into a test plan that turned out wrong. **Recommendation:** Require a "Design deviations" section in the
builder's report, which the deliver skill sends to the architect. Give the architect a rule to read the
code before syncing a design to a build.

**22. Tester cleanup came close to a recursive delete.** A tester's cleanup assigned a path to a variable
named after a read-only automatic variable, and aimed a recursive delete at the home folder. The shell
refused because the target held the working directory, so nothing was lost. **Recommendation:** Run
testers in a sandbox: a separate worktree or a temporary working directory. Cleanup deletes only paths the
run created, verified by a unique prefix. Never use automatic variable names for your own variables.

**23. Adversarial test inputs triggered endpoint protection.** Download-technique strings passed to the
guard on a process command line raised alerts, and endpoint protection killed the processes. **Recommendation:**
Feed guard cases as hook JSON on stdin, never on a command line. Keep well-known download and execute
signatures out of case files, so a shared harness can scan case files before it runs them.

**24. Reviewers could not verify behaviour.** While the guard blocked PowerShell, reviewers could not run
probes. The coordinator ran them all, so the reviews were only partly independent. Item 5 fixed this.
**Recommendation:** Treat any guard tightening as a change to what reviewers can run, and check it against
their needs.

**25. A stopped agent cannot be resumed.** The harness cannot resume a stopped agent. Recovery means a
fresh agent and a complete brief. **Recommendation:** Keep briefs self-contained.

**26. Each security tightening risked a usability regression.** **Recommendation:** Ask the tester for a
bypass suite and a false-positive suite of everyday commands in every round.

**27. Coordinator verification paid off.** Re-running the build and probing each reported finding before
routing it caught wrong findings in both directions, and confirmed real ones cheaply. **Recommendation:**
Keep this step in the deliver skill.

## E. For the pack and for wider use

**28. The controls that matter most sit below the agent.** For less technical users of AI tooling, the
strongest controls are outside the agent: endpoint protection rules scoped to device groups, application
control, and harness-managed permission settings. The read-only guard is a useful first filter for a
cooperative agent. It is not a boundary. **Status:** Open, for the pack and for wider use. **Recommendation:**
Write these controls into the pack's guidance, and do not present the guard as one of them.

## Next steps before larger projects

1. Close the four open items in Guild: 11, 12, 13 and 15. Each is small.
2. Put the process recommendations (17 to 22, then 25) into the deliver skill and the builder and
   architect role text. Where a rule can be a check, make it a check, and remove it from the role text.
3. Decide on the promotion candidates. On 2026-10-27 the findings log marked these categories as recurring:
   security (23 entries), correctness (5), docs (5), error-handling (4) and testing (2). Each promotion is
   the human's decision. The steward proposes it, with the check, template or standards entry written out.
4. Decide the guard's recursive-read gap before the guard protects a project with production secrets. The
   trial's record accepted the gap for read-only searches ([guard.md §8.3](../guard.md#83-verdicts-that-change-from-the-current-guard),
   2026-10-27). It is not a bug to fix silently.
5. Run the next trial on a larger project with the stopping rule (17), stall rules (18) and sandboxed testers
   (22) in place.

## How the statuses were checked

On 2026-10-27, these statuses were re-checked against the repository. `./build.ps1` was run, and
`Test-GuildDocs` was run against the Guild repository. Probes ran in an empty folder outside any repository.

- Re-checked by probe or by reading the code and docs: 5, 8, 9, 10, 11, 12, 13, 14, 15, 16 and 28.
  Items 17 to 27 were checked against the deliver skill and the role text.
- From the trial record, not re-run: 1 to 4, 6, 7, the trial numbers, and the live check results.

The build reported 1,777 tests discovered. `Test-GuildDocs` reported six MissingPath findings, all of them
item 13.
