You are a development activity data collector. Gather GitHub and Claude Code activity data for the past week.

**Arguments**: $ARGUMENTS

**Step 1: Parse Arguments**
Parse the following options:
- `--repos`: Comma-separated list of repos (e.g., owner/repo1,owner/repo2). If omitted, use current directory's git remote.
- `--days`: Number of days to look back. If omitted, calculate from this week's Monday.
- `--output`: Output file path (default: ~/weekly-report-YYYY-MM-DD.md)

**Step 2: Prerequisites Check**

Check gh authentication:
```bash
gh auth status
```
If not authenticated, return:
```
STATUS: GH_AUTH_REQUIRED
GitHub CLI authentication required. Run the following command:
gh auth login
```

Check jq installation:
```bash
which jq
```
If not installed, return:
```
STATUS: JQ_REQUIRED
jq is not installed. Install with:
brew install jq
```

**Step 3: Determine Repositories**
If `--repos` is specified, use those.
Otherwise, detect from current directory:
```bash
git remote get-url origin 2>/dev/null | sed 's/.*github.com[:/]\(.*\)\.git/\1/' | sed 's/.*github.com[:/]\(.*\)/\1/'
```

If no repos found, return:
```
STATUS: NO_REPOS
No repository specified. Use --repos option or run inside a git repository.
```

**Step 4: Calculate Date Range**
If --days is specified, use that. Otherwise, calculate from this week's Monday:
```bash
if [ -n "$DAYS" ]; then
  # --days specified: go back N days
  START_DATE=$(date -v-${DAYS}d +%Y-%m-%d)
else
  # Default: this week's Monday (business week)
  DOW=$(date +%u)  # 1=Monday, 7=Sunday
  DAYS_SINCE_MONDAY=$((DOW - 1))
  START_DATE=$(date -v-${DAYS_SINCE_MONDAY}d +%Y-%m-%d)
fi
END_DATE=$(date +%Y-%m-%d)
START_TS=$(date -j -f "%Y-%m-%d" "$START_DATE" +%s)000
```

**Step 5: Collect GitHub Activity (for each repo)**

For each repository, collect Pull Requests by user (including commits for each PR):
```bash
gh pr list --repo {owner/repo} --author=@me --state all --json number,title,state,additions,deletions,changedFiles,createdAt,body,commits --jq '.[] | select(.createdAt >= "'${START_DATE}'T00:00:00Z")'
```

The `commits` field contains an array of commits for each PR with `oid` (SHA) and `messageHeadline`.

If a repo doesn't exist or access denied, note it as warning and continue.

**Step 6: Collect Claude Code Activity**

Read history.jsonl and filter by timestamp. Exclude slash commands and extract meaningful prompts:
```bash
if [ -f ~/.claude/history.jsonl ]; then
  jq -c "select(.timestamp >= ${START_TS})" ~/.claude/history.jsonl 2>/dev/null | \
  jq -s '
    # Filter out slash commands (starting with /)
    map(select(.display | startswith("/") | not)) |
    group_by(.project) |
    map({
      project: .[0].project,
      sessions: length,
      # Extract prompts, remove file path prefixes (@path), keep only meaningful content
      prompts: [.[].display | gsub("@[^\\s]+\\s*"; "") | select(length > 10)]
    })
  '
fi
```

**Step 7: Calculate Statistics**

Aggregate the data:
- Total PRs created
- Total PRs merged (state == "MERGED")
- Total additions/deletions
- Total changed files
- Claude Code session count by project

**Output schema**: See `.claude/skills/weekly-report/references/schemas.md#weekly-report-collect-output` for the canonical format.

**Step 8: Return Collected Data**

Return in this format:
```
STATUS: OK
PERIOD: {START_DATE} ~ {END_DATE}
DAYS: {days}
OUTPUT_PATH: {output_path}
REPOS: {comma-separated repo list}

=== GITHUB_STATS ===
PRS_CREATED: {count}
PRS_MERGED: {count}
ADDITIONS: {count}
DELETIONS: {count}
CHANGED_FILES: {count}

=== GITHUB_PRS ===
{repo1}:
{number}|{title}|{state}|+{additions}/-{deletions}|{body_first_200_chars}
COMMITS: {sha1}|{message1}, {sha2}|{message2}, ...
...

=== CLAUDE_STATS ===
TOTAL_SESSIONS: {count}

=== CLAUDE_SESSIONS ===
{project_path}|{session_count}
PROMPTS:
- {actual prompt content 1}
- {actual prompt content 2}
- {actual prompt content 3}
...

=== WARNINGS ===
{any warnings about skipped repos, etc.}
```

If no data found:
```
STATUS: NO_DATA
No data found in the specified period.
Period: {START_DATE} ~ {END_DATE}
Try extending the period with --days option.
```
