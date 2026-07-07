#!/usr/bin/env bash
#
# Installs the DevFlow agent system into a project (or globally).
#
# Usage:
#   ./install.sh [target-dir]     # install into project (default: cwd)
#   ./install.sh --global         # install into ~/.claude for all projects
#   ./install.sh --force [dir]    # overwrite existing files
#
set -euo pipefail

SOURCE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FORCE=0
GLOBAL=0
TARGET="$(pwd)"

for arg in "$@"; do
  case "$arg" in
    --global) GLOBAL=1 ;;
    --force)  FORCE=1 ;;
    *)        TARGET="$arg" ;;
  esac
done

if [[ "$GLOBAL" == "1" ]]; then
  AGENTS_DEST="$HOME/.claude/agents"
  SKILLS_DEST="$HOME/.claude/skills"
  HOOKS_DEST="$HOME/.claude/hooks"
  WHERE="global (~/.claude)"
else
  AGENTS_DEST="$TARGET/.claude/agents"
  SKILLS_DEST="$TARGET/.claude/skills"
  HOOKS_DEST="$TARGET/.claude/hooks"
  WHERE="project ($TARGET)"
fi

echo ""
echo "  DevFlow Agent System Installer"
echo "  Source : $SOURCE"
echo "  Target : $WHERE"
echo ""

mkdir -p "$AGENTS_DEST" "$SKILLS_DEST" "$HOOKS_DEST"

copy_tree() {
  local from="$1" to="$2"
  ( cd "$from" && find . -type f ) | while read -r rel; do
    rel="${rel#./}"
    local dest="$to/$rel"
    mkdir -p "$(dirname "$dest")"
    if [[ -e "$dest" && "$FORCE" != "1" ]]; then
      echo "  skip (exists): $rel"
    else
      cp "$from/$rel" "$dest"
      echo "  installed    : $rel"
    fi
  done
}

echo "Agents:"
copy_tree "$SOURCE/.claude/agents" "$AGENTS_DEST"

echo "Skills:"
copy_tree "$SOURCE/.claude/skills" "$SKILLS_DEST"

echo "Hooks:"
copy_tree "$SOURCE/.claude/hooks" "$HOOKS_DEST"
chmod +x "$HOOKS_DEST"/*.sh 2>/dev/null || true

echo ""
echo "  Done. Open Claude Code in your project and run:"
echo ""
echo '    /ship "describe what you want built"'
echo ""
echo "  Other commands: /board (view progress), /qa, /security-audit, /debug-findings"
echo ""
