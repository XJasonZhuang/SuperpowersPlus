# Final Review and Finish

Part of superpowers:subagent-driven-development. Every task in the plan is
complete.

The final whole-branch review gets a package too: run
`bash scripts/review-package PLAN_FILE MERGE_BASE HEAD` by its absolute path,
from the working tree you're executing in (MERGE_BASE = the commit the
branch started from, e.g. `git merge-base main HEAD`) and include the
printed path in the final review dispatch, so the final reviewer reads
one file instead of re-deriving the branch diff with git commands. Dispatch
on the most capable available model (see SKILL.md's Model Selection), using
superpowers:requesting-code-review's
[code-reviewer.md](../../requesting-code-review/code-reviewer.md). Point it at
the ledger's deferred-minor and parked lines so it can triage which must be
fixed before merge. Send the applicable verification evidence and log
paths with the package. Focus this review on integration across tasks,
changed behavior, and outstanding risks. Use
superpowers:verification-before-completion to read the existing results
and identify any gap that needs a focused check. Carry forward applicable
acceptance results so finishing can use them too.

If the final whole-branch review returns findings, dispatch ONE fix subagent
with the complete findings list — not one fixer per finding.
Per-finding fixers each rebuild context and re-run suites; a real
session's final-review fix wave cost more than all its tasks combined.
Verify the affected paths once the fixes land. Keep required RED→GREEN
and run only the additional checks needed for that scope. Run a full
suite when explicitly required or when narrower checks cannot cover the
affected behavior.
Then run exactly one scoped re-review of the fix wave
(`bash scripts/review-package PLAN_FILE FIX_BASE HEAD` by its absolute path,
from the working tree you're executing in, over the fix range,
[re-review-prompt.md](../re-review-prompt.md)).
Adjudicate any residual findings as in the fix loop's breaker
(references/fix-loop.md): park with rulings, or rule on the load-bearing
ones and ledger what you decided. Only the four things that stop a running
plan (top of SKILL.md) stop you here. There is no second fix wave —
residual load-bearing findings surface to your human partner when
finishing-a-development-branch presents the options.

### Finish

Before you delete anything, collect every ledger line containing `Ruling:` —
preflight rulings, parked findings, breaker adjudications, all of them — into
your final message under "Rulings I made", in the order you made them, each
with what it costs if wrong. The list is exhaustive: if the ledger holds a
ruling, the list holds it. That list is the only place the decisions you
took on your human partner's behalf reach them — they read it and rework
whatever you got wrong. A ruling that dies with the workspace was a decision
made in secret.

Pass the applicable verification evidence to
superpowers:finishing-a-development-branch, including results for any
startup health, core workflow and test-data cleanup checks already run.
Before deleting the plan workspace or removing its worktree, preserve the
evidence record and full log in an accessible handoff, CI result or retained
artifact. The evidence identifies the tested scope, code state, command,
environment and outcome. If the original files are the only accessible
copy, retain them until finishing and any later consumer have used them.
After a clean final review and integrated fixes, delete only this plan's
workspace once this handoff condition is met.
