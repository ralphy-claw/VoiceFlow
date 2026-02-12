# Ralph Loop Template (GitHub Issues)

Autonomous AI coding loop that uses **GitHub Issues** as the task source.

## Setup

1. Copy the `ralph/` folder to your project root
2. Initialize progress file: `touch ralph/progress.txt`
3. Create GitHub issues for your tasks
4. Customize `ralph/prompt.md` for your tech stack

## Files

```
ralph/
├── AGENT.md       # Agent instructions (customize for your project)
├── prompt.md      # Per-iteration prompt (customize for your stack)
├── progress.txt   # Learning log (auto-populated)
├── afk.sh         # Autonomous mode (N iterations)
├── once.sh        # Single iteration (interactive)
├── status.sh      # Check status
└── logs/          # Iteration logs (auto-created)
```

## Usage

```bash
# Check status (shows open issues, branches, PRs)
ralph/status.sh

# Single iteration (interactive, asks before changes)
ralph/once.sh

# Autonomous mode (runs N iterations unattended)
ralph/afk.sh 10

# Use different tool
ralph/afk.sh 20 --tool opencode
ralph/once.sh --tool amp
```

## How It Works

1. **Fetches** open GitHub Issues as tasks
2. **Creates** session branch like `ralph/1-2-3` (issue numbers)
3. **Works** through issues one at a time
4. **Commits** with `RALPH: #<issue> - <title>`
5. **Comments** on issues with progress
6. **Creates PR** to main when done or max iterations reached

## Workflow

### Single Iteration (Human-in-the-Loop)
```bash
ralph/once.sh
```
- Interactive mode - agent asks before making changes
- Good for learning Ralph's capabilities
- Review each change before continuing

### Autonomous Mode (AFK)
```bash
ralph/afk.sh 10
```
- Runs up to N iterations unattended
- Creates branch, works issues, opens PR
- Stops when no more tasks or max iterations

## Customization

### prompt.md
Customize for your tech stack:
- Quality gates (build, lint, test commands)
- Project-specific patterns
- File structure documentation

### AGENT.md
Project-specific agent instructions:
- Tech stack details
- Key config files
- Testing requirements

### progress.txt
Initialize with codebase patterns:
```markdown
# Ralph Progress Log
Started: <date>

## Codebase Patterns
- Pattern 1
- Pattern 2

---
```

## Requirements

- `gh` CLI (GitHub CLI) authenticated
- Git repository with GitHub remote
- One of: `claude`, `opencode`, or `amp` CLI

## Tips

1. **Small issues** — Break large features into small, focused issues
2. **Clear acceptance criteria** — Include specific, verifiable criteria in issues
3. **File hints** — Add "File Hints: path/to/file.ts" in issue body
4. **Labels** — Use labels for priority (bug, feature, polish)
5. **Tracer bullets** — Start with tiny end-to-end slices
