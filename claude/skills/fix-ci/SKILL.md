---
name: fix-ci
description: "Diagnose and fix failed GitHub Actions workflow runs. Use when user says 'CIが落ちた', 'fix CI', 'テストが通らない', 'ワークフローが失敗', or has a failing GitHub Actions run to debug. Do NOT use for local test failures unrelated to CI, setting up new workflows, or CI configuration questions."
allowed-tools: Agent, AskUserQuestion, Bash, Read, Edit, Write, Glob, Grep
argument-hint: "[run-id or workflow-name to target specific run]"
disable-model-invocation: true
metadata:
  author: ysk1031
  version: 1.0.0
---

# CI Failure Diagnosis & Fix Skill

Diagnose failed GitHub Actions workflow runs, identify the root cause, propose a fix plan, and implement it — with user confirmation at each step.

## Instructions

### Phase 1: Data Collection (use Agent with subagent)

Call the Agent tool with:
- subagent_type: "ci-log-collector"
- description: "collect CI failure logs"
- prompt: Replace `$ARGUMENTS` in the agent's loaded prompt with actual arguments and execute.

The subagent will return collected failure data (or an error/status).

---

### Phase 2: Hypothesis Formation (use Agent with subagent)

If Phase 1 returned an error status (`"status": "GH_AUTH_REQUIRED"`, `"NO_REPO"`, `"NO_REMOTE"`, `"NO_FAILED_RUNS"`, `"RUN_NOT_FOUND"`), display the `message` field to the user and stop. Do NOT proceed to Phase 2.

Call the Agent tool with:
- subagent_type: "ci-failure-analyzer"
- description: "analyze CI failure cause"
- prompt: Use the entire Phase 1 output as CI failure data and the user hint (if any) as additional context.

---

### Phase 3: User Confirmation of Hypothesis (main agent)

Display the diagnosis results and get user confirmation.

Read `references/diagnosis-display.md` (relative to this skill's directory) with the Read tool and follow its display logic and branching instructions, using the Phase 2 output data.

**If user approves**: Proceed to Phase 4
**If user provides hint**: Re-run Phase 2 with original Phase 1 data + hint
**If user cancels**: Print "CI診断を終了しました。" and stop

---

### Phase 4: Fix Plan Creation (use Agent with subagent)

Call the Agent tool with:
- subagent_type: "ci-fix-planner"
- description: "create CI fix plan"
- prompt: Use the approved hypothesis data as the hypothesis and the Phase 1 output as CI failure data.

---

### Phase 5: User Confirmation of Fix Plan (main agent)

**`"status": "NEEDS_INFO"` from Phase 4**: Display the `question` field and use AskUserQuestion to get the answer, then re-run Phase 4 with the additional information.

**`"status": "OK"` from Phase 4**:

Display the fix plan in a clear format, using JSON fields:

```
## 修正プラン

<for each item in changes array>
### <N>. `<item.file>` (<item.action>)
<item.description>

```
<item.detail>
```

</for each>

### 検証方法
<verification>
```

Use AskUserQuestion:
- question: "この修正プランを適用しますか？"
- header: "Fix Plan"
- options:
  1. label: "適用する", description: "修正を実行します"
  2. label: "修正を指示", description: "プランを調整します（Otherで入力）"
  3. label: "キャンセル", description: "修正せずに終了します"

**If "適用する"**: Proceed to Phase 6
**If "修正を指示"**: User provides modification via "Other". Re-run Phase 4 with the original hypothesis + user's modification instructions.
**If "キャンセル"**: Print "修正をキャンセルしました。" and stop.

---

### Phase 6: Implementation (main agent)

Apply the approved fix plan directly (main agent uses Edit/Write tools, NOT a subagent):

1. For each change in the plan:
   - **modify**: Use Read to read the file, then use Edit to make the changes
   - **create**: Use Write to create the new file
   - **delete**: Use Bash `rm` to delete the file (confirm with user first)

2. After all changes are applied, show a summary:
   ```bash
   git diff --stat
   ```

3. Display completion message:

```
## 修正完了

<list of changed files>

### 検証方法
<verification steps>

### 次のステップ
- 検証方法に従ってローカルで動作確認してください
- 問題なければ `/commit` でコミットできます
- CIを再実行するには `git push` してください
```

**IMPORTANT**: Do NOT commit, push, or perform any git operations beyond `git diff --stat`. Leave that to the user.

---

### Rules

- ALWAYS display messages in Japanese — the user is a Japanese speaker and needs to review diagnostics in Japanese
- NEVER commit or push changes — only apply file modifications — fixes should only be committed after user review; unintended pushes trigger unnecessary CI re-runs
- NEVER skip user confirmation steps (Phase 3 and Phase 5) — human judgment is needed to prevent fixes based on incorrect diagnoses
- When retrying Phase 2 with a hint, reuse Phase 1 data — do NOT re-collect logs — re-collecting logs wastes API calls and only duplicates the same data
- Log truncation threshold: 200 lines per job — passing full logs consumes the context window and reduces analysis accuracy
- If `gh` commands fail with permission errors, suggest the user check their GitHub token permissions — permission issues cannot be resolved by the skill and require user action
- Keep subagent prompts focused — include only the data each subagent needs — including unnecessary data increases subagent token usage and dilutes analysis focus
- For FLAKY/TIMEOUT failures with LOW confidence, suggest re-running the workflow before attempting code fixes — flaky tests don't need code fixes and are likely resolved by re-running the workflow
- For non-FLAKY/non-TIMEOUT failures with LOW confidence, ALWAYS show a low-confidence warning and offer browser log review as an additional option — low-confidence diagnoses have a higher chance of being incorrect, and users should be encouraged to verify before proceeding

---

### Examples

#### Example 1: CI失敗の診断と修正
User says: "CIが落ちた"
Actions:
1. ci-log-collector がGitHub Actionsの失敗ログを収集
2. ci-failure-analyzer が原因の仮説を形成
3. ユーザーに診断結果を表示し確認
4. ci-fix-planner が修正プランを作成
5. ユーザー確認後、修正を適用
Result: CI失敗の原因が特定され、修正が適用される

---

### Troubleshooting

#### "GH_AUTH_REQUIRED"
Cause: GitHub CLIが未認証
Solution: `gh auth login` を実行してGitHub認証を完了

#### "NO_FAILED_RUNS"
Cause: 現在のブランチにCIの失敗が存在しない
Solution: `gh run list --status failure` でブランチと失敗ランを確認

#### 確信度がLOW
Cause: ログの情報が不十分で原因の特定が困難
Solution: 「ヒントを追加して再分析」で追加情報を提供するか、「ブラウザでログを確認」で直接ログを確認
