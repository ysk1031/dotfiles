#!/bin/bash

# Refreshes the monthly cost estimate statusline-command.sh displays. It runs
# this in the background; the statusline only ever reads the cache file.

set -uo pipefail

cache_dir="$HOME/.claude/cache"
cache_file="$cache_dir/ccusage-monthly.json"
lock_dir="$cache_dir/.ccusage-monthly.lock"
stale_lock_seconds=600

mkdir -p "$cache_dir"

# Clear a lock a killed process left behind, or refreshes stop forever.
if [ -d "$lock_dir" ]; then
    lock_mtime=$(stat -f %m "$lock_dir" 2>/dev/null || echo 0)
    if [ $(($(date +%s) - lock_mtime)) -gt "$stale_lock_seconds" ]; then
        rmdir "$lock_dir" 2>/dev/null
    fi
fi

# mkdir is atomic; macOS has no flock(1).
mkdir "$lock_dir" 2>/dev/null || exit 0
trap 'rmdir "$lock_dir" 2>/dev/null' EXIT

month_start=$(date +%Y%m01)

# No --offline: the pricing table baked into the published ccusage binary lags
# new models. claude-opus-5 was missing from it and silently costed at $0,
# which put the month at $156 instead of $1430.
result=$(bunx ccusage claude monthly --json -z Asia/Tokyo --since "$month_start" 2>/dev/null) || exit 0

# A failed price fetch doesn't fail the command — ccusage just falls back to
# that stale embedded table. Models that burned tokens yet cost nothing are
# the signature, so count them and keep the old cache rather than publish a
# figure that collapsed.
IFS=$'\t' read -r cost unpriced <<< "$(echo "$result" | jq -r '[
    (.totals.totalCost // ""),
    ([.monthly[].modelBreakdowns[]?
        | select((.cost // 0) == 0
            and ((.inputTokens // 0) + (.outputTokens // 0) + (.cacheCreationTokens // 0)) > 0)
     ] | length)
] | @tsv')"

[ -n "$cost" ] || exit 0
[ "$unpriced" = "0" ] || exit 0

# Through a temp file so the statusline never reads a half-written cache.
tmp=$(mktemp "$cache_dir/.ccusage-monthly.XXXXXX") || exit 0
if jq -n --argjson cost "$cost" --arg month "$month_start" \
    '{cost: $cost, month: $month, updated_at: (now | floor)}' > "$tmp"; then
    mv "$tmp" "$cache_file"
else
    rm -f "$tmp"
fi
