---
name: pr
description: "Create a GitHub Pull Request with auto-generated title and description. Use when user says 'PR作って', 'create PR', 'プルリクエスト', or wants to push and open a pull request. Do NOT use for reviewing existing PRs, merging PRs, or updating PR descriptions."
allowed-tools: AskUserQuestion, Bash
argument-hint: "[base-branch to specify target branch] [--draft to create as draft PR]"
metadata:
  author: ysk1031
  version: 2.0.0
---

# Pull Request Creation Skill

Analyze current branch changes, generate a PR title and description, let the user review/edit, then create the PR. All phases run in the main agent — do NOT use subagents (their output is collapsed in the UI and invisible to the user).

## Instructions

### Phase 1: Analyze Changes (Bash)

Use ONLY read-only commands (`git`, `gh`, `cat`) in this phase. NEVER modify, create, or delete any files.

**Step 1: Check Current Branch**
Run: `git branch --show-current`

If empty (detached HEAD), display the following and stop:
```
現在detached HEAD状態です。ブランチを作成してください。
git checkout -b <branch-name>
```

**Step 2: Determine Base Branch**
If arguments specify a base branch, use that.
Otherwise, auto-detect:
1. Try: `git remote show origin 2>/dev/null | grep 'HEAD branch' | awk '{print $NF}'`
2. If empty, check existence: main → master → develop
   - `git show-ref --verify --quiet refs/heads/main && echo main`
   - `git show-ref --verify --quiet refs/heads/master && echo master`
   - `git show-ref --verify --quiet refs/heads/develop && echo develop`

If no base branch found, display "ベースブランチを特定できませんでした。引数でベースブランチを指定してください。" and stop.

**Step 3: Check for Commits**
Run: `git log <base>..HEAD --oneline`

If empty, display "ベースブランチとの差分コミットがありません。変更をコミットしてから再実行してください。" and stop.

**Step 4: Check for Changes**
Run: `git diff <base>...HEAD --stat`

If empty, display "ベースブランチとの差分がありません。" and stop.

**Step 5: Gather Information**
- `git log <base>..HEAD --oneline` (commit list — already obtained in Step 3)
- `git diff <base>...HEAD --stat` (already obtained in Step 4)
- `git diff <base>...HEAD` (detailed diff)
  - If the stat shows a very large diff (e.g. thousands of lines or generated/lock files), do NOT read the full diff. Instead, read per-file diffs for the meaningful source files only and skip generated files (lock files, build output, snapshots).

**Step 5.5: Check Unpushed Commits**
Check if a remote tracking branch exists and count unpushed commits:
```bash
REMOTE_BRANCH=$(git rev-parse --abbrev-ref --symbolic-full-name @{u} 2>/dev/null)
if [ -n "$REMOTE_BRANCH" ]; then
  git log ${REMOTE_BRANCH}..HEAD --oneline
else
  echo "(リモートブランチ未設定 — 全コミットがpushされます)"
fi
```

**Step 6: Check PR Template**
Check if `.github/pull_request_template.md` exists:
- If exists, read its content for format reference

**Step 7: Detect Language**
Check recent commits and existing PRs:
- `git log --oneline -10`
- `gh pr list --limit 5 2>/dev/null || true`

If majority contain Japanese text → use Japanese
If majority contain English text → use English
If unclear (mixed or cannot determine), use AskUserQuestion:
- question: "PR説明文をどちらの言語で作成しますか？"
- header: "Language"
- options:
  1. label: "日本語", description: "日本語でPR説明文を作成"
  2. label: "English", description: "Create PR description in English"

Then continue to Phase 2 with the selected language (do NOT re-run the analysis — reuse the information already gathered).

---

### Phase 2: Draft & User Confirmation

**Step 1: Generate Title**
- If single commit: use that commit message as title
- If multiple commits: summarize changes into a concise title

**Step 2: Generate Description**
Writing style rules:
- When writing in Japanese: ALWAYS use 常体 (plain form / だ・である調). NEVER use 丁寧語 (polite form / です・ます調).
  - Good: 「認証ロジックを追加した」「エラーハンドリングを改善する」「不要な依存を削除した」
  - Bad: 「認証ロジックを追加しました」「エラーハンドリングを改善します」「不要な依存を削除しました」
- When writing in English: no special style constraint.

If PR template exists: follow that format
Otherwise, use default format:

```markdown
## Summary
[Brief description of what this PR does and why]

## Changes
- [Change 1]
- [Change 2]
- [Change 3]

## Test Plan
- [ ] [How to verify this change]
```

**Step 3: Display Draft and Confirm**
1. **MUST: Output the proposed PR draft as user-visible response text (normal markdown output, NOT thinking) BEFORE calling AskUserQuestion.** Normal response text is never truncated, so this is the only place the user can review the full draft. Display in this format:
   ```
   **Base:** <base>

   # <title>

   <body — full text, never summarized or truncated>
   ```
2. Display unpushed commit information (also as visible text):
   - If there are unpushed commits: "リモートにpushされていないコミットが {count} 件あります:\n{commit list}"
   - If no remote tracking branch: "リモートブランチが未設定のため、全コミットがpushされます。"
3. Use AskUserQuestion:
   - question: "このPR内容でよろしいですか？"
   - header: "PR"
   - options:
     1. label: "Accept", description: "このままPRを作成"
     2. label: "Edit", description: "内容を編集（Otherで自由入力）"
     3. label: "Cancel", description: "PRを作成せずに終了"
   - **Do NOT use the `preview` field** — the preview pane has a fixed height and truncates long drafts, which misleads the user into thinking content is missing. The full draft is already shown as visible text in step 1; AskUserQuestion is for confirmation only.

**If "Accept"**: Proceed to Phase 3
**If "Edit"**: User provides custom content via "Other". Parse title and body from input (first line = title, rest = body)
**If "Cancel"**: Print "PRの作成をキャンセルしました。" and stop

---

### Phase 3: Create PR (Bash)

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
gh pr create --base <base from Phase 1> --title "<confirmed title>" --body "$(cat <<'EOF'
<confirmed body>

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
- ALWAYS use the `base` value detected in Phase 1 Step 2 for `--base` — do NOT substitute the system prompt's "Main branch" value, as it may be inaccurate
- NEVER use `--force` for push — always use `--force-with-lease` to prevent overwriting others' commits — `--force` unconditionally overwrites the remote, while `--force-with-lease` fails if the remote has been updated by someone else since your last fetch
- ALWAYS confirm with user before force pushing — force push is destructive and irreversible; silent force push can destroy teammates' work

---

### Examples

#### Example 1: 通常のPR作成
User says: "PR作って"
Actions:
1. ブランチの差分を分析
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

#### Detached HEAD
Cause: detached HEAD状態でブランチに属していない
Solution: `git checkout -b <branch-name>` でブランチを作成

#### 差分コミットなし
Cause: ベースブランチとの差分コミットがない
Solution: 変更をコミットしてから再実行

#### Push失敗
Cause: リモートの認証が切れている、またはpermission不足
Solution: `gh auth login` で再認証
