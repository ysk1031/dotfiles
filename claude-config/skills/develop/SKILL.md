---
name: develop
description: "Run the full research, plan, implement pipeline end-to-end. 新機能を作りたい、大きな変更を実装したい時に使用。調査から実装まで一気通貫で実行。"
allowed-tools: Task, AskUserQuestion, Bash, Read, Edit, Write, Glob, Grep
argument-hint: "[task description] [--from 'research'|'plan'|'implement'] [--research 'file.md'] [--output 'plan-filename']"
disable-model-invocation: true
---

# Develop Skill

Orchestrator skill that runs the research → plan → implement pipeline end-to-end. References existing skill SKILL.md files (`/research`, `/plan`, `/implement`) with overrides to coordinate investigation, planning, and implementation automatically.

## Instructions

### Argument Parsing (Main Entry Point)

**Arguments**: $ARGUMENTS

Extract the following variables:

| Variable | Description | Default |
|----------|-------------|---------|
| `TASK` | Task description (all text except `--from`, `--research`, `--output` flags) | — |
| `FROM` | Starting phase (`--from` flag value) | `research` |
| `RESEARCH_FILE` | Existing research file path (`--research` flag value) | — |
| `OUTPUT` | Plan output filename (`--output` flag value) | `plan.md` |

**Phase Branching**:

- `--from research` (default): Phase R → Phase P → Phase I
- `--from plan`: Phase P → Phase I
- `--from implement`: Phase I only

**Validation**:

1. If `FROM` is `research` or `plan` and `TASK` is empty:
   ```
   タスクの説明を指定してください。例: /develop "ユーザー認証機能の追加"
   ```
   Display message and stop.

2. If `FROM` is `implement` and the plan file is not found:
   Use `OUTPUT` value (default: `plan.md`) as the plan file path.
   ```bash
   if [ ! -f "$PLAN_FILE" ]; then
     ls plan*.md 2>/dev/null | head -5
   fi
   ```
   If not found:
   ```
   計画ファイルが見つかりません。先に /plan でファイルを作成するか、--output でパスを指定してください。
   利用可能なファイル: <list or なし>
   ```
   Display message and stop.

After validation passes, execute phases sequentially starting from the `FROM` value.

---

### Phase R: Research (executed when `FROM` is `research`)

Read `~/.claude/skills/research/SKILL.md` with the Read tool and follow its
Instructions section with the following overrides:

**Overrides**:
1. **Phase 1 (Scope Determination)**: Apply these adjustments to the subagent prompt:
   - `SCOPE`: Always set to `"broad"` — ignore `--scope` flag parsing
   - `OUTPUT`: Always set to empty — Phase R determines filename automatically
   - `NO_TOPIC` error message example: Use `/develop "認証フロー"` (not `/research`)
2. **Phase 3 (User Review)**: Skip entirely — do NOT ask for user review
3. **Phase 4 (Output Generation)**: Execute automatically after Phase 2 completes

**Output**: Set `RESEARCH_FILE` to the generated file path. Display Phase R
completion summary, then transition to Phase P.

---

### Phase P: Plan (executed when `FROM` is `research` or `plan`)

Read `~/.claude/skills/plan/SKILL.md` with the Read tool and follow its
Instructions section with the following overrides:

**RESEARCH_FILE Resolution** (before Phase 1):
- If Phase R was executed: use the file path output in Phase R
- If `--from plan` with `--research`: use the `--research` flag value
- If `--from plan` without `--research`: search for `research-*.md` in the
  current directory and display candidates (do NOT auto-select)

**Overrides**:
1. **Phase 1 (Context Gathering)**: Apply these adjustments to the subagent prompt:
   - `TASK`: Already validated as non-empty — skip the NO_TASK validation
   - `RESEARCH_FILE`: Use the resolved value from above
   - `OUTPUT`: Use the `$OUTPUT` value (default: `plan.md`)
2. **Phase 1 Error Handling** (`--from plan` with missing research file):
   - Use AskUserQuestion with options: "なしで続行" / "パスを変更" / "キャンセル"
   - "キャンセル": Display "開発を終了しました。" and stop entire pipeline
3. **Phase 3 (Annotation Cycle)**: The annotation cycle is the ONLY confirmation
   gate in `/develop`. Add research file reference to the review display (Step 1).
   - Display `> 調査ファイル: \`<RESEARCH_FILE>\` — 調査結果の詳細はこちらを参照できます` in the review message (skip if RESEARCH_FILE is empty)
   - "キャンセル": Display "開発を終了しました。" and stop entire pipeline
4. **Phase 4 (Finalization)**: After completion, display
   "Phase I（実装）に自動遷移します..." and automatically transition to Phase I

**Output**: The approved plan file at `OUTPUT` path.

---

### Phase I: Implement (executed in all flows)

Read `~/.claude/skills/implement/SKILL.md` with the Read tool and follow its
Instructions section with the following overrides:

**Overrides**:
1. **Phase 1 (Plan Loading)**: Apply these adjustments to the subagent prompt:
   - `PLAN_FILE`: Use `OUTPUT` value (default: `plan.md`) — skip argument parsing
   - `SELECTED_STEPS`: Always ALL — omit from return result
   - `NO_PLAN` error message: Use shorter version: `計画ファイルが見つかりません。`
2. **Phase 2 (Scope Confirmation)**: Skip entirely — do NOT ask for user
   confirmation. Auto-execute all steps.
3. **Phase 3 → renumbered as the implementation loop**: Execute all remaining
   steps without pausing

**Output**: Display implementation completion summary with git diff --stat,
checklist, and verification results.

---

### Error Handling Summary

Each phase's specific error handling is defined in the referenced skill's SKILL.md and the overrides above. The following table provides a pipeline-wide overview:

| Situation | Phase | Response |
|-----------|-------|----------|
| Task description empty | Argument parsing | Display error message and stop |
| Topic not specified in Phase R | Phase R (via `/research`) | Display error message and stop (fallback) |
| 0 entry points in Phase R | Phase R (via `/research`) | AskUserQuestion: change keyword or cancel |
| Research file not found with `--from plan` | Phase P (override) | AskUserQuestion: continue without / change path / cancel |
| Cancel during annotation cycle | Phase P (override) | Display "開発を終了しました。" and stop entire pipeline |
| Plan file not found with `--from implement` | Argument parsing | Display error message + candidates and stop |
| Validation failure in Phase I | Phase I (via `/implement`) | Fix immediately → re-validate |
| Test failure in Phase I | Phase I (via `/implement`) | AskUserQuestion: fix or skip |

---

### Rules

- ALWAYS display messages in Japanese — the user is a Japanese speaker and needs to review pipeline progress in Japanese
- NEVER modify existing skills — `/develop` is an independent skill — modifying existing skills would affect their standalone usage (e.g., `/research` used independently)
- NEVER skip the plan annotation cycle (Phase P-3) — the plan annotation cycle is the only confirmation gate in the pipeline; skipping it risks implementing unintended changes
- Skip the review gate in Research phase — within the pipeline, research is an intermediate artifact that will be reviewed during plan annotation
- Skip scope confirmation in Implement phase — the plan is already approved, so re-confirming implementation start is redundant
- Reference existing skill SKILL.md files directly and specify only overrides — minimizes logic duplication and ensures standalone skill changes propagate automatically
- When starting mid-pipeline with `--from`, validate preconditions for skipped phases — executing later phases without meeting preconditions leads to errors or incomplete results
- NEVER commit or push changes — commits should only happen after user review; unintended pushes trigger unnecessary CI runs
- Correctly pass data between phases (RESEARCH_FILE, OUTPUT, etc.) and maintain variable consistency — data inconsistency between phases silently produces incorrect results
