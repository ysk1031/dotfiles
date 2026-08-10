#!/bin/bash

input=$(cat)
now=$(date +%s)

# "-" marks an absent value. rate_limits shows up only for Claude.ai
# subscribers, only after the session's first API response, and each window
# can drop out on its own.
IFS=$'\t' read -r cwd model context_pct fh_pct fh_reset sd_pct sd_reset <<< "$(
    echo "$input" | jq -r '[
        .workspace.current_dir,
        .model.display_name,
        .context_window.used_percentage,
        .rate_limits.five_hour.used_percentage,
        .rate_limits.five_hour.resets_at,
        .rate_limits.seven_day.used_percentage,
        .rate_limits.seven_day.resets_at
    ] | map(if . == null then "-" else tostring end) | @tsv'
)"

# Claude Code captures this output instead of attaching it to a terminal, so
# there is no TTY to test — always emit color.
bold=$'\e[1m'
grey=$'\e[90m'
cyan=$'\e[36m'
yellow=$'\e[33m'
red=$'\e[31m'
reset=$'\e[0m'

bar_cells=10

# Context goes red well before the ~90% where compaction kicks in: by then it
# is too late to wind the work down deliberately. The windows warn early for
# the same reason — changing course takes lead time.
context_warn=50
context_crit=75
limit_warn=60
limit_crit=85

level_color() {
    local pct=$1 warn=$2 crit=$3 rounded
    printf -v rounded '%.0f' "$pct"
    if [ "$rounded" -ge "$crit" ]; then
        printf '%s' "$red"
    elif [ "$rounded" -ge "$warn" ]; then
        printf '%s' "$yellow"
    fi
}

format_bar() {
    local pct=$1 color=$2 rounded filled i=0 full="" empty=""
    printf -v rounded '%.0f' "$pct"
    [ "$rounded" -gt 100 ] && rounded=100
    [ "$rounded" -lt 0 ] && rounded=0
    filled=$(((rounded * bar_cells + 50) / 100))
    # Reserve the extremes: rounding alone would draw 95% as a full bar and 4%
    # as an empty one, so a full bar reads as 100% and an empty one as 0%.
    [ "$rounded" -lt 100 ] && [ "$filled" -ge "$bar_cells" ] && filled=$((bar_cells - 1))
    [ "$rounded" -gt 0 ] && [ "$filled" -eq 0 ] && filled=1
    # Built one glyph at a time: bash 3.2 (macOS /bin/bash) slices substrings
    # by byte and would cut these multi-byte blocks in half. The braces are
    # load-bearing too — "$full█" lets bash 3.2 swallow the glyph's first byte
    # as part of the variable name.
    while [ "$i" -lt "$bar_cells" ]; do
        if [ "$i" -lt "$filled" ]; then full="${full}█"; else empty="${empty}░"; fi
        i=$((i + 1))
    done
    printf '%s%s%s%s%s' "$color" "$full" "$grey" "$empty" "$reset"
}

# Two units at most: 2d14h / 2h12m / 42m, dropping a zero lower unit.
format_reset() {
    local reset_at=$1 secs major minor
    [ "$reset_at" = "-" ] && return 1
    secs=$((reset_at - now))
    if [ "$secs" -lt 60 ]; then
        echo "0m"
    elif [ "$secs" -ge 86400 ]; then
        major=$((secs / 86400))
        minor=$((secs % 86400 / 3600))
        [ "$minor" -gt 0 ] && echo "${major}d${minor}h" || echo "${major}d"
    elif [ "$secs" -ge 3600 ]; then
        major=$((secs / 3600))
        minor=$((secs % 3600 / 60))
        [ "$minor" -gt 0 ] && echo "${major}h${minor}m" || echo "${major}h"
    else
        echo "$((secs / 60))m"
    fi
}

# Bar-less on purpose: context moves fast enough to deserve a gauge, these
# windows don't. Parentheses keep the reset time from reading as a second
# duration beside the window's own name ("5h" next to "4h49m"), and the
# right-aligned percentage holds the line still across 10% and 100%.
format_window() {
    local label=$1 pct=$2 reset_at=$3 color out remaining
    [ "$pct" = "-" ] && return 1
    color=$(level_color "$pct" "$limit_warn" "$limit_crit")
    out="${grey}${label}${reset} ${color}$(printf '%3.0f%%' "$pct")${reset}"
    remaining=$(format_reset "$reset_at")
    [ -n "$remaining" ] && out="$out ${grey}(${remaining})${reset}"
    printf '%s' "$out"
}

# Skip the optional locks; they make this noticeably slower.
git_branch=""
if git -C "$cwd" rev-parse --git-dir > /dev/null 2>&1; then
    git_branch=$(git -C "$cwd" -c core.useBuiltinFSMonitor=false -c core.fsmonitor=false branch --show-current 2>/dev/null)
    [ -n "$git_branch" ] && git_branch=" ($git_branch)"
fi

# Written by usage-cache.sh in the background. The month has to match, or a
# cache left over from last month would read as this month's spend.
cache_file="$HOME/.claude/cache/ccusage-monthly.json"
refresh_after_seconds=600
cost=$(jq -r --arg month "$(date +%Y%m01)" \
    'select(.month == $month) | .cost // empty' "$cache_file" 2>/dev/null)

# Line 1 is this session: where you are, what you're running, how full it is.
# Names like "Opus 5 (1M context)" lose the parenthetical.
line1="${bold}${cwd##*/}${reset}${grey}${git_branch}${reset}"
line1="$line1 ${grey}·${reset} ${cyan}${model%% (*}${reset}"
if [ "$context_pct" != "-" ]; then
    context_color=$(level_color "$context_pct" "$context_warn" "$context_crit")
    line1="$line1 ${grey}·${reset} $(format_bar "$context_pct" "$context_color")"
    line1="$line1 ${context_color}$(printf '%.0f%%' "$context_pct")${reset}"
fi

# Line 2 is the account: rate-limit windows and the month's cost. Each reading
# is its own segment, so a missing one takes its rule with it.
line2=""

add_segment() {
    [ -z "$1" ] && return
    line2="${line2:+$line2  ${grey}│${reset}  }$1"
}

if five_hour=$(format_window "5h" "$fh_pct" "$fh_reset"); then
    add_segment "$five_hour"
fi

if seven_day=$(format_window "7d" "$sd_pct" "$sd_reset"); then
    add_segment "$seven_day"
fi

if [ -n "$cost" ]; then
    add_segment "$(printf '$%.0f' "$cost")"
fi

echo "$line1"
[ -n "$line2" ] && echo "$line2"

cache_mtime=$(stat -f %m "$cache_file" 2>/dev/null || echo 0)
if [ $((now - cache_mtime)) -gt "$refresh_after_seconds" ]; then
    refresher="${0%/*}/usage-cache.sh"
    if [ -x "$refresher" ]; then
        nohup "$refresher" > /dev/null 2>&1 &
    fi
fi
