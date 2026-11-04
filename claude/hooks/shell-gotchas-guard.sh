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
# Each rewrite is one sed pass over all alternatives, so whichever quote opens
# first wins and a ' inside "..." or an escaped \" does not throw the pairing off.
sq="'[^']*'" dq='"([^"\\]|\\.)*"'
# Text outside quotes.
bare=$(sed -E "s/(\\\\.)|${sq}|${dq}/\\1/g" <<<"$flat" | tr '\036' '\n')
# zsh expands $B:a inside double quotes too, but not inside single quotes.
no_single=$(sed -E "s/(\\\\.)|${sq}|(${dq})/\\1\\2/g" <<<"$flat" | tr '\036' '\n')
# Quoted strings kept as one placeholder word, for checks that count arguments.
masked=$(sed -E "s/(\\\\.)|(${sq}|${dq})/\\1"$'\037'"/g; s/(\\\\.)"$'\037'"/\\1/g; s/"$'\037'"/Q/g" <<<"$flat" | tr '\036' '\n')

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

# `[[ a == b ]]` and `(( a == b ))` are fine in zsh; only a plain word that starts with = is expanded.
if sed -E 's/\[\[[^]]*\]\]//g; s/\(\([^)]*\)\)//g' <<<"$bare" | grep -qE '(^|[[:space:]])=[^[:space:]]'; then
  reasons+=('zsh は = で始まる単語（`echo ===` や `[ "$a" == b ]` の `==`）をコマンドのパスに置き換えようとして `= not found` で止まり、その呼び出しの残りのコマンドも動きません。区切り線は `echo "==="` のように引用符で囲み、比較は `[ "$a" = b ]` と = 1つで書いてください。')
fi

while read -r seg; do
  read -ra words <<<"$seg"
  short=0 revs=0
  for w in "${words[@]:1}"; do
    case $w in
      --short*) short=1 ;;
      -*|*[\<\>]*) ;;
      *) ((revs++)) ;;
    esac
  done
  if ((short && revs > 1)); then
    reasons+=('git rev-parse --short は revision を1つしか受け付けず、2つ以上渡すと `fatal: Needed a single revision` で失敗します。`git rev-parse --short HEAD; git rev-parse --short origin/x` と分けるか、`git rev-parse HEAD origin/x | cut -c1-9` を使ってください。')
    break
  fi
done < <(grep -oE '(^|[[:space:]])rev-parse([[:space:]]+[^;&|()[:space:]]+)*' <<<"$masked")

# Without -e, git grep reads the first plain word as the pattern and every later word as a revision.
while read -r seg; do
  read -ra words <<<"$seg"
  pattern=0 skip=0 bad=0
  for w in "${words[@]}"; do
    ((skip)) && { skip=0; continue; }
    case $w in
      --) break ;;
      -e|-f|--and|--or|--not) break ;;
      -A|-B|-C|-m|--max-count|--max-depth|--threads|-O) skip=1 ;;
      -*) ((pattern)) && { bad=1; break; } ;;
      *) pattern=1 ;;
    esac
  done
  if ((bad)); then
    reasons+=('git grep はパターンより後ろのオプション（`git grep -n "pat" -A3`）を revision として読み、`fatal: unable to resolve revision` で失敗します。オプションはパターンより前に書いてください（`git grep -n -A3 "pat" -- path`）。')
    break
  fi
done < <(grep -oE 'git([[:space:]]+-C[[:space:]]+[^[:space:]]+)?[[:space:]]+grep([[:space:]]+[^;&|()[:space:]]+)*' <<<"$masked" | sed -E 's/^git([[:space:]]+-C[[:space:]]+[^[:space:]]+)?[[:space:]]+grep//')

(( ${#reasons[@]} == 0 )) && exit 0
jq -n --arg r "$(printf '%s\n' "${reasons[@]}")" '{hookSpecificOutput: {hookEventName: "PreToolUse", permissionDecision: "deny", permissionDecisionReason: $r}}'
