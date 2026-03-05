---
name: weekly-report
description: Aggregate development activity (GitHub + Claude Code) from the past week and generate a review report
allowed-tools: Task, AskUserQuestion, Bash
argument-hint: "[--repos owner/repo1,repo2 to specify repositories] [--days N to set lookback period] [--output path to set output file]"
disable-model-invocation: true
---

# Weekly Development Review Report Skill

Generate a review report aggregating development activity (GitHub + Claude Code sessions) for the past week.

## Instructions

### Phase 1: Data Collection (use Task with subagent)

Call the Task tool with:
- subagent_type: "general-purpose"
- description: "collect weekly dev activity data"
- prompt: Include the subagent prompt below, replacing $ARGUMENTS with actual arguments

The subagent will return collected data (or an error/status).

#### Subagent Prompt Template

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

---

### Phase 2: User Confirmation (main agent)

Handle based on subagent STATUS:

**STATUS: GH_AUTH_REQUIRED / JQ_REQUIRED / NO_REPOS**:
Display the message and stop.

**STATUS: NO_DATA**:
Use AskUserQuestion:
- question: "指定期間にデータが見つかりませんでした。期間を延長しますか？"
- header: "Period"
- options:
  1. label: "14日間", description: "過去2週間のデータを収集"
  2. label: "30日間", description: "過去1ヶ月のデータを収集"
  3. label: "キャンセル", description: "レポート生成を中止"

If user selects extended period, call subagent again with new --days value.
If "キャンセル", print "レポート生成をキャンセルしました。" and stop.

**STATUS: OK**:
1. Display a summary preview:
   - Period
   - PR count (created/merged) and other key stats
   - Claude Code session count
   - Target repositories
   - Output path

2. Use AskUserQuestion:
   - question: "このデータでレポートを生成しますか？"
   - header: "Report"
   - options:
     1. label: "生成する", description: "レポートを生成しファイルに保存"
     2. label: "期間を変更", description: "データ収集期間を変更"
     3. label: "キャンセル", description: "レポート生成を中止"

**If "生成する"**: Proceed to Phase 3
**If "期間を変更"**: Use AskUserQuestion to get new period, then re-run Phase 1
**If "キャンセル"**: Print "レポート生成をキャンセルしました。" and stop

---

### Phase 3: Generate Report (main agent with Bash)

Generate the Markdown report file with collected data.

1. Create the report file:
```bash
cat > {OUTPUT_PATH} << 'REPORT_EOF'
# 週次開発振り返りレポート

**期間**: {START_DATE} ~ {END_DATE}
**生成日時**: {CURRENT_DATETIME}

---

## サマリー

| 項目 | 数値 |
|------|------|
| PR作成 | {PRS_CREATED} |
| PRマージ | {PRS_MERGED} |
| 変更ファイル数 | {CHANGED_FILES} |
| 追加行数 | +{ADDITIONS} |
| 削除行数 | -{DELETIONS} |
| Claude Code セッション | {CLAUDE_SESSIONS} |

---

## GitHub活動

{FOR EACH REPO}
### {owner/repo}

#### Pull Requests

| # | タイトル | 状態 | 変更 |
|---|---------|------|------|
| #{number} | {title} | {state} | +{additions}/-{deletions} |

**#{number} {title}**
> {body の最初の200文字。なければ「説明なし」}

コミット:
- `{sha1}` {message1}
- `{sha2}` {message2}
- `{sha3}` {message3}
...

{END FOR EACH}

---

## Claude Code 活動

### プロジェクト別詳細

#### {project_name} ({count}セッション)

**主な相談内容:**
- {具体的な相談内容1}
- {具体的な相談内容2}
- {具体的な相談内容3}
...

(プロジェクトごとに繰り返し)

---

## 振り返りメモ

_（ここに振り返りを記入）_

---

🤖 Generated with [Claude Code](https://claude.com/claude-code)
REPORT_EOF
```

2. Display report preview to terminal:
   - Show full report content formatted nicely
   - Print saved file path

3. Confirmation message:
```
Report generated: {OUTPUT_PATH}
```

---

### Rules

- ALWAYS include the Claude Code footer
- Format numbers with commas for readability (1,200 instead of 1200)
- Keep commit messages truncated to first line only
- Group data by repository for clarity
- Default period: This week's Monday to today (business week)
- For PRs: Include body summary (first 200 chars) if available, otherwise show "説明なし"
- For Claude Code: Extract actual prompt content, exclude slash commands (/clear, /exit, etc.)
- Remove file path prefixes (@path/to/file) from prompts, keep only the question/request part
- Use Japanese for all report content (the output report should be in Japanese)
- If a repository has no activity, still list it with "活動なし"
