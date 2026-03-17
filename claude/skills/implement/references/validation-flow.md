# Validation Failure Handling Flow

This document defines the detailed flow for handling validation failures in Step 3.3 of the implementation loop.

## Flow

When validation fails after a step implementation:

1. Read the error output
2. Fix the issue immediately
3. Re-run validation to confirm the fix
4. If validation fails again, repeat the fix-validate cycle up to **3 attempts total**

### After 3 Failed Attempts

If validation still fails after 3 attempts, use AskUserQuestion:
- question: "ステップ N のバリデーションが3回失敗しました。エラー内容:\n```\n<error output>\n```"
- header: "Validation Failure"
- options:
  1. label: "手動で修正して続行", description: "自分で修正した後、バリデーションを再実行します"
  2. label: "スキップして次へ", description: "このステップのバリデーションエラーを無視して次に進みます"
  3. label: "実装を中止", description: "実装を終了します"

### Option 1: "手動で修正して続行"

Wait for the user to finish manual edits (user will signal readiness via "Other" input or re-selection). Then re-run validation from Step 3.3 (reset the attempt counter to 0). If validation passes, proceed to Step 3.4 (checklist update) normally. If it fails again, re-enter the 3-attempt retry cycle.

### Option 2: "スキップして次へ"

Do NOT update the checklist for this step (leave it as `- [ ]`). Add a `[SKIPPED]` annotation to the checklist line: change `- [ ] Step N: ...` to `- [ ] Step N: ... [SKIPPED: validation failure]`. Proceed to the next step immediately.

### Option 3: "実装を中止"

Display a partial completion summary showing which steps were completed and which were skipped or not attempted. Use the same format as Phase 4's completion message but with `中止` status. Print "実装を中止しました。" and stop. Do NOT proceed to Phase 4.

## Important Rules

- Do NOT move to the next step until validation passes or the user explicitly chooses to skip
- If validation passes, continue to the next step without pausing
