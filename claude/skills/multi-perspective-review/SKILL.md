---
name: multi-perspective-review
description: >-
  実装完了後のブランチ差分を、複数の専門家観点（言語・設計・ドメイン・セキュリティ等）で並行レビューし、挙動を変えないリファクタ候補を洗い出して裁定用の一覧にする（コードは修正しない）。コストが大きいので、ユーザーの承諾を得てから起動する。トリガー例:「多観点でレビューして」「専門家の観点で改善点を洗い出して」「リファクタ候補を洗い出して」「レビューパネルにかけて」「いろんな角度からこの差分を見て」および同義の言い回し。大きめの実装が一段落して PR を作る前なら一言で提案してよい（1セッション1回まで。断られたら再提案しない）。Do NOT use for: PR 前の定型セルフレビュー（「PR前チェック」「PR出す前に見て」「セルフレビューして」と言われたら pre-pr-check を既定にし、多観点も要るか一言確認する）、単一パスのバグ探し（code-review / review）、外部レビュー指摘への対応判断（review-triage）、自分の結論のブラインド照合（second-opinion）、実装前の計画・設計への尋問（grilling）。
---

# Multi-Perspective Review

## What this skill is for

Take a branch diff that is implemented but not yet in a PR, have several expert-perspective subagents review it **in parallel**, then merge their findings into a list the user can adjudicate. There are two goals:

1. Exhaustively surface **refactor candidates that do not change behavior**.
2. Flag any **behavior-changing problems** found along the way (bugs, mismatches with the spec, operational risks). In practice this second bucket yields the highest-value findings.

This skill owns **the review and the adjudication list only** — it never edits code. Once the user decides what to act on, implementation goes back to the normal flow (per-commit plan → pre-work gate → evidence-backed report).

## Overall flow

1. Understand the diff.
2. Recommend 3–5 perspectives → get user confirmation.
3. Concretize perspectives (detect the manifest, ask about domain docs).
4. Launch all perspectives in one message, in parallel.
5. Integrate → present the adjudication list → wait for the user's call.

### Step 1: Understand the diff

- Confirm the base branch, then look at the changed files and size with `git diff <base>...HEAD --stat`.
- Note the kind of change (new feature / refactor / bug fix), its size, and which layers it touches (API, DB, async jobs, external integrations, UI…). This is the raw material for recommending perspectives next.

### Step 2: Recommend perspectives and confirm

- Read [references/perspectives.md](references/perspectives.md). It is a catalog of 10 perspectives, each defined by a role declaration, a "when it helps" note, and a checklist.
- Pick **3–5 perspectives** from the diff, and add a one-line "why this helps for this diff" to each. 3–5 is the usual range, not a hard floor: for a genuinely thin diff (e.g. a mechanical rename) where only two perspectives truly earn their cost, recommend two. Never pad the list with a low-value perspective just to reach a count — that produces the generic remarks this skill exists to avoid.
- **Do not run all of them every time.** Always state the cost: ~100k tokens and 4–5 minutes per perspective (e.g. 4 in parallel ≈ 400k tokens total).
- Use AskUserQuestion (multiSelect) to confirm additions/removals before launching.

### Step 3: Prepare before launch

- **Detect language and libraries**: from the manifest (pyproject.toml / go.mod / package.json / Gemfile / Cargo.toml, etc.), detect the language version and major libraries, and use them to concretize the "language pro" and "library pro" perspective checklists.
- **The domain-expert perspective is the one thing that cannot be automated.** When using it, ask the user two things before launching:
  1. Which spec docs should the subagent read (give concrete paths)?
  2. Where are the "settled design decisions" that must not be relitigated?
- **Pass the settled-decisions doc to every selected perspective's prompt.** Without it, subagents mass-produce findings that relitigate already-decided matters (in the original run, passing the plan doc made these ~zero).

### Step 4: Launch in parallel

- Issue all the Agent tool calls in **one message, at the same time**. Subagents run in the background, so waiting serially is wasted time.
- Use `general-purpose` as the subagent_type and pass `model: "opus"` explicitly on every Agent call — regardless of which model is running the main agent (e.g. even when the main agent itself is Fable). Pinning to Opus keeps review quality independent of the main agent's model.
- Each perspective's prompt follows the skeleton below. Embedding the **shared constraints** (behavior-preserving, separate-bucket reporting, no relitigating, read-only) into every prompt is the core of the quality.

### Step 5: Integrate and build the adjudication list

Integration steps:

1. **Deduplicate.** If several perspectives independently flag the same spot, that convergence is itself a strong signal — note it as "flagged independently by N perspectives" (it drives adjudication priority; in the original run, 3 of 4 perspectives independently flagged the same duplicated definition → it was tackled first).
2. **Separate "⚠️ changes behavior / needs a call" from "behavior-preserving refactor"**, and put the former first.
3. Classify the behavior-preserving side into buckets (structure / readability & domain vocabulary / tests, etc.) and lay it out in an **importance × effort** table.
4. Finally, narrow the **"points to discuss"** down to 2–3 and wait for the user's decision. **Do not fix anything on your own.**

Wording of the list:

- Internal finding IDs may use per-perspective prefixes (P-1, L-2, …; defined in the catalog). This keeps each finding traceable to its source after merge.
- But in the list shown to the user, do not invent unreadable abbreviations or coinages. Titles should read plainly in Japanese so the meaning is obvious.

### Step 6: Exit

Break the "do it" items from the adjudication into per-commit tasks and hand them to the normal implementation flow (pre-work gate → evidence-backed report). This skill's responsibility ends here.

## Subagent prompt skeleton

Each perspective's prompt is a variation on the skeleton below (written in Japanese, because the review output is delivered to the user in Japanese). Fill in `{}` at launch. Take the checklist from the relevant perspective in perspectives.md and concretize it with the detection results from Step 3.

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

Keep the format identical across all perspectives so that integration (Step 5) can be done mechanically. Target 12–15 for the max count `{N}`.

## How this differs from other skills

| Nature of the request | Use |
| --- | --- |
| Multi-perspective sweep for behavior-preserving refactor candidates | **this skill** |
| Single-pass bug hunting | code-review / review (built-in) |
| Deciding whether to act on external review comments | review-triage |
| Blind cross-check of your own conclusion | second-opinion |
| Interrogating a plan/design before implementation | grilling |
