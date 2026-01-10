#!/bin/bash
# Ralph Pattern: Finish a Ticks Epic
#
# Runs Claude in an autonomous loop to complete all tasks in a Ticks epic.
# Claude operates tk directly - the script just loops until COMPLETE.
#
# Ticks: https://github.com/pengelbrecht/ticks
#
# Usage: ./ralph-ticker.sh [--worktree] <max-iterations> [epic-id...]
#
# If epic-id is omitted, automatically selects the highest priority ready epic
# and continues to the next epic when complete (multi-epic mode).
#
# Options:
#   --worktree    Run in an isolated git worktree. Creates worktree before
#                 running, merges back to main and cleans up when done.
#
# Prerequisites:
# - Claude CLI installed
# - Ticks CLI installed (tk)

set -e

SCRIPT_NAME=$(basename "$0")

# ============================================================================
# Worktree Management Functions
# ============================================================================

WORKTREE_MODE=false
WORKTREE_NAME=""
MAIN_REPO=""
WORKTREE_DIR=""

setup_worktree() {
    local name=$1
    local branch="ralph/$name"

    MAIN_REPO=$(pwd)
    WORKTREE_DIR="$MAIN_REPO/.ralph-worktrees/$name"

    echo "Setting up worktree: $WORKTREE_DIR"
    echo "Branch: $branch"

    # Ensure .ralph-worktrees/ is in .gitignore
    if [ -f "$MAIN_REPO/.gitignore" ]; then
        if ! grep -q "^\.ralph-worktrees/?$" "$MAIN_REPO/.gitignore" 2>/dev/null; then
            echo "" >> "$MAIN_REPO/.gitignore"
            echo "# Ralph worktrees (parallel execution)" >> "$MAIN_REPO/.gitignore"
            echo ".ralph-worktrees/" >> "$MAIN_REPO/.gitignore"
            echo "Added .ralph-worktrees/ to .gitignore"
        fi
    else
        echo "# Ralph worktrees (parallel execution)" > "$MAIN_REPO/.gitignore"
        echo ".ralph-worktrees/" >> "$MAIN_REPO/.gitignore"
        echo "Created .gitignore with .ralph-worktrees/"
    fi

    # Check if worktree already exists
    if [ -d "$WORKTREE_DIR" ]; then
        echo "Error: Worktree already exists at $WORKTREE_DIR"
        echo "Clean it up with: git worktree remove $WORKTREE_DIR"
        exit 1
    fi

    # Check if branch already exists
    if git show-ref --verify --quiet "refs/heads/$branch"; then
        echo "Error: Branch $branch already exists"
        echo "Delete it with: git branch -D $branch"
        exit 1
    fi

    mkdir -p "$MAIN_REPO/.ralph-worktrees"
    git worktree add "$WORKTREE_DIR" -b "$branch"

    echo "Worktree created. Changing to: $WORKTREE_DIR"
    cd "$WORKTREE_DIR"
}

teardown_worktree() {
    local name=$1
    local branch="ralph/$name"
    local exit_code=${2:-0}

    echo ""
    echo "=== Tearing down worktree ==="

    # Return to main repo
    cd "$MAIN_REPO"

    # Get the main branch name (try multiple methods)
    local main_branch=""
    # Try to get from remote HEAD
    main_branch=$(git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's@^refs/remotes/origin/@@')
    # Fall back to checking common branch names
    if [ -z "$main_branch" ]; then
        if git show-ref --verify --quiet refs/heads/main; then
            main_branch="main"
        elif git show-ref --verify --quiet refs/heads/master; then
            main_branch="master"
        else
            # Use whatever branch we were on before creating worktree
            main_branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "main")
        fi
    fi

    echo "Checking out $main_branch..."
    git checkout "$main_branch"

    # Only pull if we have a remote
    if git remote | grep -q origin; then
        echo "Pulling latest changes..."
        git pull --rebase origin "$main_branch" || true
    fi

    echo "Merging $branch into $main_branch..."
    if git merge --no-ff "$branch" -m "Merge ralph work from $branch"; then
        echo "Merge successful"

        # Push if remote exists
        if git remote | grep -q origin; then
            echo "Pushing to remote..."
            git push origin "$main_branch" || echo "Warning: Push failed, manual push may be required"
        fi
    else
        echo "Warning: Merge failed. Branch $branch preserved for manual merge."
        echo "Worktree at $WORKTREE_DIR will be removed but branch kept."
    fi

    # Cleanup worktree
    echo "Removing worktree..."
    git worktree remove "$WORKTREE_DIR" --force 2>/dev/null || true

    # Delete branch only if merge succeeded
    if git branch --merged "$main_branch" | grep -q "$branch"; then
        echo "Deleting merged branch $branch..."
        git branch -d "$branch" 2>/dev/null || true
    else
        echo "Branch $branch not merged, keeping it for manual review"
    fi

    echo "Worktree teardown complete"

    exit "$exit_code"
}

# ============================================================================
# Argument Parsing
# ============================================================================

MAX_ITERATIONS=""
EPIC_LIST=()
AUTO_MODE=false

show_usage() {
    echo "Usage: $SCRIPT_NAME [--worktree] <iterations> [epic-id...]"
    echo ""
    echo "Options:"
    echo "  --worktree    Run in isolated git worktree (auto-merges on completion)"
    echo ""
    echo "Examples:"
    echo "  $SCRIPT_NAME 20 tick-a3f8              # Complete up to 20 tasks in epic tick-a3f8"
    echo "  $SCRIPT_NAME 50 tick-c7e2              # Complete up to 50 tasks in epic tick-c7e2"
    echo "  $SCRIPT_NAME 30                        # Auto-select epics until iterations exhausted"
    echo "  $SCRIPT_NAME 20 tick-a3f8 tick-b2c4    # Work through multiple epics sequentially"
    echo "  $SCRIPT_NAME --worktree 20 tick-a3f8   # Run in worktree, merge when done"
    exit 1
}

while [[ $# -gt 0 ]]; do
    case $1 in
        --worktree)
            WORKTREE_MODE=true
            shift
            ;;
        -h|--help)
            show_usage
            ;;
        *)
            if [[ -z "$MAX_ITERATIONS" && "$1" =~ ^[0-9]+$ ]]; then
                MAX_ITERATIONS=$1
            else
                EPIC_LIST+=("$1")
            fi
            shift
            ;;
    esac
done

if [ -z "$MAX_ITERATIONS" ]; then
    show_usage
fi

# Determine epic(s) to work on
if [ ${#EPIC_LIST[@]} -eq 0 ]; then
    AUTO_MODE=true
    echo "Auto-select mode: will continue through epics until iterations exhausted"
    EPIC_ID=$(tk next --epic --json 2>/dev/null | jq -r '.id // empty')
    if [ -z "$EPIC_ID" ]; then
        echo "No ready epics found. Create one with: tk create \"...\" --type epic"
        exit 0
    fi
    echo "Selected: $EPIC_ID"
else
    EPIC_ID="${EPIC_LIST[0]}"
fi

# ============================================================================
# Worktree Setup (if enabled)
# ============================================================================

if [ "$WORKTREE_MODE" = true ]; then
    if [ ${#EPIC_LIST[@]} -gt 1 ]; then
        WORKTREE_NAME="multi-$(date +%Y%m%d-%H%M%S)"
    elif [ ${#EPIC_LIST[@]} -eq 1 ]; then
        WORKTREE_NAME="${EPIC_LIST[0]}"
    else
        WORKTREE_NAME="auto-$(date +%Y%m%d-%H%M%S)"
    fi

    setup_worktree "$WORKTREE_NAME"

    # Set trap to cleanup on exit (success, failure, or interrupt)
    trap 'teardown_worktree "$WORKTREE_NAME" $?' EXIT
fi

# ============================================================================
# Main Loop
# ============================================================================

EPIC_INDEX=0  # Track position in EPIC_LIST

echo ""
echo "Starting Ralph loop for Ticks epic..."
echo "Max iterations: $MAX_ITERATIONS"
if [ ${#EPIC_LIST[@]} -gt 1 ]; then
    echo "Epics to process: ${EPIC_LIST[*]}"
elif [ "$AUTO_MODE" = true ]; then
    echo "Mode: Auto-select epics"
fi
echo "Current epic: $EPIC_ID"
if [ "$WORKTREE_MODE" = true ]; then
    echo "Worktree: $WORKTREE_DIR"
fi
echo ""

for ((i=1; i<=MAX_ITERATIONS; i++)); do
    echo "=== Iteration $i of $MAX_ITERATIONS ==="

    result=$(claude --dangerously-skip-permissions --print "
TICKS EPIC RALPH - ITERATION $i of $MAX_ITERATIONS

Epic: $EPIC_ID

CONTEXT:
You are running in an autonomous loop. A bash script invokes you repeatedly, once per iteration.
Each iteration is a fresh Claude session - you have no memory of previous iterations.
Read the epic's notes to see what earlier iterations accomplished and learned.

PROCESS:
1. Run 'tk next $EPIC_ID' to get the next OPEN, UNBLOCKED task in this epic.
   - If no task is returned, close the epic with 'tk close $EPIC_ID --reason \"All tasks complete\"', output <promise>COMPLETE</promise>, and stop.
2. Run 'tk show $EPIC_ID' to read epic description and notes from previous iterations.
3. Implement the task fully - code, tests, verification.
4. Run tests to ensure nothing broke.
5. Mark complete: tk close <task-id> --reason \"<brief description>\"
6. Commit changes: git add -A && git commit -m \"feat(<task-id>): <brief description>\"
7. Add iteration note: tk note $EPIC_ID \"Iteration $i: <task-id> | <what you did> | <any blockers or learnings>\"
8. Summarize what you did.

RULES:
- Complete ONE task per iteration.
- ONLY work on the task returned by 'tk next'. Never pick tasks from 'tk show' children list.
- If a task is already closed or not returned by 'tk next', skip it.
- Always leave tests passing.
- Use tk commands directly (tk show, tk next, tk close, tk note, tk update).
- Always add a note after completing a task - this is required, not optional.
- Only output <promise>COMPLETE</promise> when tk next shows no remaining tasks for this epic.

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
        echo "=== Epic $EPIC_ID completed ==="

        if [ "$AUTO_MODE" = true ]; then
            # Auto mode: find next ready epic
            EPIC_ID=$(tk next --epic --json 2>/dev/null | jq -r '.id // empty')
            if [ -z "$EPIC_ID" ]; then
                echo "No more ready epics. All done!"
                exit 0
            fi
            echo ""
            echo "=== Continuing with next epic: $EPIC_ID ==="
            echo ""
        elif [ ${#EPIC_LIST[@]} -gt 1 ]; then
            # Multi-epic list mode: move to next in list
            EPIC_INDEX=$((EPIC_INDEX + 1))
            if [ $EPIC_INDEX -ge ${#EPIC_LIST[@]} ]; then
                echo "All ${#EPIC_LIST[@]} epics completed!"
                exit 0
            fi
            EPIC_ID="${EPIC_LIST[$EPIC_INDEX]}"
            echo ""
            echo "=== Continuing with next epic ($((EPIC_INDEX + 1)) of ${#EPIC_LIST[@]}): $EPIC_ID ==="
            echo ""
        else
            # Single epic mode: done
            exit 0
        fi
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
