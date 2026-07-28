---
name: pre-pr-review
description: >-
  Run BEFORE creating a PR on a feature branch: report-only review of the branch diff, merged into one table (「PR前レビュー結果」). Two cheap core passes always run — (1) simplification (unnecessary conversions, defensive code with no consumer, dead options) and (2) convention consistency for newly added public types/files (placement, layer responsibility, type consistency, naming symmetry). Costly expert add-on perspectives (language, library, architecture, domain, security…) can join the same run; the skill recommends and confirms them with the user before spawning, so launching the skill itself needs no pre-launch consent. Behavior-changing findings are listed first and never quick-applied; approved behavior-preserving fixes are applied one-finding-one-commit. Trigger when the user says 「PR前チェック」「PR出す前に見て」「セルフレビューして」「多観点でレビューして」「専門家の観点で改善点を洗い出して」「リファクタ候補を洗い出して」「レビューパネルにかけて」「いろんな角度からこの差分を見て」and the like, or when the pr skill suggests it. When the user is merely musing (「リファクタする余地あるかな」and the like) or a sizable implementation just settled unprompted, offer it in one line instead of launching (once per session; never re-offer once declined). Skip trivially small diffs (a few changed lines) — answer directly instead. Do NOT use for: single-pass bug hunting (code-review / review); judging external review comments (review-triage); blind cross-check of your own conclusion (second-opinion); interrogating a plan or design before implementation (grilling); explaining a diff (explain-diff).
allowed-tools: Bash, Read, Grep, Glob, Edit, Write, Agent, Skill, AskUserQuestion
argument-hint: "[base-branch (default: auto-detect)]"
metadata:
  author: ysk1031
  version: 2.0.0
---

# Pre-PR Review

Human reviewers on this user's PRs rarely find bugs — tests catch those. What they find is design/convention feedback: "this belongs in the existing DAO", "this constant is domain knowledge, why is it in infra", "this field is int but every other ID is uint", "these types don't share the prefix their siblings use", "this ORDER BY has no consumer". This skill runs that review *before* the PR exists, so the feedback comes from the AI and the user adjudicates it, instead of a teammate finding it later.

Two routine passes always run; on request, expert add-on perspectives (from [references/perspectives.md](references/perspectives.md)) join the same run as extra parallel reviewers. This skill absorbed the former `multi-perspective-review` skill — the two shared the same territory, and the add-on mechanism is its continuation.

Three hard rules:
1. **Report first, touch nothing.** All passes are read-only. Fixes happen only after the user approves specific findings.
2. **Blind reviewers.** The passes run in subagents that see the diff and the repo but NOT this conversation, so the implementer's own rationalizations ("I made a separate DAO because…") don't leak into the review. A settled-decisions doc (a file, not conversation) may be passed so reviewers don't relitigate what's already decided.
3. **Behavior-changing findings are never quick-applied.** Even when the user says "直して", a ⚠️ finding goes back to the normal implementation flow (per-commit plan → pre-work gate → evidence-backed report), never straight to a commit.

## Phase 0: Scope

1. Determine base branch: use the argument if given; otherwise `git remote show origin | grep 'HEAD branch'`, falling back to main → master → develop existence checks.
2. `git diff <base>...HEAD --stat`. If there is no diff, say so and stop.
3. Triviality gate: if the diff has NO new files, NO new exported symbols, and fewer than ~50 changed lines, tell the user this diff is too small for the full check to pay off and ask whether to run it anyway.

## Phase 1: Perspective decision

The two core passes (A: simplification, B: convention consistency) always run. Decide here whether expert add-ons join them:

- **The user's request carries a multi-perspective signal** (多観点 / 専門家 / いろんな角度 / レビューパネル, or they named specific expert angles): read [references/perspectives.md](references/perspectives.md), pick 2–5 perspectives that fit the diff, and confirm via AskUserQuestion (multiSelect) with a one-line "why this helps for this diff" and the cost (~100k tokens, 4–5 min per perspective) stated. Perspectives the user already named go in pre-selected. Don't pad the list to reach a count — for a thin diff, two honest perspectives beat four generic ones.
- **Anything else** (plain 「PR前チェック」-style trigger, the pr skill's suggestion, a bare slash invocation): run core only, ask nothing. Same zero-friction behavior as the old pre-pr-check.
- **Add-on preparation** (only when add-ons were selected): detect the language version and major libraries from the manifest (go.mod / pyproject.toml / package.json / Gemfile / Cargo.toml…) to concretize the language/library checklists. For the domain perspective, ask two things before launching: which spec docs the reviewer should read (concrete paths), and where the settled design decisions live.
- **Incremental runs**: if the core passes already ran on this branch in this session, run only the newly requested add-ons and merge the results into the existing table's numbering.
- If the user explicitly asks to skip the routine passes ("定型はいいから観点だけ"), obey — but say in one line that naming/placement conventions won't be covered.

## Phase 2: Mechanical extraction (main agent, read-only)

Extract the inputs deterministically — do not rely on the LLM to enumerate:

1. **New files**: `git diff <base>...HEAD --diff-filter=A --name-only`
2. **New exported symbols** (Go example; adapt the grep to the project language):
   `git diff <base>...HEAD -- '*.go' | grep -E '^\+(type|func|const|var) ' | sort -u`
   Include symbols in new files too (the diff covers them). Keep test-file symbols out of the consistency pass unless they define shared helpers.
3. **Convention sources**: collect paths of the project `CLAUDE.md` and any convention docs it references (e.g. `agent_docs/*.md`). These are handed to the consistency reviewer. If the project has no written conventions, note it — the layer-responsibility question will be weaker and the final report must say so.

## Phase 3: Parallel blind launch

Launch ALL subagents — both core passes and any selected add-ons — in a single message so they run concurrently. Each gets: the working directory, base branch name, and the instruction to read the diff itself (`git diff <base>...HEAD`). None gets this conversation's context or the reasons behind design choices; if a settled-decisions doc is known, pass its path to every reviewer. Pass `model: "opus"` explicitly on every Agent call, regardless of which model is running the main agent (e.g. even when the main agent itself is Fable) — this keeps review quality independent of the main agent's model.

Every prompt — core and add-on alike — carries this shared constraint: *the goal is behavior-preserving findings, but if you spot a behavior bug, a mismatch with the spec, or an operational risk, report it in a separate bucket marked as such (this side-channel is welcomed — in practice it yields the highest-value findings).*

**Pass A — Simplification reviewer** (subagent_type: general-purpose, model: opus). Prompt it to find, in the changed lines only:
- conversions/copies that disappear if a variable is declared as the target type from the start
- defensive code with no consumer: ORDER BY no caller depends on, locks/retries/options nothing exercises, parameters always passed the same value
- code duplicating an existing helper in the repo (it should grep for candidates)
- dead or write-only fields introduced by the diff

Explicitly out of scope: style nits, renames. Each finding: file:line, one-sentence claim, evidence, confidence (high/medium/low). Return findings as a list; empty list is a valid result.

**Pass B — Convention-consistency reviewer** (subagent_type: general-purpose, model: opus). Give it the new-item list from Phase 2 and the convention doc paths. For EACH new item it answers exactly four fixed questions, using grep/read on the repo for evidence:

1. **置き場**: Does an existing type/interface/file already own this responsibility or return this kind of value? (Search by return type and by responsibility keywords. Example of the failure mode: adding a single-method `XxxIDDAO` when an existing `JobOfferIDDAO` already collects job-offer-ID queries.)
2. **層**: Per the convention docs, is this the layer that should decide this value? (Example: an application-decided schema version constant defined in the infrastructure layer looks like a DB default; it belongs in domain.)
3. **型**: Do fields with the same meaning use the same type across layers and neighboring types? (Example: one LLM-output job_offer_id declared int while every other ID in the codebase is uint.)
4. **命名**: Do sibling types in the same file/table share a prefix/vocabulary scheme? (Example: row type `MLJobOfferCriteriaProposal` but inner types without the `ML` prefix.)

A question with a clean answer produces no finding. Each finding: the new item, which question, the existing code it conflicts with (file:line), and a concrete alternative. Return findings as a list.

**Add-on perspectives** use the prompt skeleton below, with the checklist taken from the matching entry in perspectives.md and concretized with the Phase 1 detection results.

## Phase 4: Review table (main agent) — HARD STOP

Merge all passes. Deduplicate — when several reviewers independently flag the same spot, keep one row and note 「N観点が独立に指摘」 (that convergence drives what the user tackles first). Drop anything marked low-confidence unless the evidence is verifiable (verify it yourself before including). Present in Japanese under the heading 「PR前レビュー結果」:

```
## PR前レビュー結果（<base>...HEAD, 変更 N ファイル）

### ⚠️ 挙動が変わる / 判断が必要
| # | 対象 | 指摘 | 根拠 | 出所 |
|---|------|------|------|------|
| 1 | <file:line> | <一文> | <根拠> | <観点名> |

### 挙動を変えない改善
| # | 対象 | 指摘 | 根拠 | 出所 | 重要度 | 工数 | 推奨 |
|---|------|------|------|------|--------|------|------|
| 2 | <file:line or 型名> | <一文> | <既存コードとの対比> | 簡素化 | 中 | 小 | 直す / 見送り可 / 相談 |

**議論したい点**: <2〜3個に絞る。トレードオフが実在するものだけ>

対応する番号を返信してください（例:「2,3」「全部」「なし」）。
```

- Numbering is continuous across both tables, so "1番直して" is unambiguous about which group it hits.
- The ⚠️ table comes first and holds everything the reviewers put in the separate bucket (bugs, spec mismatches, operational risks). If it's empty, omit it.
- 出所 uses plain Japanese labels (簡素化 / 規約 / 言語 / ライブラリ / アーキ / ドメイン / セキュリティ / 性能 / テスト / 運用 / 並行処理 / 互換性) — the catalog's ID prefixes (P-1, L-2…) are for internal traceability only and never appear in the table (Pass A and the architect perspective would both claim "A"). Titles must read plainly in Japanese: no invented abbreviations or coinages.
- On a **core-only** run, drop the 出所 / 重要度 / 工数 columns — the core passes return confidence, not an importance×effort rating — and the table is the same shape the old pre-pr-check produced. 重要度×工数 exists so the add-on perspectives' ratings have somewhere to land.
- 議論したい点 is capped at 2–3 and only for genuine trade-offs. Omit the line when there are none; it is not a summary of the table.
- 推奨 must take a position — don't mark everything 直す. 見送り可 is for real-but-cheap-to-ignore items; 相談 is for genuine trade-offs.
- If all passes return nothing, say exactly that ("全パスとも指摘なし") and stop — do not manufacture findings.
- On a core-only run where the diff shows strong signals for a catalog perspective (auth/authz, concurrency, schema changes…), you may add ONE plain-text line after the table: 「追加の専門家観点（〜）も掛けられます。番号の返信と一緒にどうぞ」.
- **END THE TURN after the table.** Do not call tools after it, and do not use AskUserQuestion (dialog redraw hides the table; same lesson as the pr skill).

## Phase 5: Apply

- **Approved behavior-preserving findings**, in table order: fix → verify (build + the project's relevant test command from CLAUDE.md) → stage only the files for that finding → commit via the `commit` skill. **One finding = one commit**, so each fix stays reviewable. Skip everything the user didn't pick, silently.
- **⚠️ findings the user asks to fix**: hard rule 3 — never commit them directly from here. Treat the request as approval to *start* the normal implementation flow (per-commit plan → pre-work gate → evidence-backed report) and say so in one line.
- **Add-on requests arriving after the table** (「セキュリティ観点も見て」): re-enter Phase 1's incremental rule — run only the new perspectives, merge into the existing numbering.

After the last commit, summarize what was fixed vs. skipped and remind: 「/pr で PR 作成に進めます」.

## Add-on prompt skeleton

Each add-on perspective's prompt is a variation on the skeleton below (written in Japanese, because the review output is delivered to the user in Japanese). Fill in `{}` at launch; take the checklist from the relevant perspective in perspectives.md and concretize it with the Phase 1 detection results. Keep the format identical across perspectives so Phase 4 can merge mechanically. Target 12–15 for the max count `{N}`.

```
あなたは {観点の役割宣言} として、リポジトリ {path} のブランチ {branch} の
新規コードをレビューする。読み取り専用のレビューであり、ファイルの変更は一切禁止。

## 対象
`git diff {base}...HEAD --stat` で変更ファイル一覧が見られる。主対象: {ファイル群の列挙}
背景資料: {設計資料のパス}（確定済みの設計判断が書かれている。設計判断そのものは蒸し返さない）

## レビューの前提
- 目的は「仕様・挙動を一切変えないリファクタリング」の候補を洗い出すこと。
  挙動が変わる提案は不可。ただし挙動バグ・仕様との食い違い・運用リスクを見つけたら
  「リファクタではなくバグ/リスク」と明示して別枠で報告する（この別枠報告は歓迎される）
- 確定済みの設計判断（{要点の列挙}）は前提として受け入れる
- 命名・置き場所の定型指摘はコアの規約整合パスが担当するので出さない

## 観点（{観点名}として）
{観点のチェックリスト 5〜8項目}

## 出力形式（最終メッセージ。日本語）
発見ごとに:
- **[{接頭辞}-連番] タイトル**（file_path:line）
- 重要度: 高/中/低、工数: 小/中/大
- 現状の何が問題か（1〜3行、具体例つき）
- 改善案（具体的に。before/after のコード断片が有効なら短く示す）
- 挙動不変であることの根拠（1行）

重要度順に並べる。最大{N}件。確信度の低いものは「確信度低」と明示する。
{観点固有の追加指示（例: 既存コードベースの慣習とのズレは必ず指摘）}
```

## Notes

- Cost: the core run is two subagents, roughly a few minutes and a few tens of thousands of tokens on a mid-size diff. Each add-on perspective adds ~100k tokens and 4–5 minutes; they run in the same parallel batch, so wall-clock barely moves.
- The consistency pass is only as strong as the project's written conventions (question 2 especially). If findings keep appearing that a convention doc would have prevented, propose adding the rule to the project's CLAUDE.md / agent_docs after Phase 5.
