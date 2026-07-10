---
name: retrospective
description: >-
  End-of-session interactive retrospective on the human-AI collaboration process itself — NOT on the code. Interview the user about how the session felt to work through (fatigue, confidence, ownership, talking past each other, rework), ground every question in concrete moments from THIS session while they are still fresh, decompose the pain into its structural cause, then propose improvements and route each one to the right home: a CLAUDE.md rule (always-on reflex), a skill (heavy on-demand procedure), or a memory entry (non-derivable fact) — applying only what the user approves. Default is lightweight: 2-3 questions, 5-10 minutes; go deep only when the user signals or a big structural finding surfaces. Fire when the user says 「振り返りしよう」「振り返りやる？」「ふりかえり」「レトロ」「今日の進め方どうだった？」「協働どうだった？」「今回のやり方で改善できるところある？」 or asks to reflect on how the session went / how we worked together. Also fire PROACTIVELY (offer in one line, max once per session, don't push if declined) right after a PR is created or when the user signals the session is wrapping up (「今日はここまで」「一区切り」など). Do NOT fire for: reviewing the code/diff itself (code-review); preserving work state for the next session (session-handoff); work reports like 分報・週報 (daily-report/weekly-report); mining past transcripts for skill candidates (skill-scout); saving technical learnings to Obsidian (the user asks for that explicitly, obsidian-learning-note); or team-meeting retrospectives like sprint KPT about human teammates.
---

# Retrospective

## Why this skill exists

Working fast with AI produces a distinct kind of strain — fatigue from reviewing, low confidence in "done" claims, loss of ownership, subtle talking-past-each-other — and its causes are structural, not personal. The catch: the evidence lives in concrete moments of a session ("I was told tests pass but couldn't verify it cheaply"), and those moments fade within days. A weekly retro arrives too late to use them. So this skill runs a short retrospective **per session**, while the examples are still hot, and converts findings into durable improvements to the collaboration system: CLAUDE.md rules, skills, and memory entries.

The deliverable is **approved changes to the system**, not a report. A retro that produces only prose has failed; a retro that honestly finds nothing and ends in two minutes has succeeded.

## Mode: quick by default

- **Quick (default)**: 2-3 questions, 5-10 minutes. Suits the per-session cadence — heavier and the user stops doing it.
- **Deep-dive**: only when the user asks for it, or when an answer exposes a structural problem worth excavating. Announce the switch ("これは深掘りする価値がありそうです。少し続けていいですか？") instead of silently ballooning.

## Procedure

### 1. Present session facts first — evidence before questions

Before asking anything, summarize this session's collaboration in a few lines: what was built, and the notable **interaction events** — rework, repeated corrections on the same theme, moments the user expressed doubt or frustration, long waits, misunderstandings that took extra turns to clear. Quote or paraphrase the actual moment ("『本当にテストしたのか』と確認が入った場面がありました"). This grounds the interview in real events instead of vague vibes, and lets the user correct your reading of the session before you build questions on it.

If the session was genuinely smooth, say so and offer to stop: a forced retro trains the user to skip retros.

### 2. Interview — one question at a time, follow the pain

Pick the 2-3 most promising questions based on the facts above — do not run the whole list. Ask **one at a time**, wait for the answer, and let the answer steer the next question (dig where it hurts; move on where it doesn't). Asking multiple questions at once is bewildering and yields shallow answers.

Question lenses to draw from:

- **疲労・認知負荷**: このセッションで一番疲れた・重かった場面はどこでしたか？
- **自信・検証**: 私の「できました・確認しました」を、安心して信じられましたか？信じにくかったのはどこ？
- **オーナーシップ・楽しさ**: 「おいしい部分を取られた」「自分の理解が置いていかれた」と感じた箇所はありましたか？
- **すれ違い・手戻り**: 意図が伝わらず言い直した場面はどこでしたか？何が最初の指示から抜けていた？
- **ルールの効き目**: 既存の CLAUDE.md ルールやスキルで、今日守られていなかった・空振りだったものはありましたか？

### 3. Decompose the pain into structure

Don't stop at the surface complaint. Find the mechanism behind it — e.g. "レビューが疲れる" is usually not speed itself but **decisions buried in code and revealed late**, and "自信が持てない" is usually **claims without cheap verification**. Present the decomposition with a concrete example from this session in the user's preferred contrast form: the actual moment → how it played out today → how it would play out under the proposed change.

### 4. Propose countermeasures and route each one

For each finding, propose a countermeasure and its **home**, using this criterion:

| Home | Criterion |
|---|---|
| CLAUDE.md rule | An always-on reflex/default that must fire without being asked (e.g. "show evidence", "ask back when intent is unclear"). Skills fail here because invoking the skill is itself forgotten. |
| Skill | A heavy procedure/template invoked at a specific moment. Keeping it resident in CLAUDE.md wastes context and gets stale; loading it fresh at invocation is followed more faithfully. |
| Memory | A fact not derivable from code/git (environment facts, user preferences with their why), or a pointer to a durable doc. |
| No change | A genuine one-off. Naming it as such is a valid outcome — every rule added lowers compliance of all the others. |

Prefer **editing or merging an existing rule** over adding a new one; check the current CLAUDE.md/memory for overlap first. Do not route anything to Obsidian — the user saves learnings there explicitly, on their own initiative.

Present the proposals as a short list and get approval **per item**, not as a bundle.

### 5. Apply approved items only — and show the result

Write only what was approved, then show the actual diff or the written lines (evidence, not a claim of "updated"). If a proposed rule was rejected, don't smuggle it in elsewhere.

## Proactive offering etiquette

When offering unprompted (after a PR lands, or the user signals wrapping up): one line, e.g. 「軽く振り返りやりますか？（2〜3問・5分程度）」. **Max once per session.** If declined or ignored, drop it entirely — repeated offers are exactly the kind of friction this skill exists to remove.
