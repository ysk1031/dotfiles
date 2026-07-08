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
  # Place a `.sync-ignore` file in a skill directory to keep its code in the
  # repo but stop it from being linked into ~/.claude (i.e. disable the skill).
  # Any stale symlink left from a previous sync is removed.
  if [[ -e "$skill/.sync-ignore" ]]; then
    rm -f "$CLAUDE_DIR/skills/$name"
    echo "Skipping $name (.sync-ignore)"
    continue
  fi
  ln -sfn "$DIR/skills/$name" "$CLAUDE_DIR/skills/$name"
done

for agent in "$DIR"/agents/*.md; do
  name="$(basename "$agent")"
  ln -sf "$agent" "$CLAUDE_DIR/agents/$name"
done

echo "Synced skills/agents symlinks into $CLAUDE_DIR"
