#!/bin/bash
# PreToolUse(Bash): route PR creation and body rewrites through the `pr` skill,
# which applies the repository's template and confirms the draft first.
set -uo pipefail

input=$(cat)
cmd=$(jq -r '.tool_input.command // ""' <<<"$input")

# Match `gh` only where a command starts, so the words inside a quoted string,
# a SQL LIKE pattern or a heredoc body don't trip the guard.
at_cmd='(^|[;&|({]|\$\(|(^|[[:space:]])(then|do|else)[[:space:]])[[:space:]]*([A-Za-z_][A-Za-z0-9_]*=[^[:space:]]*[[:space:]]+)*gh[[:space:]]+pr[[:space:]]+'
if ! grep -qE "${at_cmd}create([[:space:]]|\$)" <<<"$cmd" \
  && ! { grep -qE "${at_cmd}edit([[:space:]]|\$)" <<<"$cmd" \
         && grep -qE -- '--body' <<<"$cmd"; }; then
  exit 0
fi

# The skill runs `gh pr create` itself in its final phase, so allow the command
# once the session transcript shows the skill was invoked — by the Skill tool,
# or by the user typing `/pr`, which leaves only a user message behind. The
# whole transcript is searched: the skill call can sit hundreds of lines back.
transcript=$(jq -r '.transcript_path // ""' <<<"$input")
if [[ -f "$transcript" ]] \
  && jq -e -R -n 'any(inputs | fromjson? // empty | select(type == "object")
                      | .message.content? // empty;
                      (type == "array" and any(.[]; type == "object"
                         and .type == "tool_use" and .name == "Skill"
                         and .input.skill? == "pr"))
                      or (type == "string"
                          and startswith("<command-message>pr</command-message>")))' \
       "$transcript" >/dev/null 2>&1; then
  exit 0
fi

reason='gh pr create / gh pr edit --body の直接実行は止めています。PR の作成と本文の書き換えは pr スキル経由で行ってください（Skill ツールを skill=pr で呼ぶ）。テンプレートの適用、経緯を含めない本文の書き方、作成前の確認は、すべてスキル側にあります。自律実行で確認相手がいない場合は --auto を付けて呼びます。'
jq -n --arg r "$reason" '{hookSpecificOutput: {hookEventName: "PreToolUse", permissionDecision: "deny", permissionDecisionReason: $r}}'
