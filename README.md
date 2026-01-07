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
4. **Set iteration limits** - Always cap iterations to control costs

## Installation

### Global Install (Recommended)

Create symlinks in a directory on your PATH (e.g., `~/.local/bin`):

```bash
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

Autonomously completes all tasks in a [Beads](https://github.com/steveyegge/beads) epic. Uses Steve Yegge's git-backed graph issue tracker designed for AI agents.

```bash
# Specify an epic
bead-ralph 20 bd-a3f8

# Auto-select highest priority ready epic
bead-ralph 30
```

**Features:**
- Auto-selects highest priority ready (unblocked) epic if none specified
- Reads epic context and previous iteration notes for continuity
- Non-interactive: makes autonomous decisions, installs small dependencies
- Ejects for large installs (>1GB), blocks on missing credentials

Each iteration:
1. Reads epic context with `bd show` (description, status, previous notes)
2. Finds unblocked tasks with `bd ready --parent <epic>`
3. Implements the highest priority task
4. Runs tests to verify nothing broke
5. Marks complete with `bd close <id>`
6. Commits with `feat(<task-id>): <description>`
7. Adds iteration note to epic for future iterations
8. Repeats until no ready tasks remain

**Prerequisites:**
- Claude CLI: `brew install claude`
- Beads CLI: `brew install steveyegge/beads/beads`

### 2. Test Coverage (`test-ralph`)

Incrementally improves test coverage by writing ONE meaningful test per iteration. Prioritizes user-facing behavior over coverage metrics.

```bash
test-ralph 50
```

Claude auto-detects your coverage command from project config (package.json, pyproject.toml, Makefile, CLAUDE.md).

**Philosophy:**
- Don't write tests just to increase coverage
- Use coverage to find untested user-facing behavior
- If code isn't worth testing, add ignore comments instead
- Mocks are a last resort—if a test fails, fix the bug, don't mock it away

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
- Monitor progress files or `bd show` to catch stuck loops

If using API tokens directly, a 50-iteration loop on a large codebase can cost $50-100+.

## References

- [Beads - Memory System for Coding Agents](https://github.com/steveyegge/beads)
- [Ralph Wiggum: Autonomous Loops](https://paddo.dev/blog/ralph-wiggum-autonomous-loops/)
- [frankbria/ralph-claude-code](https://github.com/frankbria/ralph-claude-code)
- [VentureBeat: Ralph Wiggum in AI](https://venturebeat.com/technology/how-ralph-wiggum-went-from-the-simpsons-to-the-biggest-name-in-ai-right-now)
