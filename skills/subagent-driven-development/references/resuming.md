# Resuming From an Existing Ledger

Part of superpowers:subagent-driven-development. This plan's workspace
already has a ledger at `<workspace>/progress.md`.

A ledger whose first line names a different plan file, or a stray ledger
at the old flat path `.superpowers/sdd/progress.md`, belongs to other work.
Leave it in place and start your own ledger.

For this plan's ledger, use its completion lines and `git log` to recover
implementation and review progress. Before treating a completed check as
passing, follow superpowers:verification-before-completion. Read the
latest relevant attempt record and log, including attempts after the
completion line. For `task-done` attempts, the workspace files
`task-<N>-started-attempt` and `task-<N>-latest-attempt` must point to
the same record and its per-attempt log must be intact. A changed HEAD
during the run leaves the tested code uncertain. For legacy results with
no pointers and runs outside `task-done`, consult the referenced log,
report or CI evidence and any later results. An applicable later failure
supersedes the earlier pass. Investigate it and resume the unresolved
check on the existing code.

An interrupted attempt or missing result has an unknown outcome. If a run
is still active, wait for its result. Otherwise, recover valid evidence if
available and run a targeted check if the outcome is still unresolved.
Preserve completed implementation and review work and evidence for
unaffected checks. Resume at the first unfinished task or unresolved
check. If a task's last line records a fix round still in progress, resume
the fix loop at the next round.
