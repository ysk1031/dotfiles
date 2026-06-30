# collect-claude-sessions.jq
# Usage:
#   FILES=$(find ~/.claude/projects -name '*.jsonl' -newermt "$START_DATE 00:00:00" \
#             -not -path '*/subagents/*' -not -path '*plugins-cache*' -not -path '*plugins/cache*')
#   jq -c --arg START "$START_ISO_UTC" -f this_file.jq $FILES | jq -s -f collect-claude-sessions-group.jq
#
# Source: ~/.claude/projects/**/*.jsonl (real session transcripts).
#   This captures BOTH terminal-CLI sessions AND macOS desktop-app sessions.
#   Do NOT use ~/.claude/history.jsonl — the desktop app does not write to it,
#   so it silently drops every desktop-app conversation.
#
# Input : a stream of transcript records across many session files (NOT slurped).
# Filter: human-authored user turns only, within the time window.
# Output: one {project, session, prompt} object per qualifying human turn.
#   $START is an ISO8601 UTC instant (e.g. 2026-06-28T15:00:00Z = JST midnight).
#   Record .timestamp is ISO8601 UTC ("...Z"), so a lexical >= compare is valid.

select(.type == "user")
| select((.isMeta // false) | not)          # drop injected meta turns
| select((.isSidechain // false) | not)      # drop subagent (Task) sidechain turns
| select(.timestamp >= $START)
| (.message.content) as $c
| (if ($c | type) == "string" then $c
   elif ($c | type) == "array" then ($c | map(select(.type == "text").text) | join("\n"))
   else null end) as $t
| select($t != null)
| select(($t | gsub("[[:space:]]"; "") | length) > 0)
| select(($t | test("^[[:space:]]*<(command-|local-command|/command)")) | not)  # slash-command stubs
| select(($t | test("^[[:space:]]*/[a-z][a-z0-9-]*[[:space:]]*$")) | not)        # bare slash command
| select(($t | test("system-reminder")) | not)
| select(($t | test("^[[:space:]]*\\[Request interrupted")) | not)
| select(($t | test("^[[:space:]]*<task-notification")) | not)
| select(($t | test("<task-id>")) | not)
| select(($t | test("^Caveat:")) | not)
| { project: (.cwd // "(unknown)"), session: (.sessionId // "(unknown)"), prompt: $t }
