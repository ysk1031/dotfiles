## {{period_label}} の振り返り

**生成日時**: {{generated_at}}

### 今日やったこと

{{#each summarized_prs}}
- **{{repo}} #{{number}}**: {{one_line_summary}}
{{/each}}
{{#if no_pr_activity}}
- (PRに紐づく活動なし — Claude Code セッションのみ)
{{/if}}

{{#if claude_only_highlights}}
**Claude Code 上の作業:**
{{#each claude_only_highlights}}
- {{this}}
{{/each}}
{{/if}}

### 考えたこと・悩んだこと

{{#each reflection_bullets}}
- {{this}}
{{/each}}

### 明日へ

_（明日に持ち越すこと・気になっていることをここにメモ）_

-

### 詳細ログ

<details>
<summary>GitHub PR ({{github_stats.prs_created}}件作成 / {{github_stats.prs_merged}}件マージ)</summary>

{{#each github_prs grouped by repo}}
#### {{repo}}

{{#each prs}}
- **#{{number}} {{title}}** — {{state}} (+{{additions}}/-{{deletions}})
  > {{body_preview || "説明なし"}}
{{#each commits}}
  - `{{sha}}` {{message}}
{{/each}}
{{/each}}

{{/each}}
{{#if no_github_activity}}
_今日のPR活動はありませんでした。_
{{/if}}

</details>

{{#if past_date_mode}}
> ⚠️ 過去日付モード: `--date {{target_date}}` 指定。activity-reporter は対象日のJST 00:00 から「現在」までを収集するため、{{target_date}} 以降のデータが混入する可能性があります。
{{/if}}

🤖 Generated with [Claude Code](https://claude.com/claude-code)
