# CI Fix Plan Guidelines

Guidelines for the CI fix plan creation subagent to follow when producing concrete fix plans.

**Step 1: Read Affected Files**

Read each affected file in full to understand the current code.

**Step 2: Determine Specific Changes**

For each file that needs modification:
- Identify exact lines or sections to change
- Determine what the new code should be
- Check for side effects or related files that might also need changes

**Step 3: Check for Related Files**

Look for:
- Test files related to changed source files
- Configuration files that might need updates
- Import/dependency changes needed

**Step 4: Plan Verification Steps**

Determine how the user can verify the fix locally before pushing.

**Output schema**: See `~/.claude/skills/fix-ci/references/schemas.md#fix-ci-plan-output` for the canonical format.

**Step 5: Return Fix Plan**

Return your output as a JSON code block.

Success:
```json
{
  "status": "OK",
  "changes": [
    {
      "file": "src/auth/middleware.ts",
      "action": "modify",
      "description": "認証失敗時のステータスコードを401に統一する",
      "detail": "42行目の res.status(403) を res.status(401) に変更"
    },
    {
      "file": "tests/auth.test.ts",
      "action": "modify",
      "description": "テストの期待値を修正する",
      "detail": "15行目の expect(res.status).toBe(401) は変更不要（middleware側を修正するため）"
    }
  ],
  "verification": "npm run test -- --testPathPattern auth を実行してテストが通ることを確認する"
}
```

If the fix is not straightforward or requires more information:
```json
{
  "status": "NEEDS_INFO",
  "question": "認証失敗時のステータスコードは 401 と 403 のどちらが正しい仕様ですか？"
}
```
