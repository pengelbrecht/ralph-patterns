# Ralph Patterns

Reusable patterns for autonomous AI development loops using the **Ralph Wiggum technique**.

## What is the Ralph Pattern?

The Ralph Wiggum technique (named after The Simpsons character) is a method for running AI agents in autonomous loops until completion. Created by Geoffrey Huntley, it inverts the typical AI coding workflow:

> Instead of carefully reviewing each step, you define success criteria upfront and let the agent iterate toward them. Failures become data.

The core pattern is deceptively simple:

```bash
while :; do cat PROMPT.md | claude ; done
```

This loop continuously re-feeds Claude the original prompt, allowing it to iterate toward completion criteria across multiple invocations.

### Key Principles

1. **Define clear completion criteria** - The agent must know when it's done
2. **One task per iteration** - Prevents scope creep and ensures progress
3. **State persists via files** - Git history, Beads tasks, and modified code carry context
4. **Set iteration limits** - Always cap iterations to stay within usage limits

## What is Beads?

[Beads](https://github.com/steveyegge/beads) is a git-native issue tracker designed for AI agents. Created by Steve Yegge, it solves a key problem: how do you give an AI agent persistent memory across sessions?

Unlike traditional issue trackers (Jira, GitHub Issues), Beads stores issues directly in your repo as JSONL files. This means Claude can read and write tasks without API integrations—it just uses the `bd` CLI.

**Key features for AI workflows:**

- **Hierarchical IDs**: `bd-a3f8` (epic) → `bd-a3f8.1` (task) → `bd-a3f8.1.1` (subtask)
- **Dependencies**: Tasks can block other tasks, modeling real-world constraints
- **Ready queue**: `bd ready` returns only unblocked work—no manual prioritization
- **Comments**: Notes persist context across Claude sessions (what was tried, what failed)
- **Git-native**: Issues sync via normal git push/pull, no external service needed

This makes Beads ideal for Ralph loops: Claude can pick up where it left off, see what previous iterations accomplished, and work through a dependency graph autonomously.

## Installation

### Global Install (Recommended)

Clone this repo and create symlinks in a directory on your PATH:

```bash
git clone https://github.com/pengelbrecht/ralph-patterns.git
ln -sf /path/to/ralph-patterns/bead-ralph.sh ~/.local/bin/bead-ralph
ln -sf /path/to/ralph-patterns/test-ralph.sh ~/.local/bin/test-ralph
```

Then run from any repo:

```bash
bead-ralph 20 bd-a3f8
test-ralph 30
```

Updates to this repo are automatically reflected via symlinks.

### Per-Project

Copy scripts directly into your project and run locally.

## Patterns

### 1. Beads Epic Completion (`bead-ralph`)

Autonomously completes all tasks in a Beads epic.

```bash
# Complete a specific epic
bead-ralph 20 bd-a3f8

# Auto-select mode: work through epics until iterations exhausted
bead-ralph 50
```

**Features:**
- **Multi-epic mode**: When no epic specified, continues to next epic after completing one—perfect for overnight runs
- **Auto-select**: Picks highest priority ready (unblocked) epic
- **Context-aware**: Reads epic description and previous iteration notes
- **Non-interactive**: Makes autonomous decisions, installs small dependencies
- **Safe exits**: Ejects for large installs (>1GB), blocks on missing credentials

**Each iteration:**
1. Reads epic context with `bd show` (description, status, previous notes)
2. Finds unblocked tasks with `bd ready --parent <epic>`
3. Implements the highest priority task
4. Runs tests to verify nothing broke
5. Marks complete with `bd close <id>`
6. Commits with `feat(<task-id>): <description>`
7. Adds iteration note to epic for future iterations
8. Closes epic and moves to next (in auto-select mode) or exits

**Prerequisites:**
- Claude CLI
- Beads CLI: `brew install steveyegge/beads/beads`

### 2. Test Coverage (`test-ralph`)

Incrementally improves test coverage by writing ONE meaningful test per iteration. Prioritizes user-facing behavior over coverage metrics.

```bash
test-ralph 50
```

Claude auto-detects your coverage command from project config (package.json, pyproject.toml, Makefile, CLAUDE.md).

**Philosophy:**
- Don't write tests just to increase coverage numbers
- Use coverage to find untested user-facing behavior
- If code isn't worth testing, add ignore comments instead
- Mocks are a last resort—don't mock away real behavior
- Does NOT fix failing tests—that's a separate concern

**Prerequisites:**
- Claude CLI
- Coverage tool configured in your project

## Signal Protocol

Scripts detect completion and errors via promise markers in Claude's output:

| Signal | Meaning | Exit Code |
|--------|---------|-----------|
| `<promise>COMPLETE</promise>` | All work done | 0 |
| `<promise>EJECT: reason</promise>` | Large install or manual step needed | 2 |
| `<promise>BLOCKED: reason</promise>` | Missing credentials or unclear requirements | 3 |
| `<promise>NO_COVERAGE_CONFIGURED</promise>` | No coverage command found (test-ralph only) | 1 |

## Autonomy Rules

Both scripts run with `--dangerously-skip-permissions` and instruct Claude to:

- **Never ask questions** - Make autonomous decisions
- **Install small dependencies** - Go, Node, Python packages, test frameworks
- **Eject on large installs** - Xcode, Android SDK, Docker images (>1GB)
- **Block on true blockers** - Missing credentials, unclear requirements

## Usage Considerations

Most Claude Code users have a Claude Pro/Max subscription with usage limits rather than per-token costs. Still:
- Set reasonable max iterations to avoid burning through your daily limit
- Start small and increase as needed
- Monitor progress with `bd show <epic>` to catch stuck loops

If using API tokens directly, a 50-iteration loop on a large codebase can cost $50-100+.

## References

- [Beads - Memory System for Coding Agents](https://github.com/steveyegge/beads)
- [Ralph Wiggum: Autonomous Loops](https://paddo.dev/blog/ralph-wiggum-autonomous-loops/)
- [frankbria/ralph-claude-code](https://github.com/frankbria/ralph-claude-code)
