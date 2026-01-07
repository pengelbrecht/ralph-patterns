#!/bin/bash
# Ralph Pattern: Drive Test Coverage to Completion
#
# Runs Claude in an autonomous loop to incrementally improve test coverage.
# Uses the Ralph Wiggum pattern: iterate, writing ONE meaningful test per iteration,
# until all user-facing behavior is tested.
#
# Usage: ./test-ralph.sh <max-iterations>
#
# Prerequisites:
# - Claude CLI installed
# - Coverage tool configured in project (package.json, pyproject.toml, Makefile, etc.)

set -e

SCRIPT_NAME=$(basename "$0")

if [ -z "$1" ]; then
    echo "Usage: $SCRIPT_NAME <iterations>"
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

    # Read progress file for inclusion in prompt
    PROGRESS_CONTENT=$(cat "$PROGRESS_FILE" 2>/dev/null || echo "No progress yet")

    result=$(claude --dangerously-skip-permissions --print "
TEST COVERAGE RALPH - ITERATION $i of $MAX_ITERATIONS

YOU ARE IN AUTONOMOUS MODE. Execute the process below. Do NOT ask questions. Do NOT describe files. Just DO the work.

CONTEXT:
You are running in an autonomous loop. A bash script invokes you repeatedly, once per iteration.
Each iteration is a fresh Claude session - you have no memory of previous iterations.

PREVIOUS PROGRESS (from $PROGRESS_FILE):
$PROGRESS_CONTENT

WHAT MAKES A GREAT TEST: \
A great test covers behavior users depend on. It tests a feature that, if broken, would frustrate or block users. \
It validates real workflows - not implementation details. It catches regressions before users do. \
Do NOT write tests just to increase coverage. Use coverage as a guide to find UNTESTED USER-FACING BEHAVIOR. \
If uncovered code is not worth testing (boilerplate, unreachable error branches, internal plumbing), \
add coverage ignore comments appropriate for this project's language instead of writing low-value tests. \

MOCKS - BE SKEPTICAL: \
Mocks are a last resort, not a first choice. Do not mock away real behavior. \
Only mock: external services (APIs, databases), time/randomness, or truly slow operations. \
Never mock: the code under test, internal modules, or anything that hides real behavior. \
If you find yourself mocking extensively, the code may need refactoring, not more mocks. \

PROCESS (execute immediately - do not ask questions): \
1. Determine how to run coverage for this project (check package.json, pyproject.toml, Makefile, CLAUDE.md, etc.). \
   If this repo has no testable code or no coverage tool, output <promise>NO_COVERAGE_CONFIGURED</promise> and stop. \
2. Run coverage to see which files have low coverage. \
3. Read the uncovered lines and identify the most important USER-FACING FEATURE that lacks tests. \
   Prioritize: error handling users will hit, CLI commands, git operations, file parsing. \
   Deprioritize: internal utilities, edge cases users won't encounter, boilerplate. \
4. Write ONE meaningful test that validates the feature works correctly for users. \
   OR if remaining uncovered code is not worth testing, add ignore comments and skip writing a test. \
5. Run coverage again. \
6. Commit with message: test(<file>): <describe the user behavior being tested> \
   Or if only adding ignore comments: chore(<file>): mark <description> as not needing coverage \
7. Append super-concise notes to $PROGRESS_FILE: what you tested, coverage %, any learnings. \

RULES: \
- Write ONE test per iteration (or add ignore comments if code isn't worth testing). \
- DO NOT fix failing tests. Your job is coverage, not bug fixing. Note failures in $PROGRESS_FILE and move on. \
- Always append to $PROGRESS_FILE after each iteration - this is required, not optional. \
- Output <promise>COMPLETE</promise> when ALL user-facing behavior is tested. \
  This can be 100% coverage, OR lower if remaining uncovered code has ignore comments. \

AUTONOMY: \
- You are running NON-INTERACTIVELY. Never ask questions or wait for input. \
- Make smart autonomous decisions - install test dependencies, choose reasonable defaults. \
- For small installs (test frameworks, coverage tools): just do it. \
- For large installs (>1GB): output <promise>EJECT: <reason></promise> instead. \
- If truly blocked (missing credentials, unclear requirements): output <promise>BLOCKED: <reason></promise>. \
")

    echo "$result"

    if [[ "$result" == *"<promise>COMPLETE</promise>"* ]]; then
        echo ""
        echo "=== Coverage complete after $i iterations ==="
        exit 0
    fi

    if [[ "$result" == *"<promise>NO_COVERAGE_CONFIGURED</promise>"* ]]; then
        echo ""
        echo "=== Could not determine coverage command for this project ==="
        echo "Add test/coverage instructions to CLAUDE.md or configure in package.json/pyproject.toml"
        exit 1
    fi

    if [[ "$result" == *"<promise>EJECT:"* ]]; then
        echo ""
        echo "=== Ejected - manual intervention required ==="
        exit 2
    fi

    if [[ "$result" == *"<promise>BLOCKED:"* ]]; then
        echo ""
        echo "=== Blocked - cannot proceed ==="
        exit 3
    fi

    echo ""
done

echo ""
echo "=== Max iterations ($MAX_ITERATIONS) reached ==="
echo "Check $PROGRESS_FILE for progress notes."
exit 1
