---
name: pr
description: Create a GitHub Pull Request from current branch with auto-generated description. Use when the user wants to create a PR.
allowed-tools: Task, AskUserQuestion, Bash
argument-hint: [base-branch to specify target branch] [--draft to create as draft PR]
---

# Pull Request Creation Skill

Generate a PR title and description from current branch changes, let the user review/edit, then create the PR.

## Instructions

### Phase 1: Analyze Changes (use Task with Bash subagent)

Call the Task tool with:
- subagent_type: "Bash"
- description: "analyze branch changes for PR"
- prompt: Include the subagent prompt below, replacing $ARGUMENTS with actual arguments

The subagent will return the proposed PR content (or an error/status).

#### Subagent Prompt Template

You are a PR analyzer. Analyze branch changes and generate a PR title and description.

**Arguments**: $ARGUMENTS

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
Return in this format:
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

---

### Phase 2: User Confirmation (main agent)

Handle based on subagent STATUS:

**STATUS: NOT_ON_BRANCH / NO_BASE / NO_COMMITS / NO_CHANGES**:
Display the message and stop.

**STATUS: ASK_LANGUAGE**:
Use AskUserQuestion:
- question: "PR説明文をどちらの言語で作成しますか？"
- header: "Language"
- options:
  1. label: "日本語", description: "日本語でPR説明文を作成"
  2. label: "English", description: "Create PR description in English"

Then call subagent again with the language specified.

**STATUS: OK**:
1. Display the proposed PR title and body
2. Display unpushed commit information:
   - If UNPUSHED_COUNT is a number: "リモートにpushされていないコミットが {UNPUSHED_COUNT} 件あります:\n{UNPUSHED_COMMITS}"
   - If UNPUSHED_COUNT is "all": "リモートブランチが未設定のため、全コミットがpushされます。"
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
```bash
git push -u origin HEAD
```

2. Create PR:
```bash
gh pr create --base <base> --title "<title>" --body "$(cat <<'EOF'
<body>

---
🤖 Generated with [Claude Code](https://claude.com/claude-code)
EOF
)" [--draft if specified]
```

3. Display the PR URL from the command output

---

### Rules
- ALWAYS add footer: `🤖 Generated with [Claude Code](https://claude.com/claude-code)`
- Push to remote without additional confirmation (required for PR creation)
- Use HEREDOC for body to ensure proper formatting
- Keep title concise (under 72 characters if possible)
- If --draft flag is in arguments, add --draft to gh pr create
