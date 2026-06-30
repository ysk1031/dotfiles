---
name: skill-scout
description: >-
  Mine the user's own recent Claude Code session transcripts to surface what is
  worth codifying, and route each finding to the right home — an Agent Skill, a
  CLAUDE.md rule, a slash command, or a subagent. Every candidate is ranked by a
  value score, backed by quoted evidence, and tagged with a 4-way destination and
  a publishability flag; expect most findings to land as CLAUDE.md rules, not new
  skills (the most-repeated thing is usually a correction). Produces a candidate
  report only — it never auto-creates anything; the user decides what to build,
  then hands each pick to its tool (skill-creator for skills, CLAUDE.md edits for
  rules, etc.). Fire proactively whenever the user wants to discover or extract
  reusable patterns from how they actually work, even if they don't say the word
  "skill", e.g.: 「最近のセッションから繰り返してる指示を棚卸しして」「自分の作業から
  仕組み化できるものを探して」「何を CLAUDE.md ルールにすべき？」「よくやってる手順を
  skill か slash command にできない？」「最近の会話から自動化できそうなものある？」
  「skill 候補をレコメンドして」「extract reusable patterns from my sessions」「what
  should I turn into a skill, a CLAUDE.md rule, or a slash command」. Also fire when
  the user reflects that they keep giving the same instruction/correction and
  wonders if it should be codified. Do NOT fire for: creating or editing one
  specific, already-named skill (use skill-creator); writing CLAUDE.md content
  directly (claude-md tooling); activity/work reports such as 分報・週報
  (daily-report/weekly-report); or analyzing a codebase rather than the user's own
  session history.
---

# Skill Scout

## What this does and why

Surfaces, from the user's *own* recent Claude Code sessions, the instructions
and procedures they repeat often enough to be worth codifying. The output is a
**candidate report**, not new skills — extraction is a separate, human-gated step.

The guiding principle (settled with the user): **frequency alone is a weak
signal.** The most-repeated thing is often a *correction* the user keeps giving,
which means a missing CLAUDE.md rule, not a new skill. So every candidate is
sorted into one of four destinations and scored on five axes — never ranked by
raw count. Expect the headline finding to be "most frequent pain → CLAUDE.md
rules; genuine new-skill candidates are fewer." That's the point of classifying.

## Hard constraints (read before running)

- **Report only.** Never create a skill, write a CLAUDE.md, or commit anything.
  End at the report and hand off to skill-creator for whatever the user picks.
- **The final report is written to the current working directory** (the project
  root where the skill was invoked) as `skill_candidates_report_<YYYY-MM-DD>.{md,html}`,
  so it persists and is easy to find. Only the *intermediate* corpus files stay
  in the session scratchpad. The report quotes work-repo content, so after
  writing it, tell the user its path and that it is **not** auto-committed; if the
  cwd is a shared/public repo, suggest adding `skill_candidates_report_*` to
  `.gitignore` (covers both extensions).
- **No headless `claude -p`.** It 401s in this environment. All analysis runs
  through in-session subagents (the Agent tool). This is why the pipeline is a
  subagent map-reduce, not a script that shells out to a model.
- **Analyze the user's sessions, including work repos** (the user opted in), but
  keep the publishability flag honest so work-specific patterns aren't proposed
  for public skills.

## Pipeline

### 1. Build the corpus
Run the bundled script into the session scratchpad (default window 30 days; the
user may pass another, or restrict repos):

```bash
bash <skill-dir>/scripts/collect_corpus.sh 30 "<scratchpad-dir>"
```

It enumerates human-facing sessions (excluding subagent transcripts and the
skill-creator plugin cache), extracts only human-authored turns in a single fast
jq pass, and writes `corpus.txt` (turns grouped by session) plus
`session_index.tsv` (`sNNN <tab> path <tab> project <tab> turn_count`). It prints
the session count, turn count, and corpus size — note the size for step 2.

### 2. Choose a strategy by corpus size
- **Small (≲ 250KB / ~60K tokens)** — *multi-lens sweep*: each of the four lenses
  reads the **whole** corpus. Best quality: every lens sees every repetition, so
  within- vs cross-session repetition is never split. (A 14-day window was ~196KB.)
- **Large (≳ 250KB)** — the whole corpus won't fit comfortably per subagent.
  Batch sessions **by project** (map: each batch-subagent applies all four lenses
  to its batch and returns the shared schema), then in reduce do an extra
  cross-cutting pass to catch patterns that span batches. `log`/note that you
  batched so coverage isn't silently capped.

### 3. Fan out the lens subagents (map)
Read `references/lenses.md` for the four lens prompts, the shared output schema,
and the per-lens framing. Spawn the lenses **in parallel**, substituting the real
`corpus.txt` / `session_index.tsv` paths into each prompt. Each returns a JSON
array of candidate patterns with quoted evidence and a proposed destination.

### 4. Reduce (you, in the main context)
Follow the reduce rubric in `references/lenses.md`:
1. Cluster findings across lenses (convergence across ≥3 lenses = high confidence).
2. **Correct the counts**: name-merge worktree re-entries; discount non-organic
   single-turn near-duplicate sessions (eval fixtures). Record both in the report.
3. Dedup against the **full skill inventory available in your current session**
   (you already see `available_skills`; also scan `~/.claude/skills` + plugins).
4. Classify into new-skill / claude-md-rule / slash-command / subagent /
   existing-skill-fix.
5. Score each on the 5 axes (repetition, stability, per-use cost, coverage gap,
   generalizability); priority = their product, not raw frequency.
6. Flag generalizability (generalizable / work-specific-sanitize / personal-env) —
   which also implies user-level vs project-level placement.

### 5. Write the report
Author the report as **markdown** using `references/report_template.md` — markdown is
the canonical, editable source (HTML is just a rendering of it). Keep quotes verbatim;
state the count corrections in the methodology section so the numbers are trustworthy.

**Output format** — honor what the user asked for, defaulting to `md`. Targets are the
**current working directory** (the project root where the skill was invoked), not the
scratchpad, so they persist for the user:
- **`md`** (default): write `./skill_candidates_report_<YYYY-MM-DD>.md`.
- **`html`**: write the markdown to the scratchpad as the conversion source, then emit
  only the `.html` to the cwd via the bundled converter.
- **`both`**: write the `.md` to the cwd (as in `md`), then also convert it to `.html`.

The converter is dependency-free (Python stdlib only) and emits a self-contained HTML
(inlined CSS, no external requests, GFM `:--:` column alignment honored):
```bash
python3 <skill-dir>/scripts/md2html.py <source>.md ./skill_candidates_report_<YYYY-MM-DD>.html "Skill候補レポート <YYYY-MM-DD>"
```

### 6. Present and stop
Summarize in chat: the validated headline, the shortlist table, your recommended
order of action, and the per-candidate "skill-ify or not" decisions to discuss.
State the report's path(s) and the not-auto-committed / gitignore reminder above.
Then **stop** — don't build anything. When the user picks candidates, route each
to its destination (skill-creator for skills; CLAUDE.md edits; etc.), deciding
placement (a user-level skill in `claude/skills/` vs a project-level skill in the relevant repo) at that point.

## Notes
- The window is a knob: 14 days over-weights whatever single project dominated
  that fortnight; 30+ days surfaces more cross-project, generalizable patterns.
- This skill's own report-generation sessions will appear in future corpora as
  low-signal noise; the reduce's non-organic discounting handles them.
