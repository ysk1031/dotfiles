---
name: pr
description: "Create a GitHub Pull Request with auto-generated title and description from branch changes. PRを作りたい時に使用。タイトルと説明文を自動生成。"
allowed-tools: Task, AskUserQuestion, Bash
argument-hint: "[base-branch to specify target branch] [--draft to create as draft PR]"
---

# Pull Request Creation Skill

Generate a PR title and description from current branch changes, let the user review/edit, then create the PR.

## Instructions

### Phase 1: Analyze Changes (use Task with subagent)

Call the Task tool with:
- subagent_type: "custom"
- agent: "analyze-pr-branch"
- description: "analyze branch changes for PR"
- prompt: Replace `$ARGUMENTS` in the agent's loaded prompt with the actual user arguments and execute.

The subagent will return the proposed PR content (or an error/status).

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
- ALWAYS add footer: `🤖 Generated with [Claude Code](https://claude.com/claude-code)` — ensures traceability of PR origin
- Push to remote without additional confirmation (required for PR creation) — pushing is a prerequisite for PR creation; confirming each time adds unnecessary friction
- Use HEREDOC for body to ensure proper formatting — regular strings don't properly handle markdown line breaks and special characters
- Keep title concise (under 72 characters if possible) — prevents truncation in GitHub UI and maintains readability in PR lists
- If --draft flag is in arguments, add --draft to gh pr create — accurately reflects the user's intent in the GitHub API call
