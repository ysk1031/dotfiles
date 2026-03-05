---
name: commit
description: Generate and execute git commits for staged changes with Conventional Commits format. Use when the user wants to commit staged changes.
allowed-tools: Task, AskUserQuestion, Bash
argument-hint: "[--force/-f to skip granularity check] [optional commit message hint]"
---

# Git Commit Skill

Generate a commit message for staged changes and let the user review/edit before committing.

## Instructions

### Phase 1: Analyze Changes (use Task with subagent)

Call the Task tool with:
- subagent_type: "general-purpose"
- description: "analyze staged changes"
- prompt: Include the subagent prompt below, replacing $ARGUMENTS with actual arguments

The subagent will return the proposed commit message (or an error/warning).

#### Subagent Prompt Template

You are a git commit analyzer. Analyze staged changes and generate a commit message.

**Arguments**: $ARGUMENTS

**Step 1: Check Staged Changes**
Run: `git diff --staged`

If no staged changes, return:
```
STATUS: NO_CHANGES
ステージされた変更がありません。git add <files> でファイルをステージしてから再度 /commit を実行してください。
```
Then run `git status` and stop.

**Step 2: Check Force Flag**
If arguments contain "--force" or "-f", skip Step 4.

**Step 3: Detect Language Convention**
Run: `git log --oneline -10`
- If majority contain Japanese → use Japanese
- Otherwise → use English

**Step 4: Granularity Check (skip if --force/-f)**
If changes span more than 3 unrelated concerns, return:
```
STATUS: NEEDS_SPLIT
警告: このコミットには複数の異なる変更が含まれています。
コミットを分割することを検討してください:

1. [変更1の説明]
2. [変更2の説明]

分割する場合: git reset HEAD <files>
このまま続行する場合: /commit --force
```

**Step 5: Determine Commit Type**
Select prefix: feat/fix/perf/refactor/style/test/docs/build/ci/chore/release

**Step 6: Generate and Return Message**
Return in this format:
```
STATUS: OK
TITLE: <type>: <description>
BODY: <body or empty if not needed>
```

- Title: under 72 characters
- Body: Add when changes are complex (multiple files, significant changes). Explain WHAT and WHY.
- Consider user arguments as hints.

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
- NEVER skip Co-Authored-By (always use your actual model name, never hardcode a specific version)
- NEVER use --amend unless explicitly requested
- NEVER use --no-verify
- Keep first line under 72 characters
- Body should wrap at 72 characters
