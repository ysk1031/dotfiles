#!/bin/bash
# collect_corpus.sh — Build an analysis corpus from recent Claude Code sessions.
#
# Usage: collect_corpus.sh <days> <outdir>
#   <days>   : look-back window in days (default 30)
#   <outdir> : where to write artifacts (use the session scratchpad)
#
# Produces in <outdir>:
#   target_sessions.txt  — the session files analyzed (one path per line)
#   all_human_turns.jsonl — {f,t} per human-authored turn
#   corpus.txt           — human turns grouped by session (what subagents read)
#   session_index.tsv    — sNNN <tab> path <tab> project <tab> turn_count <tab> date
#
# Why this shape: 65MB+ of raw transcripts is mostly tool_results/assistant
# output (noise). The signal is the *human* turns. We extract only those, in a
# single jq pass (per-file jq invocation is ~60x slower and times out), then
# group by session so a reading subagent can judge repetition with context.
set -uo pipefail

DAYS="${1:-30}"
OUTDIR="${2:?usage: collect_corpus.sh <days> <outdir>}"
PROJECTS="${CLAUDE_PROJECTS_DIR:-$HOME/.claude/projects}"
mkdir -p "$OUTDIR"

LIST="$OUTDIR/target_sessions.txt"
# Human-facing sessions only: skip subagent transcripts (double-counts) and the
# skill-creator plugin cache (synthetic eval fixtures, not organic usage).
find "$PROJECTS" -name '*.jsonl' -mtime -"$DAYS" \
  -not -path '*/subagents/*' \
  -not -path '*plugins-cache*' \
  -not -path '*plugins/cache*' \
  | sort > "$LIST"

COUNT=$(wc -l < "$LIST" | tr -d ' ')
if [ "$COUNT" -eq 0 ]; then echo "No sessions found in last $DAYS days under $PROJECTS"; exit 0; fi

RAW="$OUTDIR/all_human_turns.jsonl"
# input_filename tags each record with its source session. The select() chain
# drops: tool_results (array items that aren't text), slash-command stubs,
# injected system reminders, task-notifications, interrupt markers, Caveat lines.
jq -rc '
  input_filename as $f
  | select(.type=="user") | select((.isMeta // false)|not)
  | (.message.content) as $c
  | (if ($c|type)=="string" then $c
     elif ($c|type)=="array" then ($c | map(select(.type=="text").text) | join("\n"))
     else null end) as $t
  | select($t != null)
  | select(($t|gsub("[[:space:]]";"")|length) > 0)
  | select(($t|test("^[[:space:]]*<(command-|local-command|/command)")) | not)
  | select(($t|test("system-reminder")) | not)
  | select(($t|test("^[[:space:]]*\\[Request interrupted")) | not)
  | select(($t|test("^[[:space:]]*<task-notification")) | not)
  | select(($t|test("<task-id>")) | not)
  | select(($t|test("^Caveat:")) | not)
  | {f:$f, t:$t}
' $(cat "$LIST") > "$RAW" 2>/dev/null

COR="$OUTDIR/corpus.txt"
IDX="$OUTDIR/session_index.tsv"
: > "$COR"; : > "$IDX"
# \x01 as field separator so arbitrary text (incl. tabs) survives one-line records.
jq -rc '"" + .f + "" + (.t | gsub("[\n\t]+";" ") | gsub(" +";" "))' "$RAW" \
| awk -F$'\x01' -v COR="$COR" -v IDX="$IDX" '
function proj(p,  s){ s=p;
  sub(/.*\/projects\//,"",s); sub(/\/[0-9a-f-]+\.jsonl$/,"",s);
  sub(/^-Users-[^-]+/,"",s); sub(/^-?src-github-com-/,"",s); sub(/^-/,"",s);
  if (s=="") s="(home)"; return s }
{
  path=$2; t=$3;
  if (path != prev) { n++; tag=sprintf("s%03d", n); order[n]=tag;
    tagpath[tag]=path; tagproj[tag]=proj(path);
    printf "\n=== SESSION %s | project: %s ===\n", tag, proj(path) >> COR;
    prev=path }
  if (length(t) > 800) t=substr(t,1,800) " …[truncated]";
  if (length(t) > 0) { printf "  - %s\n", t >> COR; cnt[tag]++ }
}
END { for (i=1;i<=n;i++){ tg=order[i];
  printf "%s\t%s\t%s\t%d\n", tg, tagpath[tg], tagproj[tg], cnt[tg]+0 >> IDX } }'

# Augment the index with a per-session date (file mtime) as a 5th column, so the
# report can cite "quote — project (date)" instead of opaque internal sNNN handles.
_sdate() { stat -f '%Sm' -t '%Y-%m-%d' "$1" 2>/dev/null || { stat -c '%y' "$1" 2>/dev/null | cut -d' ' -f1; } || echo '?'; }
while IFS=$'\t' read -r _tag _path _proj _cnt; do
  printf '%s\t%s\t%s\t%s\t%s\n' "$_tag" "$_path" "$_proj" "$_cnt" "$(_sdate "$_path")"
done < "$IDX" > "$IDX.tmp" && mv "$IDX.tmp" "$IDX"

echo "sessions: $(wc -l < "$IDX" | tr -d ' ')  human_turns: $(wc -l < "$RAW" | tr -d ' ')  corpus_size: $(du -h "$COR" | cut -f1)"
echo "corpus: $COR"
echo "index:  $IDX"
