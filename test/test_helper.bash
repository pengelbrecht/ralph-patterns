#!/bin/bash
# Test helper for bead-ralph.sh BATS tests

# Get the directory containing the test files
TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$TEST_DIR")"

# Path to the script under test
BEAD_RALPH="$PROJECT_ROOT/bead-ralph.sh"

# Setup mock environment
setup_mocks() {
    # Add mocks to PATH (must come first)
    export PATH="$TEST_DIR/mocks:$PATH"

    # Create log file for mock calls
    export MOCK_LOG_FILE="$BATS_TEST_TMPDIR/mock_calls.log"
    touch "$MOCK_LOG_FILE"
}

# Create a temporary git repo for testing
setup_test_repo() {
    export TEST_REPO="$BATS_TEST_TMPDIR/test-repo"
    mkdir -p "$TEST_REPO"
    cd "$TEST_REPO"

    git init --quiet
    git config user.email "test@test.com"
    git config user.name "Test User"

    # Create initial commit
    echo "# Test Repo" > README.md
    git add README.md
    git commit --quiet -m "Initial commit"

    # Create a fake .beads directory
    mkdir -p .beads
    echo '{}' > .beads/config.yaml
    touch .beads/issues.jsonl
    git add .beads
    git commit --quiet -m "Add beads"
}

# Cleanup test repo
teardown_test_repo() {
    if [ -n "$TEST_REPO" ] && [ -d "$TEST_REPO" ]; then
        cd /
        # Clean up any worktrees first
        if [ -d "$TEST_REPO/.ralph-worktrees" ]; then
            for wt in "$TEST_REPO/.ralph-worktrees"/*; do
                [ -d "$wt" ] && git -C "$TEST_REPO" worktree remove "$wt" --force 2>/dev/null || true
            done
        fi
        rm -rf "$TEST_REPO"
    fi
}

# Assert that a mock was called with specific arguments
assert_mock_called() {
    local expected="$1"
    grep -q "$expected" "$MOCK_LOG_FILE"
}

# Assert that a mock was called N times
assert_mock_call_count() {
    local pattern="$1"
    local expected_count="$2"
    local actual_count
    actual_count=$(grep -c "$pattern" "$MOCK_LOG_FILE" || echo 0)
    [ "$actual_count" -eq "$expected_count" ]
}

# Get mock call log
get_mock_calls() {
    cat "$MOCK_LOG_FILE"
}
