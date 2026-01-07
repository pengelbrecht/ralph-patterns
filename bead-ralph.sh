#!/bin/bash
# Ralph Pattern: Finish a Beads Epic
#
# Runs Claude in an autonomous loop to complete all tasks in a Beads epic.
# Claude operates bd directly - the script just loops until COMPLETE.
#
# Beads: https://github.com/steveyegge/beads
#
# Usage: ./bead-ralph.sh <max-iterations> [epic-id]
#
# If epic-id is omitted, automatically selects the highest priority ready epic.
#
# Prerequisites:
# - Claude CLI installed
# - Beads CLI installed (bd)

set -e

SCRIPT_NAME=$(basename "$0")

if [ -z "$1" ]; then
    echo "Usage: $SCRIPT_NAME <iterations> [epic-id]"
    echo ""
    echo "Examples:"
    echo "  $SCRIPT_NAME 20 bd-a3f8    # Complete up to 20 tasks in epic bd-a3f8"
    echo "  $SCRIPT_NAME 50 bd-c7e2    # Complete up to 50 tasks in epic bd-c7e2"
    echo "  $SCRIPT_NAME 30            # Auto-select highest priority ready epic"
    exit 1
fi

MAX_ITERATIONS=$1

if [ -z "$2" ]; then
    echo "No epic specified, finding highest priority ready epic..."
    EPIC_ID=$(bd ready --type=epic --limit=1 --sort=priority --json 2>/dev/null | jq -r '.[0].id // empty')
    if [ -z "$EPIC_ID" ]; then
        echo "Error: No ready epics found. Create one with: bd create --type=epic --title=\"...\""
        exit 1
    fi
    echo "Selected: $EPIC_ID"
else
    EPIC_ID="$2"
fi

echo "Starting Ralph loop for Beads epic..."
echo "Max iterations: $MAX_ITERATIONS"
echo "Epic: $EPIC_ID"
echo ""

for ((i=1; i<=MAX_ITERATIONS; i++)); do
    echo "=== Iteration $i of $MAX_ITERATIONS ==="

    result=$(claude --dangerously-skip-permissions --print "
BEADS EPIC RALPH - ITERATION $i of $MAX_ITERATIONS

Epic: $EPIC_ID

CONTEXT:
You are running in an autonomous loop. A bash script invokes you repeatedly, once per iteration.
Each iteration is a fresh Claude session - you have no memory of previous iterations.
Read the epic's comments to see what earlier iterations accomplished and learned.

PROCESS:
1. Run 'bd show $EPIC_ID' to see epic context, children status, and notes from previous iterations.
2. Run 'bd ready --parent $EPIC_ID' to see unblocked tasks for this epic.
3. If no tasks remain, output <promise>COMPLETE</promise> and stop.
4. Pick the highest priority ready task.
5. Implement it fully - code, tests, verification.
6. Run tests to ensure nothing broke.
7. Mark complete: bd close <task-id>
8. Commit changes: git add -A && git commit -m \"feat(<task-id>): <brief description>\"
9. Add iteration note: bd comments add $EPIC_ID \"Iteration $i: <task-id> | <what you did> | <any blockers or learnings>\"
10. Summarize what you did.

RULES:
- Complete ONE task per iteration.
- Always leave tests passing.
- Only work on tasks under epic $EPIC_ID.
- Use bd commands directly (bd show, bd ready, bd close, bd comments add, bd update).
- Always add a comment after completing a task - this is required, not optional.
- Only output <promise>COMPLETE</promise> when bd ready shows no remaining tasks for this epic.

AUTONOMY:
- You are running NON-INTERACTIVELY. Never ask questions or wait for input.
- Make smart autonomous decisions - install dependencies, choose reasonable defaults.
- For small installs (Go, Node, Python packages): just do it.
- For large installs (>1GB like Xcode, Android SDK, Docker images): output <promise>EJECT: <reason></promise> instead.
- If truly blocked (missing credentials, unclear requirements): output <promise>BLOCKED: <reason></promise>.
")

    echo "$result"

    if [[ "$result" == *"<promise>COMPLETE</promise>"* ]]; then
        echo ""
        echo "=== Epic completed after $i iterations ==="
        exit 0
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
    sleep 2
done

echo ""
echo "=== Max iterations ($MAX_ITERATIONS) reached ==="
exit 1
