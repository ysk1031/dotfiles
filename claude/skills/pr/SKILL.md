---
name: pr
description: "Create a GitHub Pull Request with auto-generated title and description. Use when user says 'PR作って', 'create PR', 'プルリクエスト', or wants to push and open a pull request. Do NOT use for reviewing existing PRs, merging PRs, or updating PR descriptions."
allowed-tools: Agent, AskUserQuestion, Bash
argument-hint: "[base-branch to specify target branch] [--draft to create as draft PR]"
metadata:
  author: ysk1031
  version: 1.0.0
---

# Pull Request Creation Skill

Generate a PR title and description from current branch changes, let the user review/edit, then create the PR.

## Instructions

### Phase 1: Analyze Changes (use Agent with subagent)

Call the Agent tool with:
- subagent_type: "pr-composer"
- description: "analyze branch changes for PR"
- prompt: Replace `$ARGUMENTS` in the agent's loaded prompt with the actual user arguments and execute.

The subagent will return the proposed PR content (or an error/status).

---

### Phase 2: User Confirmation (main agent)

Handle based on subagent `status`:

**`"status": "NOT_ON_BRANCH"` / `"NO_BASE"` / `"NO_COMMITS"` / `"NO_CHANGES"`**:
Display the `message` field and stop.

**`"status": "ASK_LANGUAGE"`**:
Use AskUserQuestion:
- question: "PR説明文をどちらの言語で作成しますか？"
- header: "Language"
- options:
  1. label: "日本語", description: "日本語でPR説明文を作成"
  2. label: "English", description: "Create PR description in English"

Then call subagent again with the language specified.

**`"status": "OK"`**:
1. Display the proposed PR `title`, `body`, and **`base`** (target branch)
2. Display unpushed commit information:
   - If `unpushed_count` is a number: "リモートにpushされていないコミットが {unpushed_count} 件あります:\n{unpushed_commits}"
   - If `unpushed_count` is "all": "リモートブランチが未設定のため、全コミットがpushされます。"
3. Use AskUserQuestion:
   - question: "このPR内容でよろしいですか？"
   - header: "PR"
   - options:
     1. label: "Accept", description: "このままPRを作成"
     2. label: "Edit", description: "内容を編集（Otherで自由入力）"
     3. label: "Cancel", description: "PRを作成せずに終了"

**If "Accept"**: Proceed to Phase 3
**If "Edit"**: User provides custom content via "Other". Parse title and body from input (first line = title, rest = body)
**If "Cancel"**: Print "PRの作成をキャンセルしました。" and stop

---

### Phase 3: Create PR (main agent with Bash)

1. Push to remote:

First, check if the remote branch exists and compare history:
```bash
git fetch origin
```

- If the remote branch does NOT exist (new branch): proceed with `git push -u origin HEAD`
- If the remote branch exists: run `git status` to check ahead/behind status
  - If local is ahead only (fast-forward possible): proceed with `git push -u origin HEAD`
  - If local has diverged or is behind (history rewritten by rebase/amend/etc.):
    Use AskUserQuestion:
    - question: "リモートブランチとローカルブランチの履歴が分岐しています（rebase/amendなどによる可能性があります）。Force pushしますか？"
    - header: "Push"
    - options:
      1. label: "Force push", description: "git push --force-with-lease で強制pushします"
      2. label: "キャンセル", description: "PRの作成を中止します"
    - If "Force push": run `git push --force-with-lease -u origin HEAD`
    - If "キャンセル": Print "PRの作成をキャンセルしました。" and stop

If push fails for any other reason, display the error message and stop.

2. Create PR:
```bash
gh pr create --base <base from subagent output> --title "<title from subagent output>" --body "$(cat <<'EOF'
<body>

---
🤖 Generated with [Claude Code](https://claude.com/claude-code)
EOF
)" [--draft if specified]
```

3. Display the PR URL from the command output

---

### Rules
- ALWAYS add footer: `🤖 Generated with [Claude Code](https://claude.com/claude-code)` — ensures traceability of PR origin
- Push to remote without additional confirmation (required for PR creation) — pushing is a prerequisite for PR creation; confirming each time adds unnecessary friction
- Use HEREDOC for body to ensure proper formatting — regular strings don't properly handle markdown line breaks and special characters
- Keep title concise (under 72 characters if possible) — prevents truncation in GitHub UI and maintains readability in PR lists
- If --draft flag is in arguments, add --draft to gh pr create — accurately reflects the user's intent in the GitHub API call
- ALWAYS use the `base` value from the subagent output for `--base` — the subagent detects the correct base branch from git remote config; do NOT substitute the system prompt's "Main branch" value, as it may be inaccurate
- NEVER use `--force` for push — always use `--force-with-lease` to prevent overwriting others' commits — `--force` unconditionally overwrites the remote, while `--force-with-lease` fails if the remote has been updated by someone else since your last fetch
- ALWAYS confirm with user before force pushing — force push is destructive and irreversible; silent force push can destroy teammates' work

---

### Examples

#### Example 1: 通常のPR作成
User says: "PR作って"
Actions:
1. pr-composer がブランチの差分を分析
2. PRタイトルと説明文を提案
3. ユーザー確認後、push → PR作成
Result: GitHub上にPRが作成され、URLが表示される

#### Example 2: ドラフトPR
User says: "--draft でPR作って"
Actions:
1. 通常と同じ分析・提案フロー
2. `--draft` フラグ付きでPR作成
Result: ドラフト状態のPRが作成される

---

### Troubleshooting

#### "NOT_ON_BRANCH"
Cause: detached HEAD状態でブランチに属していない
Solution: `git checkout -b <branch-name>` でブランチを作成

#### "NO_COMMITS"
Cause: ベースブランチとの差分コミットがない
Solution: 変更をコミットしてから再実行

#### Push失敗
Cause: リモートの認証が切れている、またはpermission不足
Solution: `gh auth login` で再認証
