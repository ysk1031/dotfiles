# 週次開発振り返りレポート

**期間**: {{period}}
**生成日時**: {{generated_at}}

---

## サマリー

| 項目 | 数値 |
|------|------|
| PR作成 | {{github_stats.prs_created}} |
| PRマージ | {{github_stats.prs_merged}} |
| 変更ファイル数 | {{github_stats.changed_files}} |
| 追加行数 | +{{github_stats.additions}} |
| 削除行数 | -{{github_stats.deletions}} |
| Claude Code セッション | {{claude_stats.total_sessions}} |

---

## GitHub活動

{{#each github_prs grouped by repo}}
### {{repo}}

#### Pull Requests

| # | タイトル | 状態 | 変更 |
|---|---------|------|------|
{{#each prs}}
| #{{number}} | {{title}} | {{state}} | +{{additions}}/-{{deletions}} |
{{/each}}

{{#each prs}}
**#{{number}} {{title}}**
> {{body_preview || "説明なし"}}

コミット:
{{#each commits}}
- `{{sha}}` {{message}}
{{/each}}

{{/each}}
{{/each}}

---

## Claude Code 活動

### プロジェクト別詳細

{{#each claude_sessions}}
#### {{project_path}} ({{session_count}}セッション)

**主な相談内容:**
{{#each prompts}}
- {{this}}
{{/each}}

{{/each}}

---

## 振り返りメモ

_（ここに振り返りを記入）_

---

🤖 Generated with [Claude Code](https://claude.com/claude-code)
