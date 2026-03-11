---
name: implement
description: "Execute an approved plan step by step with continuous validation and checklist tracking. 計画ファイル（plan.md）に沿って実装したい時に使用。"
allowed-tools: Agent, AskUserQuestion, Bash, Read, Edit, Write, Glob, Grep
argument-hint: "[plan file path, default: 'plan.md'] [--steps '1,3,5' to run specific steps only]"
disable-model-invocation: true
---

# Implementation Skill

Execute an approved implementation plan from start to finish. Read the plan, implement each step, update the checklist, and run validation continuously — without stopping until all steps are complete.

## Instructions

### Phase 1: Plan Loading & Tooling Detection (use Agent with subagent)

Call the Agent tool with:
- subagent_type: "custom"
- agent: "plan-reader"
- description: "load plan and detect tooling"
- prompt: Replace `$ARGUMENTS` in the agent's loaded prompt with the actual user arguments and execute.

---

### Phase 2: Scope Confirmation (main agent)

If Phase 1 returned `NO_PLAN`, display the message and stop.

1. Read the full plan file with the Read tool.
2. Extract the implementation steps and checklist.

Display the implementation scope:

```
## 実装計画

**ファイル**: <plan file>
**ステップ数**: 残り <remaining> / 全 <total>
**検出ツール**: type check: <yes/no>, lint: <yes/no>, test: <yes/no>

### チェックリスト
<display checklist with current status>
```

If `SELECTED_STEPS` is not ALL, show only the selected steps.

Use AskUserQuestion:
- question: "実装を開始しますか？"
- header: "Implement"
- options:
  1. label: "すべて実装", description: "残りの全ステップを実装します"
  2. label: "ステップを選択", description: "実装するステップを指定します（Otherで番号をカンマ区切り入力）"
  3. label: "キャンセル", description: "実装せずに終了します"

**If "すべて実装"**: Proceed to Phase 3 with all remaining (unchecked) steps.
**If "ステップを選択"**: User provides step numbers via "Other". Proceed to Phase 3 with selected steps only.
**If "キャンセル"**: Print "実装を終了しました。" and stop.

---

### Phase 3: Implementation Loop (main agent)

**This is the core execution phase. Do NOT stop until all selected steps are complete or a critical error occurs.**

Read the CLAUDE.md if it exists to follow project conventions during implementation.

For each remaining step (in order):

#### Step 3.1: Read Step Details

Re-read the plan file to get the detailed instructions for the current step. Each step should have:
- Target file and action (create / modify)
- Specific changes to make
- Reasoning and details

#### Step 3.2: Implement

Based on the step action:

**modify**:
1. Read the target file with the Read tool
2. Apply changes using the Edit tool
3. If the edit is too large or complex, use Write to rewrite the file

**create**:
1. Verify the parent directory exists: `ls <parent-dir>`
2. Write the new file with the Write tool

**delete** (if specified):
1. Confirm with the user before deleting
2. Use Bash `rm` to delete

For each implementation:
- Follow existing code patterns identified in the plan
- Do NOT add unnecessary comments, JSDoc, or type annotations beyond what the plan specifies
- Do NOT add features, error handling, or abstractions not in the plan
- Keep changes minimal and focused on what the step requires

#### Step 3.3: Validate

After each step, run available validation commands:

1. **Type check** (if available): Run the detected type check command via Bash
2. **Lint** (if available): Run the detected lint command via Bash

If validation fails:
- Read the error output
- Fix the issue immediately
- Re-run validation to confirm the fix
- Do NOT move to the next step until validation passes

If validation passes, continue to the next step without pausing.

**IMPORTANT**: Do NOT run the full test suite after every step — only run type check and lint. Tests are run once in Phase 4.

#### Step 3.4: Update Checklist

After each step completes successfully (including validation):
1. Read the plan file
2. Update the checklist: change `- [ ] Step N: ...` to `- [x] Step N: ...`
3. Write the updated plan file using Edit

Then immediately proceed to the next step. Do NOT ask for user confirmation between steps.

---

### Phase 4: Verification & Summary (main agent)

After all selected steps are complete:

1. **Run full test suite** (if available):
```bash
<detected test command>
```

If tests fail:
- Display the failure output
- Use AskUserQuestion:
  - question: "テストが失敗しました。修正を試みますか？"
  - header: "Test Failure"
  - options:
    1. label: "修正する", description: "失敗したテストを分析して修正します"
    2. label: "スキップ", description: "テスト失敗を無視して完了とします"

  If "修正する": Analyze the test failure, fix the issue, re-run tests. Repeat until tests pass or user chooses to skip.
  If "スキップ": Continue to summary.

2. **Show summary**:
```bash
git diff --stat
```

3. **Display completion message**:

```
## 実装完了

### 変更されたファイル
<git diff --stat output>

### チェックリスト
<display updated checklist — all implemented steps should be checked>

### 検証結果
- Type check: <PASS / FAIL / N/A>
- Lint: <PASS / FAIL / N/A>
- Test: <PASS / FAIL / SKIPPED / N/A>

### 次のステップ
- 動作確認を行ってください
- 問題なければ `/commit` でコミットできます
```

---

### Rules

- ALWAYS display messages in Japanese — the user is a Japanese speaker and needs to review progress and errors in Japanese
- NEVER stop between steps unless a critical error occurs — keep going until all steps are done — stopping between steps increases user wait time and significantly slows implementation
- NEVER commit or push changes — only apply file modifications — commits should only happen after user review; unintended commits are difficult to undo
- NEVER add comments, JSDoc, or type annotations not specified in the plan — additions not in the plan create noise in code review and diverge from the approved plan
- NEVER add features or abstractions beyond what the plan specifies — out-of-scope changes can introduce unexpected bugs and architectural distortions
- ALWAYS update the checklist after each step — without an up-to-date checklist, the resume point is unknown if implementation is interrupted
- ALWAYS run type check and lint after each step (if available) — validating after each step makes it easier to identify the cause of issues and reduces fix cost
- Run the full test suite only ONCE at the end (Phase 4), not after every step — running tests is time-consuming; running after every step significantly increases total implementation time
- If a step's target file doesn't exist for a "modify" action, flag it and ask the user — forcing changes to a non-existent file would create an unintended new file
- If the plan file changes during implementation (e.g., user edits it), re-read it before each step — implementing based on an outdated plan fails to reflect the user's revisions
- Respect CLAUDE.md conventions if the file exists — code violating project conventions will be rejected during lint/review
- Keep the implementation faithful to the plan — do not deviate or "improve" beyond what's specified — deviating from the plan bypasses the approval process and introduces unintended changes
