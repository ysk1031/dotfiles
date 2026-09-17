---
name: obsidian-learning-note
description: "Summarize the learnings from the current Claude Code session and save them as a new Markdown note in the user's Obsidian vault at ~/Documents/Obsidian/SyncedNotes/. Invoked explicitly — '/obsidian-learning-note', '今の学びをObsidianに保存して', '学びをノートにして', 'save the learnings to Obsidian'."
allowed-tools: AskUserQuestion, Bash, Write
argument-hint: "[optional: focus or viewpoint hint, e.g. 'Hooksの挙動にフォーカス' / '抽象化レベルを上げて汎用的な学びだけ' / 'codebase固有の知見のみ']"
disable-model-invocation: true
metadata:
  author: ysk1031
  version: 1.1.0
---

# Obsidian Learning Note Skill

Save the learnings from the current session as a single note in the user's Obsidian vault at **~/Documents/Obsidian/SyncedNotes/** (flat — no subfolders). Preserve the insight, not a transcript: future-self should get the takeaway without remembering this session.

---

## Phase 0: Read the optional argument

An argument (e.g. `/obsidian-learning-note Hooksの挙動にフォーカス`) is a focus hint that steers Phase 1 — it can narrow the scope, raise the abstraction level, filter to one category, or set the framing. Drop the learnings that fall outside the hint, and say in the Phase 2 preview what was dropped. If the session holds nothing matching the hint, say so in Phase 2 instead of inventing content. No argument → extract across all categories.

---

## Phase 1: Extract learnings from the conversation

Read the conversation itself, not the diffs or commits — the insight lives in what the user wrestled with.

| Category | What to look for |
|---|---|
| デバッグ / トラブルシューティング | A real stuck-point hit in the session, the root cause, why the fix works. Not "fixed a typo" but "the test failed because X, which surprised me because Y". |
| 新しい技術・ツール・パターン | A library/CLI/pattern encountered or properly understood for the first time. Signs: questions about how it works, surprise at its behavior. |
| コードベース固有の知見 | Repository structure, conventions, gotchas, "where X lives" — what helps future-self navigate this repo faster. |
| ワークフロー / プロセスの改善 | Claude Code usage patterns, command sequences, tricks the user reacted positively to. |

Counts as a learning: something uncertain that the session resolved; a discovery that contradicted an assumption; a non-obvious codebase fact that took effort; a workflow worth repeating.

Does not count: routine task completion, things the user already knew, the mechanics of this skill, restatements of what the code does.

Found nothing? Don't pad — report it honestly in Phase 2.

---

## Phase 2: Confirm with the user

Show topic lines only, not full bodies:

```
今回のセッションから、以下の学びを抽出しました:
1. [{category}] {one-line topic}
2. [{category}] {one-line topic}
```

Then confirm the title with `AskUserQuestion` — question: "このタイトルで保存しますか？（Other で自由入力も可）", header: "Title", options: two title proposals taking different angles, plus "内容を見直したい" (description: "プレビューを修正してから保存").

Title guidance:
- Match the vault style: title-only filenames, Japanese, spaces, parentheses and commas allowed. Existing notes look like `Claude Code - Subagent, Agent Team, Skill の違いについて.md`.
- Make it searchable later: "Claude Code Hooks の PostToolUse で値を受け取る方法" beats "Hooks の学び".
- Several findings → name the unifying theme rather than concatenating topics.
- Propose only titles that survive the filename sanitizing below — no `/`, `:`, `*`, `?`, `"`, `<`, `>`, `|`. Otherwise the saved file no longer matches the title the user approved.

"内容を見直したい" → ask what to change, regenerate the preview, re-confirm. Never write before an explicit title confirmation.

No learnings found → replace the preview with 「今回のセッションには、新しい学びと呼べる発見が見当たりませんでした。」 and offer 「手動で内容を指定する / キャンセル」 via AskUserQuestion. Default to cancel.

---

## Phase 3: Write the note

### Format

```markdown
---
source: claude-code
skill: obsidian-learning-note
generated-at: {YYYY-MM-DD}
---

> {YYYY-MM-DD}

{本文 — 見出し・コードブロック・表・引用を自由に使う}

🤖 Generated with [Claude Code](https://claude.com/claude-code)
```

- Those three frontmatter fields are required and no others — they let the user filter auto-generated notes in Obsidian's Properties view.
- Don't write `# {タイトル}` — Obsidian shows the filename as the title, so an H1 duplicates it. The body starts with the date quote line.
- Always end with the Claude Code footer, on its own line after a blank line.
- Get the date once with `date +%Y-%m-%d` and use it for both `generated-at` and the quote line.

### Body composition

- One learning → no h2 sections. A short coherent piece or a few labeled bullets.
- One learning with several facets → a 1-2 line lead paragraph stating the conclusion, then h2 per facet (name them after the content; 仕様 / 補足 / 教訓 / 参考 are examples, not fixed labels). Split by topic, never chronologically (背景 → 試したこと → 解決 is wrong).
- Several learnings → one note, h2 per learning, ordered by what matters most to future-self. Open with a one-line lead saying what the set is about. Split into separate notes only when the topics are genuinely independent, and only after asking.

### Writing rules

- Frame learnings so future-self can reuse them: 「JWT検証で `iat` と `exp` を扱う際の注意点」 over 「`auth/middleware.go:132` の `JWT.Verify` が...」.
- But keep codebase-specific knowledge specific — 「`internal/foo/` 配下は単体テスト不要」 loses its value if generalized.
- Write in Japanese, with technical terms, identifiers and command names in their original form.
- Put doc URLs, PR/commit links and related file paths at the end of the body — only ones that actually appeared in the session. Never supply a URL from memory.

### Filename and saving

1. Replace `/`, `\`, `:`, `*`, `?`, `"`, `<`, `>`, `|` with `-`. Leave Japanese, spaces, parentheses, commas, hyphens as-is.
2. Path: `~/Documents/Obsidian/SyncedNotes/{sanitized-title}.md`. If the vault directory does not exist (`test -d`), ask the user for the right path — don't create it.
3. `test -f` the path; on collision append ` (2)`, ` (3)`, ... before `.md`. Never overwrite, never append to an existing note.

Write with the `Write` tool, then report `ノートを保存しました: {full path}`, adding 「注: 同名ノートが既にあったため "{title} (2).md" として保存しました。」 when a suffix was used.
