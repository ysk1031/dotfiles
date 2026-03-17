# collect-claude-sessions.jq
# Usage: jq -c "select(.timestamp >= $START_TS)" ~/.claude/history.jsonl | jq -s -f this_file.jq
#
# Input: array of history.jsonl entries (pre-filtered by timestamp via slurp)
# Output: array of {project_path, session_count, prompts}

map(select(.display | startswith("/") | not)) |
group_by(.project) |
map({
  project_path: .[0].project,
  session_count: length,
  prompts: [.[].display | gsub("@[^\\s]+\\s*"; "") | select(length > 10)]
})
