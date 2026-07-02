---
name: daily-report
description: "Aggregate today's Claude Code session logs and GitHub activity into a personal reflection-style daily report (what I did / what I was thinking / what I struggled with). Use whenever the user says '日報', 'daily report', '今日の振り返り', '今日何やった', '今日まとめて', or wants a self-reflective summary of a single day's development work. This is the right skill anytime the scope is a single day — even if the user doesn't say '日報' explicitly. Distinct from [[weekly-report]] (which covers a multi-day business week with aggregate stats); prefer daily-report for single-day scopes. Do NOT use for non-development journaling, sprint planning, or weekly/monthly reviews."
allowed-tools: Agent, AskUserQuestion, Bash
argument-hint: "[--repos owner/repo1,repo2 to restrict (default: auto-detect)] [--date YYYY-MM-DD to target a past day instead of today] [--output path to override output file]"
disable-model-invocation: true
metadata:
  author: ysk1031
  version: 1.1.0
---

# Daily Development Reflection Report Skill

Generate a reflective daily report aggregating today's development activity (GitHub + Claude Code sessions). The goal is to surface **what I did**, **what I was thinking**, and **what I was struggling with** — not a comprehensive log dump.

This is a personal journal-style report for the user's own use, not a status report for others.

---

## Phase 1: Data Collection (use Agent with subagent)

Compute today's date in JST and call the `activity-reporter` subagent.

```bash
TODAY=$(date +%Y-%m-%d)
```

Then call the Agent tool with:
- subagent_type: "activity-reporter"
- description: "collect today's dev activity data"
- prompt: Pass `--days 0 --output ~/Desktop/daily-report-${TODAY}.md` as the arguments. If the user supplied `--repos`, append that. If the user supplied `--date YYYY-MM-DD`, translate it: compute `DAYS_AGO=$(( ($(date +%s) - $(date -j -f "%Y-%m-%d" "$USER_DATE" +%s)) / 86400 ))` and pass `--days $DAYS_AGO --output ~/Desktop/daily-report-${USER_DATE}.md` instead. The activity-reporter then collects data from JST 00:00 of the target date to "now" (which, for a past date, will include time after that date — for typical use cases this is fine because the focus is the target day's activity; if precision is needed, this is a known limitation noted under Rules).

The subagent returns collected data as JSON (or an error/status). The agent treats `--days 0` as "from today's JST midnight to now" via its existing date-range logic.

---

## Phase 2: User Confirmation (main agent)

Handle the subagent's `status` field:

**`"GH_AUTH_REQUIRED"` / `"JQ_REQUIRED"` / `"NO_REPOS"`**:
Display the `message` field verbatim and stop.

**`"NO_DATA"`**:
For a daily report, "no data today" is a normal outcome (the user might not have worked yet, or only had meetings). Use AskUserQuestion:
- question: "今日の活動データが見つかりませんでした。どうしますか？"
- header: "No data"
- options:
  1. label: "昨日分を生成", description: "1日前のデータでレポートを生成（昨日の振り返り）"
  2. label: "過去3日分", description: "直近3日間に広げて再収集"
  3. label: "キャンセル", description: "レポート生成を中止"

If "昨日分", re-invoke Phase 1 with `--days 1 --output ~/Desktop/daily-report-$(date -v-1d +%Y-%m-%d).md`.
If "過去3日分", re-invoke with `--days 3 --output ~/Desktop/daily-report-${TODAY}.md`.
If "キャンセル", print "レポート生成をキャンセルしました。" and stop.

**`"OK"`**:
Show a brief preview — for a daily report, keep this very short, since the user is about to read the full report anyway — then confirm via a normal chat reply, NOT AskUserQuestion.

**Why no AskUserQuestion here:** text output in the same turn is only guaranteed visible to the user when it is the FINAL message of the turn with NO tool calls after it. Calling AskUserQuestion after displaying the preview causes the dialog to redraw the terminal and hide the preview text (same issue previously fixed in [[pr]]). Confirmation MUST happen via the user's next chat message instead.

1. Output the following as the final response text of this turn:

   ```
   今日の活動: PR {prs_created}件作成 / {prs_merged}件マージ, Claude Code セッション {total_sessions}件
   対象リポジトリ: {repos joined by ', ' — or "なし（GitHub PR活動なし）" if empty}
   出力先: {output_path}
   ```

   Followed by the confirmation prompt:
   "このデータで日報を生成してよければ「OK」と返信してください。中止する場合は「キャンセル」と返信してください。"

2. **END THE TURN immediately after this message.** Do NOT call any tool (Bash, AskUserQuestion, anything) after displaying the preview. The preview must be the last thing in the turn.

3. Handle the user's reply:
   - **Approval** ("OK", "生成して", "お願い", etc.): Proceed to Phase 3
   - **Cancel** ("キャンセル", "やめる", etc.): Print "レポート生成をキャンセルしました。" and stop

Note: The `"NO_DATA"` path above still uses AskUserQuestion — that is fine, because no preview text precedes the dialog there (the question itself is the only content).

Note: We do NOT offer "期間を変更" here. Daily reports are scoped to a single day by design — if the user wants a multi-day view, they should use [[weekly-report]] instead.

---

## Phase 3: Generate Report (main agent with Write tool)

Read the report template at `assets/report-template.md` (relative to this skill's directory).

The template uses `{{placeholder}}` and `{{#each ...}}` blocks. Some slots map directly to the Phase 1 JSON (e.g., `{{github_stats.prs_created}}`, `{{github_prs}}`, `{{claude_sessions}}`). The rest are **derived fields** you compute yourself from the JSON. The derived fields are:

| Template variable | How to derive |
|---|---|
| `period_label` | Target date in `YYYY-MM-DD (曜日)` form, e.g., `2026-05-25 (月)`. For past-date mode use the target date; otherwise use today. |
| `generated_at` | Current ISO8601 datetime in JST when writing the file (e.g., `2026-05-25T14:32:00+09:00`). |
| `summarized_prs` | Array of `{repo, number, one_line_summary}` — see 「今日やったこと」 below. |
| `no_pr_activity` | Boolean: true if `summarized_prs` is empty. |
| `claude_only_highlights` | Optional 0-3 line summary of project-level work surfaced only via Claude Code (no PR). Skip if redundant with `summarized_prs`. |
| `reflection_bullets` | Array of 2-5 strings — see 「考えたこと・悩んだこと」 below. |
| `no_github_activity` | Boolean: true if `github_prs` is empty. |
| `no_claude_activity` | Boolean: true if `claude_sessions` is empty. |
| `past_date_mode` | Boolean: true if `--date` was supplied. |
| `target_date` | The user-supplied date (only used when `past_date_mode`). |

Most slots are mechanical substitutions, but the two narrative sections — **今日やったこと** (`summarized_prs`) and **考えたこと・悩んだこと** (`reflection_bullets`) — require judgment, not listing. See the per-section guidance below.

### 「今日やったこと」 section

For each PR with substantive activity today, write **one line** in this form:
```
- **{repo} #{number}**: {一文での要約}
```

The summary should be in your own words drawn from `title` + `body_preview` — not a verbatim title copy. Aim for "何をやったか" plain language, e.g., "認証ミドルウェアにJWT検証を追加" rather than "feat(auth): add JWT verification to middleware".

If there are no PRs, write: `- (PRに紐づく活動なし — Claude Code セッションのみ)`

### 「考えたこと・悩んだこと」 section

This is the heart of the report. Scan `claude_sessions[].prompts` for signs of thinking/struggle, then **abstract upward** to the underlying themes. The user is the audience — they already lived the day, so quoting individual prompts back at them is low value. What they want is a higher-altitude read on *what kind of thinking they were doing today*.

Aim for **2-5 bullets**, each describing a theme in **one or two sentences**. Quoting specific prompts is allowed but should be rare — use a quote only when one specific phrase crystallizes a theme better than paraphrase can. Default to abstraction.

Signals worth abstracting from:
- Repeated questions of the same shape (multiple "なぜ X？", "Y って合ってる？" across the day → a thinking pattern, not N separate facts)
- Comparative deliberation across alternatives
- Stuck-points or repeated debugging questions
- Design decisions and naming concerns
- Trade-off framing ("X を優先するか Y を優先するか")

Example of the right altitude:

```
- コードレビュー対応で、ドメインモデルの責務境界と命名の妥当性に繰り返し立ち戻っていた。設計判断を即決せず、自分の理解と照合しながら詰める進め方をしていた日。
- プロンプトチューニングは「部分最適に陥っている感覚」と「全体の読みやすさ」の往復で、評価を回しては書き直す試行錯誤が中心だった。
- タスクの優先度判断では、与えられた前提を一度疑ってから結論を出す思考をしていた（「この前提がなかったら結論は変わるか？」と問い直す型）。
```

Example of **too concrete** (avoid this):

```
- `is_first_use` の命名を悩んだ。`current_last_used_at` の等号/不等号を悩んだ。`_ensure_utc` の呼び出し要否を悩んだ。
```

→ This is a list of individual points. Fold it up one level of abstraction, e.g. 「ドメインモデルの責務境界と命名」.

If no reflective material is found, write: `- 今日は淡々と手を動かす日だった様子（明確な悩み・迷いのシグナルは見当たらず）`

Avoid:
- Listing prompts verbatim or near-verbatim — abstract upward instead
- Long quote chains — pick at most one quote per bullet, and only when it adds something paraphrase can't
- Including slash commands or one-word prompts as "thinking" — they're noise
- Speculating about emotions not evidenced in the prompts

### 「詳細ログ」 section

Mechanical expansion — list every PR (number, title, state, additions/deletions) and every Claude Code session group (project_path, session_count, all prompts). This is the raw record for when the narrative sections are insufficient.

**Collapsing uses Obsidian foldable callouts, NOT HTML `<details>`.** This report is read primarily in Obsidian, where `<details>` blocks containing blank-line-separated Markdown fail to collapse (Obsidian terminates the HTML block at the first blank line, so the content renders outside the `<details>` and is always expanded). Use the `> [!note]- Title` callout syntax from the template instead, with every content line prefixed by `>`. Do not reintroduce `<details>`/`<summary>` for these sections.

### Writing the file

Use the Write tool to create the file at `output_path` returned by the subagent. If the subagent did not return `output_path`, fall back to `~/Desktop/daily-report-${TODAY}.md`.

After writing:
1. Display a short preview to the terminal — just the top of the report (date header through 「考えたこと・悩んだこと」).
2. Print the saved file path on its own line:
   ```
   Report generated: {OUTPUT_PATH}
   ```

---

## Rules

- **Single-day scope by design** — if the user wants a wider window, route them to [[weekly-report]] instead of expanding here.
- **Reflective tone, not status-report tone** — this report is for the user themselves. Use phrasing like "〜に悩んでいた様子" or "〜を考えていた" rather than "〜を完了しました". The user is the audience; objectivity matters more than achievement-emphasis.
- **Don't over-extract from prompts** — Claude Code prompts include a lot of routine task-giving. Only the reflective/uncertain ones belong in the 「考えたこと・悩んだこと」 section. When in doubt, leave it out — the appendix preserves the raw record.
- **Past-date mode is approximate** — `--date YYYY-MM-DD` translates to `--days N`, which means the activity-reporter scans from JST 00:00 of the target date to *now*, not to 23:59 of that date. This is generally fine for the most-recent day or two, but data from later dates will leak in. Note this in a footer warning when `--date` is used.
- **Japanese output** — the report body must be in Japanese (the user is a Japanese speaker writing in Japanese). ALWAYS use 常体 (plain form / だ・である調), NEVER 丁寧語 (です・ます調).
- **Include the Claude Code footer** — for traceability.
- **GitHub activity may be sparse** — the underlying agent only fetches PRs created in the window, not commits-without-PR or comments on older PRs. For a daily report this often means GitHub section is empty; that's expected, and the Claude Code section carries the day.

---

## Examples

### Example 1: 通常の日報生成
User says: "日報作って"
Actions:
1. `activity-reporter` を `--days 0` で呼び出し
2. 簡易プレビュー表示でターンを終了し、ユーザーのチャット返信で確認
3. テンプレートに沿って `~/Desktop/daily-report-YYYY-MM-DD.md` を生成

### Example 2: 過去の日報生成
User says: "/daily-report --date 2026-05-23"
Actions:
1. 今日との差分日数を計算し `--days N` に変換して活動収集
2. ファイル名に対象日付を使う (`~/Desktop/daily-report-2026-05-23.md`)
3. フッターに「過去日付モード: NOW までのデータが含まれる可能性あり」と注記

### Example 3: 今日まだ活動なし
User says: "今日の振り返り"
Subagent returns `NO_DATA`.
Actions:
1. 「昨日分を生成 / 過去3日分 / キャンセル」を提示
2. ユーザー選択に応じて再収集

---

## Troubleshooting

### "GH_AUTH_REQUIRED"
Cause: GitHub CLI 未認証
Solution: `gh auth login` を実行

### "JQ_REQUIRED"
Cause: jq 未インストール
Solution: `brew install jq`

### "NO_DATA"
今日まだ活動がない時の自然な結果。Phase 2 のフォールバック選択肢で対応。
