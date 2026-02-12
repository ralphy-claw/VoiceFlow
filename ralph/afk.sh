#!/bin/bash
# RALPH — Autonomous Loop (GitHub Issues + Progress)
# Usage: ralph/afk.sh <iterations> [--tool claude|opencode|amp] [--sandbox]
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
PROMPT_FILE="$SCRIPT_DIR/prompt.md"
PROGRESS_FILE="$SCRIPT_DIR/progress.txt"
CONTEXT_FILE="$SCRIPT_DIR/.context.md"
LOG_DIR="$SCRIPT_DIR/logs"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Defaults
MAX_ITERATIONS=10
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
    [0-9]*)
      MAX_ITERATIONS="$1"
      shift
      ;;
    *)
      shift
      ;;
  esac
done

# Validate
if [ ! -f "$PROMPT_FILE" ]; then
  echo -e "${RED}Error: ralph/prompt.md not found${NC}"
  exit 1
fi

# Create directories
mkdir -p "$LOG_DIR"

# Initialize progress file if missing
if [ ! -f "$PROGRESS_FILE" ]; then
  cat > "$PROGRESS_FILE" << 'EOF'
# Ralph Progress Log
Started: $(date)

## Codebase Patterns
(Add reusable patterns here as you discover them)

---
EOF
fi

# Clean up context file on exit
cleanup() {
  rm -f "$CONTEXT_FILE"
}
trap cleanup EXIT

# Sandbox status
if [ "$USE_SANDBOX" = true ]; then
  SANDBOX_STATUS="${GREEN}enabled${NC}"
else
  SANDBOX_STATUS="${YELLOW}disabled${NC}"
fi

# Count open issues
OPEN_ISSUES=$(gh issue list --state open --json number 2>/dev/null | grep -c '"number"' || echo "?")

echo ""
echo -e "${CYAN}╔═══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║                     RALPH — Autonomous Loop                  ║${NC}"
echo -e "${CYAN}╚═══════════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "  ${BLUE}Tool:${NC}        $TOOL"
echo -e "  ${BLUE}Sandbox:${NC}     $SANDBOX_STATUS"
echo -e "  ${BLUE}Max Iters:${NC}   $MAX_ITERATIONS"
echo -e "  ${BLUE}Open Issues:${NC} $OPEN_ISSUES"
echo -e "  ${BLUE}Project:${NC}     $PROJECT_ROOT"

cd "$PROJECT_ROOT"

# --- Create session branch ---
echo -e "${CYAN}Creating session branch...${NC}"
issue_numbers=$(gh issue list --state open --json number --jq '.[].number' 2>/dev/null | sort -n | head -5 | tr '\n' '-' | sed 's/-$//')
if [ -z "$issue_numbers" ]; then
  echo -e "${RED}No open issues found. Nothing to do.${NC}"
  exit 0
fi
SESSION_BRANCH="ralph/${issue_numbers}"

if git show-ref --verify --quiet "refs/heads/$SESSION_BRANCH"; then
  echo -e "${YELLOW}Branch $SESSION_BRANCH exists, checking out...${NC}"
  git checkout "$SESSION_BRANCH"
else
  git checkout -b "$SESSION_BRANCH"
  echo -e "${GREEN}Created branch: $SESSION_BRANCH${NC}"
fi

echo -e "  ${BLUE}Branch:${NC}      $SESSION_BRANCH"
echo ""

# --- Push branch and create PR ---
create_session_pr() {
  local exit_reason="$1"

  # Check if there are any commits on this branch beyond main
  commit_count=$(git rev-list --count main..HEAD 2>/dev/null || echo "0")
  if [ "$commit_count" = "0" ]; then
    echo -e "${YELLOW}No new commits on $SESSION_BRANCH — skipping PR.${NC}"
    return
  fi

  echo -e "${CYAN}Pushing branch and creating PR...${NC}"
  git push -u origin "$SESSION_BRANCH" 2>/dev/null || {
    echo -e "${RED}Failed to push branch. Create PR manually.${NC}"
    return
  }

  # Build PR body from RALPH commits on this branch
  commit_log=$(git log main..HEAD --format="- %s" 2>/dev/null || echo "- (could not read commits)")
  issue_refs=$(git log main..HEAD --format="%s" 2>/dev/null | grep -oE '#[0-9]+' | sort -u | tr '\n' ' ')

  # Build "Closes" lines for each issue
  closes_lines=""
  for ref in $issue_refs; do
    closes_lines="${closes_lines}Closes ${ref}"$'\n'
  done

  pr_body=$(cat <<PR_EOF
${closes_lines}
## Summary
RALPH autonomous session ($exit_reason)

## Commits
$commit_log
PR_EOF
  )

  gh pr create --base main \
    --title "[RALPH] $issue_refs" \
    --body "$pr_body" 2>/dev/null && {
    echo -e "${GREEN}PR created successfully.${NC}"
  } || {
    echo -e "${RED}Failed to create PR. Push succeeded — create PR manually.${NC}"
  }
}

for i in $(seq 1 "$MAX_ITERATIONS"); do
  echo ""
  echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
  echo -e "${BLUE}  Iteration $i of $MAX_ITERATIONS — $(date '+%Y-%m-%d %H:%M:%S')${NC}"
  echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
  echo ""

  LOG_FILE="$LOG_DIR/iteration-$i-$(date '+%Y%m%d-%H%M%S').log"

  # --- Gather context ---
  echo -e "${CYAN}Fetching GitHub issues...${NC}"
  issues=$(gh issue list --state open --json number,title,body,labels,comments 2>/dev/null || echo "[]")

  echo -e "${CYAN}Fetching RALPH commit history...${NC}"
  ralph_commits=$(git log --grep="RALPH" -n 10 --format="%H%n%ad%n%B---" --date=short 2>/dev/null || echo "No previous RALPH commits")

  echo -e "${CYAN}Reading progress log...${NC}"
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

  # --- Run the agent ---
  echo ""
  echo -e "${YELLOW}>>> Agent working (live output) <<<${NC}"
  echo ""

  CLAUDE_FLAGS="--dangerously-skip-permissions --print"
  if [ "$USE_SANDBOX" = true ]; then
    CLAUDE_FLAGS="--sandbox $CLAUDE_FLAGS"
  fi

  if [[ "$TOOL" == "claude" ]]; then
    output=$(claude $CLAUDE_FLAGS \
      "Read @ralph/.context.md for GitHub issues, commit history, and progress. Then follow @ralph/prompt.md to complete ONE task." \
      2>&1 | tee /dev/stderr) || true
  elif [[ "$TOOL" == "opencode" ]]; then
    output=$(cat "$CONTEXT_FILE" "$PROMPT_FILE" | opencode --non-interactive 2>&1 | tee /dev/stderr) || true
  elif [[ "$TOOL" == "amp" ]]; then
    output=$(cat "$CONTEXT_FILE" "$PROMPT_FILE" | amp --dangerously-allow-all 2>&1 | tee /dev/stderr) || true
  else
    echo -e "${RED}Unknown tool: $TOOL${NC}"
    exit 1
  fi

  echo "$output" > "$LOG_FILE"

  echo ""
  echo -e "${YELLOW}>>> End agent output <<<${NC}"

  # --- Check for completion signal ---
  if echo "$output" | grep -q "NO_MORE_TASKS"; then
    echo ""
    echo -e "${GREEN}╔═══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║                    RALPH — No More Tasks                     ║${NC}"
    echo -e "${GREEN}║              Stopped at iteration $i — all done               ║${NC}"
    echo -e "${GREEN}╚═══════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    create_session_pr "all tasks completed"
    exit 0
  fi

  # --- Show status ---
  OPEN_ISSUES=$(gh issue list --state open --json number 2>/dev/null | grep -c '"number"' || echo "?")
  LAST_COMMIT=$(git log -1 --format="%s" 2>/dev/null || echo "none")
  echo ""
  echo -e "  ${CYAN}Branch:${NC}      $(git branch --show-current)"
  echo -e "  ${CYAN}Open issues:${NC} $OPEN_ISSUES"
  echo -e "  ${CYAN}Last commit:${NC} $LAST_COMMIT"
  echo ""

  if [ "$i" -lt "$MAX_ITERATIONS" ]; then
    echo -e "${YELLOW}Iteration $i complete. Next in 5s...${NC}"
    sleep 5
  fi
done

echo ""
echo -e "${RED}Reached max iterations ($MAX_ITERATIONS).${NC}"
create_session_pr "max iterations reached"
echo "Check logs at: $LOG_DIR"
exit 1
