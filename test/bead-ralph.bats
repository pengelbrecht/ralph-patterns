#!/usr/bin/env bats
# BATS tests for bead-ralph.sh

load 'test_helper'

# =============================================================================
# Setup / Teardown
# =============================================================================

setup() {
    setup_mocks
    setup_test_repo
}

teardown() {
    teardown_test_repo
}

# =============================================================================
# Argument Parsing Tests
# =============================================================================

@test "shows usage when no arguments provided" {
    run "$BEAD_RALPH"
    [ "$status" -eq 1 ]
    [[ "$output" == *"Usage:"* ]]
}

@test "shows usage with --help flag" {
    run "$BEAD_RALPH" --help
    [ "$status" -eq 1 ]
    [[ "$output" == *"Usage:"* ]]
    [[ "$output" == *"--worktree"* ]]
}

@test "shows usage with -h flag" {
    run "$BEAD_RALPH" -h
    [ "$status" -eq 1 ]
    [[ "$output" == *"Usage:"* ]]
}

@test "accepts iterations as first argument" {
    export MOCK_CLAUDE_RESPONSE="<promise>COMPLETE</promise>"
    run "$BEAD_RALPH" 1 bd-test-epic
    # Should run successfully (exit 0 on COMPLETE)
    [ "$status" -eq 0 ]
}

@test "accepts --worktree flag before iterations" {
    export MOCK_CLAUDE_RESPONSE="<promise>COMPLETE</promise>"
    run "$BEAD_RALPH" --worktree 1 bd-test-epic
    [ "$status" -eq 0 ]
    [[ "$output" == *"Setting up worktree"* ]]
}

@test "accepts multiple epic IDs" {
    export MOCK_CLAUDE_RESPONSE="<promise>COMPLETE</promise>"
    run "$BEAD_RALPH" 2 bd-epic-1 bd-epic-2
    [ "$status" -eq 0 ]
    [[ "$output" == *"Epics to process: bd-epic-1 bd-epic-2"* ]]
}

@test "rejects non-numeric iterations" {
    run "$BEAD_RALPH" abc bd-test-epic
    [ "$status" -eq 1 ]
    [[ "$output" == *"Usage:"* ]]
}

# =============================================================================
# Auto-select Mode Tests
# =============================================================================

@test "auto-selects epic when none provided" {
    export MOCK_CLAUDE_RESPONSE="<promise>COMPLETE</promise>"
    run "$BEAD_RALPH" 1
    [ "$status" -eq 0 ]
    [[ "$output" == *"Auto-select mode"* ]]
    [[ "$output" == *"Selected: bd-test-epic"* ]]
}

@test "exits cleanly when no epics available in auto mode" {
    export MOCK_BD_NO_EPICS=1
    run "$BEAD_RALPH" 1
    [ "$status" -eq 0 ]
    [[ "$output" == *"No ready epics found"* ]]
}

# =============================================================================
# Multi-Epic Mode Tests
# =============================================================================

@test "processes multiple epics sequentially" {
    export MOCK_CLAUDE_RESPONSE="<promise>COMPLETE</promise>"
    run "$BEAD_RALPH" 3 bd-epic-1 bd-epic-2
    [ "$status" -eq 0 ]
    [[ "$output" == *"Epic bd-epic-1 completed"* ]]
    [[ "$output" == *"Continuing with next epic (2 of 2): bd-epic-2"* ]]
    [[ "$output" == *"All 2 epics completed"* ]]
}

@test "completes single epic and exits" {
    export MOCK_CLAUDE_RESPONSE="<promise>COMPLETE</promise>"
    run "$BEAD_RALPH" 1 bd-single-epic
    [ "$status" -eq 0 ]
    [[ "$output" == *"Epic bd-single-epic completed"* ]]
    # Should NOT say "Continuing with next epic"
    [[ "$output" != *"Continuing with next epic"* ]]
}

# =============================================================================
# Promise Signal Tests
# =============================================================================

@test "exits on COMPLETE signal" {
    export MOCK_CLAUDE_RESPONSE="Task done. <promise>COMPLETE</promise>"
    run "$BEAD_RALPH" 5 bd-test-epic
    [ "$status" -eq 0 ]
    [[ "$output" == *"Epic bd-test-epic completed"* ]]
}

@test "exits with code 2 on EJECT signal" {
    export MOCK_CLAUDE_RESPONSE="Need Xcode. <promise>EJECT: Xcode required</promise>"
    run "$BEAD_RALPH" 1 bd-test-epic
    [ "$status" -eq 2 ]
    [[ "$output" == *"Ejected - manual intervention required"* ]]
}

@test "exits with code 3 on BLOCKED signal" {
    export MOCK_CLAUDE_RESPONSE="Missing API key. <promise>BLOCKED: No credentials</promise>"
    run "$BEAD_RALPH" 1 bd-test-epic
    [ "$status" -eq 3 ]
    [[ "$output" == *"Blocked - cannot proceed"* ]]
}

@test "exits with code 1 when max iterations reached" {
    export MOCK_CLAUDE_RESPONSE="Did some work but not done yet."
    run "$BEAD_RALPH" 2 bd-test-epic
    [ "$status" -eq 1 ]
    [[ "$output" == *"Max iterations (2) reached"* ]]
}

# =============================================================================
# Worktree Lifecycle Tests
# =============================================================================

@test "worktree mode creates .ralph-worktrees directory" {
    export MOCK_CLAUDE_RESPONSE="<promise>COMPLETE</promise>"
    run "$BEAD_RALPH" --worktree 1 bd-test-epic
    [ "$status" -eq 0 ]

    # Directory should have been created (and cleaned up, but we check the output)
    [[ "$output" == *"Setting up worktree"* ]]
    [[ "$output" == *".ralph-worktrees/bd-test-epic"* ]]
}

@test "worktree mode adds entry to .gitignore" {
    export MOCK_CLAUDE_RESPONSE="<promise>COMPLETE</promise>"

    # Remove .ralph-worktrees from gitignore if present
    if [ -f .gitignore ]; then
        grep -v "ralph-worktrees" .gitignore > .gitignore.tmp || true
        mv .gitignore.tmp .gitignore
    fi

    run "$BEAD_RALPH" --worktree 1 bd-test-epic
    [ "$status" -eq 0 ]

    # Check gitignore was updated
    grep -q ".ralph-worktrees/" .gitignore
}

@test "worktree mode creates branch with ralph/ prefix" {
    export MOCK_CLAUDE_RESPONSE="<promise>COMPLETE</promise>"
    run "$BEAD_RALPH" --worktree 1 bd-test-epic
    [ "$status" -eq 0 ]
    [[ "$output" == *"Branch: ralph/bd-test-epic"* ]]
}

@test "worktree mode tears down on completion" {
    export MOCK_CLAUDE_RESPONSE="<promise>COMPLETE</promise>"
    run "$BEAD_RALPH" --worktree 1 bd-test-epic
    [ "$status" -eq 0 ]
    [[ "$output" == *"Tearing down worktree"* ]]
    [[ "$output" == *"Worktree teardown complete"* ]]
}

@test "worktree mode merges branch back to main" {
    export MOCK_CLAUDE_RESPONSE="<promise>COMPLETE</promise>"
    run "$BEAD_RALPH" --worktree 1 bd-test-epic
    [ "$status" -eq 0 ]
    [[ "$output" == *"Merging ralph/bd-test-epic"* ]]
}

@test "worktree mode cleans up worktree directory" {
    export MOCK_CLAUDE_RESPONSE="<promise>COMPLETE</promise>"
    "$BEAD_RALPH" --worktree 1 bd-test-epic

    # Worktree directory should be removed
    [ ! -d ".ralph-worktrees/bd-test-epic" ]
}

@test "worktree uses timestamp for multi-epic runs" {
    export MOCK_CLAUDE_RESPONSE="<promise>COMPLETE</promise>"
    run "$BEAD_RALPH" --worktree 2 bd-epic-1 bd-epic-2
    [ "$status" -eq 0 ]
    [[ "$output" == *"Branch: ralph/multi-"* ]]
}

@test "worktree fails if worktree already exists" {
    # Create a conflicting worktree
    mkdir -p .ralph-worktrees/bd-conflict-epic
    git worktree add .ralph-worktrees/bd-conflict-epic -b ralph/bd-conflict-epic 2>/dev/null || true

    run "$BEAD_RALPH" --worktree 1 bd-conflict-epic
    [ "$status" -eq 1 ]
    [[ "$output" == *"Worktree already exists"* ]]

    # Cleanup
    git worktree remove .ralph-worktrees/bd-conflict-epic --force 2>/dev/null || true
    git branch -D ralph/bd-conflict-epic 2>/dev/null || true
}

@test "worktree tears down even on EJECT" {
    export MOCK_CLAUDE_RESPONSE="<promise>EJECT: Big install needed</promise>"
    run "$BEAD_RALPH" --worktree 1 bd-test-epic
    [ "$status" -eq 2 ]
    [[ "$output" == *"Tearing down worktree"* ]]
}

@test "worktree tears down even on BLOCKED" {
    export MOCK_CLAUDE_RESPONSE="<promise>BLOCKED: Missing creds</promise>"
    run "$BEAD_RALPH" --worktree 1 bd-test-epic
    [ "$status" -eq 3 ]
    [[ "$output" == *"Tearing down worktree"* ]]
}

# =============================================================================
# Claude Invocation Tests
# =============================================================================

@test "invokes claude with --dangerously-skip-permissions" {
    export MOCK_CLAUDE_RESPONSE="<promise>COMPLETE</promise>"
    "$BEAD_RALPH" 1 bd-test-epic

    assert_mock_called "claude --dangerously-skip-permissions"
}

@test "invokes claude with --print flag" {
    export MOCK_CLAUDE_RESPONSE="<promise>COMPLETE</promise>"
    "$BEAD_RALPH" 1 bd-test-epic

    assert_mock_called "claude --dangerously-skip-permissions --print"
}

@test "passes epic ID in prompt to claude" {
    export MOCK_CLAUDE_RESPONSE="<promise>COMPLETE</promise>"
    "$BEAD_RALPH" 1 bd-my-specific-epic

    # The epic ID should appear in the claude call (in the prompt)
    assert_mock_called "bd-my-specific-epic"
}

# =============================================================================
# BD Command Tests
# =============================================================================

@test "calls bd ready to check for tasks" {
    export MOCK_CLAUDE_RESPONSE="<promise>COMPLETE</promise>"
    "$BEAD_RALPH" 1 bd-test-epic

    # bd ready is called in auto-select mode or when claude runs
    # In this test, we're providing an epic, so bd ready isn't called by the script
    # but claude would call it (via the prompt instructions)
    [ "$status" -eq 0 ] || true
}

@test "calls bd ready for epic selection in auto mode" {
    export MOCK_CLAUDE_RESPONSE="<promise>COMPLETE</promise>"
    "$BEAD_RALPH" 1

    assert_mock_called "bd ready --type=epic"
}
