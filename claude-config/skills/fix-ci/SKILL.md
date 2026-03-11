---
name: fix-ci
description: "Diagnose and fix failed GitHub Actions workflow runs on the current branch. CIが落ちた、テストが通らない時に使用。GitHub Actionsの失敗を診断して修正。"
allowed-tools: Agent, AskUserQuestion, Bash, Read, Edit, Write, Glob, Grep
argument-hint: "[run-id or workflow-name to target specific run]"
disable-model-invocation: true
---

# CI Failure Diagnosis & Fix Skill

Diagnose failed GitHub Actions workflow runs, identify the root cause, propose a fix plan, and implement it — with user confirmation at each step.

## Instructions

### Phase 1: Data Collection (use Agent with subagent)

Call the Agent tool with:
- subagent_type: "custom"
- agent: "ci-log-collector"
- description: "collect CI failure logs"
- prompt: Replace `$ARGUMENTS` in the agent's loaded prompt with actual arguments and execute.

The subagent will return collected failure data (or an error/status).

---

### Phase 2: Hypothesis Formation (use Agent with general-purpose subagent)

If Phase 1 returned an error status (`GH_AUTH_REQUIRED`, `NO_REPO`, `NO_REMOTE`, `NO_FAILED_RUNS`, `RUN_NOT_FOUND`), display the message to the user and stop. Do NOT proceed to Phase 2.

Call the Agent tool with:
- subagent_type: "general-purpose"
- description: "analyze CI failure cause"
- prompt: Read the file `~/.claude/skills/fix-ci/prompts/analyze-failure.md` and use its content as the subagent prompt. Embed the entire Phase 1 output as `CI Failure Data` and the user hint (if any) as `Additional context from user`.

---

### Phase 3: User Confirmation of Hypothesis (main agent)

**STATUS: OK from Phase 2**:

Display the hypothesis to the user in a clear format:

```
## CI失敗の診断結果

**ワークフロー**: <workflow name>
**カテゴリ**: <category>
**確信度**: <confidence>

### 原因の仮説
<hypothesis>

### 根拠
<evidence list>

### 影響ファイル
<affected files list>
```

If CONFIDENCE is LOW and CATEGORY is FLAKY or TIMEOUT, add a note:
"この失敗はフレーキーテスト（非決定的な失敗）の可能性があります。再実行で解決する場合があります。"

Use AskUserQuestion:
- question: "この診断結果に基づいて修正プランを作成しますか？"
- header: "Diagnosis"
- options:
  1. label: "修正プランを作成", description: "この仮説に基づいて修正プランを作成します"
  2. label: "ヒントを追加して再分析", description: "追加情報を提供して再分析します（Otherで入力）"
  3. label: "キャンセル", description: "診断を終了します"

**If "修正プランを作成"**: Proceed to Phase 4
**If "ヒントを追加して再分析"**: User provides additional context via "Other". Re-run Phase 2 with the original Phase 1 data PLUS user's hint. Do NOT re-run Phase 1.
**If "キャンセル"**: Print "CI診断を終了しました。" and stop.

**STATUS: UNCLEAR from Phase 2**:

Display the partial analysis:

```
## CI失敗の部分分析

原因を特定できませんでした。

### 判明していること
<partial analysis>

### 可能性のある原因
<possible causes>
```

Use AskUserQuestion:
- question: "原因を特定できませんでした。どうしますか？"
- header: "Diagnosis"
- options:
  1. label: "ヒントを追加して再分析", description: "追加情報を提供して再分析します（Otherで入力）"
  2. label: "ブラウザでログを確認", description: "GitHub Actionsのログをブラウザで開きます"
  3. label: "キャンセル", description: "診断を終了します"

**If "ヒントを追加して再分析"**: Re-run Phase 2 with hint
**If "ブラウザでログを確認"**: Run `gh run view <run-id> --web` via Bash, then print "CI診断を終了しました。" and stop.
**If "キャンセル"**: Print "CI診断を終了しました。" and stop.

---

### Phase 4: Fix Plan Creation (use Agent with general-purpose subagent)

Call the Agent tool with:
- subagent_type: "general-purpose"
- description: "create CI fix plan"
- prompt: Read the file `~/.claude/skills/fix-ci/prompts/create-fix-plan.md` and use its content as the subagent prompt. Embed the approved hypothesis data and Phase 1 output into the appropriate placeholders.

---

### Phase 5: User Confirmation of Fix Plan (main agent)

**STATUS: NEEDS_INFO from Phase 4**: Display the question and use AskUserQuestion to get the answer, then re-run Phase 4 with the additional information.

**STATUS: OK from Phase 4**:

Display the fix plan in a clear format:

```
## 修正プラン

<for each change>
### <N>. `<file path>` (<action>)
<description>

```
<detail>
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
