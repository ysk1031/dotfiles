# Commit Schemas

Subagent I/O format definitions for the commit skill.

---

## commit-analyze-output

Output format for commit/prompts/analyze-changes.md.

Success:
```
STATUS: OK
TITLE: <type>: <description>
BODY: <body or empty>
```

No changes:
```
STATUS: NO_CHANGES
ステージされた変更がありません。git add <files> でファイルをステージしてから再度 /commit を実行してください。
```

Split recommended:
```
STATUS: NEEDS_SPLIT
警告: このコミットには複数の異なる変更が含まれています。
コミットを分割することを検討してください:

1. [変更1の説明]
2. [変更2の説明]

分割する場合: git reset HEAD <files>
このまま続行する場合: /commit --force
```

**Fields:**
- `STATUS` — `OK`: message generated, `NO_CHANGES`: no staged changes, `NEEDS_SPLIT`: commit split recommended
- `TITLE` — Commit message title line (Conventional Commits format, max 72 chars)
- `BODY` — Commit message body (only for complex changes; explains WHAT and WHY)
