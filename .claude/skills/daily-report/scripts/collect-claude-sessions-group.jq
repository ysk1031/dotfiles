# collect-claude-sessions-group.jq
# Slurp pass: groups the per-turn {project, session, prompt} stream produced by
# collect-claude-sessions.jq into the claude_sessions[] schema.
#
# Usage: ... | jq -s -f collect-claude-sessions-group.jq
#
# Output: [{project_path, session_count, prompts}]
#   - session_count = distinct sessionId count for that project (a "session" is one
#     transcript file, NOT a prompt — this is why git worktrees of the same repo,
#     which live in separate project dirs, each contribute their own sessions).
#   - prompts keeps substantive human turns (length > 10), with @file mentions stripped.

group_by(.project)
| map({
    project_path: .[0].project,
    session_count: ([.[].session] | unique | length),
    prompts: [ .[].prompt
               | gsub("@[^\\s]+\\s*"; "")
               | select((. | gsub("[[:space:]]"; "") | length) > 10)
               | if (. | length) > 500 then (.[:500] + " …[truncated]") else . end ]
  })
| map(select(.prompts | length > 0))
