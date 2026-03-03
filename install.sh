#!/usr/bin/env bash
# LangGraph Skill Installer for Claude Code
# Usage: ./install.sh [--uninstall]

set -euo pipefail

SKILL_NAME="langgraph"
SKILL_DIR="$HOME/.claude/skills/$SKILL_NAME"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SRC_DIR="$SCRIPT_DIR/src"

if [[ "${1:-}" == "--uninstall" ]]; then
    echo "Uninstalling $SKILL_NAME skill..."
    rm -rf "$SKILL_DIR"
    echo "Done. Removed $SKILL_DIR"
    exit 0
fi

echo "Installing $SKILL_NAME skill to $SKILL_DIR..."

mkdir -p "$SKILL_DIR/references"
mkdir -p "$SKILL_DIR/examples"

cp "$SRC_DIR/SKILL.md" "$SKILL_DIR/SKILL.md"
cp "$SRC_DIR/references/"*.md "$SKILL_DIR/references/"
cp "$SRC_DIR/examples/"*.md "$SKILL_DIR/examples/"

echo "Done. Skill installed to $SKILL_DIR"
echo ""
echo "Usage in Claude Code:"
echo "  /langgraph                     - invoke directly"
echo "  /langgraph build a ReAct agent - invoke with arguments"
echo "  Or just ask about LangGraph    - auto-invoked by Claude"
