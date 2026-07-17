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

### Phase 2: Risk Gate & Confirmation (main agent)

If subagent returns `"status": "NO_CHANGES"` or `"status": "NEEDS_SPLIT"`, display the `message` field and stop.

If subagent returns `"status": "OK"`, decide whether to auto-commit or confirm.

**Step 1: Gather facts (Bash)**
- `git diff --staged --numstat` → count changed files and sum insertions+deletions (total changed lines). Binary files show `-`/`-`; count them as files but 0 lines.
- `git diff --staged --name-only` → the list of changed paths (for the sensitive-path check).

**Step 2: Evaluate confirmation conditions** — confirmation is required if ANY of:
1. `-r` or `--review` was passed in the arguments.
2. **Sensitive path**: any changed path matches the sensitive list below (case-insensitive; match the basename unless noted).
3. **Large change**: files > 5 **OR** total changed lines > 100.

Sensitive path list (high-precision filename/path patterns only — deliberately NOT matching broad `*key*`/`*token*`, which hit files like `keybindings.json`):
- `.env`, `.env.*`, `*.env` — but EXCLUDE `*.example` / `*.sample` / `*.template` / `*.dist`
- basename contains `secret` or `credential`
- extension `.pem` / `.key` / `.p12` / `.pfx` / `.keystore` / `.jks`
- `id_rsa*` / `id_ed25519*` / `id_dsa*` / `id_ecdsa*`
- `.npmrc` / `.pypirc` / `.netrc` / `.git-credentials`

**Step 3a: No conditions met → auto-commit.** Proceed to Phase 3 (auto path). Do NOT call AskUserQuestion.

**Step 3b: A condition is met → confirm.** Use AskUserQuestion:
- question: Start with a one-line reason for the confirmation, then the proposed message. Reasons:
  - Sensitive: "機微パス `<matched path>` を含むため確認します。"
  - Large: "変更が大きいため（<N> ファイル / <M> 行）確認します。"
  - Forced: "`-r` 指定のため確認します。"
  - If multiple apply, list each reason line.
  Then append the proposal:
  Example (no body): "<reason>\n\n提案コミットメッセージ:\n\n`<title>`\n\nこのコミットメッセージでよろしいですか？"
  Example (with body): "<reason>\n\n提案コミットメッセージ:\n\n`<title>`\n\n<body>\n\nこのコミットメッセージでよろしいですか？"
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

**Auto path only (Phase 2 Step 3a)**: after committing, print the message and undo hints so the user can review after the fact:
```
✅ コミットしました（確認スキップ: 小規模・機微パスなし）
<type>: <description>
取り消し: git reset --soft HEAD^   ／   文面修正: git commit --amend
```
The confirmed path (Phase 2 Step 3b) does not print these hints — the user already reviewed.

---

### Rules
- Auto-commit (no confirmation) when the change is small and touches no sensitive path — local commits are reversible (`git reset --soft HEAD^` / `git commit --amend`), so gating every message costs more friction than it saves
- ALWAYS confirm when a sensitive path is touched, even with `-f` — committing secrets is the one costly mistake this gate exists to prevent
- `-f`/`--force` only skips the granularity (NEEDS_SPLIT) check; it does NOT bypass the risk gate. `-r`/`--review` forces confirmation regardless of risk
- NEVER skip Co-Authored-By (always use your actual model name, never hardcode a specific version) — ensures traceability of AI-generated commits and enables audit of change history
- NEVER use --amend unless explicitly requested — amend rewrites the previous commit, risking unintended data loss
- NEVER use --no-verify — pre-commit hooks enforce project quality standards; bypassing them can introduce lint errors and security issues
- Keep first line under 72 characters — industry-standard convention to prevent truncation in git log and GitHub UI
- Body should wrap at 72 characters — ensures readability in terminals and git log output

---

### Examples

#### Example 1: 小規模な変更（自動コミット）
User says: "コミットして"（2ファイル・40行、機微パスなし）
Actions:
1. commit-composer がステージ済み変更を分析
2. リスクゲート判定: どの条件にも当たらない → 確認なし
3. 即コミット実行し、メッセージと取り消し/amend ヒントを表示
Result: 確認モーダルなしで `docs: update README` のようなコミットが作成される

#### Example 2: 大規模な変更（確認あり）
User says: "コミットして"（8ファイル・143行）
Actions:
1. commit-composer が分析
2. リスクゲート判定: 大規模（>5ファイル）→ 確認
3. 「変更が大きいため（8 ファイル / 143 行）確認します。」を添えて AskUserQuestion
Result: ユーザーが Accept してコミット

#### Example 3: 機微パスを含む（確認あり）
User says: "コミットして"（`config/.env` を1ファイルだけ変更）
Actions:
1. commit-composer が分析
2. リスクゲート判定: 機微パス一致 → 小規模でも確認
3. 「機微パス `config/.env` を含むため確認します。」を添えて AskUserQuestion
Result: 誤コミット防止のため必ず人の目を通す

#### Example 4: --force付きコミット
User says: "-f でコミット"
Actions:
1. 粒度チェック（NEEDS_SPLIT）をスキップ
2. リスクゲートは通常どおり適用（機微パスがあれば確認、なければ規模で判定）
Result: 粒度に関わらず単一コミット。機微パスがあれば `-f` でも確認される

#### Example 5: --review付きコミット
User says: "-r でコミット"（小規模でも）
Actions:
1. commit-composer が分析
2. リスクゲート判定: `-r` 指定 → 強制的に確認
Result: 旧来どおり毎回確認する挙動に戻せる

---

### Troubleshooting

#### "No staged changes"
Cause: ステージされた変更がない
Solution: `git add <files>` でファイルをステージングしてから再実行

#### "NEEDS_SPLIT"
Cause: ステージされた変更が大きすぎて単一コミットに不適切
Solution: `git add -p` で変更を分割してステージングし、複数コミットに分ける
