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

**Output schema**: See `.claude/skills/commit/references/schemas.md#commit-analyze-output` for the canonical format.

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
