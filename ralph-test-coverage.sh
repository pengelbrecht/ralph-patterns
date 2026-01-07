#!/bin/bash
# Ralph Pattern: Drive Test Coverage to 100%
#
# This script runs Claude in an autonomous loop to incrementally improve test coverage.
# Uses the Ralph Wiggum pattern: iterate, writing ONE meaningful test per iteration,
# until 100% statement coverage is reached.
#
# Usage: ./ralph-test-coverage.sh <max-iterations>
#
# Prerequisites:
# - Claude CLI installed (or docker sandbox)
# - Coverage tool configured in project (package.json, pyproject.toml, Makefile, etc.)
# - @test-coverage-progress.txt for tracking progress notes

set -e

if [ -z "$1" ]; then
    echo "Usage: $0 <iterations>"
    echo ""
    echo "Claude will determine the coverage command from your project config"
    echo "(package.json, pyproject.toml, Makefile, CLAUDE.md, etc.)"
    exit 1
fi

MAX_ITERATIONS=$1
PROGRESS_FILE="@test-coverage-progress.txt"

# Initialize progress file if it doesn't exist
if [ ! -f "$PROGRESS_FILE" ]; then
    echo "# Test Coverage Progress" > "$PROGRESS_FILE"
    echo "# Format: iteration | what was tested | coverage % | learnings" >> "$PROGRESS_FILE"
    echo "" >> "$PROGRESS_FILE"
fi

echo "Starting Ralph loop for test coverage..."
echo "Max iterations: $MAX_ITERATIONS"
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
add coverage ignore comments appropriate for this project's language instead of writing low-value tests. \

MOCKS - BE SKEPTICAL: \
Mocks are a last resort, not a first choice. If a test fails, FIX THE BUG - do not mock away the failure. \
Only mock: external services (APIs, databases), time/randomness, or truly slow operations. \
Never mock: the code under test, internal modules, or anything that hides real behavior. \
If you find yourself mocking extensively, the code may need refactoring, not more mocks. \

PROCESS: \
1. Determine how to run coverage for this project (check package.json, pyproject.toml, Makefile, CLAUDE.md, etc.). \
   If you cannot determine the coverage command, output <promise>NO_COVERAGE_CONFIGURED</promise> and stop. \
2. Run coverage to see which files have low coverage. \
3. Read the uncovered lines and identify the most important USER-FACING FEATURE that lacks tests. \
   Prioritize: error handling users will hit, CLI commands, git operations, file parsing. \
   Deprioritize: internal utilities, edge cases users won't encounter, boilerplate. \
4. Write ONE meaningful test that validates the feature works correctly for users. \
5. Run coverage again - coverage should increase as a side effect of testing real behavior. \
6. Commit with message: test(<file>): <describe the user behavior being tested> \
7. Append super-concise notes to $PROGRESS_FILE: what you tested, coverage %, any learnings. \

RULES: \
- Write ONE test per iteration. \
- Always append to $PROGRESS_FILE after each test - this is required, not optional. \
- If statement coverage reaches 100%, output <promise>COMPLETE</promise>. \
")

    echo "$result"

    if [[ "$result" == *"<promise>COMPLETE</promise>"* ]]; then
        echo ""
        echo "100% coverage reached after $i iterations!"
        exit 0
    fi

    if [[ "$result" == *"<promise>NO_COVERAGE_CONFIGURED</promise>"* ]]; then
        echo ""
        echo "=== Could not determine coverage command for this project ==="
        echo "Add test/coverage instructions to CLAUDE.md or configure in package.json/pyproject.toml"
        exit 1
    fi

    echo ""
done

echo ""
echo "=== Max iterations ($MAX_ITERATIONS) reached ==="
echo "Check $PROGRESS_FILE for progress notes."
exit 1
