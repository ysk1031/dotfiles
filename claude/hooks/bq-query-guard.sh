#!/bin/bash
# PreToolUse(Bash): let a lone `bq query --dry_run` run without a prompt, and
# ask before any other `bq query`, since a real query is billed.
set -uo pipefail

input=$(cat)
cmd=$(jq -r '.tool_input.command // ""' <<<"$input")

bq_query='(^|[^[:alnum:]_.-])bq([[:space:]]+-[^[:space:]]+)*[[:space:]]+query([[:space:]]|$)'
if ! grep -qE "$bq_query" <<<"$cmd"; then
  exit 0
fi

decide() {
  jq -n --arg d "$1" --arg r "$2" '{hookSpecificOutput: {hookEventName: "PreToolUse", permissionDecision: $d, permissionDecisionReason: $r}}'
  exit 0
}
ask() { decide ask "bq query は課金されます。実行してよいか確認してください（--dry_run 単独の実行だけ確認なしで通します）。"; }

# Judge flags and operators on the text outside quotes, so SQL such as `a || b`
# or a literal '--dry_run' inside the query does not count.
no_single=$(sed -E "s/'[^']*'//g" <<<"$cmd")
# Double quotes still expand $(...) and backticks.
if grep -qE '\$\(|`' <<<"$no_single"; then ask; fi
bare=$(sed -E 's/"[^"]*"//g' <<<"$no_single")

if [[ $(wc -l <<<"$cmd") -gt 1 ]] \
  || grep -qE '[;&|]' <<<"$bare" \
  || [[ $(grep -oE "$bq_query" <<<"$bare" | wc -l) -ne 1 ]] \
  || ! grep -qE '(^|[[:space:]])--dry_run(=true)?([[:space:]]|$)' <<<"$bare" \
  || grep -qE '(^|[[:space:]])(--nodry_run|--dry_run=(false|0))([[:space:]]|$)' <<<"$bare"; then
  ask
fi

decide allow "bq query --dry_run は課金されないため確認を省略しました。"
