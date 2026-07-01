#!/bin/bash
# Symlinks each skill/agent in this repo into ~/.claude/ individually.
#
# ~/.claude/skills and ~/.claude/agents are kept as real directories (not
# symlinks to this repo) so that external tools (e.g. `pnpm dlx skills add`)
# can add their own entries there without writing into this repo.
#
# Re-run this script after adding a new skill or agent to this repo.
set -euo pipefail
shopt -s nullglob

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLAUDE_DIR="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"

mkdir -p "$CLAUDE_DIR/skills" "$CLAUDE_DIR/agents"

for skill in "$DIR"/skills/*/; do
  name="$(basename "$skill")"
  ln -sfn "$DIR/skills/$name" "$CLAUDE_DIR/skills/$name"
done

for agent in "$DIR"/agents/*.md; do
  name="$(basename "$agent")"
  ln -sf "$agent" "$CLAUDE_DIR/agents/$name"
done

echo "Synced skills/agents symlinks into $CLAUDE_DIR"
