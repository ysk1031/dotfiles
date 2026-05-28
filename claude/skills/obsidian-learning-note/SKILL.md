---
name: obsidian-learning-note
description: "Summarize the learnings from the current Claude Code session and save them as a new Markdown note in the user's Obsidian vault at ~/Documents/Obsidian/SyncedNotes/. Use when the user explicitly asks to capture session insights to Obsidian — phrases like '今の学びをObsidianに保存して', 'この学びをまとめて', '学びをノートにして', 'Obsidianにメモして', 'save the learnings to Obsidian'. Extracts insights across debugging solutions, newly-encountered tech/tools/patterns, codebase-specific knowledge, and workflow improvements, then writes one consolidated note. Do NOT use for activity-style daily summaries (use [[daily-report]] instead), for appending to an existing note, or for non-learning content."
allowed-tools: AskUserQuestion, Bash, Write
argument-hint: "[optional: focus or viewpoint hint, e.g. 'Hooksの挙動にフォーカス' / '抽象化レベルを上げて汎用的な学びだけ' / 'codebase固有の知見のみ']"
disable-model-invocation: true
metadata:
  author: ysk1031
  version: 1.0.0
---

# Obsidian Learning Note Skill

Capture the learnings from the current Claude Code session and save them as a single Markdown note in the user's Obsidian vault. The goal is to preserve the **insight**, not a transcript of what happened — future-self should be able to read the note cold and understand the takeaway without remembering this session.

Vault location: **~/Documents/Obsidian/SyncedNotes/** (flat — notes live at the top level, no subfolders).

---

## Phase 0: Read the optional argument

If the user passed an argument when invoking the skill (e.g., `/obsidian-learning-note Hooksの挙動にフォーカス`), treat it as a **focus hint** that shapes Phase 1. Examples of what the hint can do:

- **Scope narrowing** — "Hooksの挙動にフォーカス" → ignore unrelated learnings even if they exist
- **Abstraction control** — "抽象化レベルを上げて" → prefer general/reusable framings over codebase-specific facts
- **Category filtering** — "codebase固有の知見のみ" → only include findings from that category
- **Tone / framing** — "なぜこの設計か、を中心に" → emphasize reasoning over mechanics

The hint is a steering signal, not a strict filter. If the hint asks for something not present in the session (e.g., focus on Hooks but the session had nothing about Hooks), say so in Phase 2 rather than fabricating content. If no argument was passed, extract learnings across all categories as default.

---

## Phase 1: Extract learnings from the conversation

Scan the current conversation for genuine learnings, looking across four categories. Read the conversation itself — not just diffs or commits — because the *insight* lives in what the user wrestled with and resolved, not in the final code.

| Category | What to look for |
|---|---|
| デバッグ / トラブルシューティング | A real error or stuck-point hit during the session, what the root cause turned out to be, why the fix works. Not "I fixed a typo" — but "the test failed because X, which I didn't expect because Y". |
| 新しい技術・ツール・パターン | A library/CLI/pattern that the user encountered or properly understood for the first time in this session. Signs: questions about how it works, surprise at its behavior, "へぇ" reactions. |
| コードベース固有の知見 | Repository structure, conventions, gotchas, "where X lives", non-obvious behaviors specific to this codebase. Information that would help future-self navigate this repo faster. |
| ワークフロー / プロセスの改善 | Claude Code usage patterns, command sequences, productivity tricks. What worked well in this session that the user might want to repeat. |

What counts as a learning:
- Something the user (or you) was uncertain about, and the session resolved
- A surprising discovery — something that contradicted an initial assumption
- A non-obvious fact about the codebase that took effort to figure out
- A workflow the user reacted positively to ("これいいな", "今後もこうしよう")

What does NOT count (filter these out):
- Routine task completion ("PRをマージした", "テストが通った")
- Things the user already knew before the session and merely applied
- Mechanics of this skill itself
- Pure restatements of what the code does (the code is the documentation for that)

If you find no meaningful learnings: **don't pad**. Report that honestly in Phase 2 and offer to cancel or let the user dictate the content manually.

---

## Phase 2: Confirm with the user

Show a brief preview of the extracted learnings — topic lines only, not full bodies — so the user can scan and react quickly:

```
今回のセッションから、以下の学びを抽出しました:
1. [{category}] {one-line topic}
2. [{category}] {one-line topic}
3. [{category}] {one-line topic}
```

Then propose 1-2 titles and confirm with `AskUserQuestion`:

- question: "このタイトルで保存しますか？（Other で自由入力も可）"
- header: "Title"
- options:
  1. label: `{suggested-title-1}`, description: "提案タイトル案1"
  2. label: `{suggested-title-2}`, description: "提案タイトル案2（別の切り口）"
  3. label: "内容を見直したい", description: "プレビューを修正してから保存"

Title guidance:
- The vault uses **title-only filenames** (no date prefix) and freely allows Japanese, spaces, parentheses, commas. Match that style — examples in the user's vault: `Claude Code - Subagent, Agent Team, Skill の違いについて.md`, `Azure OpenAI のAPI Rate-limit メモ.md`.
- Be **searchable later**: "Claude Code Hooks の PostToolUse で値を受け取る方法" beats "Hooks の学び".
- If the session covered one specific finding → name that finding. If it covered several related findings → find the unifying theme rather than concatenating topics.

If the user picks "内容を見直したい", ask what to change, regenerate the preview, and re-confirm. Don't proceed to Phase 3 until they've explicitly confirmed a title.

If you found no meaningful learnings in Phase 1, replace the preview with:
```
今回のセッションには、新しい学びと呼べる発見が見当たりませんでした。
```
And offer "手動で内容を指定する / キャンセル" via AskUserQuestion. Default to cancel — adding low-value notes to a long-term vault is worse than not adding anything.

---

## Phase 3: Write the note

### Format

Keep the structure light. The vault's existing notes are freeform Markdown — don't impose rigid sections.

Minimum structure:
```markdown
> {YYYY-MM-DD}

{本文 — 内容に応じて見出し・コードブロック・表・引用を自由に使う}
```

**Do NOT write `# {タイトル}` as the first line of the body.** Obsidian displays the filename as the note's title in the view header automatically, so an H1 in the body produces a visually duplicated title and reduces readability. The user's existing vault notes follow this convention (no leading H1). The body should start directly with the date quote line.

Compute today's date in JST: `date +%Y-%m-%d` via Bash.

Body composition:
- **One learning, simple** → no need for h2 sections. Write it as a coherent short essay or a few labeled bullets.
- **One learning with multiple facets** → start with a **1-2行のリード段落**（タイトル直下、最初の h2 の前）で結論を先に述べる。その後、h2 は **トピック/側面で切る**（例: 仕様 / 補足事実 / 教訓 / 参考）。**時系列構成は避ける**（背景 → 試したこと → 解決、のような narrative arc は使わない）。理由: 未来の自分はストーリーを聞きに来る読者ではなく、事実を引きに来る読者。リードで結論を出し、各論で深掘れる構成のほうが後で再利用しやすい。
- **Multiple related learnings** → use h2 (`##`) per learning. Order by what would matter most to future-self, not chronologically. リード段落で「3点まとめて何の話か」を1行で示すと、ノートを開いた瞬間に内容が分かる。

### Writing rules

- **抽象化して書く** — このセッション固有の文脈をそのまま転記せず、未来の自分が読んで再利用できる形に。「`auth/middleware.go:132` の `JWT.Verify` が...」ではなく「JWT検証で `iat` と `exp` を扱う際の注意点」のように、汎用化できる部分は汎用化する。
- **ただしコードベース固有の知見は固有のまま残す** — 「`internal/foo/` 配下は単体テスト不要」のようなリポジトリ規約は、汎用化すると価値が消える。固有事実はそのまま、抽象化できる学びは抽象化、と書き分ける。
- **言い回しは日本語** — vault 内の既存ノートが日本語中心。技術用語・コード識別子・コマンド名は原文のまま。
- **日付は本文に書く** — ファイル名には日付を入れない（vault の慣習）。ノートを開いたとき鮮度が分かるように、本文の最初の行に `> YYYY-MM-DD` を引用ブロックで置く（H1 タイトルは書かない — 上述の通り Obsidian が自動表示する）。
- **必要なら参考リンク** — 公式ドキュメントURL、PR/コミットへのリンク、関連ファイルパス（このリポジトリ固有の話の場合）は本文末尾に書く。

### Filename and conflict handling

1. Filesystem-unsafe character substitution: replace `/`, `\`, `:`, `*`, `?`, `"`, `<`, `>`, `|` with `-`. Leave Japanese characters, spaces, parentheses, commas, hyphens as-is — they're standard in the vault.
2. Path: `~/Documents/Obsidian/SyncedNotes/{sanitized-title}.md`
3. If the file already exists: append ` (2)`, ` (3)`, ... before `.md` until a free name is found. Do **not** overwrite — the user's vault is their long-term memory.

Use `test -f` via Bash to check existence before deciding the final filename.

### Saving and reporting

Write the note with the `Write` tool. After saving, report concisely:

```
ノートを保存しました: {full path}
```

If a numbered suffix was used due to conflict, call it out:
```
注: 同名ノートが既にあったため "{title} (2).md" として保存しました。
```

---

## Rules

- **明示的依頼があったときのみ動く** — `disable-model-invocation: true` のため自動発動はしない。ユーザーが `/obsidian-learning-note` や明確な日本語/英語のリクエストで呼んだときだけ動作する。
- **保存はユーザー確認後** — Obsidian vault はユーザーの長期記憶。プレビューを必ず見せ、タイトルを確認してから書き込む。確認なしで書き込まない。
- **学びがなければ作らない** — 価値の薄いノートを増やすと検索ノイズになる。「学びなし」を素直に報告して終了する選択肢を必ず提示する。
- **常に新規ノート作成** — 既存ノートへの追記はこのスキルの対象外。タイトル衝突したら必ず別名で保存する。
- **会話の文脈から書く** — diff やコミット履歴を漁る必要はない。ユーザーとのやりとりが学びの源泉であり、コードは結果に過ぎない。
- **1セッション = 1ノート（デフォルト）** — 複数の学びがあっても1つのノートに h2 でまとめる。完全に独立した話題で分けたほうがよさそうな場合のみ、ユーザーに確認した上で複数ノートにする。

---

## Examples

### Example 1: 単一の学び（複数の側面あり）
ユーザー発話: "今の学びをObsidianに保存して"
セッション内容: Claude Code Hooks の `PostToolUse` で環境変数経由でツール情報を取ろうとして空だった話。
プレビュー:
```
1. [ワークフロー] Claude Code Hooks は stdin で JSON を受け取る（環境変数ではない）
```
提案タイトル: "Claude Code Hooks で PostToolUse の値を受け取る方法"
本文構成: 1行目に日付の引用ブロック → **リード段落**で結論（「環境変数ではなく stdin に JSON で渡される」を1-2行）→ `## 仕様`（JSON の構造とコード例）→ `## 環境変数として渡されるもの`（補足）→ `## 教訓`（一般化）→ `## 参考`。物語順（背景→試行→解決）ではなく、トピック/側面で切る。H1 は書かない（Obsidian がファイル名から自動表示）。

### Example 2: 複数の学び → 1ノートにまとめる
ユーザー発話: "今日のセッションの学びまとめて"
セッション内容: `difit` の使い方、zsh history 設定改善、`fzf --preview` 連携の3点。
プレビュー:
```
1. [ツール] difit でローカル差分を Web UI でレビューできる
2. [ワークフロー] zsh history を強化する設定（HIST_IGNORE_DUPS 等）
3. [ツール] fzf の --preview で grep プレビュー表示
```
提案タイトル: "ターミナル周りの改善メモ（difit / zsh history / fzf）"
本文構成: h2 で3セクション。

### Example 3: 引数で観点を絞る
ユーザー発話: "/obsidian-learning-note Hooksの挙動にフォーカス"
セッション内容: Hooks の話と zsh history の話の両方があった。
動作: Hooks に関する学びだけ抽出し、zsh history の話は意図的にスキップする旨をプレビューに明記。

### Example 4: 学びが見つからない
ユーザー発話: "今の学びを保存"
セッション内容: ファイル名変更とコミットのみで、新規の発見なし。
動作:
```
今回のセッションには、新しい学びと呼べる発見が見当たりませんでした。
```
AskUserQuestion で「手動で内容を指定する / キャンセル」を提示。

---

## Troubleshooting

### vault のパスが違う / 存在しない
`test -d ~/Documents/Obsidian/SyncedNotes/` で確認。存在しない場合はユーザーに正しいパスを訊いてから保存する（勝手にディレクトリを作らない — vault 設定ミスの可能性がある）。

### 同名ノートが既にある
番号サフィックス（` (2)`, ` (3)`, ...）で衝突回避し、保存後にその旨を明記。
