---
name: weekly-report
description: "Aggregate GitHub + Claude Code activity into a structured weekly review report. 今週何をやったか振り返りたい時に使用。GitHub活動とClaude Codeセッションを集計。"
allowed-tools: Agent, AskUserQuestion, Bash
argument-hint: "[--repos owner/repo1,repo2 to specify repositories] [--days N to set lookback period] [--output path to set output file]"
disable-model-invocation: true
---

# Weekly Development Review Report Skill

Generate a review report aggregating development activity (GitHub + Claude Code sessions) for the past week.

## Instructions

### Phase 1: Data Collection (use Agent with subagent)

Call the Agent tool with:
- subagent_type: "custom"
- agent: "activity-reporter"
- description: "collect weekly dev activity data"
- prompt: Replace `$ARGUMENTS` in the agent's loaded prompt with the actual user arguments and execute.

The subagent will return collected data (or an error/status).

---

### Phase 2: User Confirmation (main agent)

Handle based on subagent `status`:

**`"status": "GH_AUTH_REQUIRED"` / `"JQ_REQUIRED"` / `"NO_REPOS"`**:
Display the `message` field and stop.

**`"status": "NO_DATA"`**:
Use AskUserQuestion:
- question: "指定期間にデータが見つかりませんでした。期間を延長しますか？"
- header: "Period"
- options:
  1. label: "14日間", description: "過去2週間のデータを収集"
  2. label: "30日間", description: "過去1ヶ月のデータを収集"
  3. label: "キャンセル", description: "レポート生成を中止"

If user selects extended period, call subagent again with new --days value.
If "キャンセル", print "レポート生成をキャンセルしました。" and stop.

**`"status": "OK"`**:
1. Display a summary preview using JSON fields:
   - `period`
   - PR count (`github_stats.prs_created` / `github_stats.prs_merged`) and other key stats
   - Claude Code session count (`claude_stats.total_sessions`)
   - Target repositories (`repos`)
   - Output path (`output_path`)

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

**期間**: {period}
**生成日時**: {CURRENT_DATETIME}

---

## サマリー

| 項目 | 数値 |
|------|------|
| PR作成 | {github_stats.prs_created} |
| PRマージ | {github_stats.prs_merged} |
| 変更ファイル数 | {github_stats.changed_files} |
| 追加行数 | +{github_stats.additions} |
| 削除行数 | -{github_stats.deletions} |
| Claude Code セッション | {claude_stats.total_sessions} |

---

## GitHub活動

{FOR EACH pr IN github_prs}
### {pr.repo}

#### Pull Requests

| # | タイトル | 状態 | 変更 |
|---|---------|------|------|
| #{pr.number} | {pr.title} | {pr.state} | +{pr.additions}/-{pr.deletions} |

**#{pr.number} {pr.title}**
> {pr.body_preview。なければ「説明なし」}

コミット:
- `{pr.commits[0].sha}` {pr.commits[0].message}
- `{pr.commits[1].sha}` {pr.commits[1].message}
...

{END FOR EACH}

---

## Claude Code 活動

### プロジェクト別詳細

{FOR EACH session IN claude_sessions}
#### {session.project_path} ({session.session_count}セッション)

**主な相談内容:**
{FOR EACH prompt IN session.prompts}
- {prompt}
{END FOR EACH}

{END FOR EACH}

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

- ALWAYS include the Claude Code footer — ensures traceability of report origin
- Format numbers with commas for readability (1,200 instead of 1200) — improves readability of large numbers
- Keep commit messages truncated to first line only — commit details can be checked via git log as needed; prevents verbose reports
- Group data by repository for clarity — organizes cross-repository activity for easy scanning
- Default period: This week's Monday to today (business week) — standard period for weekly reviews; enables immediate use without additional configuration
- For PRs: Include body summary (first 200 chars) if available, otherwise show "説明なし" — PR summaries help recall context during review
- For Claude Code: Extract actual prompt content, exclude slash commands (/clear, /exit, etc.) — slash commands are utility operations and irrelevant to development activity review
- Remove file path prefixes (@path/to/file) from prompts, keep only the question/request part — file paths are noise; retain only the essence of what was consulted
- Use Japanese for all report content (the output report should be in Japanese) — the user is a Japanese speaker and needs to conduct reviews in Japanese
- If a repository has no activity, still list it with "活動なし" — explicitly shows no activity occurred, distinguishing from missing data
