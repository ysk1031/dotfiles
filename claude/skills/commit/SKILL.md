---
name: commit
description: "Generate and execute git commits with Conventional Commits format. Use when user says 'commit', 'コミットして', 'save changes', 'この変更をコミット', or has staged changes to commit. Do NOT use for amending existing commits, interactive rebase, or unstaging files."
allowed-tools: Agent, AskUserQuestion, Bash
argument-hint: "[--force/-f to skip granularity check] [optional commit message hint]"
metadata:
  author: ysk1031
  version: 1.0.0
---

# Git Commit Skill

Generate a commit message for staged changes and let the user review/edit before committing.

## Instructions

### Phase 1: Analyze Changes (use Agent with subagent)

Call the Agent tool with:
- subagent_type: "commit-composer"
- description: "analyze staged changes"
- prompt: Replace `$ARGUMENTS` in the agent's loaded prompt with the actual user arguments and execute.

The subagent will return the proposed commit message (or an error/warning).

---

### Phase 2: User Confirmation (main agent)

If subagent returns `"status": "NO_CHANGES"` or `"status": "NEEDS_SPLIT"`, display the `message` field and stop.

If subagent returns `"status": "OK"`:
1. Use AskUserQuestion:
   - question: Include the proposed commit message (from `title` and `body` fields) in the question text
     Example (no body): "提案コミットメッセージ:\n\n`<title>`\n\nこのコミットメッセージでよろしいですか？"
     Example (with body): "提案コミットメッセージ:\n\n`<title>`\n\n<body>\n\nこのコミットメッセージでよろしいですか？"
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

---

### Examples

#### Example 1: 通常のコミット
User says: "コミットして"
Actions:
1. commit-composer がステージ済み変更を分析
2. Conventional Commits形式のメッセージを提案
3. ユーザー確認後コミット実行
Result: `feat: add user authentication flow` のようなコミットが作成される

#### Example 2: --force付きコミット
User says: "-f でコミット"
Actions:
1. 粒度チェックをスキップ
2. 即座にコミットメッセージを提案
Result: 粒度に関わらず単一コミットとして作成される

---

### Troubleshooting

#### "No staged changes"
Cause: ステージされた変更がない
Solution: `git add <files>` でファイルをステージングしてから再実行

#### "NEEDS_SPLIT"
Cause: ステージされた変更が大きすぎて単一コミットに不適切
Solution: `git add -p` で変更を分割してステージングし、複数コミットに分ける
