#!/bin/bash
# RALPH — Status Overview
# Usage: ralph/status.sh
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
PROGRESS_FILE="$SCRIPT_DIR/progress.txt"
LOG_DIR="$SCRIPT_DIR/logs"

# Colors
CYAN='\033[0;36m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
NC='\033[0m'

cd "$PROJECT_ROOT"

echo ""
echo -e "${CYAN}╔═══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║                     RALPH — Status                           ║${NC}"
echo -e "${CYAN}╚═══════════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "  ${BLUE}Current branch:${NC} $(git branch --show-current)"
echo ""

# --- Open GitHub Issues ---
echo -e "${BLUE}Open Issues:${NC}"
issues=$(gh issue list --state open --json number,title --limit 20 2>/dev/null || echo "")
if [ -n "$issues" ] && [ "$issues" != "[]" ]; then
  echo "$issues" | python3 -c "
import json, sys
issues = json.load(sys.stdin)
for i in issues:
    print(f\"  #{i['number']:>4}  {i['title']}\")
if not issues:
    print('  (none)')
" 2>/dev/null || echo "  (could not parse issues)"
else
  echo "  (none)"
fi
echo ""

# --- Last 5 RALPH Commits ---
echo -e "${BLUE}Recent RALPH Commits:${NC}"
ralph_commits=$(git log --grep="RALPH" -n 5 --format="  %Cgreen%h%Creset %s %Cblue(%ar)%Creset" 2>/dev/null || echo "")
if [ -n "$ralph_commits" ]; then
  echo "$ralph_commits"
else
  echo "  (none)"
fi
echo ""

# --- RALPH Branches ---
echo -e "${BLUE}RALPH Branches:${NC}"
current=$(git branch --show-current)
ralph_branches=$(git branch --list "ralph/*" --format="%(refname:short)" 2>/dev/null)
if [ -n "$ralph_branches" ]; then
  while IFS= read -r branch; do
    if [ "$branch" = "$current" ]; then
      echo -e "  ${GREEN}* $branch${NC} (current)"
    else
      echo "    $branch"
    fi
  done <<< "$ralph_branches"
else
  echo "  (none)"
fi
echo ""

# --- Open RALPH PRs ---
echo -e "${BLUE}Open RALPH PRs:${NC}"
gh pr list --state open --json number,headRefName,title 2>/dev/null | python3 -c "
import json, sys
prs = json.load(sys.stdin)
ralph_prs = [p for p in prs if p['headRefName'].startswith('ralph/')]
for p in ralph_prs:
    print(f\"  #{p['number']:>4}  {p['headRefName']}  ->  main\")
if not ralph_prs:
    print('  (none)')
" 2>/dev/null || echo "  (could not fetch PRs)"
echo ""

# --- Progress Summary (last 3 entries) ---
echo -e "${BLUE}Progress (last 3 entries):${NC}"
if [ -f "$PROGRESS_FILE" ]; then
  grep "^## " "$PROGRESS_FILE" | tail -3 | while read -r line; do
    echo "  $line"
  done
else
  echo "  (no progress.txt)"
fi
echo ""

# --- Log Directory ---
echo -e "${BLUE}Logs:${NC}"
if [ -d "$LOG_DIR" ]; then
  log_count=$(ls -1 "$LOG_DIR"/*.log 2>/dev/null | wc -l | tr -d ' ')
  log_size=$(du -sh "$LOG_DIR" 2>/dev/null | cut -f1 | tr -d ' ')
  echo "  $log_count log files ($log_size)"
else
  echo "  (no logs directory)"
fi
echo ""
