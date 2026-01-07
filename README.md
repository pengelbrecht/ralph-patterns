# Ralph Patterns

Reusable patterns for autonomous AI development loops using the **Ralph Wiggum technique**.

## What is the Ralph Pattern?

The Ralph Wiggum technique (named after The Simpsons character) is a method for running AI agents in autonomous loops until completion. Created by Geoffrey Huntley, it inverts the typical AI coding workflow:

> Instead of carefully reviewing each step, you define success criteria upfront and let the agent iterate toward them. Failures become data.

The core pattern is deceptively simple:

```bash
while :; do cat PROMPT.md | claude ; done
```

This infinite loop continuously re-feeds Claude the original prompt, allowing it to iterate toward completion criteria across multiple invocations.

### Key Principles

1. **Define clear completion criteria** - The agent must know when it's done
2. **One task per iteration** - Prevents scope creep and ensures progress
3. **State persists via files** - Progress files, git history, and modified code carry context
4. **Set iteration limits** - Always cap iterations to control costs

### When to Use Ralph Loops

**Good for:**
- Large refactors (framework migrations, dependency upgrades)
- Test coverage expansion
- Batch standardization (API versions, code style)
- Epic/task completion with clear acceptance criteria

**Avoid for:**
- Ambiguous requirements
- Architectural decisions requiring judgment
- Security-sensitive code
- Exploratory work

## Patterns in This Repo

### 1. Bead Epic Completion (`ralph-bead-epic.sh`)

Autonomously completes all tasks in an epic/feature. Each iteration picks the next uncompleted task, implements it fully, marks it done, and continues until all tasks are complete.

```bash
# Usage
./ralph-bead-epic.sh <max-iterations> [progress-file]

# Example
./ralph-bead-epic.sh 20 @epic-progress.txt
```

**Progress file format:**
```markdown
# Epic: User Authentication

- [ ] Implement login endpoint
- [ ] Add session management
- [x] Create user model (completed)
```

### 2. Test Coverage to 100% (`ralph-test-coverage.sh`)

Incrementally improves test coverage by writing ONE meaningful test per iteration. Prioritizes user-facing behavior over coverage metrics.

```bash
# With docker sandbox (safer)
./ralph-test-coverage.sh <max-iterations> [coverage-command]

# Local version (faster)
./ralph-test-coverage-local.sh 50 "pnpm coverage"
./ralph-test-coverage-local.sh 50 "pytest --cov=src"
```

**Philosophy:** Don't write tests just to increase coverage. Use coverage as a guide to find untested user-facing behavior. If code isn't worth testing, mark it with ignore comments.

## Setup

1. Copy the desired script to your project
2. Make it executable: `chmod +x ralph-*.sh`
3. Create the required progress file (see `examples/`)
4. Run with iteration limit: `./ralph-bead-epic.sh 20`

## The Promise Pattern

Scripts detect completion via the `<promise>COMPLETE</promise>` marker in Claude's output. When Claude determines all work is done, it outputs this marker to break the loop.

## Cost Considerations

Each iteration costs API tokens. A 50-iteration loop on a large codebase can cost $50-100+. Always:
- Set conservative `--max-iterations`
- Start small and increase as needed
- Monitor progress files to catch stuck loops

## References

- [Ralph Wiggum: Autonomous Loops](https://paddo.dev/blog/ralph-wiggum-autonomous-loops/)
- [Awesome Claude - Ralph Wiggum](https://awesomeclaude.ai/ralph-wiggum)
- [frankbria/ralph-claude-code](https://github.com/frankbria/ralph-claude-code)
- [VentureBeat: Ralph Wiggum in AI](https://venturebeat.com/technology/how-ralph-wiggum-went-from-the-simpsons-to-the-biggest-name-in-ai-right-now)
