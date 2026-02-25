---
name: code-simplifier
description: Simplify and refine recently modified code for clarity and maintainability
allowed-tools: Task, AskUserQuestion, Bash, Read, Edit, Glob, Grep
argument-hint: "[file-path or empty for recent changes]"
---

# Code Simplifier Skill

Simplifies and refactors code after implementation to make it cleaner and more readable, while preserving all functionality.

## Instructions

### Phase 1: Target File Identification (use Task with Bash subagent)

Call the Task tool with:
- subagent_type: "Bash"
- description: "identify target files for simplification"
- prompt: Include the subagent prompt below, replacing $ARGUMENTS with actual arguments

#### Subagent Prompt Template

You are a file identification helper. Determine which files should be analyzed for code simplification.

**Arguments**: $ARGUMENTS

**Step 1: Determine Target Files**

If arguments contain a file path:
1. Check if the file exists: `test -f <path> && echo "EXISTS" || echo "NOT_FOUND"`
2. If exists, use that file as target
3. If not found, return:
```
STATUS: FILE_NOT_FOUND
指定されたファイルが見つかりません: <path>
```

If arguments are empty:
1. Check recent changes:
```bash
# Uncommitted changes first
UNCOMMITTED=$(git diff --name-only 2>/dev/null)
STAGED=$(git diff --staged --name-only 2>/dev/null)
# If no uncommitted/staged changes, check last commit
if [ -z "$UNCOMMITTED" ] && [ -z "$STAGED" ]; then
  LAST_COMMIT=$(git diff --name-only HEAD~1 2>/dev/null)
fi
```
2. Combine all found files, deduplicate, and filter to only existing files

**Step 2: Validate Files**
- Filter out binary files, lock files, generated files (*.lock, *.min.js, dist/, node_modules/, etc.)
- If no valid files remain, return:
```
STATUS: NO_FILES
対象ファイルが見つかりません。ファイルパスを引数で指定するか、変更を加えてから実行してください。
```

**Step 3: Check for CLAUDE.md**
```bash
if [ -f CLAUDE.md ]; then
  echo "CLAUDE_MD: EXISTS"
else
  echo "CLAUDE_MD: NOT_FOUND"
fi
```

**Step 4: Return Result**
```
STATUS: OK
CLAUDE_MD: <EXISTS or NOT_FOUND>
FILES:
<file1>
<file2>
...
```

---

### Phase 2: Code Analysis (use Task with code-simplifier subagent)

If Phase 1 returned an error status (`FILE_NOT_FOUND`, `NO_FILES`), display the message to the user and stop. Do NOT proceed to Phase 2.

Call the Task tool with:
- subagent_type: "code-simplifier"
- description: "analyze code for simplification"
- prompt: Include the analysis prompt below with the file list from Phase 1

#### Analysis Prompt

You are analyzing code for simplification opportunities. Your job is to ANALYZE ONLY — do NOT modify any files.

**Target files**:
<file list from Phase 1>

**CLAUDE.md available**: <yes/no from Phase 1>

**Instructions**:

1. Read each target file using the Read tool
2. If CLAUDE.md exists, read it to understand project conventions
3. Analyze each file for improvement opportunities in these categories:
   - Unnecessary complexity and nesting
   - Redundant code and abstractions
   - Unclear variable and function names
   - Nested ternary operators that should be switch/if-else
   - Dense one-liners that hurt readability
   - Dead code or unused imports
4. For each improvement, assign a severity:
   - **high**: Significantly impacts readability or maintainability
   - **medium**: Noticeable improvement but not critical
   - **low**: Minor stylistic improvement
5. Return your analysis in this EXACT format:

```
STATUS: OK
TOTAL_IMPROVEMENTS: <count>

=== FILE: <path> ===
IMPROVEMENT_COUNT: <count>

[<N>] SEVERITY: <high|medium|low>
DESCRIPTION: <what to improve and why>
BEFORE:
\`\`\`<lang>
<original code snippet>
\`\`\`
AFTER:
\`\`\`<lang>
<improved code snippet>
\`\`\`

(repeat for each improvement)

=== END FILE ===
```

If no improvements found:
```
STATUS: NO_IMPROVEMENTS
対象ファイルに改善点は見つかりませんでした。コードは十分にクリーンです。
```

**IMPORTANT**:
- Do NOT edit any files — analysis only
- Do NOT change functionality — only improve how code is written
- Keep useful abstractions — avoid over-simplification
- Preserve debuggability

---

### Phase 3: User Confirmation (main agent)

**STATUS: NO_IMPROVEMENTS from Phase 2**:
Display "対象ファイルに改善点は見つかりませんでした。コードは十分にクリーンです。" and stop.

**STATUS: OK from Phase 2**:

1. Display the improvement summary grouped by file:

```
## コード改善提案

### 1. `<file path>` (<count>件)
- [high] <description>
- [medium] <description>
- [low] <description>

### 2. `<file path>` (<count>件)
...

合計: <total> 件の改善提案 (high: X, medium: Y, low: Z)
```

2. Use AskUserQuestion:
   - question: "どの改善を適用しますか？"
   - header: "Apply"
   - options:
     1. label: "すべて適用", description: "全改善を適用"
     2. label: "highのみ", description: "重要度highの改善のみ適用"
     3. label: "high+medium", description: "重要度high/mediumの改善を適用"
     4. label: "キャンセル", description: "何もせず終了"

**If "すべて適用"**: Proceed to Phase 4 with all improvements
**If "highのみ"**: Proceed to Phase 4 with high-severity improvements only
**If "high+medium"**: Proceed to Phase 4 with high and medium severity improvements
**If custom input (Other)**: Parse user's selection (e.g., file names or improvement numbers) and proceed to Phase 4
**If "キャンセル"**: Print "改善をキャンセルしました。" and stop

---

### Phase 4: Apply Changes (main agent)

Apply the approved improvements:

1. For each file with approved improvements:
   - Read the file with the Read tool
   - Apply changes using the Edit tool
   - Use the BEFORE/AFTER snippets from Phase 2 as guidance for the edit

2. After all changes, show summary:
```bash
git diff --stat
```

3. Display completion message:

```
## 改善完了

<list of changed files and improvement counts>

### 次のステップ
- 動作確認を行ってください
- 問題なければ `/commit` でコミットできます
```

**IMPORTANT**: Do NOT commit or push — only apply file modifications.

---

### Rules

- ALWAYS display messages in Japanese
- NEVER commit or push changes — only apply file modifications
- NEVER change functionality — only improve how code is written
- NEVER skip user confirmation (Phase 3)
- If CLAUDE.md exists, respect its conventions in the analysis
- Filter out binary files, lock files, and generated files from targets
- For very large files (>500 lines), focus on the most impactful improvements
- If the code-simplifier subagent is unavailable, fall back to general-purpose subagent
