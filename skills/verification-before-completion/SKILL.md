---
name: verification-before-completion
description: Use when deciding whether a change is verified, handing off acceptance evidence, or about to claim that work is complete, fixed, or passing
---

# Verification Before Completion

## Overview

**Core principle:** Evidence before claims, always.

**Violating the letter of this rule is violating the spirit of this rule.**

## The Iron Law

```
NO COMPLETION CLAIMS WITHOUT APPLICABLE VERIFICATION EVIDENCE
```

Freshness depends on what was tested. A handoff, new message or change of
reviewer does not invalidate a result. Read the evidence before making the claim.

## The Gate Function

1. Name the acceptance criterion and target. For a real workflow, identify
   the required startup health, user-visible outcome and test-data cleanup.
   One end-to-end run may establish all three.
2. Inspect an existing run: the command or manual steps, outcome (including
   exit status for commands), and accessible log, CI job or observation.
   Match the tested tree or build to the target. A commit alone cannot
   identify dirty or untracked inputs. Check relevant dependencies, config,
   environment, fixture and external state; an unknown match is a gap.
3. If that evidence covers the criterion and no later failure contradicts
   it, cite it. If inputs changed, establish which criteria they affect;
   run only the missing or affected checks once. A later failure on the
   same inputs must be investigated. Honor explicitly required fresh runs,
   CI jobs and independent approvals.
4. Record the result and a reference the next stage can still open. Keep the
   evidence through its last consumer. If it is unavailable or inconclusive,
   report the gap until the required check succeeds.

For example, a passing import through the installed app can cover startup,
import and cleanup during review and release. A subsequent change to the
import configuration calls for checking that flow on the new configuration.
A unit test of the parser cannot establish the installed-app result.

## Common Failures

| Claim | Requires | Not Sufficient |
|-------|----------|----------------|
| Tests pass | Matching command and target, successful output | Old green result on unknown inputs |
| Linter clean | Linter output: 0 errors | Partial check, extrapolation |
| Build succeeds | Build command: exit 0 | Linter passing, logs look good |
| Bug fixed | Test original symptom: passes | Code changed, assumed fixed |
| Regression test works | Red-green cycle verified | Test passes once |
| Agent completed | VCS diff shows changes | Agent reports "success" |
| Requirements met | Each criterion mapped to applicable evidence | A green test count alone |

## Red Flags - STOP

- Using "should", "probably", "seems to"
- Expressing satisfaction before verification ("Great!", "Perfect!", "Done!", etc.)
- About to commit/push/PR without verification
- Trusting agent success reports
- Relying on partial verification
- Thinking "just this once"
- Tired and wanting work over
- Claiming success without inspecting applicable evidence

## Rationalization Prevention

| Excuse | Reality |
|--------|---------|
| "Should work now" | RUN the verification |
| "I'm confident" | Confidence ≠ evidence |
| "Just this once" | No exceptions |
| "Linter passed" | Linter ≠ compiler |
| "Agent said success" | Inspect the supporting record and its scope |
| "I'm tired" | Exhaustion ≠ excuse |
| "Partial check is enough" | Partial proves nothing |
| "Different words so rule doesn't apply" | Spirit over letter |

## Key Patterns

**Tests:**
```
✅ [Read matching CI job: suite, exit 0, 34/34] "All 34 suite tests passed in job 187."
❌ "Should pass now" / "Looks correct"
```

**Regression tests (TDD Red-Green):**
```
✅ Record the test failing for the expected reason before the fix, then passing with the fix. Use the recorded red and green results at handoff.
❌ "I've written a regression test" (without red-green verification)
```

**Build:**
```
✅ [Run build] [See: exit 0] "Build passes"
❌ "Linter passed" (linter doesn't check compilation)
```

**Requirements:**
```
✅ Re-read plan → Create checklist → Verify each → Report gaps or completion
❌ "Tests pass, phase complete"
```

**Agent delegation:**
```
✅ Agent reports success → Inspect diff and linked acceptance evidence → Check any uncovered integration → Report actual state
❌ Trust agent report
```

## When To Apply

**ALWAYS before:**
- ANY variation of success/completion claims
- ANY expression of satisfaction
- ANY positive statement about work state
- Committing, PR creation, task completion
- Moving to next task
- Delegating to agents

**Rule applies to:**
- Exact phrases
- Paraphrases and synonyms
- Implications of success
- ANY communication suggesting completion/correctness
