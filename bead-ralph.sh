#!/bin/bash
# Ralph Pattern: Finish a Beads Epic
#
# Runs Claude in an autonomous loop to complete all tasks in a Beads epic.
# Claude operates bd directly - the script just loops until COMPLETE.
#
# Beads: https://github.com/steveyegge/beads
#
# Usage: ./bead-ralph.sh [--worktree] <max-iterations> [epic-id...]
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
# - Beads CLI installed (bd)

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

    # Get current main branch name
    local main_branch=$(git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's@^refs/remotes/origin/@@' || echo "main")

    echo "Checking out $main_branch..."
    git checkout "$main_branch"

    echo "Pulling latest changes..."
    git pull --rebase origin "$main_branch" || true

    echo "Merging $branch into $main_branch..."
    if git merge --no-ff "$branch" -m "Merge ralph work from $branch"; then
        echo "Merge successful"

        # Handle any beads JSONL conflicts that might have occurred
        if git diff --name-only --diff-filter=U 2>/dev/null | grep -q ".beads/issues.jsonl"; then
            echo "Resolving beads JSONL conflict..."
            git checkout --theirs .beads/issues.jsonl
            git add .beads/issues.jsonl
            git commit --no-edit
        fi

        # Sync beads and push
        echo "Syncing beads..."
        bd sync || true

        echo "Pushing to remote..."
        git push origin "$main_branch" || echo "Warning: Push failed, manual push may be required"
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
    echo "  $SCRIPT_NAME 20 bd-a3f8              # Complete up to 20 tasks in epic bd-a3f8"
    echo "  $SCRIPT_NAME 50 bd-c7e2              # Complete up to 50 tasks in epic bd-c7e2"
    echo "  $SCRIPT_NAME 30                      # Auto-select epics until iterations exhausted"
    echo "  $SCRIPT_NAME 20 bd-a3f8 bd-b2c4      # Work through multiple epics sequentially"
    echo "  $SCRIPT_NAME --worktree 20 bd-a3f8   # Run in worktree, merge when done"
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
    EPIC_ID=$(bd ready --type=epic --limit=1 --sort=priority --json 2>/dev/null | jq -r '.[0].id // empty')
    if [ -z "$EPIC_ID" ]; then
        echo "No ready epics found. Create one with: bd create --type=epic --title=\"...\""
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
echo "Starting Ralph loop for Beads epic..."
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
BEADS EPIC RALPH - ITERATION $i of $MAX_ITERATIONS

Epic: $EPIC_ID

CONTEXT:
You are running in an autonomous loop. A bash script invokes you repeatedly, once per iteration.
Each iteration is a fresh Claude session - you have no memory of previous iterations.
Read the epic's comments to see what earlier iterations accomplished and learned.

PROCESS:
1. Run 'bd ready --parent $EPIC_ID' to get the list of OPEN, UNBLOCKED tasks.
   - ONLY tasks from this output are valid to work on.
   - If empty, close the epic with 'bd close $EPIC_ID', output <promise>COMPLETE</promise>, and stop.
2. Run 'bd show $EPIC_ID' to read epic description and comments from previous iterations.
3. Pick the highest priority task FROM THE bd ready OUTPUT (not from bd show).
4. Implement it fully - code, tests, verification.
5. Run tests to ensure nothing broke.
6. Mark complete: bd close <task-id>
7. Commit changes: git add -A && git commit -m \"feat(<task-id>): <brief description>\"
8. Add iteration note: bd comments add $EPIC_ID \"Iteration $i: <task-id> | <what you did> | <any blockers or learnings>\"
9. Summarize what you did.

RULES:
- Complete ONE task per iteration.
- ONLY work on tasks that appear in 'bd ready' output. Never pick tasks from 'bd show' children list.
- If a task is already closed or not in 'bd ready', skip it - do not verify or report on it.
- Always leave tests passing.
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
        echo "=== Epic $EPIC_ID completed ==="

        if [ "$AUTO_MODE" = true ]; then
            # Auto mode: find next ready epic
            EPIC_ID=$(bd ready --type=epic --limit=1 --sort=priority --json 2>/dev/null | jq -r '.[0].id // empty')
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
