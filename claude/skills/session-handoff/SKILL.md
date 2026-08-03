---
name: session-handoff
description: >-
  At the end of a work session, generate a handoff doc (a single markdown file) plus a ready-to-paste kickoff message so the next session can resume with zero prior context — preserving the decisions, their rationale, and the gotchas that compaction drops. Fire proactively even when the words "doc" or "引き継ぎ" don't appear, e.g.: 「引き継ぎ／handoff を作って」「別のセッション・別チャットに渡したい／次のセッション用にまとめて」「(会話の)context がいっぱい／そろそろ限界」「/clear・compact する前に今の状態を残したい」「今日はここまで／作業を中断するので状態を残して」. Do NOT fire for: code cleanup itself (関数の切り出し・リネーム・リファクタ); general document authoring (PR 説明文・コミットメッセージ・README・設計ドキュメント); work reports / 分報 to Slack and the like; business handover for offboarding or role changes (退職・担当交代の業務引き継ぎ資料); and 「もっとファイルを読んで文脈(context)を把握して直して」, which means code comprehension rather than running out of conversation context.
---

# Session Handoff

Compaction and a handoff doc solve different problems. Compaction auto-summarizes the history so the *current* session can keep going — machine-driven, and you can't curate what it drops. A handoff doc crosses a session boundary, and you choose what survives.

So the doc's value is not completeness but **keeping only what cannot be re-derived**. The yardstick for every line: *could the next session work this out in 5 minutes from the code or `git log`?* If yes, leave it out — it only buries what matters.

- **Leave out**: directory structure, function signatures, restatements of the implementation, raw `git log` / `git diff` pastes, generic "carry on as usual" filler.
- **Keep**: decisions and their rationale; alternatives considered and rejected, and why; conventions and naming adopted, and where they came from; verification commands that actually worked, plus the gotchas hit; project policies not visible in the code; remaining work and why it's deferred.
- A file list earns its place only when each line says why that file matters.

## When the state is risky, say so — then keep going

Uncommitted half-done edits scattered around (or a user who is themselves torn between compacting and a doc) deserve one line of trade-off and a recommendation: work in progress that isn't committed can't be faithfully reproduced in a doc, so commit or stash before crossing a boundary, or stay in this session and compact instead; if the handoff has to happen now, preserve the uncommitted parts explicitly in §0. Then generate the doc anyway — don't stop at the recommendation. When the state is committed and the intent is clear, skip this and generate.

## Generating

One script grounds §0 in reality and finds where the doc belongs:

```bash
bash <skill-dir>/scripts/collect_state.sh 10   # arg = number of recent log entries (default 10)
```

It reports the branch, recent log, working tree, uncommitted stat, and any existing handoff/summary-style docs and doc directories. That is **raw data**: don't paste it into the doc, interpret it. §0 says what each uncommitted change is and why it isn't committed yet — the part git can't tell you. Outside a repo, drop the git material.

Put the doc where related docs already live, matching their filename style and format. When several locations compete with no clear winner, or none exists, ask the user instead of inventing a directory. Filenames pair a descriptive form with an **absolute date** (`<topic>_handoff_2026-06-22.md`) — keep the date even where neighbouring files omit it, since it is what keeps handoffs findable later; convert relative expressions like 「今日」 to absolute dates inside the body too.

Then write the doc from the template below, and emit the kickoff message into the chat body as well as into §5.

## doc template

```markdown
# <トピック> 引き継ぎ (YYYY-MM-DD)

> このドキュメントの役割: <何の作業を、なぜ次セッションに引き継ぐのか1〜2行>。
> 関連する正本 doc があれば先に挙げる: `path/to/related.md`（何が書いてあるか）

## 0. 現在地
- ブランチ: `<branch>`（git 裏取り済み）
- 直近の到達点: <どこまで進んだか。コミット列の貼り付けではない>
- 作業ツリー: <未コミットの各変更が何で、なぜまだコミットしていないか。クリーンならそう書く>

## 1. 確立した決定・規約（蒸し返さない）
| 決定 | 内容 | 根拠（なぜ・却下した案） |
|---|---|---|

## 2. 検証・作業フロー（実際に動かしたもの）
<コピペで動く実コマンド＋パス、ハマり所。今回動かしていないなら「未実行」と断って載せる>

## 3. 作業方針（やること・やらないこと）
<コードに書いていない進め方。「あえてやらない」と決めたことと理由>

## 4. 残作業・保留候補
- [ ] <次にやること。なぜ未了か・ブロッカー>
- 保留: <今あえてやらないこと＋理由>

## 5. 次セッション開始メッセージ
<キックオフメッセージをそのまま転記>
```

薄いセクションは1〜2行で構わないが、空でも落とさず「特になし」と書く。既存 doc に強い書式があればそちらに合わせてよい。

## Kickoff message

A prompt that stands on its own as the next session's first move: it names the repository, the work target, and the doc's path; points at which sections to read (§0 現在地 / §1 確立した決定・規約 / §4 残作業); states the concrete first move drawn from §4; and gives the working branch. Context-dependent openers like 「さっきの続きをやってください」 fail this test.
