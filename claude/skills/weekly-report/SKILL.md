---
name: weekly-report
description: "Aggregate GitHub + Claude Code activity into a structured weekly review report. Use when user says '週報を作って', 'weekly report', '今週の振り返り', '活動レポート', or wants to review development activity for a period. Do NOT use for daily standups, sprint planning, or non-development activity tracking."
allowed-tools: Agent, AskUserQuestion, Bash
argument-hint: "[--repos owner/repo1,repo2 to restrict (default: auto-detect all)] [--days N to set lookback period] [--output path to set output file]"
disable-model-invocation: true
metadata:
  author: ysk1031
  version: 1.0.0
---

# Weekly Development Review Report Skill

Generate a review report aggregating development activity (GitHub + Claude Code sessions) for the past week.

## Instructions

### Phase 1: Data Collection (use Agent with subagent)

Call the Agent tool with:
- subagent_type: "activity-reporter"
- description: "collect weekly dev activity data"
- prompt: Replace `$ARGUMENTS` in the agent's loaded prompt with the actual user arguments and execute.

The subagent will return collected data (or an error/status).

---

### Phase 2: User Confirmation (main agent)

Handle based on subagent `status`:

**`"status": "GH_AUTH_REQUIRED"` / `"JQ_REQUIRED"` / `"NO_REPOS"`**:
Display the `message` field and stop. Note: `NO_REPOS` is only returned when `--repos` is explicitly specified but none are accessible. When repos are auto-detected, empty results continue with Claude Code data only.

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
   - Target repositories (`repos`). If repos is an empty array, display: "GitHub活動: なし（期間内にPR活動のあるリポジトリが見つかりませんでした）"
   - Output path (`output_path`). サブエージェントの JSON に `output_path` が含まれない場合は `~/weekly-report-{START_DATE}.md` をデフォルトとして使用する。

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

**output_path の決定**: Phase 1 サブエージェントの JSON レスポンスから取得した `output_path` の値をそのまま使用すること。サブエージェントが `output_path` を返さなかった場合のみ、`~/weekly-report-{START_DATE}.md` をフォールバックとして使用する。独自にパスを生成してはならない。

1. Read the report template from the `assets/report-template.md` file (relative to this skill's directory) with the Read tool.
2. Use the Write tool to create the report file at `{output_path}`. Populate the template by replacing `{{placeholder}}` values with actual data from the Phase 1 JSON, and expanding `{{#each}}` blocks by iterating over the corresponding arrays. For `{{body_preview || "説明なし"}}`, use the PR body preview if available, otherwise use "説明なし".

3. Display report preview to terminal:
   - Show full report content formatted nicely
   - Print saved file path

4. Confirmation message:
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
- Default repository scope: All repositories with PR activity in the period (auto-detected via GitHub search API) — eliminates the need to specify repos manually for standard weekly reviews
- For PRs: Include body summary (first 200 chars) if available, otherwise show "説明なし" — PR summaries help recall context during review
- For Claude Code: Extract actual prompt content, exclude slash commands (/clear, /exit, etc.) — slash commands are utility operations and irrelevant to development activity review
- Remove file path prefixes (@path/to/file) from prompts, keep only the question/request part — file paths are noise; retain only the essence of what was consulted
- Use Japanese for all report content (the output report should be in Japanese) — the user is a Japanese speaker and needs to conduct reviews in Japanese
- If a repository has no activity, still list it with "活動なし" — explicitly shows no activity occurred, distinguishing from missing data

---

### Examples

#### Example 1: 通常の週報生成
User says: "週報を作って"
Actions:
1. activity-reporter がGitHub活動とClaude Codeセッションを収集
2. データプレビューを表示
3. ユーザー確認後、テンプレートに沿ってレポートを生成
Result: `~/weekly-report-YYYY-MM-DD.md` にレポートが保存される

#### Example 2: 期間指定
User says: "--days 14 で過去2週間のレポート"
Actions:
1. 過去14日間のデータを収集
2. 通常と同じフロー
Result: 2週間分のデータを含むレポートが生成される

---

### Troubleshooting

#### "GH_AUTH_REQUIRED"
Cause: GitHub CLIが未認証
Solution: `gh auth login` を実行してGitHub認証を完了

#### "JQ_REQUIRED"
Cause: jqコマンドがインストールされていない
Solution: `brew install jq` でインストール

#### "NO_DATA"
Cause: 指定期間内にデータが見つからない
Solution: `--days` で期間を延長して再実行
