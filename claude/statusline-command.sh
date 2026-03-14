#!/bin/bash

# Read JSON input from stdin
input=$(cat)

# Extract values from JSON
cwd=$(echo "$input" | jq -r '.workspace.current_dir')
model=$(echo "$input" | jq -r '.model.display_name')
used_pct=$(echo "$input" | jq -r '.context_window.used_percentage // empty')

# Get current directory basename
dir_name=$(basename "$cwd")

# Get git branch (skip optional locks to avoid slowness)
git_branch=""
if git -C "$cwd" rev-parse --git-dir > /dev/null 2>&1; then
    git_branch=$(git -C "$cwd" -c core.useBuiltinFSMonitor=false -c core.fsmonitor=false branch --show-current 2>/dev/null)
    if [ -n "$git_branch" ]; then
        git_branch=" ($git_branch)"
    fi
fi

# Build status line
status="$dir_name$git_branch"

# Add model info
status="$status | $model"

# Add context usage if available
if [ -n "$used_pct" ]; then
    status="$status | Context: ${used_pct}%"
fi

echo "$status"
