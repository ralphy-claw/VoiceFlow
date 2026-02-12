#!/bin/bash
# RALPH — Single Iteration (Human-in-the-Loop)
# Usage: ralph/once.sh [--tool claude|opencode|amp] [--sandbox]
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
PROMPT_FILE="$SCRIPT_DIR/prompt.md"
PROGRESS_FILE="$SCRIPT_DIR/progress.txt"
CONTEXT_FILE="$SCRIPT_DIR/.context.md"

# Defaults
TOOL="claude"
USE_SANDBOX=false

# Parse args
while [[ $# -gt 0 ]]; do
  case $1 in
    --tool)
      TOOL="$2"
      shift 2
      ;;
    --tool=*)
      TOOL="${1#*=}"
      shift
      ;;
    --sandbox)
      USE_SANDBOX=true
      shift
      ;;
    *)
      shift
      ;;
  esac
done

if [ ! -f "$PROMPT_FILE" ]; then
  echo "Error: ralph/prompt.md not found"
  exit 1
fi

# Clean up context file on exit
cleanup() {
  rm -f "$CONTEXT_FILE"
}
trap cleanup EXIT

cd "$PROJECT_ROOT"

# --- Gather context ---
echo "Fetching GitHub issues..."
issues=$(gh issue list --state open --json number,title,body,labels,comments 2>/dev/null || echo "[]")

echo "Fetching RALPH commit history..."
ralph_commits=$(git log --grep="RALPH" -n 10 --format="%H%n%ad%n%B---" --date=short 2>/dev/null || echo "No previous RALPH commits")

echo "Reading progress log..."
progress=""
if [ -f "$PROGRESS_FILE" ]; then
  progress=$(cat "$PROGRESS_FILE")
fi

# Write context file
cat > "$CONTEXT_FILE" << CONTEXT_EOF
# GitHub Issues (JSON)
$issues

# Previous RALPH Commits
$ralph_commits

# Progress Log
$progress
CONTEXT_EOF

# --- Run the agent (interactive, no --dangerously-skip-permissions) ---
echo ""
echo "────────────────────────────────────────────────────"
echo "RALPH — Single iteration with $TOOL"
echo "────────────────────────────────────────────────────"
echo ""

CLAUDE_FLAGS=""
if [ "$USE_SANDBOX" = true ]; then
  CLAUDE_FLAGS="--sandbox"
fi

if [[ "$TOOL" == "claude" ]]; then
  claude $CLAUDE_FLAGS \
    "Read @ralph/.context.md for GitHub issues, commit history, and progress. Then follow @ralph/prompt.md to complete ONE task."
elif [[ "$TOOL" == "opencode" ]]; then
  cat "$CONTEXT_FILE" "$PROMPT_FILE" | opencode
elif [[ "$TOOL" == "amp" ]]; then
  cat "$CONTEXT_FILE" "$PROMPT_FILE" | amp
else
  echo "Unknown tool: $TOOL"
  exit 1
fi

echo ""
echo "────────────────────────────────────────────────────"
echo "RALPH iteration complete"
echo "────────────────────────────────────────────────────"
