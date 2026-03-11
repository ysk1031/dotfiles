# Weekly Report Schemas

Subagent I/O format definitions for the weekly-report skill.

---

## weekly-report-collect-output

Output format for weekly-report/prompts/collect-activity.md.

Success:
```
STATUS: OK
PERIOD: <START_DATE> ~ <END_DATE>
DAYS: <number>
OUTPUT_PATH: <path>
REPOS: <comma-separated repo list>

=== GITHUB_STATS ===
PRS_CREATED: <number>
PRS_MERGED: <number>
ADDITIONS: <number>
DELETIONS: <number>
CHANGED_FILES: <number>

=== GITHUB_PRS ===
<repo>:
<number>|<title>|<state>|+<additions>/-<deletions>|<body_first_200_chars>
COMMITS: <sha>|<message>, ...

=== CLAUDE_STATS ===
TOTAL_SESSIONS: <number>

=== CLAUDE_SESSIONS ===
<project_path>|<session_count>
PROMPTS:
- <prompt content>

=== WARNINGS ===
<warnings>
```

Error:
```
STATUS: GH_AUTH_REQUIRED | JQ_REQUIRED | NO_REPOS | NO_DATA
<error message>
```

**Fields:**
- `STATUS` — `OK`: data collection complete, `GH_AUTH_REQUIRED`: gh authentication required, `JQ_REQUIRED`: jq not installed, `NO_REPOS`: no repositories specified, `NO_DATA`: no data
- `PERIOD` — Data collection period
- `DAYS` — Number of days
- `OUTPUT_PATH` — Report output path
- `REPOS` — List of target repositories
- `GITHUB_STATS` — GitHub statistics summary
- `GITHUB_PRS` — PR details by repository (including commit info)
- `CLAUDE_STATS` — Claude Code session statistics
- `CLAUDE_SESSIONS` — Session details and prompt content by project
- `WARNINGS` — Warnings for skipped repositories, etc.
