---
description: >-
  At the end of a work session, generate a handoff doc (a single markdown file) plus a ready-to-paste kickoff message so the next session can resume with zero prior context. The goal is to preserve exactly what conversation auto-summarization (compaction) tends to lose: the decisions made and their rationale, the conventions/options adopted or rejected, the verification commands and toolchain gotchas actually hit, project-specific policies that can't be re-derived from code or git, and remaining work with why it's deferred. Fire proactively even when the words "doc" or "引き継ぎ" don't appear, e.g.: 「引き継ぎ／handoff を作って」「別のセッション・別チャットに渡したい／そっちで続きをやる」「次のセッション用にまとめて」「(会話の)context・コンテキストがいっぱい／そろそろ限界」「このまま /clear・compact する前に今の状態を残したい」「compact すべきか doc に残すべきか迷う」「今日はここまで／作業を中断する／一区切りつけるので、明日や後で再開する自分が迷わず続けられるよう状態を残して」. Do NOT fire for: code cleanup itself (関数の切り出し・リネーム・1ファイル内のリファクタ); general document authoring (PR 説明文・コミットメッセージ・README・設計ドキュメント design doc); work reports / 分報 summaries to Slack and the like; human/team business handover material for offboarding or role changes (退職や担当交代に伴う業務引き継ぎ資料); and requests like 「もっとファイルを読んで文脈(context)を把握して直して」 that mean code comprehension, not running out of conversation context.
---

# Session Handoff

## Why this skill exists

There are two ways to close a session. **Compaction** auto-summarizes the history so the *current* session can keep going; the summary is machine-driven, you can't curate it, and the "why" behind decisions and the options you discarded are the first things to drop. A **handoff doc** is for crossing a session boundary, and you choose what to keep.

So the value of the doc is not "accuracy" but "**keeping only what cannot be re-derived**". Copying down what the next session could learn by reading the code or `git log` has zero value — it will reread that anyway — and it buries the information that actually matters. What to keep is what a summary or a reread won't bring back: **the decisions made and their rationale, the conventions/options adopted or rejected, the verification commands that actually worked and the gotchas, project policies not written in the code, and remaining work plus "why not now"**. This principle runs through every step.

## First check: compaction or doc (lightly — not every time)

Read the situation and route to one of the two below. Don't lecture.

- Only when there is a **risky pre-commit in-flight state** (half-done edits scattered uncommitted / a mid-interruption state complex enough that the code alone is hard to reconstruct from), **or** the user themselves says they're torn between compacting and a doc, state the trade-off in one line and give a recommendation. The gist: "**Uncommitted work-in-progress edits can't be faithfully reproduced in a doc. If you're crossing a boundary (/clear, another session), commit or stash first; or if you're continuing here, compaction is safer. If you really must hand off via a doc now, explicitly preserve the uncommitted parts in §0.**" After stating the recommendation, don't stop — proceed straight to generating the doc (give a wavering user the decision input, but keep your hands moving).
- If the **state is committed and the intent is clear**, don't touch the gate — silently proceed to generation.

## How to generate

### 1. Ground the current state in git

**Do not fabricate** the hashes or status in §0. Use the bundled script to grab the actual git output in one go:

```bash
bash <skill-dir>/scripts/collect_git_state.sh 10   # arg = number of recent log entries (default 10)
```

You get the branch / recent log / working tree (status --short) / stat of uncommitted changes. This is **raw data**. Don't paste it into the doc as-is; in §0, **interpret** it into "what each uncommitted change is, and why it hasn't been committed yet" (the "why" that git doesn't show is your job). Outside a repo, omit the git part.

### 2. Decide where the doc goes

Don't hardcode the location globally. Conventions differ per repo (e.g., docs for a specific topic are consolidated into a dedicated directory). **Look at where the existing docs related to this work live, and conform to them**:

```bash
# find existing handoff/summary-style docs to get your bearings
find . -type f -name '*.md' \( -iname '*handoff*' -o -iname '*summary*' -o -iname '*引き継ぎ*' \) -not -path '*/node_modules/*' 2>/dev/null
find . -type d \( -name docs -o -name summary -o -name handoff \) -not -path '*/node_modules/*' 2>/dev/null
```

- If there's a directory where docs on related topics are gathered, match it (follow the existing filename style and format too).
- When there are multiple candidates with no clear winner, or no existing doc and you're unsure, **ask the user where to put it**. Don't create a new directory on your own and leave clutter.
- The filename is a descriptive form + an **absolute date** (e.g. `<topic>_handoff_2026-06-22.md`). Don't use relative expressions like "today" or "last week" even in the doc body — convert them to absolute dates.

### 3. Write the doc (§0–§5)

Write it following the "doc template" below. In each section, apply the [What to write vs. skip](#what-to-write-vs-skip-core-principle) principle. Short is fine — a thin section is 1–2 lines; if there's nothing, state it explicitly with "特になし" rather than dropping the section.

### 4. Emit the kickoff message to chat

Separately from the doc, emit a self-contained prompt — ready to paste at the start of the next session — **into the chat body** (put the same thing in §5 of the doc). Writing that assumes context, like "continue from before", is forbidden — write as if the person pasting it has zero prior knowledge. Details in [Kickoff message](#kickoff-message) below.

## doc template

```markdown
# <トピック> 引き継ぎ (YYYY-MM-DD)

> このドキュメントの役割: <何の作業を、なぜ次セッションに引き継ぐのか1〜2行>。
> 関連する正本 doc があれば先に挙げる: `path/to/related.md`（何が書いてあるか）

## 0. 現在地
- ブランチ: `<branch>`（git 裏取り済み）
- 直近の到達点: <log から向き付けに必要な数行。コミット列の貼り付けではなく「どこまで進んだか」>
- 作業ツリー: <未コミットの各変更が何で、なぜまだコミットしていないか。クリーンならそう書く>

## 1. 確立した決定・規約（蒸し返さない）
<下した判断／採用した規約・命名・パターンを、根拠とセットで。表が読みやすい>
| 決定 | 内容 | 根拠（なぜ・却下した案） |
|---|---|---|

## 2. 検証・作業フロー（実際に動かしたもの）
<コピペで動く実コマンド＋パス。通っただけでなくハマり所も。例: コンテナのマウント範囲、
 必要な事前手順、落とし穴。コマンドが無いなら省略してよい>

## 3. 作業方針（やること・やらないこと）
<コードに書いていない進め方の方針。「あえてやらない」と決めたこと、その理由も>

## 4. 残作業・保留候補
- [ ] <次にやること。なぜ未了か・ブロッカーがあれば添える>
- 保留: <今あえてやらないこと＋その理由（後で蒸し返さないため）>

## 5. 次セッション開始メッセージ
<セクション「キックオフメッセージ」の自己完結プロンプトをそのまま転記>
```

The section numbers and headings are a guideline. If an existing doc has a strong style, you may conform to it. Don't pad to fill a near-empty section.

## What to write vs. skip (core principle)

**Don't write (re-derivable from code/git = the next session can reread it)**

- Directory structure, function signatures, verbatim explanations of the implementation
- Raw pastes of `git log` / `git diff`
- Generic "just do the rest the usual way" filler

**Write (won't come back from a summary or a reread)**

- The decisions made and the **rationale**, and the **alternatives rejected** after consideration (why they were rejected)
- The conventions/naming/patterns adopted, and their **origin / precedent**
- The **verification commands** that actually worked (in copy-pasteable form) and the **gotchas**
- **Project-specific policies/constraints** that don't appear in the code
- Remaining work and "**why not now / why deferred**"

The yardstick: "Can the next session figure this out in 5 minutes by looking at code or git?" If yes, don't write it. **Even a file list has value if each line carries a 'why it's needed / what role it plays' annotation** (an unannotated list is unnecessary).

## Kickoff message

A prompt that **stands on its own** as the first move of the next session. Conditions to meet:

- Name the repository, the work target, and the doc's path up front (assume zero context)
- Point to which sections of the doc to read
- Write the "concrete first move" derived from §4
- Include the working branch name

**Example** (good — paste it standalone and you can resume):

> green-api で「ターゲットリスト抽出」バッチの Go 本実装を引き継ぎます。まず `curation_research/docs/summary/<topic>_handoff_2026-06-22.md` を読んでください——前セッションの引き継ぎ doc で、§0=現在地、§1=確定済みの決定（蒸し返さない）、§4=残作業です。作業ブランチは `GR-20488-...`。読んだら §4 の先頭タスク「週次更新版の反映ロジック追加」に着手してください。設計の正本は同 doc が指す `judgment_axis_aggregation_spec.md` です。

**Avoid** (bad — context-dependent, doesn't work standalone):

> さっきの続きをやってください。残りのタスクをお願いします。
