---
name: research
description: Deep codebase investigation before planning or implementation. Produces a structured research document for human review.
allowed-tools: Task, AskUserQuestion, Bash, Read, Glob, Grep
argument-hint: "[topic, feature name, or file path] [--scope 'broad'|'focused'] [--output 'filename']"
context: fork
---

# Codebase Research Skill

Deeply investigate a codebase topic, feature, or module and produce a structured research document (`research-<topic>.md`) for human review — before any planning or implementation begins.

## Instructions

### Phase 1: Scope Determination (use Task with Bash subagent)

Call the Task tool with:
- subagent_type: "Bash"
- description: "determine research scope"
- prompt: Include the subagent prompt below, replacing $ARGUMENTS with actual arguments

#### Subagent Prompt Template

You are a research scope analyzer. Determine the scope and entry points for a codebase investigation.

**Arguments**: $ARGUMENTS

**Step 1: Parse Arguments**

Extract:
- `TOPIC`: The investigation subject (feature name, module, file path, or question). REQUIRED — if empty, return:
```
STATUS: NO_TOPIC
調査対象を指定してください。例: /research "認証フロー" or /research src/auth/
```
- `SCOPE`: "broad" (default) or "focused" — from `--scope` flag
- `OUTPUT`: Custom output filename — from `--output` flag, or empty

**Step 2: Project Context**

Gather project context:
```bash
# Project type detection
ls package.json go.mod Cargo.toml pyproject.toml requirements.txt Makefile build.gradle pom.xml 2>/dev/null

# Directory structure (top 2 levels, excluding noise)
find . -maxdepth 2 -type d \
  -not -path '*/node_modules/*' \
  -not -path '*/.git/*' \
  -not -path '*/vendor/*' \
  -not -path '*/dist/*' \
  -not -path '*/__pycache__/*' \
  -not -path '*/.next/*' \
  -not -path '*/build/*' \
  | head -60

# CLAUDE.md for project conventions
if [ -f CLAUDE.md ]; then
  echo "CLAUDE_MD: EXISTS"
else
  echo "CLAUDE_MD: NOT_FOUND"
fi
```

**Step 3: Find Entry Points**

Based on the TOPIC, find relevant files as investigation starting points:

If TOPIC is a file path:
```bash
test -f "$TOPIC" && echo "ENTRY_TYPE: FILE" || echo "ENTRY_TYPE: NOT_FOUND"
```
If file not found, try glob: `find . -path "*$TOPIC*" -type f | head -10`

If TOPIC is a feature name or keyword:
```bash
# Search for references in code
grep -rl "$TOPIC" --include='*.ts' --include='*.tsx' --include='*.js' --include='*.jsx' --include='*.go' --include='*.py' --include='*.rs' --include='*.java' --include='*.rb' --include='*.swift' --include='*.kt' . 2>/dev/null | grep -v node_modules | grep -v vendor | grep -v dist | head -20

# Also search with common variations (camelCase, snake_case, kebab-case)
```

If SCOPE is "focused", limit entry points to the most directly relevant 5 files.
If SCOPE is "broad", include up to 20 files and look for related configuration, tests, and types.

**Step 4: Return Result**

```
STATUS: OK
TOPIC: <topic>
SCOPE: <broad|focused>
OUTPUT: <custom filename or empty>
CLAUDE_MD: <EXISTS or NOT_FOUND>
PROJECT_TYPE: <detected project type>
DIRECTORY_STRUCTURE:
<structure output>

ENTRY_POINTS:
<file1>
<file2>
...

ENTRY_POINT_COUNT: <count>
```

---

### Phase 2: Deep Investigation (use Task with general-purpose subagent)

If Phase 1 returned an error status (`NO_TOPIC`), display the message to the user and stop.

If Phase 1 returned `ENTRY_POINT_COUNT: 0`, use AskUserQuestion to ask the user for clarification:
- question: "`<topic>` に関連するファイルが見つかりませんでした。キーワードやパスを変えて再試行しますか？"
- header: "Research"
- options:
  1. label: "キーワードを変更", description: "別のキーワードで検索します（Otherで入力）"
  2. label: "キャンセル", description: "調査を終了します"

If "キーワードを変更": Re-run Phase 1 with the new keyword.
If "キャンセル": Print "調査を終了しました。" and stop.

Otherwise, call the Task tool with:
- subagent_type: "general-purpose"
- description: "deep codebase investigation"
- prompt: Read the file `.claude/skills/research/prompts/investigate.md` and use its content as the subagent prompt. Embed the entire Phase 1 output as `Scope Data` and the TOPIC as `Investigation Topic`.

---

### Phase 3: User Review (main agent)

**STATUS: OK from Phase 2**:

Display the research summary to the user:

```
## 調査結果サマリー

**トピック**: <topic>
**調査範囲**: <scope>
**調査ファイル数**: <count>

### 主要な発見
<key findings summary — 3-5 bullet points>

### アーキテクチャ概要
<brief architecture description>
```

Use AskUserQuestion:
- question: "調査結果をファイルに出力しますか？"
- header: "Research"
- options:
  1. label: "ファイルに出力", description: "research-<topic>.md として保存します"
  2. label: "追加調査", description: "特定の領域をさらに深く調査します（Otherで入力）"
  3. label: "キャンセル", description: "調査を終了します"

**If "ファイルに出力"**: Proceed to Phase 4
**If "追加調査"**: User provides a follow-up question or area via "Other". Re-run Phase 2 with the original scope data PLUS the follow-up request AND the previous Phase 2 results as prior context. Do NOT re-run Phase 1.
**If "キャンセル"**: Print "調査を終了しました。" and stop.

---

### Phase 4: Output Generation (main agent)

Write the research document:

1. Determine filename:
   - If `OUTPUT` was specified in Phase 1: use that filename
   - Otherwise: `research-<sanitized-topic>.md` (sanitize: lowercase, replace spaces/special chars with hyphens)

2. Write the file using the Write tool. The file MUST include these sections:

```markdown
# Research: <topic>

> Generated by Claude Code research skill on <date>
> Scope: <broad|focused>

## 概要

<2-3 sentence overview of what was investigated and the key takeaway>

## アーキテクチャ

<Architecture description: component relationships, layers, data flow>

## 主要コンポーネント

### <Component 1>
- **ファイル**: `<path>`
- **責務**: <what it does>
- **依存先**: <what it depends on>
- **依存元**: <what depends on it>

### <Component 2>
...

## データフロー

<How data moves through the system for this feature/topic>

## 既存パターンと規約

<Patterns, conventions, and idioms used in this area of the codebase>

## 依存関係

<External dependencies, internal module dependencies>

## 注意点・リスク

<Gotchas, technical debt, potential issues to be aware of>

## 関連ファイル一覧

<Complete list of files investigated, grouped by role>
```

3. Open the file in the editor:
```bash
code <filename> 2>/dev/null || true
```

4. Display completion message:

```
## 調査完了

`<filename>` に調査結果を出力しました。

### 次のステップ
- 調査結果を確認し、認識の誤りがあれば修正してください
- 計画策定に進む場合、このファイルをコンテキストとして活用できます
```

---

### Rules

- ALWAYS display messages in Japanese
- NEVER modify any source code — this skill is read-only investigation
- NEVER skip user review (Phase 3) — the human must validate findings before output
- When re-running Phase 2 with follow-up, include previous findings to avoid redundant investigation
- Read files in full — do NOT use partial reads (head/tail) unless the file exceeds 1000 lines
- Trace call chains at least 2 levels deep (caller → callee → callee's callee)
- When assumptions are made, explicitly mark them as assumptions in the output
- If CLAUDE.md exists, read it and incorporate project conventions into the analysis
- The research output file should be detailed enough for someone unfamiliar with the codebase to understand the topic
