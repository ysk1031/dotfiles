---
name: commit
description: "Generate and execute git commits with Conventional Commits format for staged changes. 変更をコミットしたい時に使用。Conventional Commits形式で生成。"
allowed-tools: Task, AskUserQuestion, Bash
argument-hint: "[--force/-f to skip granularity check] [optional commit message hint]"
---

# Git Commit Skill

Generate a commit message for staged changes and let the user review/edit before committing.

## Instructions

### Phase 1: Analyze Changes (use Task with subagent)

Call the Task tool with:
- subagent_type: "custom"
- agent: "analyze-commit-changes"
- description: "analyze staged changes"
- prompt: Replace `$ARGUMENTS` in the agent's loaded prompt with the actual user arguments and execute.

The subagent will return the proposed commit message (or an error/warning).

---

### Phase 2: User Confirmation (main agent)

If subagent returns STATUS: NO_CHANGES or STATUS: NEEDS_SPLIT, display the message and stop.

If subagent returns STATUS: OK:
1. Use AskUserQuestion:
   - question: Include the proposed commit message in the question text
     Example (no body): "提案コミットメッセージ:\n\n`<type>: <description>`\n\nこのコミットメッセージでよろしいですか？"
     Example (with body): "提案コミットメッセージ:\n\n`<type>: <description>`\n\n<body>\n\nこのコミットメッセージでよろしいですか？"
   - header: "Commit"
   - options:
     1. label: "Accept", description: "このままコミットを実行"
     2. label: "Edit", description: "メッセージを編集（Otherで自由入力）"
     3. label: "Cancel", description: "コミットせずに終了"

**If "Accept"**: Proceed to Phase 3
**If "Edit"**: User provides custom message via "Other". Use that message for Phase 3
**If "Cancel"**: Print "コミットをキャンセルしました。" and stop

---

### Phase 3: Execute Commit (main agent with Bash)

**Determine Co-Authored-By name**: Use your own model name for the Co-Authored-By trailer.
Format: `Co-Authored-By: Claude <model> <noreply@anthropic.com>` where `<model>` is your model name (e.g., "Opus 4.6", "Sonnet 4.5") as stated in your system prompt.

Execute the commit:

For title only:
```bash
git commit -m "$(cat <<'EOF'
<type>: <description>

Co-Authored-By: Claude <model> <noreply@anthropic.com>
EOF
)"
```

For title + body:
```bash
git commit -m "$(cat <<'EOF'
<type>: <description>

<body>

Co-Authored-By: Claude <model> <noreply@anthropic.com>
EOF
)"
```

Then verify: `git status && git log -1`

---

### Rules
- NEVER skip Co-Authored-By (always use your actual model name, never hardcode a specific version) — ensures traceability of AI-generated commits and enables audit of change history
- NEVER use --amend unless explicitly requested — amend rewrites the previous commit, risking unintended data loss
- NEVER use --no-verify — pre-commit hooks enforce project quality standards; bypassing them can introduce lint errors and security issues
- Keep first line under 72 characters — industry-standard convention to prevent truncation in git log and GitHub UI
- Body should wrap at 72 characters — ensures readability in terminals and git log output
