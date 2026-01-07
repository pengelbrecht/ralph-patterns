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

## Patterns in This Repo

### 1. Beads Epic Completion (`ralph-bead-epic.sh`)

Autonomously completes all tasks in a [Beads](https://github.com/steveyegge/beads) epic. Uses Steve Yegge's git-backed graph issue tracker designed for AI agents.

Beads stores tasks in `.beads/` as JSONL with hierarchical IDs:
- `bd-a3f8` = Epic
- `bd-a3f8.1` = Task
- `bd-a3f8.1.1` = Subtask

```bash
# Usage
./ralph-bead-epic.sh <max-iterations> <epic-id>

# Examples
./ralph-bead-epic.sh 20 bd-a3f8          # Complete up to 20 tasks in epic bd-a3f8
./ralph-bead-epic.sh 50 bd-c7e2          # Complete up to 50 tasks in epic bd-c7e2
```

Each iteration:
1. Runs `bd ready` to find unblocked tasks in the epic
2. Claude implements the highest priority task
3. Runs tests to verify nothing broke
4. Marks complete with `bd done <id>`
5. Commits with `feat(<task-id>): <description>`
6. Repeats until no ready tasks remain

**Prerequisites:**
- Claude CLI
- Beads CLI: `brew install steveyegge/beads/beads`

### 2. Test Coverage to 100% (`ralph-test-coverage.sh`)

Incrementally improves test coverage by writing ONE meaningful test per iteration. Prioritizes user-facing behavior over coverage metrics.

```bash
# With docker sandbox (safer)
./ralph-test-coverage.sh <max-iterations> [coverage-command]

# Local version (faster)
./ralph-test-coverage-local.sh 50 "pnpm coverage"
./ralph-test-coverage-local.sh 50 "pytest --cov=src"
```

**Philosophy:** Don't write tests just to increase coverage. Use coverage as a guide to find untested user-facing behavior. If code isn't worth testing, mark it with ignore comments instead.

## Setup

1. Copy the desired script to your project
2. Make it executable: `chmod +x ralph-*.sh`
3. For Beads: ensure `bd` is installed and you have tasks created
4. For coverage: ensure your coverage command works
5. Run with iteration limit and epic ID: `./ralph-bead-epic.sh 20 bd-a3f8`

## The Promise Pattern

Scripts detect completion via the `<promise>COMPLETE</promise>` marker in Claude's output. When Claude determines all work is done, it outputs this marker to break the loop.

For Beads, the loop also exits when `bd ready` returns no tasks.

## Cost Considerations

Each iteration costs API tokens. A 50-iteration loop on a large codebase can cost $50-100+. Always:
- Set conservative max iterations
- Start small and increase as needed
- Monitor `bd ready` or progress files to catch stuck loops

## References

- [Beads - Memory System for Coding Agents](https://github.com/steveyegge/beads)
- [Ralph Wiggum: Autonomous Loops](https://paddo.dev/blog/ralph-wiggum-autonomous-loops/)
- [frankbria/ralph-claude-code](https://github.com/frankbria/ralph-claude-code)
- [VentureBeat: Ralph Wiggum in AI](https://venturebeat.com/technology/how-ralph-wiggum-went-from-the-simpsons-to-the-biggest-name-in-ai-right-now)
