# Activity Reporter Schemas

JSON Schema definitions for the activity-reporter agent output. daily-report owns this file; weekly-report shared it before being retired (see `weekly-report/.sync-ignore`).

See each agent file for inline JSON examples.

---

## activity-reporter-output

JSON Schema for activity-reporter agent output.

```json
{
  "$schema": "https://json-schema.org/draft/2020-12/schema",
  "type": "object",
  "required": ["status"],
  "properties": {
    "status": {
      "type": "string",
      "enum": ["OK", "GH_AUTH_REQUIRED", "JQ_REQUIRED", "NO_REPOS", "NO_DATA"],
      "description": "OK: data collection complete, GH_AUTH_REQUIRED: gh auth needed, JQ_REQUIRED: jq not installed, NO_REPOS: no repos specified, NO_DATA: no data found"
    },
    "period": { "type": "string", "description": "Data collection period (START_DATE ~ END_DATE)" },
    "days": { "type": "integer", "description": "Number of days" },
    "output_path": { "type": "string", "description": "Suggested report output path (for caller use only — agent must NOT write to this path)" },
    "repos": {
      "type": "array",
      "items": { "type": "string" },
      "description": "Target repositories for GitHub PR collection (auto-detected or user-specified). Empty array means no GitHub PR activity found in the period. Claude Code projects are tracked separately in claude_sessions"
    },
    "github_stats": {
      "type": "object",
      "properties": {
        "prs_created": { "type": "integer" },
        "prs_merged": { "type": "integer" },
        "additions": { "type": "integer" },
        "deletions": { "type": "integer" },
        "changed_files": { "type": "integer" }
      },
      "description": "GitHub statistics summary"
    },
    "github_prs": {
      "type": "array",
      "items": {
        "type": "object",
        "properties": {
          "repo": { "type": "string" },
          "number": { "type": "integer" },
          "title": { "type": "string" },
          "state": { "type": "string" },
          "additions": { "type": "integer" },
          "deletions": { "type": "integer" },
          "body_preview": { "type": "string", "maxLength": 200 },
          "commits": {
            "type": "array",
            "items": {
              "type": "object",
              "properties": {
                "sha": { "type": "string" },
                "message": { "type": "string" }
              }
            }
          }
        }
      },
      "description": "PR details by repository"
    },
    "claude_stats": {
      "type": "object",
      "properties": {
        "total_sessions": { "type": "integer" }
      },
      "description": "Claude Code session statistics"
    },
    "claude_sessions": {
      "type": "array",
      "items": {
        "type": "object",
        "properties": {
          "project_path": { "type": "string" },
          "session_count": { "type": "integer" },
          "prompts": {
            "type": "array",
            "items": { "type": "string" }
          }
        }
      },
      "description": "Cross-project Claude Code session details. Collected from session transcripts under ~/.claude/projects/**/*.jsonl (captures both terminal-CLI and desktop-app sessions), independent of GitHub repos"
    },
    "warnings": {
      "type": "array",
      "items": { "type": "string" },
      "description": "Warnings for skipped repositories, etc."
    },
    "message": { "type": "string", "description": "User-facing message (for error statuses)" }
  }
}
```

### Status variants
- `OK`: includes all data fields (`period`, `days`, `output_path`, `repos`, `github_stats`, `github_prs`, `claude_stats`, `claude_sessions`, `warnings`)
- Error statuses (`GH_AUTH_REQUIRED`, `JQ_REQUIRED`, `NO_DATA`): includes `message` only
- `NO_REPOS`: Only returned when `--repos` is explicitly specified but none are accessible. When repos are auto-detected, empty results continue with Claude Code data only (status remains `OK` with empty `repos` array)
