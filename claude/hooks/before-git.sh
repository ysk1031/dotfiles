#!/bin/bash
# PreToolUse hook: before Claude runs git commit or git reset, show which branch
# the session is on and exactly what is staged.
#
# The deny list makes "stage everything" impossible; it cannot make "commit onto
# the wrong branch" impossible. Both real incidents were about the wrong things
# going in, so the branch name has to be in front of you at that moment.
#
# It reports on the session's own directory and never digs a target directory
# out of the command. Extracting `cd` / `git -C` was rejected on two counts: the
# extracted text has to reach `eval` to handle `~` and quoted paths, and that
# runs any `$(...)` sitting inside a command the user has not approved yet —
# this hook fires before the permission decision — and the extraction reports
# the wrong branch for parenthesised, newline-separated, and unrelated `git -C`
# commands. A wrong branch is worse than no branch, so when the command aims
# somewhere else this says only that.
#
# `git add` deliberately does not fire this: it runs several times per commit and
# the notice would land on every one of them.
#
# stdout on PreToolUse goes to the debug log, never the transcript — the message
# has to travel in systemMessage, in a JSON object, on exit 0.
set -uo pipefail

input=$(cat)
cmd=$(printf '%s' "$input" | jq -r '.tool_input.command // ""')

# Global options may sit between `git` and the subcommand, as in `git -C dir
# commit`, so anything up to the next separator is allowed in between. That is
# deliberately loose: a false positive costs one extra notice, a miss costs the
# notice at the moment it was supposed to appear. Matching happens in bash
# rather than through `grep`, because this hook runs on every Bash tool call.
git_re=$'(^|[;&|(\n])[[:space:]]*git[[:space:]]+([^;&|]*[[:space:]])?(commit|reset)([[:space:]]|$)'
[[ $cmd =~ $git_re ]] || exit 0

elsewhere_re=$'(^|[;&|(\n])[[:space:]]*cd[[:space:]]|git[[:space:]]+[^;&|]*-C[[:space:]]|--git-dir|--work-tree'
if [[ $cmd =~ $elsewhere_re ]]; then
  jq -n '{systemMessage: "このコマンドはセッションとは別のディレクトリを指しています（cd / git -C）。書き込み先のブランチを確定できないため表示しません。"}'
  exit 0
fi

cwd=$(printf '%s' "$input" | jq -r '.cwd // ""')
[ -n "$cwd" ] && cd "$cwd" 2>/dev/null
git rev-parse --is-inside-work-tree >/dev/null 2>&1 || exit 0

branch=$(git branch --show-current 2>/dev/null)
[ -z "$branch" ] && branch='(detached HEAD)'
staged=$(git diff --cached --name-status 2>/dev/null)
count=$(printf '%s' "$staged" | grep -c .)

if [ "$count" -eq 0 ]; then
  body='ステージ済み: なし'
else
  body="ステージ済み ${count} 件:
$(printf '%s' "$staged" | head -20)"
  [ "$count" -gt 20 ] && body="${body}
… 他 $((count - 20)) 件"
fi

jq -n --arg m "ブランチ: ${branch}
${body}" '{systemMessage: $m}'
