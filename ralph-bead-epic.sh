#!/bin/bash
# Ralph Pattern: Finish a Beads Epic
#
# Runs Claude in an autonomous loop to complete all tasks in a Beads epic.
# Claude operates bd directly - the script just loops until COMPLETE.
#
# Beads: https://github.com/steveyegge/beads
#
# Usage: ./ralph-bead-epic.sh <max-iterations> [epic-id]
#
# Prerequisites:
# - Claude CLI installed
# - Beads CLI installed (bd)

set -e

if [ -z "$1" ]; then
    echo "Usage: $0 <iterations> [epic-id]"
    echo ""
    echo "Examples:"
    echo "  $0 20                  # Work on any ready task"
    echo "  $0 20 bd-a3f8          # Work only on tasks in epic bd-a3f8"
    exit 1
fi

MAX_ITERATIONS=$1
EPIC_ID="${2:-}"

echo "Starting Ralph loop for Beads epic..."
echo "Max iterations: $MAX_ITERATIONS"
[ -n "$EPIC_ID" ] && echo "Epic: $EPIC_ID"
echo ""

for ((i=1; i<=MAX_ITERATIONS; i++)); do
    echo "=== Iteration $i of $MAX_ITERATIONS ==="

    EPIC_FILTER=""
    [ -n "$EPIC_ID" ] && EPIC_FILTER="Focus only on tasks under epic $EPIC_ID."

    result=$(claude --print "
BEADS EPIC RALPH - ITERATION $i

$EPIC_FILTER

PROCESS:
1. Run 'bd ready' to see unblocked tasks.
2. If no tasks remain, output <promise>COMPLETE</promise> and stop.
3. Pick the highest priority ready task.
4. Implement it fully - code, tests, verification.
5. Run tests to ensure nothing broke.
6. Mark complete: bd done <task-id>
7. Add iteration note to epic: bd note <epic-id> \"Iteration $i: <what you completed>\"
8. Summarize what you did.

RULES:
- Complete ONE task per iteration.
- Always leave tests passing.
- Use bd commands directly (bd ready, bd show, bd done, bd note, bd block).
- Only output <promise>COMPLETE</promise> when bd ready shows no remaining tasks.
")

    echo "$result"

    if [[ "$result" == *"<promise>COMPLETE</promise>"* ]]; then
        echo ""
        echo "=== Epic completed after $i iterations ==="
        exit 0
    fi

    echo ""
    sleep 2
done

echo ""
echo "=== Max iterations ($MAX_ITERATIONS) reached ==="
exit 1
