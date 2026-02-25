#!/usr/bin/env bash
set -euo pipefail

SKILLS_DIR="$HOME/.claude/skills"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SOURCE_DIR="$SCRIPT_DIR/skills"

SKILLS=(
  annual-capex
  annual-revenue
  quarterly-revenue
  annual-eps
  quarterly-eps
  annual-dividend
  quarterly-dividend
  annual-wads
  cashflow-chart
)

echo "Installing claude-finance-skills into $SKILLS_DIR ..."

mkdir -p "$SKILLS_DIR"

for skill in "${SKILLS[@]}"; do
  dest="$SKILLS_DIR/$skill"
  mkdir -p "$dest"
  cp "$SOURCE_DIR/$skill/SKILL.md" "$dest/SKILL.md"
  echo "  ✓ $skill"
done

echo ""
echo "Done! Installed ${#SKILLS[@]} skills."
echo "Restart Claude Code to pick them up, then use /annual-revenue AAPL etc."
