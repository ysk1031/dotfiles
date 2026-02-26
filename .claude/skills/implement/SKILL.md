---
name: implement
description: Execute an approved implementation plan step by step, updating the checklist and running validation continuously until all steps are complete.
allowed-tools: Task, AskUserQuestion, Bash, Read, Edit, Write, Glob, Grep
argument-hint: "[plan file path, default: 'plan.md'] [--steps '1,3,5' to run specific steps only]"
---

# Implementation Skill

Execute an approved implementation plan from start to finish. Read the plan, implement each step, update the checklist, and run validation continuously — without stopping until all steps are complete.

## Instructions

### Phase 1: Plan Loading & Tooling Detection (use Task with Bash subagent)

Call the Task tool with:
- subagent_type: "Bash"
- description: "load plan and detect tooling"
- prompt: Include the subagent prompt below, replacing $ARGUMENTS with actual arguments

#### Subagent Prompt Template

You are a plan loader and project tooling detector. Load an implementation plan file and detect available validation tools.

**Arguments**: $ARGUMENTS

**Step 1: Parse Arguments**

Extract:
- `PLAN_FILE`: Path to plan file. Default: `plan.md`. If argument is a path ending in `.md`, use it.
- `STEPS`: Comma-separated step numbers from `--steps` flag (optional). Example: `--steps 1,3,5`

**Step 2: Load Plan File**

```bash
if [ -f "$PLAN_FILE" ]; then
  echo "PLAN: EXISTS"
  wc -l "$PLAN_FILE"
else
  echo "PLAN: NOT_FOUND"
fi
```

If not found, check for alternatives:
```bash
ls plan*.md 2>/dev/null | head -5
```

If not found at all, return:
```
STATUS: NO_PLAN
計画ファイルが見つかりません。先に /plan でファイルを作成するか、パスを指定してください。
利用可能なファイル: <list or なし>
```

If found, extract the checklist:
```bash
grep -n '^\- \[[ x]\]' "$PLAN_FILE"
```

Count total steps and already-completed steps:
```bash
TOTAL=$(grep -c '^\- \[ \]' "$PLAN_FILE" 2>/dev/null || echo 0)
DONE=$(grep -c '^\- \[x\]' "$PLAN_FILE" 2>/dev/null || echo 0)
echo "TOTAL_STEPS: $TOTAL"
echo "COMPLETED_STEPS: $DONE"
echo "REMAINING_STEPS: $((TOTAL - DONE + 0))"
```

**Step 3: Detect Project Tooling**

Detect available validation commands:

```bash
# TypeScript / JavaScript
if [ -f "tsconfig.json" ]; then
  echo "TYPECHECK: npx tsc --noEmit"
fi
if [ -f "package.json" ]; then
  # Detect lint script
  node -e "const p=require('./package.json'); if(p.scripts?.lint) console.log('LINT: npm run lint')" 2>/dev/null
  # Detect test script
  node -e "const p=require('./package.json'); if(p.scripts?.test) console.log('TEST: npm run test')" 2>/dev/null
  # Detect typecheck script
  node -e "const p=require('./package.json'); if(p.scripts?.typecheck) console.log('TYPECHECK: npm run typecheck')" 2>/dev/null
fi

# Go
if [ -f "go.mod" ]; then
  echo "TYPECHECK: go build ./..."
  echo "LINT: golangci-lint run 2>/dev/null || go vet ./..."
  echo "TEST: go test ./..."
fi

# Python
if [ -f "pyproject.toml" ] || [ -f "setup.py" ]; then
  command -v mypy >/dev/null 2>&1 && echo "TYPECHECK: mypy ."
  command -v ruff >/dev/null 2>&1 && echo "LINT: ruff check ." || (command -v flake8 >/dev/null 2>&1 && echo "LINT: flake8 .")
  command -v pytest >/dev/null 2>&1 && echo "TEST: pytest"
fi

# Rust
if [ -f "Cargo.toml" ]; then
  echo "TYPECHECK: cargo check"
  echo "LINT: cargo clippy"
  echo "TEST: cargo test"
fi

# Makefile targets
if [ -f "Makefile" ]; then
  grep -E '^(lint|test|check|typecheck|verify):' Makefile 2>/dev/null | while read line; do
    TARGET=$(echo "$line" | cut -d: -f1)
    echo "MAKE_TARGET: $TARGET (make $TARGET)"
  done
fi
```

If CLAUDE.md exists, note it:
```bash
[ -f CLAUDE.md ] && echo "CLAUDE_MD: EXISTS" || echo "CLAUDE_MD: NOT_FOUND"
```

**Step 4: Return Result**

```
STATUS: OK
PLAN_FILE: <path>
SELECTED_STEPS: <comma-separated numbers or ALL>
TOTAL_STEPS: <count>
COMPLETED_STEPS: <count>
REMAINING_STEPS: <count>
CLAUDE_MD: <EXISTS or NOT_FOUND>

TOOLING:
TYPECHECK: <command or NONE>
LINT: <command or NONE>
TEST: <command or NONE>

CHECKLIST:
<raw checklist lines with line numbers>
```

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

- ALWAYS display messages in Japanese
- NEVER stop between steps unless a critical error occurs — keep going until all steps are done
- NEVER commit or push changes — only apply file modifications
- NEVER add comments, JSDoc, or type annotations not specified in the plan
- NEVER add features or abstractions beyond what the plan specifies
- ALWAYS update the checklist after each step
- ALWAYS run type check and lint after each step (if available)
- Run the full test suite only ONCE at the end (Phase 4), not after every step
- If a step's target file doesn't exist for a "modify" action, flag it and ask the user
- If the plan file changes during implementation (e.g., user edits it), re-read it before each step
- Respect CLAUDE.md conventions if the file exists
- Keep the implementation faithful to the plan — do not deviate or "improve" beyond what's specified
