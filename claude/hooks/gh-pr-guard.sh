#!/bin/bash
# PreToolUse(Bash): route PR creation and body rewrites through the `pr` skill,
# which applies the repository's template and confirms the draft first.
set -uo pipefail

input=$(cat)
cmd=$(jq -r '.tool_input.command // ""' <<<"$input")

if ! grep -qE '(^|[^[:alnum:]_./-])gh[[:space:]]+pr[[:space:]]+create([[:space:]]|$)' <<<"$cmd" \
  && ! { grep -qE '(^|[^[:alnum:]_./-])gh[[:space:]]+pr[[:space:]]+edit([[:space:]]|$)' <<<"$cmd" \
         && grep -qE -- '--body' <<<"$cmd"; }; then
  exit 0
fi

# The skill runs `gh pr create` itself in its final phase, so allow the command
# once the session transcript shows the skill was invoked.
transcript=$(jq -r '.transcript_path // ""' <<<"$input")
if [[ -f "$transcript" ]] && tail -n 500 "$transcript" \
  | jq -e -R -n '[inputs | fromjson? // empty]
                 | any(.[]; ((.message.content // []) | type == "array")
                            and ((.message.content // [])
                                 | any(.type == "tool_use" and .name == "Skill"
                                       and (.input.skill? == "pr"))))' >/dev/null 2>&1; then
  exit 0
fi

reason='gh pr create / gh pr edit --body の直接実行は止めています。PR の作成と本文の書き換えは pr スキル経由で行ってください（Skill ツールを skill=pr で呼ぶ）。テンプレートの適用、経緯を含めない本文の書き方、作成前の確認は、すべてスキル側にあります。自律実行で確認相手がいない場合は --auto を付けて呼びます。'
jq -n --arg r "$reason" '{hookSpecificOutput: {hookEventName: "PreToolUse", permissionDecision: "deny", permissionDecisionReason: $r}}'
