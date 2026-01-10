# Project Instructions

## Git Commit Guidelines for Autonomous Loops

When operating in a Ralph loop (autonomous iteration), follow these commit conventions:

### Commit Message Format

```
<type>(<task-id>): <brief description>
```

**Types:**
- `feat` - New feature or functionality
- `fix` - Bug fix
- `refactor` - Code restructuring without behavior change
- `docs` - Documentation only
- `test` - Adding or modifying tests
- `chore` - Maintenance tasks, dependency updates

**Examples:**
```bash
git commit -m "feat(a3f): Add CLAUDE.md with commit guidance"
git commit -m "fix(c7e): Resolve null pointer in user validation"
git commit -m "test(f4d): Add coverage for edge cases in parser"
```

### Rules for Autonomous Commits

1. **One commit per task** - Each completed task gets exactly one commit
2. **Task ID in scope** - Always include the task ID in parentheses
3. **Imperative mood** - "Add feature" not "Added feature" or "Adds feature"
4. **Keep it brief** - Under 72 characters for the subject line
5. **No WIP commits** - Only commit when the task is complete and tests pass

### Before Committing

```bash
# Ensure tests pass
<your-test-command>

# Stage all changes
git add -A

# Commit with task ID
git commit -m "feat(<task-id>): <description>"
```

### Atomic Commits

Each commit should:
- Be self-contained and buildable
- Pass all tests
- Represent a complete unit of work
- Not break bisectability

## Issue Tracking

This project uses [ticks](https://github.com/pengelbrecht/ticks) for issue tracking. See AGENTS.md for the `tk` command reference.
