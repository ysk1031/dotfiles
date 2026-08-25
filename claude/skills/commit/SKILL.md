---
name: commit
description: "Generate and execute git commits with Conventional Commits format. Use when user says 'commit', 'コミットして', 'save changes', 'この変更をコミット', or has staged changes to commit. Do NOT use for amending existing commits, interactive rebase, or unstaging files."
allowed-tools: Agent, AskUserQuestion, Bash
argument-hint: "[--force/-f to skip granularity check] [--review/-r to force confirmation] [optional commit message hint]"
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

### Phase 2: Trim, Risk Gate & Confirmation (main agent)

If subagent returns `"status": "NO_CHANGES"` or `"status": "NEEDS_SPLIT"`, display the `message` field and stop.

If subagent returns `"status": "OK"`, first trim the body, then decide whether to auto-commit or confirm.

**Step 1: Strip any scope, trim the body to 5 lines**
If the title reads `type(scope): ...`, drop the parenthesized scope — the user has corrected this in multiple repositories, so it applies whatever the repo's history looks like.
Rewrap the body at 72 columns and count its lines, blank separator lines not counted. Over 5, cut it here and rewrap: keep the problem, why this way rather than a rejected alternative, and one number for the effect, dropping the rest until it fits. This applies to a body you wrote or extended yourself from session context too — that detail is the first to cut, not an exemption.

**Step 2: Gather facts (Bash)**
- `git diff --staged --numstat` → count changed files and sum insertions+deletions (total changed lines). Binary files show `-`/`-`; count them as files but 0 lines.
- `git diff --staged --name-only` → the list of changed paths (for the sensitive-path check).

**Step 3: Evaluate confirmation conditions** — confirmation is required if ANY of:
1. `-r` or `--review` was passed in the arguments. (`-f`/`--force` does not skip this gate — it only skips the granularity check.)
2. **Sensitive path**: any changed path matches the sensitive list below (case-insensitive; match the basename).
3. **Large change**: files > 8 **OR** total changed lines > 200.

Sensitive path list (high-precision filename/path patterns only — deliberately NOT matching broad `*key*`/`*token*`, which hit files like `keybindings.json`):
- `.env`, `.env.*`, `*.env` — but EXCLUDE `*.example` / `*.sample` / `*.template` / `*.dist`
- basename contains `secret` or `credential`
- extension `.pem` / `.key` / `.p12` / `.pfx` / `.keystore` / `.jks`
- `id_rsa*` / `id_ed25519*` / `id_dsa*` / `id_ecdsa*`
- `.npmrc` / `.pypirc` / `.netrc` / `.git-credentials`

**Step 4a: No conditions met → auto-commit.** Proceed to Phase 3 (auto path). Do NOT call AskUserQuestion.

**Step 4b: A condition is met → confirm.** Use AskUserQuestion:
- question: Start with a one-line reason for the confirmation, then the proposed message. Reasons:
  - Sensitive: "機微パス `<the changed path that matched, in full>` を含むため確認します。"
  - Large: "変更が大きいため（<N> ファイル / <M> 行）確認します。"
  - Forced: "`-r` 指定のため確認します。"
  - If multiple apply, list each reason line.
  Then append the proposal:
  Example: "<reason>\n\n提案コミットメッセージ:\n\n`<title>`\n\n<body>\n\nこのコミットメッセージでよろしいですか？"（body がなければその段落ごと省く）
- header: "Commit"
- options:
  1. label: "Accept", description: "このままコミットを実行"
  2. label: "Edit", description: "メッセージを編集（Otherで自由入力）"
  3. label: "Cancel", description: "コミットせずに終了"

**If "Accept"**: Proceed to Phase 3 (confirmed path)
**If "Edit"**: User provides custom message via "Other". Use that message for Phase 3 (confirmed path)
**If "Cancel"**: Print "コミットをキャンセルしました。" and stop

---

### Phase 3: Execute Commit (main agent with Bash)

**Determine Co-Authored-By name**: Never skip the Co-Authored-By trailer — it is what makes AI-generated commits auditable.
Format: `Co-Authored-By: Claude <model> <noreply@anthropic.com>` where `<model>` is your own model name exactly as your system prompt states it, parenthetical included (e.g. "Opus 5 (1M context)") — read it off the prompt each time rather than reusing a name you have seen in the history.

Execute the commit:

Drop the `<body>` line and the blank line above it when there is no body.

```bash
git commit -m "$(cat <<'EOF'
<type>: <description>

<body>

Co-Authored-By: Claude <model> <noreply@anthropic.com>
EOF
)"
```

Then verify: `git status && git log -1`

**Auto path only (Phase 2 Step 4a)**: after committing, print the message and undo hints so the user can review after the fact:
```
✅ コミットしました（確認スキップ: 小規模・機微パスなし）
<type>: <description>
取り消し: git reset --soft HEAD^   ／   文面修正: git commit --amend
```
The confirmed path (Phase 2 Step 4b) does not print these hints — the user already reviewed.

---

### Rules
- Auto-commit (no confirmation) when the change is small and touches no sensitive path — local commits are reversible (`git reset --soft HEAD^` / `git commit --amend`), so gating every message costs more friction than it saves
- ALWAYS confirm when a sensitive path is touched, even with `-f` — committing secrets is the one costly mistake this gate exists to prevent
- NEVER use --amend unless explicitly requested — amend rewrites the previous commit, risking unintended data loss
- NEVER use --no-verify — pre-commit hooks enforce project quality standards; bypassing them can introduce lint errors and security issues
- Keep first line under 72 characters — industry-standard convention to prevent truncation in git log and GitHub UI
