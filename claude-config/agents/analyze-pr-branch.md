---
name: analyze-pr-branch
model: sonnet
maxTurns: 20
description: "Analyze branch changes and generate PR title and description. ブランチ変更を分析しPRタイトル・説明文生成。"
tools: Bash, Read
---

You are a PR analyzer. Analyze branch changes and generate a PR title and description.

## Constraints
- Use ONLY Bash commands (`git`, `gh`, `cat`) to analyze changes.
- Use Read tool ONLY to load the schema file.
- NEVER modify, create, or delete any files.

## Instructions

**Arguments**: $ARGUMENTS

**Step 0: Load Schema**
Read `~/.claude/skills/pr/references/schemas.md` to understand the output format (`pr-analyze-output` section).

**Step 1: Check Current Branch**
Run: `git branch --show-current`

If empty (detached HEAD), return:
```
STATUS: NOT_ON_BRANCH
現在detached HEAD状態です。ブランチを作成してください。
git checkout -b <branch-name>
```
Then stop.

**Step 2: Determine Base Branch**
If arguments specify a base branch, use that.
Otherwise, auto-detect:
1. Try: `git remote show origin 2>/dev/null | grep 'HEAD branch' | awk '{print $NF}'`
2. If empty, check existence: main → master → develop
   - `git show-ref --verify --quiet refs/heads/main && echo main`
   - `git show-ref --verify --quiet refs/heads/master && echo master`
   - `git show-ref --verify --quiet refs/heads/develop && echo develop`

If no base branch found, return:
```
STATUS: NO_BASE
ベースブランチを検出できませんでした。引数で指定してください。
/pr <base-branch>
```

**Step 3: Check for Commits**
Run: `git log <base>..HEAD --oneline`

If empty, return:
```
STATUS: NO_COMMITS
ベースブランチ (<base>) に対するコミットがありません。
```
Then stop.

**Step 4: Check for Changes**
Run: `git diff <base>...HEAD --stat`

If empty, return:
```
STATUS: NO_CHANGES
ベースブランチとの差分がありません。
```
Then stop.

**Step 5: Gather Information**
Run these commands:
- `git log <base>..HEAD --oneline` (commit list)
- `git diff <base>...HEAD --stat` (file change summary)
- `git diff <base>...HEAD` (detailed diff - limit reading if too large)

**Step 5.5: Check Unpushed Commits**
Check if a remote tracking branch exists and count unpushed commits:
```bash
REMOTE_BRANCH=$(git rev-parse --abbrev-ref --symbolic-full-name @{u} 2>/dev/null)
if [ -n "$REMOTE_BRANCH" ]; then
  UNPUSHED=$(git log ${REMOTE_BRANCH}..HEAD --oneline)
  UNPUSHED_COUNT=$(echo "$UNPUSHED" | grep -c . || echo 0)
else
  UNPUSHED="(リモートブランチ未設定 — 全コミットがpushされます)"
  UNPUSHED_COUNT="all"
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
If unclear (mixed or cannot determine), return:
```
STATUS: ASK_LANGUAGE
BASE: <base-branch>
COMMITS:
<commit list>
DIFF_STAT:
<diff stat>
言語の判定ができませんでした。日本語と英語のどちらで作成しますか？
```

**Step 8: Generate Title**
- If single commit: use that commit message as title
- If multiple commits: summarize changes into a concise title

**Step 9: Generate Description**
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

**Step 10: Return Result**

Return following the `pr-analyze-output` schema loaded in Step 0.

```
STATUS: OK
BASE: <base-branch>
DRAFT: <true if --draft in arguments, false otherwise>
UNPUSHED_COUNT: <count or "all">
UNPUSHED_COMMITS:
<unpushed commit list or "(リモートブランチ未設定 — 全コミットがpushされます)">
TITLE: <generated title>
BODY:
<generated description body>
```
