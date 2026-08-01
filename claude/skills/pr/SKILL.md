---
name: pr
description: "Create a GitHub Pull Request with auto-generated title and description. Use when user says 'PR作って', 'create PR', 'プルリクエスト', or wants to push and open a pull request. ALSO use whenever you (the agent) are about to open a pull request as the culmination of a task — never run `gh pr create` directly; always route through this skill. When creating a PR autonomously without an interactive user available to confirm, invoke with `--auto` (creates a draft and skips the chat confirmation). ALSO use when rewriting the description of a PR that already exists ('PRの説明を更新して', 'PR本文が古いので直して', `gh pr edit --body`) — the same template and body rules apply there. Do NOT use for reviewing existing PRs or merging PRs."
allowed-tools: AskUserQuestion, Bash
argument-hint: "[base-branch to specify target branch] [--draft to create as draft PR] [--auto for autonomous/non-interactive runs: create as draft and skip chat confirmation]"
metadata:
  author: ysk1031
  version: 2.3.0
---

# Pull Request Creation Skill

Analyze current branch changes, generate a PR title and description, let the user review/edit, then create the PR. All phases run in the main agent — do NOT use subagents (their output is collapsed in the UI and invisible to the user). Draft confirmation happens via a normal chat reply, NOT AskUserQuestion (see Phase 2 Step 3 for why).

**Autonomous mode (`--auto`):** When invoked with `--auto` (agent-initiated PR with no interactive user to confirm), the skill still runs Phase 1 analysis, but skips the Phase 2 Step 3 chat confirmation and forces a **draft** PR. The draft is the asynchronous approval gate: the human reviews it on GitHub and marks it "Ready for review" when satisfied. `--auto` never force-pushes (see Phase 3).

## Instructions

### Phase 1: Analyze Changes (Bash)

Use ONLY read-only commands (`git`, `gh`, `cat`) in this phase. NEVER modify, create, or delete any files.

**Step 0: Suggest pre-pr-review (once, non-blocking)**
If ALL of the following hold, suggest — in one line, once per session — running the `pre-pr-review` skill before continuing, then wait for the user's reply:
- the `pre-pr-review` skill has NOT been run for this branch in this session
- the diff vs. the base branch is non-trivial (new files, new exported types, or roughly 50+ changed lines)

Example: 「PR作成前に /pre-pr-review（単純化＋慣習整合のセルフレビュー。専門家観点の追加も選べます）を回しますか？ 回さず進める場合はこのまま続けます。」
If the user declines, has already run it, or the diff is trivial: continue without mentioning it again.

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
- If exists, read its content for format reference — follow its headings and checklist as-is. Do NOT invent your own structure (a `Summary / Changes / Test Plan` layout written over a template that asks for something else has been rejected before). Keep sections that don't apply, filled with 該当なし / N/A or left as unchecked `[ ]`
- Only the repository root's `.github/` (or root / `docs/`) template is the one GitHub uses. In a monorepo, ignore template-looking files under subdirectories

**Step 6.5: Check Project Conventions**
Read the project's `CLAUDE.md` (if present) for PR-related conventions — e.g. a required title prefix (issue number, ticket ID), a default draft state, or required sections. Apply anything found there in Phase 2.

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
- If Step 6.5 found a required title prefix convention, apply it
- An identifier that only makes sense inside the code (a column name, a type, a coined term) needs a short parenthetical gloss so a reviewer who did not write the change can read the title: `feat: add consumed_feedback_boundary (どこまでのフィードバックを反映済みか示す境界)`. When the gloss would push the title past ~72 characters, keep the title short and define the identifier in the body's first paragraph instead.

**Step 2: Generate Description**
Writing style rules:
- When writing in Japanese: ALWAYS use 常体 (plain form / だ・である調). NEVER use 丁寧語 (polite form / です・ます調).
  - Good: 「認証ロジックを追加した」「エラーハンドリングを改善する」「不要な依存を削除した」
  - Bad: 「認証ロジックを追加しました」「エラーハンドリングを改善します」「不要な依存を削除しました」
- When writing in English: no special style constraint.

What the body is, and is not:
- It describes the final diff. It is not a work log: the self-review, the pre-PR check, the review rounds and the approaches abandoned along the way all stay out. The reader is a reviewer who did not write the code, and the only question they need answered is what changes when this ships.
- Fill each template section by how well the facts support it: write what the diff and the repository establish, put 該当なし / N/A where they establish nothing, and ask the user where the answer is not the kind of thing either can settle. Checklists follow the same rule — `[x]` only where a fact backs it, otherwise leave `[ ]`. Never fill or tick from guesswork.
- Rewriting an existing description follows every rule above, and re-derives the content from the commits as they stand now rather than patching the old text.

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

**Step 3: Display Draft and END THE TURN — do NOT use AskUserQuestion for confirmation**

**If `--auto` was passed:** skip this entire step (no draft display, no turn end, no confirmation). Proceed directly to Phase 3 with `--draft` forced. The GitHub draft is the approval gate instead.

**Why no AskUserQuestion here:** text output in the same turn is only guaranteed visible to the user when it is the FINAL message of the turn with NO tool calls after it. Calling AskUserQuestion after displaying the draft causes the dialog to redraw the terminal and hide the draft text — this has repeatedly broken in the past. Confirmation MUST happen via the user's next chat message instead.

1. Output the following as the final response text of this turn:
   ```
   **Base:** <base>

   # <title>

   <body — full text, never summarized or truncated>
   ```
   Followed by unpushed commit information:
   - If there are unpushed commits: "リモートにpushされていないコミットが {count} 件あります:\n{commit list}"
   - If no remote tracking branch: "リモートブランチが未設定のため、全コミットがpushされます。"

   Followed by the confirmation prompt:
   "この内容でPRを作成してよければ「OK」と返信してください。修正したい場合は修正内容を、中止する場合は「キャンセル」と返信してください。"

2. **END THE TURN immediately after this message.** Do NOT call any tool (Bash, AskUserQuestion, anything) after displaying the draft. The draft must be the last thing in the turn.

3. Handle the user's reply:
   - **Approval** ("OK", "いいよ", "作成して", etc.): Proceed to Phase 3
   - **Edit request** (correction instructions or replacement text): Revise the title/body accordingly, then repeat this Step 3 (re-display the full revised draft and end the turn again)
   - **Cancel** ("キャンセル", "やめる", etc.): Print "PRの作成をキャンセルしました。" and stop

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
    **If `--auto` was passed:** do NOT force push (no interactive user to authorize a destructive operation). Print "リモートブランチと履歴が分岐しているため、自律モードではpushを中止した。手動で確認してほしい。" and stop.
    Otherwise, use AskUserQuestion:
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
)" [--draft if specified, OR always --draft when --auto]
```

3. Display the PR URL from the command output
   - If `--auto` was used: also print "自律作成のためdraftで作成した。レビューして問題なければ GitHub で Ready for review に切り替えてほしい。"

---

### Rules
- ALWAYS add footer: `🤖 Generated with [Claude Code](https://claude.com/claude-code)` — ensures traceability of PR origin
- Push to remote without additional confirmation (required for PR creation) — pushing is a prerequisite for PR creation; confirming each time adds unnecessary friction
- Use HEREDOC for body to ensure proper formatting — regular strings don't properly handle markdown line breaks and special characters
- Keep title concise (under 72 characters if possible) — prevents truncation in GitHub UI and maintains readability in PR lists
- If --draft flag is in arguments, add --draft to gh pr create — accurately reflects the user's intent in the GitHub API call
- If --auto flag is in arguments, always create as draft and skip the Phase 2 Step 3 chat confirmation — autonomous runs have no interactive user, so the draft PR serves as the asynchronous approval gate the human flips to "Ready for review"
- Under --auto, NEVER force push — abort on diverged history instead — force push is destructive and there is no interactive user to authorize it
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

#### Example 3: 自律作成（--auto）
Context: エージェントがタスクの締めくくりとして、対話ユーザーの確認を取れないまま PR を作る
Actions:
1. Phase 1 の分析は通常どおり実行
2. Phase 2 Step 3 のチャット確認をスキップ
3. `--draft` を強制して `gh pr create`
Result: draft PR が作成され、URL と「Ready for review に切り替えてほしい」旨を報告。承認権は GitHub の draft ゲートに残る

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
