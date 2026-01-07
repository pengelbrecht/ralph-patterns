#!/bin/bash
# Ralph Pattern: Finish a Bead Epic
#
# This script runs Claude in an autonomous loop to complete all tasks in an epic.
# Uses the Ralph Wiggum pattern: iterate until COMPLETE or max iterations reached.
#
# Usage: ./ralph-bead-epic.sh <max-iterations> [progress-file]
#
# Prerequisites:
# - Claude CLI installed
# - @epic-progress.txt file with current epic status (or specify custom file)
# - Docker sandbox recommended for safety

set -e

if [ -z "$1" ]; then
    echo "Usage: $0 <iterations> [progress-file]"
    exit 1
fi

MAX_ITERATIONS=$1
PROGRESS_FILE="${2:-@epic-progress.txt}"

# Ensure progress file exists
if [ ! -f "$PROGRESS_FILE" ]; then
    echo "Error: Progress file '$PROGRESS_FILE' not found."
    echo "Create it with your epic tasks, e.g.:"
    echo ""
    echo "  # Epic: User Authentication"
    echo "  - [ ] Implement login endpoint"
    echo "  - [ ] Add session management"
    echo "  - [ ] Write integration tests"
    exit 1
fi

echo "Starting Ralph loop for epic completion..."
echo "Max iterations: $MAX_ITERATIONS"
echo "Progress file: $PROGRESS_FILE"
echo ""

for ((i=1; i<=MAX_ITERATIONS; i++)); do
    echo "=== Iteration $i of $MAX_ITERATIONS ==="

    result=$(claude --print "@$PROGRESS_FILE" "
WHAT MAKES A GREAT BEAD: \
A bead represents a discrete unit of user-facing value. Complete it fully before moving on. \
Each bead should leave the codebase in a working state with passing tests. \

PROCESS: \
1. Read the epic progress file to understand remaining tasks. \
2. Pick the NEXT UNCOMPLETED task (marked with [ ]). \
3. Implement it fully - code, tests, and verification. \
4. Mark it complete in the progress file (change [ ] to [x]). \
5. Run tests to verify nothing broke. \
6. If ALL tasks are marked [x], output <promise>COMPLETE</promise>. \
7. Otherwise, summarize what you completed and what's next. \

RULES: \
- Complete ONE bead per iteration. \
- Always leave tests passing. \
- Update the progress file after each bead. \
- Only output COMPLETE when genuinely done. \
")

    echo "$result"

    if [[ "$result" == *"<promise>COMPLETE</promise>"* ]]; then
        echo ""
        echo "=== Epic completed after $i iterations ==="

        # Optional: Send notification (uncomment if tt is available)
        # tt notify "Ralph: Epic completed after $i iterations"

        exit 0
    fi

    echo ""
    sleep 2  # Brief pause between iterations
done

echo ""
echo "=== Max iterations ($MAX_ITERATIONS) reached without completion ==="
echo "Check $PROGRESS_FILE for remaining tasks."
exit 1
