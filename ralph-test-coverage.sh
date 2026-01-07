#!/bin/bash
# Ralph Pattern: Drive Test Coverage to 100%
#
# This script runs Claude in an autonomous loop to incrementally improve test coverage.
# Uses the Ralph Wiggum pattern: iterate, writing ONE meaningful test per iteration,
# until 100% statement coverage is reached.
#
# Usage: ./ralph-test-coverage.sh <max-iterations> [coverage-command]
#
# Prerequisites:
# - Claude CLI installed (or docker sandbox)
# - Coverage tool configured (pnpm coverage, npm run coverage, pytest --cov, etc.)
# - @test-coverage-progress.txt for tracking progress notes

set -e

if [ -z "$1" ]; then
    echo "Usage: $0 <iterations> [coverage-command]"
    echo ""
    echo "Examples:"
    echo "  $0 50                           # Uses 'pnpm coverage' by default"
    echo "  $0 50 'npm run coverage'"
    echo "  $0 50 'pytest --cov=src'"
    exit 1
fi

MAX_ITERATIONS=$1
COVERAGE_CMD="${2:-pnpm coverage}"
PROGRESS_FILE="@test-coverage-progress.txt"

# Initialize progress file if it doesn't exist
if [ ! -f "$PROGRESS_FILE" ]; then
    echo "# Test Coverage Progress" > "$PROGRESS_FILE"
    echo "# Format: iteration | what was tested | coverage % | learnings" >> "$PROGRESS_FILE"
    echo "" >> "$PROGRESS_FILE"
fi

echo "Starting Ralph loop for test coverage..."
echo "Max iterations: $MAX_ITERATIONS"
echo "Coverage command: $COVERAGE_CMD"
echo ""

for ((i=1; i<=MAX_ITERATIONS; i++)); do
    echo "=== Iteration $i of $MAX_ITERATIONS ==="

    # Use docker sandbox for safety (remove 'docker sandbox run' if running locally)
    result=$(docker sandbox run claude --dangerously-skip-permissions "@$PROGRESS_FILE" "
WHAT MAKES A GREAT TEST: \
A great test covers behavior users depend on. It tests a feature that, if broken, would frustrate or block users. \
It validates real workflows - not implementation details. It catches regressions before users do. \
Do NOT write tests just to increase coverage. Use coverage as a guide to find UNTESTED USER-FACING BEHAVIOR. \
If uncovered code is not worth testing (boilerplate, unreachable error branches, internal plumbing), \
add /* v8 ignore next */ or /* v8 ignore start */ comments instead of writing low-value tests. \

PROCESS: \
1. Run $COVERAGE_CMD to see which files have low coverage. \
2. Read the uncovered lines and identify the most important USER-FACING FEATURE that lacks tests. \
   Prioritize: error handling users will hit, CLI commands, git operations, file parsing. \
   Deprioritize: internal utilities, edge cases users won't encounter, boilerplate. \
3. Write ONE meaningful test that validates the feature works correctly for users. \
4. Run $COVERAGE_CMD again - coverage should increase as a side effect of testing real behavior. \
5. Commit with message: test(<file>): <describe the user behavior being tested> \
6. Append super-concise notes to $PROGRESS_FILE: what you tested, coverage %, any learnings. \

ONLY WRITE ONE TEST PER ITERATION. \
If statement coverage reaches 100%, output <promise>COMPLETE</promise>. \
")

    echo "$result"

    if [[ "$result" == *"<promise>COMPLETE</promise>"* ]]; then
        echo ""
        echo "100% coverage reached, exiting."

        # Optional: Send notification (uncomment if tt is available)
        # tt notify "AI Hero CLI: 100% coverage after $i iterations"

        exit 0
    fi

    echo ""
done

echo ""
echo "=== Max iterations ($MAX_ITERATIONS) reached ==="
echo "Check $PROGRESS_FILE for progress notes."
exit 1
