#!/bin/bash
# Ralph Pattern: Finish a Beads Epic
#
# This script runs Claude in an autonomous loop to complete all tasks in a Beads epic.
# Uses the Ralph Wiggum pattern with Steve Yegge's Beads issue tracker.
#
# Beads: https://github.com/steveyegge/beads
# - Git-backed graph issue tracker for AI agents
# - Tasks stored in .beads/ directory as JSONL
# - Hierarchical IDs: bd-a3f8 (epic) > bd-a3f8.1 (task) > bd-a3f8.1.1 (subtask)
#
# Usage: ./ralph-bead-epic.sh <max-iterations> [epic-id]
#
# Prerequisites:
# - Claude CLI installed
# - Beads CLI installed (bd): go install github.com/steveyegge/beads/cmd/bd@latest
# - A Beads epic with tasks: bd create "Epic title" && bd create "Task" -p <epic-id>

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

# Check if bd CLI is available
if ! command -v bd &> /dev/null; then
    echo "Error: Beads CLI (bd) not found."
    echo "Install: go install github.com/steveyegge/beads/cmd/bd@latest"
    exit 1
fi

echo "Starting Ralph loop for Beads epic completion..."
echo "Max iterations: $MAX_ITERATIONS"
if [ -n "$EPIC_ID" ]; then
    echo "Epic filter: $EPIC_ID"
fi
echo ""

for ((i=1; i<=MAX_ITERATIONS; i++)); do
    echo "=== Iteration $i of $MAX_ITERATIONS ==="

    # Get ready (unblocked) tasks
    if [ -n "$EPIC_ID" ]; then
        READY_TASKS=$(bd ready --json 2>/dev/null | jq -r ".[] | select(.id | startswith(\"$EPIC_ID\"))" || echo "")
    else
        READY_TASKS=$(bd ready --json 2>/dev/null || echo "")
    fi

    # Check if any tasks remain
    if [ -z "$READY_TASKS" ] || [ "$READY_TASKS" = "[]" ] || [ "$READY_TASKS" = "null" ]; then
        echo ""
        echo "=== No ready tasks remaining. Epic complete after $i iterations ==="
        exit 0
    fi

    # Get the first ready task
    NEXT_TASK=$(echo "$READY_TASKS" | jq -s '.[0]' 2>/dev/null || echo "$READY_TASKS" | head -1)

    echo "Next task: $(echo "$NEXT_TASK" | jq -r '.id // .title // "unknown"' 2>/dev/null || echo "$NEXT_TASK")"

    result=$(claude --print "
BEADS CONTEXT:
$(bd ready)

CURRENT TASK:
$NEXT_TASK

WHAT MAKES A GREAT BEAD: \
A bead represents a discrete unit of user-facing value. Complete it fully before moving on. \
Each bead should leave the codebase in a working state with passing tests. \
Beads track dependencies - only work on unblocked tasks shown by 'bd ready'. \

PROCESS: \
1. Review the current task details above. \
2. Implement it fully - code, tests, and verification. \
3. Run tests to verify nothing broke. \
4. Mark it complete: bd done <task-id> \
5. If this was the last task, output <promise>COMPLETE</promise>. \
6. Otherwise, summarize what you completed. \

BEADS COMMANDS: \
- bd ready          # List unblocked tasks \
- bd show <id>      # Show task details and history \
- bd done <id>      # Mark task complete \
- bd block <id>     # Mark task blocked \
- bd note <id> msg  # Add a note to a task \

RULES: \
- Complete ONE bead per iteration. \
- Always leave tests passing. \
- Use bd commands to update task status. \
- Only output COMPLETE when 'bd ready' would return empty. \
")

    echo "$result"

    if [[ "$result" == *"<promise>COMPLETE</promise>"* ]]; then
        echo ""
        echo "=== Epic completed after $i iterations ==="
        exit 0
    fi

    echo ""
    sleep 2  # Brief pause between iterations
done

echo ""
echo "=== Max iterations ($MAX_ITERATIONS) reached ==="
echo "Run 'bd ready' to see remaining tasks."
exit 1
