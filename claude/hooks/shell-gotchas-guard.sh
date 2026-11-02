#!/bin/bash
# PreToolUse(Bash): stop command forms that fail in this machine's zsh on macOS,
# and say in the denial what to write instead.
set -uo pipefail

input=$(cat)
cmd=$(jq -r '.tool_input.command // ""' <<<"$input")

# A heredoc body is data (a script, a commit message), not commands to judge.
cmd=$(awk '
  delim != "" { line = $0; sub(/^[\t ]+/, "", line); if (line == delim) delim = ""; next }
  match($0, /<<-?[ \t]*["'\'']?[A-Za-z_][A-Za-z0-9_]*/) {
    delim = substr($0, RSTART, RLENGTH); sub(/^<<-?[ \t]*["'\'']?/, "", delim)
  }
  { print }' <<<"$cmd")

# The whole command on one line, so a quoted string spanning lines can be matched.
flat=$(tr '\n' '\036' <<<"$cmd")
# Text outside quotes, split back into lines.
bare=$(sed -E "s/'[^']*'//g; s/\"[^\"]*\"//g" <<<"$flat" | tr '\036' '\n')
# zsh expands $B:a inside double quotes too, but not inside single quotes.
no_single=$(sed -E "s/'[^']*'//g" <<<"$flat" | tr '\036' '\n')

at_cmd='(^|[;&|({]|\$\(|(^|[[:space:]])(then|do|else)[[:space:]])[[:space:]]*([A-Za-z_][A-Za-z0-9_]*=[^[:space:]]*[[:space:]]+)*'
reasons=()

if grep -qE '(^|[^\\$])\$[A-Za-z_][A-Za-z0-9_]*:[aAchtrelquQP]' <<<"$no_single"; then
  reasons+=('zsh は `$B:app` の `:a` を変数の修飾子（絶対パス化など）として読み、`git show $B:app/x.rb` は別のパスになって失敗します。`"${B}:app/x.rb"` のように変数を `${...}` で囲んでください。')
fi
if grep -qE "(^|[^[:alnum:]_])echo([[:space:]]+-[[:alpha:]]+)*[[:space:]]+('[[{][^']*\\\\n[^']*'|\"[[{][^\"]*\\\\n[^\"]*\")" <<<"$flat"; then
  reasons+=("zsh の echo は文字列の中の \`\\n\` を本物の改行に変えるため、JSON が壊れます。\`printf '%s\\n' '<JSON>' | …\` で渡すか、Write ツールでファイルに書いてから渡してください。")
fi
if grep -qE "${at_cmd}g?timeout[[:space:]]" <<<"$bare"; then
  reasons+=('macOS に timeout コマンドはありません。時間を区切るときは Bash ツールの timeout 引数（ミリ秒、最大 600000）を使い、もっと長くかかるものは run_in_background で動かしてください。')
fi
if grep -qE "${at_cmd}cat([[:space:]]+-[[:alpha:]]+)*[[:space:]]+-[[:alpha:]]*A" <<<"$bare"; then
  reasons+=('macOS の cat に -A はありません。タブや行末を見せるときは cat -vet を使ってください（a<TAB>b は a^Ib$ と出ます）。')
fi

# trash itself accepts -v, -s and -h.
if grep -qE "${at_cmd}rm([[:space:]]+[^[:space:];&|()][^[:space:];&|()]*)*[[:space:]]+(-[[:alnum:]]*[^vsh[:space:];&|()-]|--(recursive|force|interactive|dir))" <<<"$bare"; then
  reasons+=('このマシンの rm は trash の alias で、-r や -f などのオプションを付けると Un-recognized argument で失敗します。ディレクトリもオプションなしの rm <path> でゴミ箱に移せます。')
fi

(( ${#reasons[@]} == 0 )) && exit 0
jq -n --arg r "$(printf '%s\n' "${reasons[@]}")" '{hookSpecificOutput: {hookEventName: "PreToolUse", permissionDecision: "deny", permissionDecisionReason: $r}}'
