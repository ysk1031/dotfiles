---
name: pre-pr-review
description: >-
  Run BEFORE creating a PR on a feature branch: a report-only review of the branch diff, delivered as one table for the user to adjudicate. Launching it needs no consent — the skill recommends and confirms any costly expert perspectives with the user itself. Trigger when the user says 「PR前チェック」「PR出す前に見て」「セルフレビューして」「多観点でレビューして」「専門家の観点で改善点を洗い出して」「リファクタ候補を洗い出して」「レビューパネルにかけて」「いろんな角度からこの差分を見て」and the like, or when the pr skill suggests it. When the user is merely musing (「リファクタする余地あるかな」and the like) or a sizable implementation just settled unprompted, offer it in one line instead of launching — once per session, and never re-offer once declined. Do NOT use for: single-pass bug hunting; judging external review comments (review-triage); blind cross-check of your own conclusion (second-opinion); interrogating a plan before implementation (grilling); explaining a diff (explain-diff); opening the diff in crit with your explanation attached (crit-annotate).
allowed-tools: Bash, Read, Grep, Glob, Edit, Write, Agent, Skill, AskUserQuestion
argument-hint: "[base-branch (default: auto-detect)]"
metadata:
  author: ysk1031
  version: 3.0.0
---

# Pre-PR Review

Human reviewers on this user's PRs rarely find bugs — tests catch those. What they find is design/convention feedback: "this belongs in the existing DAO", "this constant is domain knowledge, why is it in infra", "this field is int but every other ID is uint", "these types don't share the prefix their siblings use", "this ORDER BY has no consumer". This skill runs that review *before* the PR exists, so the feedback comes from the AI and the user adjudicates it, instead of a teammate finding it later.

**Every reviewer here is the same kind of object**: a catalog entry — role declaration, prefix, 合図 (the grep-able signals that make it worth running), checklist — launched as a blind subagent that answers in one fixed format. Two entries are always-on and cheap (`SIM`, `CNV`, defined at the bottom of this file); the expert entries live in [references/perspectives.md](references/perspectives.md) and join the same run on request. There is no second kind of pass and no mode switch: this skill is the successor of both `pre-pr-check` and `multi-perspective-review`, which reviewed the same diff at the same stage under two names.

Three hard rules:

1. **Report first, touch nothing.** Every reviewer is read-only. Fixes happen only after the user approves specific findings.
2. **Blind reviewers.** They see the diff and the repo but NOT this conversation, so the implementer's own rationalizations ("I made a separate DAO because…") don't leak in. A settled-decisions doc may be passed so reviewers don't relitigate what's decided — but only a doc that **already existed before this review** (one committed on the branch qualifies even if this diff added it; one written or edited during this conversation does not), and only as a path they read themselves, never as your summary. Two things are therefore forbidden, because both carry the implementer's framing across the wall by hand: suggesting the user add a rationale they just told you to that doc, and telling the user what the reviewers are about to flag before they have flagged it.
3. **Approval is permission to apply, not exemption from procedure.** Even when the user says 「直して」, a finding whose fix is behavior-changing, creates a new public type/interface/file, or touches an externally referenced contract (production schema, API, enum) is treated as a fresh implementation request: plan first, then implement. See Phase 5.

## Phase 0: Scope

1. Determine base branch: use the argument if given; otherwise `git remote show origin | grep 'HEAD branch'`, falling back to main → master → develop existence checks.
2. `git diff <base>...HEAD --stat`. If there is no diff, say so and stop.
3. Triviality gate: if the diff has NO new files, NO new exported symbols, and fewer than ~50 changed lines, say in one line that the full run may not pay off and ask whether to run it anyway.

## Phase 1: Who runs

`SIM` and `CNV` run every time, no questions asked. Whether expert perspectives join:

- **The request carries a multi-perspective signal** (多観点 / 専門家 / いろんな角度 / レビューパネル, or a named expert angle): read the catalog and keep the entries whose 合図 you actually found in the diff. Cap the experts at 5; the three default slots (language / library / architect) take three of those, so the user is choosing 0–2 more. List no more candidate options than those open slots — the dialog cannot cap how many get selected, so the option count is the cap. Confirm via AskUserQuestion (multiSelect), where:
  - each option quotes **the 合図 you found** and the cost (~100k tokens, 4–5 min each). Quote the signal and stop — what might be *wrong* with it is the pre-announcement hard rule 2 forbids.
  - perspectives the user named go first in the list, labeled as theirs (AskUserQuestion has no pre-selection; ordering and labeling is the whole mechanism).
  - selecting nothing means "defaults only". Say that in one line of prose, never as an option.
  - the domain slot needs its spec paths: find the candidates yourself and put them in that option's description as a proposal (「specs/xxx.md を読ませます」), so agreeing costs no second round trip.
- **Anything else** (plain 「PR前チェック」, the pr skill's suggestion, a bare slash invocation): `SIM` and `CNV` only, ask nothing.
- **「観点は絞って」**: cut non-default slots first. A default slot comes out **only** when its own exclusion condition in the catalog is met — never merely because the user wants fewer. State the surviving floor and its combined cost in one line of prose, put only the non-default candidates in the dialog, and never offer "just the defaults is fine" as an option. If the floor already exceeds the budget the user is worried about, say so plainly: the savings can only come from the non-default slots.
- **Incremental runs** (a table already went out this session): naming a perspective *is* the approval — state the cost in one line and launch, no dialog. Run only the new reviewers, reusing Phase 2's outputs from the earlier run as-is, merge per Phase 4's numbering example, and leave the rows already shown exactly as they are — same numbers, same text, same eight columns.

## Phase 2: Mechanical extraction (main agent, read-only)

Extract the inputs deterministically — do not rely on the LLM to enumerate:

1. **New files**: `git diff <base>...HEAD --diff-filter=A --name-only`
2. **New top-level declarations, with the file each one lives in** (Go example; adapt to the project language):
   `git diff -U0 <base>...HEAD -- '*.go' | grep -E '^(\+\+\+ b/|\+(type|func|const|var) )'`
   Keeping the `+++ b/<path>` headers is the point — a bare symbol list cannot answer the 置き場 and 層 questions, and guessing the file afterwards is exactly the enumeration this phase exists to avoid. Methods count as declarations. Include symbols in new files too.
   **Unexported declarations are in scope** — 置き場 / 型 / 命名 apply to them as much as to exported ones. Mark each item exported or not by its own name (an exported function returning an unexported type is exported), and tell `CNV` to skip the 層 question for unexported ones: a package-private value has no cross-layer contract to violate.
   A test-file symbol joins the list only when a second test file uses it. New docs/specs/config files never join it — they go to the reviewers as background material, because asking where a markdown spec belongs is wasted budget.
3. **Convention sources**: paths of the project's own `CLAUDE.md` (not the machine-wide `~/.claude/CLAUDE.md`, which is not a project convention) and any convention docs it references (e.g. `agent_docs/*.md`). If the project has no written conventions, note it — the 層 question will be weaker and the final report must say so.
4. **Manifest**: the language version and major libraries (go.mod / pyproject.toml / package.json / Gemfile / Cargo.toml…). Always, even on a two-reviewer run — it costs one file read, and the template's 言語/主要ライブラリ line, the expert role declarations, and Phase 1's 合図 quotes all depend on it.

## Phase 3: Parallel blind launch

Before the launch message, print one line naming what is being reviewed and how many reviewers are about to run: base branch, file count, changed-line count, and the reviewer prefixes. The user is about to wait several minutes for work they cannot see — that line is their only chance to catch a wrong base branch or an unexpectedly large diff before the tokens are spent.

Launch ALL selected reviewers in a single message so they run concurrently, each built from the one template at the bottom of this file. Every Agent call is `subagent_type: "general-purpose"` with `model: "opus"` passed explicitly, regardless of which model runs the main agent (even when it is Fable) — read-only is enforced by the prompt text, and pinning opus keeps review quality independent of the main agent's model.

Only five things vary between reviewers: **役割宣言 / 接頭辞 / チェックリスト / 観点固有の追加指示 / 主対象ファイル**. Everything else in the template is identical for all of them, which is what lets Phase 4 merge mechanically.

Inputs are fixed per the template, not per-reviewer judgment calls:
- **Every reviewer, always**: the repo path, the base branch, the instruction to read the diff body itself (not just `--stat`), the 言語/主要ライブラリ line (from Phase 2-4), and the paths of every background doc — the settled-decisions docs AND the convention docs, `SIM` included. **Paths only, never your summary of them** (hard rule 2).
- **主対象 defaults to the code files the diff touched, minus test files.** An entry's 観点固有の追加指示 may widen or narrow that — `SIM` adds the test files back; `CNV`'s targets are the files holding its item list.
- **`CNV` only**: Phase 2's item list.
- Set 最大件数 to 12–15 (small diff → 12; large or many reviewers → 15).

## Phase 4: One table (main agent) — HARD STOP

Merge every reviewer's output.

**Deduplicate by the underlying issue, not by the line number.** Two reviewers citing a type declaration and the method that uses it have found one issue: one row, noting 「N観点が独立に指摘」 (that convergence drives what the user tackles first). A single reviewer reporting the same issue twice merges the same way, minus the note. When the same statement arrives both as a behavior-preserving fix and as a ⚠️ finding, keep the single row in the ⚠️ table — whatever the user decides there settles whether the simplification still applies. Two adjacent lines with *different* concerns (dropping a temp variable vs. validating what goes into it) stay separate rows.

**Then filter, and say below the table what you dropped and why** — one line, or a short paragraph when a correction needs explaining, and 「除外なし」 when nothing was dropped. An invisible filter reads as "nothing else was found":

- Anything whose 確信度 is 低, unless you verify the evidence yourself.
- Anything whose target is a file the diff didn't touch. Reviewers do violate that constraint.
- A finding whose target is right but whose stated evidence is wrong (a claimed existing method that turns out not to exist) is neither dropped nor kept as-is: correct the wording, keep the row, note the correction.

These rules chain rather than compete. An unverified 低 drops. Once you have verified a finding, only the verdict matters: wrong target drops the row; right target with wrong evidence keeps the corrected row.

**You assign 重要度 and 工数 for every row** — reviewers return 確信度 only, because importance needs the repo-wide view a single reviewer doesn't have. Rate 重要度 by whether a written convention is violated and how far the problem reaches; 工数 by the number of call sites you can count with grep. Where a reviewer argued severity in its finding body (an exploitable path, a spec mismatch), you may adopt that in 重要度. Confidence is not importance. Both scales are three-valued: 重要度 高/中/低, 工数 小/中/大.

Present in Japanese under the heading 「PR前レビュー結果」. **Both tables have the same eight columns**:

```
## PR前レビュー結果（<base>...HEAD, 変更 N ファイル）

### ⚠️ 挙動が変わる / 判断が必要
| # | 対象 | 指摘 | 根拠 | 出所 | 重要度 | 工数 | 推奨 |
|---|------|------|------|------|--------|------|------|
| 1 | <file:line> | <一文> | <根拠> | <観点名> | 高 | 小 | 仕様を確認 / 実装フローで直す / 様子見 |

### 挙動を変えない改善
| # | <同じ8列> | | | | | | 直す / 見送り可 / 相談 |

**議論したい点**: <2〜3個に絞る。トレードオフが実在するものだけ>

対応する番号を返信してください（例:「2,3」「全部」「なし」）。
```

- Numbering is continuous across both tables, so 「1番直して」 is unambiguous. Within each table, order rows by 重要度 (高 first) and number them in that order. N in the heading is the `--stat` file count, docs included.
- The ⚠️ table comes first and holds everything the reviewers filed in their separate bucket. Omit it when empty. The reviewer's label is not binding: promote a finding it filed as behavior-preserving when the fix would change a repeated or externally visible side effect — how many rows get written, whether a request is retried, whether a lock is still held. Rewording a message or an error string is not that.
- **Incremental runs never renumber.** Example: 1–6 already went out, and a security perspective then returns one ⚠️ and two behavior-preserving findings → the ⚠️ table (new) holds **7**, and the behavior-preserving table continues **8, 9** after the existing 1–6. The ⚠️ table still sits on top even though its number is larger, and rows 1–6 keep both their numbers and their text — their *position* may shift, since new rows interleave by 重要度 while the old rows hold their relative order. Among the new findings, the ⚠️ rows take the smaller numbers first, as in the example. Re-present the whole merged table, not just the additions — the user replies with numbers, so the list must be one piece. When a new ⚠️ finding lands on the same issue as an existing behavior-preserving row, immutability wins over the merge rule: add it as a new ⚠️ row that names the old number (「2番と同じ箇所」), and note in one sentence under the ⚠️ table that the old row's 推奨 is superseded by the ⚠️ adjudication.
- 出所 names the reviewer that produced the finding (not the nature of the finding), as a plain Japanese label: 簡素化 / 規約 / 言語 / ライブラリ / アーキ / ドメイン / セキュリティ / 性能 / テスト / 運用 / 並行処理 / 互換性. Finding IDs (`SIM-1`, `P-2`…) are for internal traceability and never appear in the table; match findings by file:line when merging, never by ID alone. Titles must read plainly in Japanese: no invented abbreviations.
- 推奨 must take a position — don't mark everything 直す. In the ⚠️ table, 「仕様を確認」 is for a spec question, 「実装フローで直す」 for a real defect, 「様子見」 for something to record and not act on. When a finding admits two different fixes, write 推奨 and 工数 for the one you recommend and send the alternative to 議論したい点 — a cell cannot hold two effort estimates.
- 議論したい点 is capped at 2–3 and only for genuine trade-offs. Omit the line when there are none; it is not a summary of the table. An incremental run may add to it.
- If every reviewer returns nothing, say exactly that (「全レビュアーとも指摘なし」) and stop — do not manufacture findings.
- On a two-reviewer run where the diff shows strong signals for a catalog perspective, you may add ONE plain-text line after the table: 「追加の専門家観点（〜）も掛けられます。番号の返信と一緒にどうぞ」.
- **END THE TURN after the table.** Do not call tools after it, and do not use AskUserQuestion (dialog redraw hides the table; same lesson as the pr skill).

## Phase 5: Apply

**The gate for applying a finding yourself: the fix is behavior-preserving, creates no new public type/interface/file, and touches no externally referenced contract (production schema, API, enum).** All three must hold. 工数 is shown in the table but is not the gate — a mechanical rename reaching three files qualifies. A fix that embeds a judgment you made yourself (a threshold, a pattern new to this codebase) may still be applied directly, but state that judgment in one line when presenting the fix.

- **Findings that pass the gate**, in table order: fix → verify (build + the project's relevant test command from CLAUDE.md) → stage only that finding's files → commit via the `commit` skill. **One finding = one commit**, so each fix stays reviewable.
- **Approved findings that don't pass** (behavior-changing ⚠️ items, fixes that create a new public type/interface/file or touch an externally referenced contract): hard rule 3. Treat the request as approval to *start* a fresh implementation task — plan before code — and say so in one line.
- Skip everything the user didn't pick, silently.
- **Add-on requests arriving after the table** (「セキュリティ観点も見て」): Phase 1's incremental rule.

After the last commit, summarize what was fixed vs. skipped and remind: 「/pr で PR 作成に進めます」.

## The two always-on reviewers

Same schema as the catalog entries, kept here so a two-reviewer run never has to load the catalog.

### SIM — 簡素化 (prefix: `SIM`, label 簡素化)

- **役割宣言**: `不要な変換・消費者のいない防御的コードを洗い出す簡素化レビュアー`
- **合図**: always on
- **チェックリスト**:
  - 最初から目的の型で宣言すれば消える変換・コピー
  - 消費者のいない防御的コード: どの呼び出し元も依存していない ORDER BY、何も行使しないロック・リトライ・オプション、常に同じ値が渡される引数
  - リポジトリ内の既存ヘルパーと重複しているコード（候補を自分で grep して探すこと）
  - 差分が持ち込んだ、使われないフィールド・書き込むだけのフィールド
  - コードの言い換えにすぎないコメント: 同じコードを読む人が既に知っている情報しか含まないコメントは削除候補（コメントアウトされた旧コードも同じ。履歴は git に残る）。採用理由・棄却した代替案・警告・不変条件・単位・仕様やチケットへの参照・TODO は残す。次の2つは**置かれている位置**で決まる免除で、文言が言い換えでも指摘しない:
    - 宣言（関数・型・定数・フィールド）の直上に置かれ、その宣言を説明しているコメント。言語が専用の doc 記法（docstring / JSDoc / GoDoc）を持つかは問わず、`//` や `#` の行コメントも同じに扱う。関数の中の文や局所変数の直上はこれに当たらない
    - その下に続く宣言をまとめて名指しする区切りコメント。ただし名指しと、実際に並んでいる宣言が合っていないとき（例: 「内部」と名乗る節に公開 API が並ぶ）だけ、食い違いを理由として指摘する。「その下」は次の区切りかファイル末尾まで
- **観点固有の追加指示**: `スタイルの些末な指摘とリネームは対象外（言い換えコメントの削除はスタイルではなく簡素化なので対象）`。主対象には差分が触ったテストファイルも含める。

### CNV — 規約整合 (prefix: `CNV`, label 規約)

- **役割宣言**: `差分が追加した宣言ごとに置き場・層・型・命名の4問に答える規約整合レビュアー`
- **合図**: always on
- **チェックリスト** — Phase 2 の一覧の**アイテムごとに**、grep / read で証拠を取ってから4問に答える。きれいに答えが出る問いは指摘にしない。タイトルにどの問いから出たかを書く。
  1. **置き場**: この責務を既に持っている、あるいはこの種類の値を返している既存の型・interface・ファイルはないか（返り値の型と責務のキーワードの両方で検索する。失敗例: 既存の `JobOfferIDDAO` が求人 ID のクエリを集めているのに、1メソッドだけの `XxxIDDAO` を新設している）
  2. **層**: 規約ドキュメントに照らして、この値を決めるべき層はここか（失敗例: アプリケーションが決めるスキーマ版番号の定数が infrastructure にあると DB のデフォルト値のように見える。domain に属する）。**unexported な宣言ではこの問いをスキップする**
  3. **型**: 同じ意味のフィールドが、層をまたいでも隣接する型の間でも同じ型か（失敗例: LLM 出力の job_offer_id だけ int で、他の ID はすべて uint）
  4. **命名**: 同じファイル・同じテーブルに属する兄弟の型が接頭辞や語彙の体系を共有しているか（失敗例: 行の型が `MLJobOfferCriteriaProposal` なのに内側の型に `ML` 接頭辞がない）
- **観点固有の追加指示**: 背景資料の設計ドキュメントはコードではないので4問の対象アイテムではない、と明示して渡す。

## Reviewer prompt template

Every reviewer's prompt is this template with the five varying slots filled in. It is written in Japanese because the review is delivered to the user in Japanese. Keep the shape identical across reviewers so Phase 4 stays mechanical.

```
あなたは {役割宣言} として、リポジトリ {path} のブランチ {branch} の
新規コードをレビューする。読み取り専用のレビューであり、ファイルの変更は一切禁止。
git の状態を変える操作も禁止。

## 対象
base ブランチ: {base}
言語 / 主要ライブラリ: {マニフェスト検出の結果}
`git diff {base}...HEAD` を自分で実行して**差分の本体を読む**（`--stat` はファイル一覧の把握用）。
主対象: {ファイル群の列挙}
背景資料: {設計資料・規約ドキュメントのパス} — 自分で読むこと。
確定済みの設計判断とプロジェクトの規約が書かれている。
{規約整合レビュアーのみ: Phase 2 の対象アイテム一覧（ファイルごと・exported/unexported 付き）}

## レビューの前提
- 目的は「仕様・挙動を一切変えないリファクタリング」の候補を洗い出すこと。
  挙動が変わる提案は不可。ただし挙動バグ・仕様との食い違い・運用リスクを見つけたら
  「リファクタではなくバグ/リスク」と明示して別枠で報告する（この別枠報告は歓迎される。
  実際に最も価値の高い発見になることが多い）
- **指摘は差分が触った行に限る。** 既存コードは比較対象として読むだけで、指摘の対象にはしない
- 背景資料に書かれた設計判断は前提として受け入れ、蒸し返さない
- 置き場・層・型・命名の定型指摘は、接頭辞 CNV のレビュアーの担当。あなたの接頭辞が
  CNV なら、この4問こそがあなたの仕事。CNV でないなら、この4問に当たる定型指摘は
  出さない（深い構造上の問題を示しているときだけ触れてよい）

## 観点（{観点名}として）
{チェックリスト 4〜8項目}

## 出力形式（最終メッセージ。日本語）
発見ごとに:
- **[{接頭辞}-連番] タイトル**（file_path:line）
- 確信度: 高/中/低
- 現状の何が問題か（1〜3行、具体例つき）
- 改善案（具体的に。before/after のコード断片が有効なら短く示す）
- 挙動不変であることの根拠（1行）

確信度の高い順に並べる。最大{N}件。重要度と工数は付けない（統合側で付ける）。
指摘がなければ「指摘なし」とだけ返す（無理に作らない）。
挙動が変わる発見・仕様との食い違い・運用リスクは、上とは別の「⚠️別枠」節にまとめる
（この別枠報告は歓迎される。無理に挙動不変の枠へ押し込めない）。
{観点固有の追加指示}
```

## Notes

- Cost: the two always-on reviewers are a few tens of thousands of tokens and a few minutes on a mid-size diff. Each expert perspective adds ~100k tokens and 4–5 minutes; they run in the same parallel batch, so wall-clock barely moves.
- `CNV` is only as strong as the project's written conventions (the 層 question especially). If findings keep appearing that a convention doc would have prevented, propose adding the rule to the project's CLAUDE.md / agent_docs after Phase 5.
