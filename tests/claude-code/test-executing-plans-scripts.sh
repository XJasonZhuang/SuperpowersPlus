#!/usr/bin/env bash
# Tests for executing-plans' bookkeeping helpers: scripts/task-start extracts
# the brief and records BASE in one call; scripts/task-done runs the task's
# test command, records the result in the ledger, and refuses to record a
# failing task.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
EP_SCRIPTS="$REPO_ROOT/skills/executing-plans/scripts"

FAILURES=0
TEST_ROOT=""

pass() { echo "  [PASS] $1"; }
fail() {
    echo "  [FAIL] $1"
    FAILURES=$((FAILURES + 1))
}

cleanup() {
    if [[ -n "$TEST_ROOT" && -d "$TEST_ROOT" ]]; then
        rm -rf "$TEST_ROOT"
    fi
}

evidence_field() {
    grep -Fxq -- "$(printf '%s=%q' "$2" "$3")" "$1"
}

main() {
    echo "=== Test: executing-plans scripts ==="

    TEST_ROOT="$(mktemp -d)"
    trap cleanup EXIT

    # Exercise the inline workflow as installed by extractors that drop
    # executable bits, keeping the skills' relative paths intact (#2040).
    local stripped="$TEST_ROOT/skills"
    local sdd_scripts="$REPO_ROOT/skills/subagent-driven-development/scripts"
    local stripped_sdd="$stripped/subagent-driven-development/scripts"
    local stripped_ep="$stripped/executing-plans/scripts"
    mkdir -p "$stripped_ep" "$stripped_sdd"
    cp "$EP_SCRIPTS/task-start" "$EP_SCRIPTS/task-done" "$stripped_ep/"
    cp "$sdd_scripts/task-brief" "$sdd_scripts/sdd-workspace" "$sdd_scripts/sdd-repo" "$stripped_sdd/"
    chmod a-x "$stripped_ep"/* "$stripped_sdd"/*

    git init -q -b main "$TEST_ROOT/repo"
    local repo
    repo="$(cd "$TEST_ROOT/repo" && git rev-parse --show-toplevel)"
    # Same spelling as the scripts print: C:/... from cygpath -m on Windows,
    # plain pwd elsewhere.
    repo="$(cd "$repo" && if command -v cygpath >/dev/null 2>&1; then cygpath -m "$PWD"; else pwd; fi)"
    local git_id=(-c user.email=t@example.com -c user.name=t -c commit.gpgsign=false)

    cat > "$repo/plan.md" <<'PLAN'
# Plan

## Task 1: First thing

Do the first thing.

## Task 2: Second thing

Do the second thing.
PLAN
    mkdir "$repo/suite"
    touch "$repo/suite/.keep"
    ( cd "$repo" && git add plan.md suite/.keep && git "${git_id[@]}" commit -qm fixture && git config status.showUntrackedFiles no )
    local base
    base="$(cd "$repo" && git rev-parse HEAD)"

    # --- task-start: argument validation ---
    local rc=0
    (cd "$repo" && bash "$stripped_ep/task-start" plan.md >/dev/null 2>&1) || rc=$?
    if [[ "$rc" -eq 2 ]]; then
        pass "task-start without a task number errors with exit 2"
    else
        fail "task-start without a task number errors with exit 2 (got $rc)"
    fi

    # --- task-start: brief path + BASE in one call ---
    local out
    out="$(cd "$repo" && bash "$stripped_ep/task-start" plan.md 1)"
    if [[ "$out" == *"brief: $repo/.superpowers/sdd/plan/task-1-brief.md"* ]]; then
        pass "task-start prints the brief path under the plan's workspace"
    else
        fail "task-start prints the brief path under the plan's workspace"
        echo "    got: $out"
    fi
    if [[ "$out" == *"base: $base"* ]]; then
        pass "task-start prints BASE as the current HEAD"
    else
        fail "task-start prints BASE as the current HEAD"
        echo "    got: $out"
    fi
    if [[ -s "$repo/.superpowers/sdd/plan/task-1-brief.md" ]]; then
        pass "task-start writes the brief file"
    else
        fail "task-start writes the brief file"
    fi

    # --- task-done: records a passing task and keeps its evidence on retry ---
    ( cd "$repo" && echo x > work.txt && git add work.txt && git "${git_id[@]}" commit -qm "task 1" )
    local head workspace test_command
    head="$(cd "$repo" && git rev-parse HEAD)"
    workspace="$repo/.superpowers/sdd/plan"
    test_command='if [ -f .superpowers/sdd/retry-marker ]; then
        cmp -s .superpowers/sdd/plan/task-1-started-attempt .superpowers/sdd/plan/task-1-latest-attempt && exit 93;
        touch retry-output; echo "FAILED (errors=1)"; exit 3;
    fi; echo "Ran 3 tests"; echo OK'
    # The legacy ledger stores a single display line. Flatten the shell snippet
    # while still passing it as one argv entry to exercise exact capture.
    test_command=${test_command//$'\n'/ }
    out="$(cd "$repo" && SUPERPOWERS_TEST_ENVIRONMENT= bash "$stripped_ep/task-done" plan.md 1 "$base" -- sh -c "$test_command")"
    rc=$?
    local ledger="$workspace/progress.md"
    local expected="Task 1: complete (commits ${base:0:7}..${head:0:7}, tests: sh -c '$test_command' → OK)"
    if [[ -f "$ledger" ]] && grep -qF "$expected" "$ledger"; then
        pass "task-done appends the completion line with commit range and test result"
    else
        fail "task-done appends the completion line with commit range and test result"
        echo "    expected: $expected"
        echo "    ledger:"; sed 's/^/      /' "$ledger" 2>/dev/null || echo "      (missing)"
    fi
    if [[ "$out" == *"OK"* ]]; then
        pass "task-done prints the tail of the test output"
    else
        fail "task-done prints the tail of the test output"
        echo "    got: $out"
    fi
    local first_evidence first_log first_hash first_payload first_ledger
    first_evidence="$(printf '%s\n' "$out" | sed -n 's/^evidence: //p')"
    first_log="${first_evidence%/*}/tests.log"
    first_hash="$(git -C "$repo" hash-object --no-filters -- "$first_log")"
    first_payload="$(cat "$first_evidence")"
    first_ledger="$(cat "$ledger")"
    if grep -Fxq -- "Task 1: evidence $first_evidence" "$ledger" &&
       cmp -s "$first_log" "$workspace/task-1-tests.log" && [[ "$(cat "$first_log")" == $'Ran 3 tests\nOK' ]] &&
       [[ "$first_evidence" == "$workspace"/task-1-attempt.*/evidence.txt ]] &&
       [[ "$(cat "$workspace/task-1-started-attempt")" == "$first_evidence" &&
          "$(cat "$workspace/task-1-latest-attempt")" == "$first_evidence" ]] &&
       evidence_field "$first_evidence" version 1 &&
       evidence_field "$first_evidence" base "$base" &&
       evidence_field "$first_evidence" head_before "$head" &&
       evidence_field "$first_evidence" head_after "$head" &&
       evidence_field "$first_evidence" worktree_before clean &&
       evidence_field "$first_evidence" worktree_after clean &&
       evidence_field "$first_evidence" cwd "$repo" &&
       evidence_field "$first_evidence" environment unspecified &&
       evidence_field "$first_evidence" exit_status 0 &&
       evidence_field "$first_evidence" log "$first_log" &&
       evidence_field "$first_evidence" log_git_blob "$first_hash" &&
       evidence_field "$first_evidence" argc 3 &&
       [[ "$(grep '^arg=' "$first_evidence")" == "$(printf 'arg=%q\n' sh -c "$test_command")" ]]; then
        pass "passing attempt records the full output, exact invocation, commit and clean worktree"
    else
        fail "passing attempt records the full output, exact invocation, commit and clean worktree"
    fi

    # The same HEAD and command must execute again. Changing an ignored input
    # changes its result and creates an untracked output counted by Git status.
    # During the command the started pointer must differ from the prior result.
    touch "$repo/.superpowers/sdd/retry-marker"
    rc=0
    out="$(cd "$repo" && SUPERPOWERS_TEST_ENVIRONMENT= bash "$stripped_ep/task-done" plan.md 1 "$base" -- sh -c "$test_command" 2>&1)" || rc=$?
    local failed_evidence failed_log
    failed_evidence="$(printf '%s\n' "$out" | sed -n 's/^evidence: //p')"
    failed_log="${failed_evidence%/*}/tests.log"
    if [[ "$rc" -eq 3 && "$out" == *"FAILED (errors=1)"* && -f "$repo/retry-output" ]] &&
       evidence_field "$failed_evidence" exit_status 3 &&
       evidence_field "$failed_evidence" head_before "$head" &&
       evidence_field "$failed_evidence" head_after "$head" &&
       evidence_field "$failed_evidence" worktree_before clean &&
       evidence_field "$failed_evidence" worktree_after dirty &&
       cmp -s "$failed_log" "$workspace/task-1-tests.log"; then
        pass "task-done reruns the same test at the same HEAD and keeps its failed evidence"
    else
        fail "task-done reruns the same test at the same HEAD and keeps its failed evidence"
    fi
    if [[ "$failed_evidence" != "$first_evidence" && "$(cat "$first_evidence")" == "$first_payload" &&
          "$(cat "$workspace/task-1-started-attempt")" == "$failed_evidence" &&
          "$(cat "$workspace/task-1-latest-attempt")" == "$failed_evidence" &&
          "$(git -C "$repo" hash-object --no-filters -- "$first_log")" == "$first_hash" &&
          "$(cat "$ledger")" == "$first_ledger" ]]; then
        pass "failed retry advances both pointers and preserves the prior record, full log and ledger"
    else
        fail "failed retry advances both pointers and preserves the prior record, full log and ledger"
    fi

    # --- task-done: records a passing task whose test command prints nothing ---
    # https://github.com/obra/superpowers/issues/2385 -- under `set -euo
    # pipefail`, the ledger's `grep -v '^[[:space:]]*$' log | tail -n 1`
    # exits 1 on an empty/blank log, which used to abort the whole script
    # (silently, no ledger line) even though the test command itself passed.
    ( cd "$repo" && echo y > work2.txt && git add work2.txt && git "${git_id[@]}" commit -qm "task 2" )
    local head2
    head2="$(cd "$repo" && git rev-parse HEAD)"
    local silent_command='test "$1" = "value with spaces" && rm ../retry-output'
    rc=0
    out="$(cd "$repo/suite" && SUPERPOWERS_TEST_ENVIRONMENT="local isolated" bash "$stripped_ep/task-done" ../plan.md 2 "$head" -- sh -c "$silent_command" runner 'value with spaces' 2>&1)" || rc=$?
    if [[ "$rc" -eq 0 ]]; then
        pass "task-done exits 0 when a passing test command prints nothing"
    else
        fail "task-done exits 0 when a passing test command prints nothing (got rc=$rc)"
        echo "    got: $out"
    fi
    local expected2="Task 2: complete (commits ${head:0:7}..${head2:0:7}, tests: sh -c '$silent_command' runner 'value with spaces' → (no output))"
    if [[ -f "$ledger" ]] && grep -qF "$expected2" "$ledger"; then
        pass "task-done records a passing task that printed no output"
    else
        fail "task-done records a passing task that printed no output"
        echo "    expected: $expected2"
        echo "    ledger:"; sed 's/^/      /' "$ledger" 2>/dev/null || echo "      (missing)"
    fi
    local silent_evidence
    silent_evidence="$(printf '%s\n' "$out" | sed -n 's/^evidence: //p')"
    if evidence_field "$silent_evidence" cwd "$repo/suite" &&
       evidence_field "$silent_evidence" environment 'local isolated' &&
       evidence_field "$silent_evidence" worktree_before dirty &&
       evidence_field "$silent_evidence" worktree_after clean &&
       [[ "$(grep '^arg=' "$silent_evidence")" == "$(printf 'arg=%q\n' sh -c "$silent_command" runner 'value with spaces')" ]]; then
        pass "evidence distinguishes the actual cwd, supplied environment and cleanup"
    else
        fail "evidence distinguishes the actual cwd, supplied environment and cleanup"
    fi

    # A successful command spanning two revisions cannot certify either.
    local before_change after_change changed_record
    before_change="$(git -C "$repo" rev-parse HEAD)"
    rc=0
    (cd "$repo" && bash "$stripped_ep/task-done" plan.md 3 "$before_change" -- git "${git_id[@]}" commit --allow-empty -qm 'change during test') >/dev/null 2>&1 || rc=$?
    after_change="$(git -C "$repo" rev-parse HEAD)"
    changed_record="$(cat "$workspace/task-3-latest-attempt")"
    if [[ "$rc" -ne 0 && "$before_change" != "$after_change" ]] &&
       evidence_field "$changed_record" exit_status 0 &&
       evidence_field "$changed_record" head_before "$before_change" &&
       evidence_field "$changed_record" head_after "$after_change" &&
       ! grep -q '^Task 3: complete' "$ledger"; then
        pass "a successful test spanning different revisions cannot complete the task"
    else
        fail "a successful test spanning different revisions cannot complete the task"
    fi

    # --- no usable repository: every helper stops with one message (#2242, #2429) ---
    # The same message for a new project and for a caller standing in the
    # wrong directory (such as the plugin's skill directory, where git init
    # is the wrong fix), so "init and commit" is only the new-project case.
    git init -q -b main "$TEST_ROOT/unborn"
    cp "$repo/plan.md" "$TEST_ROOT/unborn/plan.md"
    mkdir -p "$TEST_ROOT/no-repo"
    cp "$repo/plan.md" "$TEST_ROOT/no-repo/plan.md"
    # git's own first error line follows the shared message, so the reason
    # git refused is never hidden.
    local where msg said
    for where in unborn no-repo; do
        msg="SDD scripts must run from inside the git working tree you're executing in, with at least one commit (current directory: $TEST_ROOT/$where). If this is a new project, run 'git init' and make a first commit, then rerun."
        said="git said: fatal: "
        [[ "$where" == no-repo ]] && said="git said: fatal: not a git repository"
        rc=0
        out="$(cd "$TEST_ROOT/$where" && bash "$stripped_ep/task-start" plan.md 1 2>&1)" || rc=$?
        if [[ "$rc" -eq 2 && "$out" == "$msg"$'\n'"$said"* ]]; then
            pass "task-start in a $where directory exits 2 with the shared message"
        else
            fail "task-start in a $where directory exits 2 with the shared message"
            echo "    exit: $rc"
            echo "    got: $out"
        fi
        rc=0
        out="$(cd "$TEST_ROOT/$where" && bash "$stripped_ep/task-done" plan.md 1 HEAD -- true 2>&1)" || rc=$?
        if [[ "$rc" -eq 2 && "$out" == "$msg"$'\n'"$said"* ]]; then
            pass "task-done in a $where directory exits 2 with the shared message"
        else
            fail "task-done in a $where directory exits 2 with the shared message"
            echo "    exit: $rc"
            echo "    got: $out"
        fi
    done
    if [[ ! -e "$TEST_ROOT/unborn/.superpowers" && ! -e "$TEST_ROOT/no-repo/.superpowers" ]]; then
        pass "nothing is written without a usable repository"
    else
        fail "nothing is written without a usable repository"
    fi

    # --- outside any repository, a plan in a repository is not a fallback (#2429) ---
    # Like git, the scripts act on the current directory's working tree; an
    # absolute plan path into some repository does not pick that one instead.
    msg="SDD scripts must run from inside the git working tree you're executing in, with at least one commit (current directory: $TEST_ROOT/no-repo). If this is a new project, run 'git init' and make a first commit, then rerun."
    local before head_now
    head_now="$(cd "$repo" && git rev-parse HEAD)"
    before="$(find "$repo/.superpowers" | sort; cat "$repo/.superpowers/sdd/plan/progress.md")"
    rc=0
    out="$(cd "$TEST_ROOT/no-repo" && bash "$stripped_ep/task-start" "$repo/plan.md" 2 2>&1)" || rc=$?
    if [[ "$rc" -eq 2 && "$out" == "$msg"$'\n'"git said: fatal: not a git repository"* ]]; then
        pass "task-start outside any repository stops with the shared message despite a plan in a repository"
    else
        fail "task-start outside any repository stops with the shared message despite a plan in a repository"
        echo "    exit: $rc"
        echo "    got: $out"
    fi
    rc=0
    out="$(cd "$TEST_ROOT/no-repo" && bash "$stripped_ep/task-done" "$repo/plan.md" 2 "$head_now" -- true 2>&1)" || rc=$?
    if [[ "$rc" -eq 2 && "$out" == "$msg"$'\n'"git said: fatal: not a git repository"* ]]; then
        pass "task-done outside any repository stops with the shared message despite a plan in a repository"
    else
        fail "task-done outside any repository stops with the shared message despite a plan in a repository"
        echo "    exit: $rc"
        echo "    got: $out"
    fi
    if [[ "$(find "$repo/.superpowers" | sort; cat "$repo/.superpowers/sdd/plan/progress.md")" == "$before" && ! -e "$TEST_ROOT/no-repo/.superpowers" ]]; then
        pass "outside any repository, task-start and task-done write nothing to the plan's repository"
    else
        fail "outside any repository, task-start and task-done write nothing to the plan's repository"
    fi

    echo
    if [[ "$FAILURES" -eq 0 ]]; then
        echo "PASS"
    else
        echo "FAIL ($FAILURES)"
        exit 1
    fi
}

main "$@"
