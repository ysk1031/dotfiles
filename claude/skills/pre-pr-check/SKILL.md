---
name: pre-pr-check
description: "Run BEFORE creating a PR on a feature branch: two report-only review passes over the branch diff — (1) simplification (unnecessary conversions, defensive code with no consumer, dead options) and (2) convention consistency for newly added public types/files (placement in existing homes, layer responsibility, type consistency, naming symmetry) — merged into one adjudication table. No code is touched until the user approves specific findings; approved fixes are applied one-finding-one-commit. Catches the design/convention feedback human reviewers would otherwise leave on the PR. Trigger when the user says 「PR前チェック」「pre-pr-check」「PR出す前に見て」「セルフレビューして」, or when the pr skill suggests it. Do NOT use for bug hunting (code-review/review), judging external review comments (review-triage), broad refactor brainstorming (multi-perspective-review), or explaining a diff (explain-diff)."
allowed-tools: Bash, Read, Grep, Glob, Edit, Write, Agent, Skill
argument-hint: "[base-branch (default: auto-detect)]"
metadata:
  author: ysk1031
  version: 1.0.0
---

# Pre-PR Check

Human reviewers on this user's PRs rarely find bugs — tests catch those. What they find is design/convention feedback: "this belongs in the existing DAO", "this constant is domain knowledge, why is it in infra", "this field is int but every other ID is uint", "these types don't share the prefix their siblings use", "this ORDER BY has no consumer". This skill runs that review *before* the PR exists, so the feedback comes from the AI and the user adjudicates it, instead of a teammate finding it later.

Two hard rules:
1. **Report first, touch nothing.** Both passes are read-only. Fixes happen only after the user approves specific findings.
2. **Blind reviewers.** The passes run in subagents that see the diff and the repo but NOT this conversation, so the implementer's own rationalizations ("I made a separate DAO because…") don't leak into the review.

## Phase 0: Scope

1. Determine base branch: use the argument if given; otherwise `git remote show origin | grep 'HEAD branch'`, falling back to main → master → develop existence checks.
2. `git diff <base>...HEAD --stat`. If there is no diff, say so and stop.
3. Triviality gate: if the diff has NO new files, NO new exported symbols, and fewer than ~50 changed lines, tell the user this diff is too small for the full check to pay off and ask whether to run it anyway.

## Phase 1: Mechanical extraction (main agent, read-only)

Extract the inputs deterministically — do not rely on the LLM to enumerate:

1. **New files**: `git diff <base>...HEAD --diff-filter=A --name-only`
2. **New exported symbols** (Go example; adapt the grep to the project language):
   `git diff <base>...HEAD -- '*.go' | grep -E '^\+(type|func|const|var) ' | sort -u`
   Include symbols in new files too (the diff covers them). Keep test-file symbols out of the consistency pass unless they define shared helpers.
3. **Convention sources**: collect paths of the project `CLAUDE.md` and any convention docs it references (e.g. `agent_docs/*.md`). These are handed to the consistency reviewer. If the project has no written conventions, note it — the layer-responsibility question will be weaker and the final report must say so.

## Phase 2: Two blind passes (parallel subagents)

Launch BOTH subagents in a single message so they run concurrently. Each gets: the working directory, base branch name, and the instruction to read the diff itself (`git diff <base>...HEAD`). Neither gets this conversation's context or the reasons behind design choices. Pass `model: "opus"` explicitly on both Agent calls, regardless of which model is running the main agent (e.g. even when the main agent itself is Fable) — this keeps review quality independent of the main agent's model.

**Pass A — Simplification reviewer** (subagent_type: general-purpose, model: opus). Prompt it to find, in the changed lines only:
- conversions/copies that disappear if a variable is declared as the target type from the start
- defensive code with no consumer: ORDER BY no caller depends on, locks/retries/options nothing exercises, parameters always passed the same value
- code duplicating an existing helper in the repo (it should grep for candidates)
- dead or write-only fields introduced by the diff

Explicitly out of scope: bugs, style nits, renames. Each finding: file:line, one-sentence claim, evidence, confidence (high/medium/low). Return findings as a list; empty list is a valid result.

**Pass B — Convention-consistency reviewer** (subagent_type: general-purpose, model: opus). Give it the new-item list from Phase 1 and the convention doc paths. For EACH new item it answers exactly four fixed questions, using grep/read on the repo for evidence:

1. **置き場**: Does an existing type/interface/file already own this responsibility or return this kind of value? (Search by return type and by responsibility keywords. Example of the failure mode: adding a single-method `XxxIDDAO` when an existing `JobOfferIDDAO` already collects job-offer-ID queries.)
2. **層**: Per the convention docs, is this the layer that should decide this value? (Example: an application-decided schema version constant defined in the infrastructure layer looks like a DB default; it belongs in domain.)
3. **型**: Do fields with the same meaning use the same type across layers and neighboring types? (Example: one LLM-output job_offer_id declared int while every other ID in the codebase is uint.)
4. **命名**: Do sibling types in the same file/table share a prefix/vocabulary scheme? (Example: row type `MLJobOfferCriteriaProposal` but inner types without the `ML` prefix.)

A question with a clean answer produces no finding. Each finding: the new item, which question, the existing code it conflicts with (file:line), and a concrete alternative. Return findings as a list.

## Phase 3: Adjudication table (main agent) — HARD STOP

Merge both passes, drop duplicates, drop anything the subagents marked low-confidence unless the evidence is verifiable (verify it yourself before including). Present in Japanese:

```
## PR前チェック結果（<base>...HEAD, 変更 N ファイル）

| # | 対象 | 指摘 | 根拠 | 推奨 |
|---|------|------|------|------|
| 1 | <file:line or 型名> | <一文> | <既存コードとの対比> | 直す / 見送り可 / 相談 |

対応する番号を返信してください（例:「1,3」「全部」「なし」）。
```

- 推奨 must take a position — don't mark everything 直す. 見送り可 is for real-but-cheap-to-ignore items; 相談 is for genuine trade-offs.
- If both passes return nothing, say exactly that ("両パスとも指摘なし") and stop — do not manufacture findings.
- **END THE TURN after the table.** Do not call tools after it, and do not use AskUserQuestion (dialog redraw hides the table; same lesson as the pr skill).

## Phase 4: Apply approved findings only

For each approved finding, in table order: fix → verify (build + the project's relevant test command from CLAUDE.md) → stage only the files for that finding → commit via the `commit` skill. **One finding = one commit**, so each fix stays reviewable. Skip everything the user didn't pick, silently.

After the last commit, summarize what was fixed vs. skipped and remind: 「/pr で PR 作成に進めます」.

## Notes

- Cost: two subagents, roughly a few minutes and a few tens of thousands of tokens on a mid-size diff. Not worth it on trivial diffs — that's what the Phase 0 gate is for.
- This skill's consistency pass is only as strong as the project's written conventions (question 2 especially). If findings keep appearing that a convention doc would have prevented, propose adding the rule to the project's CLAUDE.md / agent_docs after Phase 4.
