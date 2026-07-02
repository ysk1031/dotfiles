# Lens prompts and reduce rubric

This file holds (1) the four lens subagent prompts used in the map phase, and
(2) the reduce rubric (clustering, scoring, classification) applied afterward.
SKILL.md tells you when to read this.

## Shared output schema (every lens returns this)

Each lens subagent returns **only** a JSON array, no prose. One element per
recurring pattern it finds:

```json
{
  "theme": "short name",
  "what": "the recurring instruction/pattern in 1-2 sentences",
  "destination": "new-skill | claude-md-rule | slash-command | subagent | existing-skill-fix",
  "evidence": [{"session":"sNNN","project":"...","quote":"a real quote from the corpus, <=120 chars"}],
  "distinct_sessions": 3,
  "spans_projects": 2,
  "generalizability": "generalizable | work-specific-sanitize | personal-env",
  "confidence": "high | med | low",
  "note": "ties to an existing skill, or why it's borderline (optional)"
}
```

Rules given to every lens:
- Quotes must be **verbatim** from the corpus. No fabrication.
- Count `distinct_sessions` / `spans_projects` from the index (`session_index.tsv`).
- Take only patterns recurring in **≥2 distinct sessions** (exception: a single
  but forcefully-stated standing preference is allowed for the preference lens).
- Skip one-off domain tasks. Quality over quantity; cap ~12 items.
- Destination is the lens's *proposal*; dedup and final classification happen in reduce.

## Shared preamble (prepend to each lens prompt)

> You analyze Claude Code session history. Goal: surface instruction patterns
> the user repeats, so they can be codified. Inputs (Read the corpus fully —
> it's worth it):
> - Corpus: `<CORPUS_PATH>` — human turns only, grouped per session. Separator
>   `=== SESSION sNNN | project: <proj> ===`, each `  - <turn>` is one turn.
> - Index: `<INDEX_PATH>` — `sNNN <tab> path <tab> project <tab> turn_count <tab> date`.
>   A high count of **single-turn** sessions that repeat near-identical text is
>   likely synthetic eval data, not organic usage — weight it lightly. `sNNN` is an
>   internal handle for citing evidence; the user never sees it — the report cites
>   the verbatim quote + project + date instead (look the date up here).
>
> Existing assets (for the `note`/destination hint; full dedup happens later):
> user custom skills + all plugin/builtin skills available in the session.
> Then output per the shared schema above. Your lens:

## Lens 1 — Workflow / procedure

Recurring **multi-step "how to do X"** instructions the user gives the same way
each time (e.g. "read the handoff doc → explain current changes → propose next
actions"; a fixed verify-before-commit sequence; a set investigation routine).
These are the strongest **new-skill** candidates. Skip one-off domain tasks.

## Lens 2 — Correction / standing preference

Recurring **corrections and standing preferences**: communication style
(plain language, lead with the conclusion, avoid jargon, language), scope
control ("don't run ahead", "just note it", "stop here"), output-format
preferences. These usually point to **CLAUDE.md rules** or an existing-skill
defect — "the same correction, repeatedly" = a missing rule. A strong standing
preference counts even from one forceful instance.

## Lens 3 — Task-type / kickoff

The **kinds of tasks** the user repeatedly starts (look at the first few turns
of each session) and recurring domain operations. **Always reflect work-specificity
in `generalizability`** (work-specific-sanitize vs personal-env vs generalizable). A
generalizable "shape" → new-skill/subagent; non-generalizable domain grind → don't propose.

## Lens 4 — Tooling / integration / deliverables

Recurring **external tool & artifact** operations: gh/PR, code review, notes,
daily/weekly reports, design/handoff docs, git worktree, eval/lint harnesses,
repeated command sequences. Propose slash-command or skill. Things already
covered by an existing skill → `existing-skill-fix` or note the skill name.

---

# Reduce rubric (applied after all lenses return)

You (the orchestrator) run this in the main context.

### 1. Cluster across lenses
Merge findings that describe the same underlying pattern (the lenses overlap by
design — convergence across ≥3 lenses is a strong confidence signal; say so).

### 2. Correct the counts before trusting them
- **Worktree re-entry**: the same task re-entered across git worktrees inflates
  `distinct_sessions`. Name-merge sessions that open with near-identical task
  statements or reference the same handoff doc; count the *task* once.
- **Non-organic sessions**: discount clusters whose evidence is dominated by
  single-turn, near-duplicate sessions (skill-creator/trigger eval fixtures,
  often `(home)`-rooted). Use `turn_count` in the index to spot them.
- State both corrections in the report's methodology section so counts are trusted.

### 3. Dedup against the full skill inventory and persistent memory
The dedup baseline is **every skill available in your current session** — you
already see the `available_skills` list in context. Also scan `~/.claude/skills/*/SKILL.md`
and plugin skills. If a pattern is already covered, reclassify it as
`existing-skill-fix` (if the existing skill underperforms) or drop it (if fully covered).

Then cross-check the user's **persistent memory**: enumerate every
`~/.claude/projects/*/memory/` directory, read each `MEMORY.md` index, and open
the entries that plausibly match a candidate (the total corpus is tens of small
files — read it in the main context, don't fan out). Memory is a
**corroboration and dedup source, never additive evidence**: memories were
distilled from the same past sessions the transcripts come from, so a matching
memory must NOT raise `distinct_sessions` or the repetition score. Use a match
three ways:
- A matching `feedback`/`project` memory **corroborates** the candidate — note
  it in the report as independent-looking but non-additive support.
- If the pattern is fully handled by an existing memory **and** the corpus shows
  no recurrence after that memory was written, drop the candidate as covered.
- If a memory exists **yet the corpus still shows the user repeating the same
  correction afterwards**, recall isn't sticking — classify as `memory-promote`.

### 4. Classify into one of four destinations
In Claude Code, **a slash command and a skill are the same mechanism** (custom
commands were merged into skills). So `new-skill` vs `slash-command` is not "which
kind of artifact" but a single skill destination with an **invocation mode**: keep
both labels — they carry useful intent — but the real question is *should the model
auto-trigger it, and does it bundle files?*
- **new-skill** — a stable, repeated *procedure* worth packaging that the model
  should be able to **auto-invoke** (carries a real `description`). Default home:
  a **user-level skill** in the user's `claude/skills/` (project-independent),
  *unless* it is work-specific (then a **project-level skill** in that repo's `.claude/skills/`).
- **slash-command** — the **manual-only** flavor of the same artifact: a skill
  with `disable-model-invocation: true` (or a lightweight `.claude/commands/*.md`
  file). Pick this over `new-skill` when the model should *not* decide to run it —
  short canned invocations and side-effecting actions (deploy/commit/send) the user
  fires deliberately.
- **claude-md-rule** — a standing preference/correction. The same correction
  repeated is this, not a skill. user-level vs project-level CLAUDE.md.
- **subagent** — a heavy, self-contained research/analysis routine. (Also
  expressible as a forked skill via `context: fork` + `agent:`; propose a real
  `.claude/agents/` subagent when it needs its own system prompt / tool allowlist / model.)
- (**existing-skill-fix** — a defect/gap in a skill that already exists.)
- (**memory-promote** — the pattern already lives in a persistent-memory file but
  transcripts show corrections continuing after it was saved. Memory relies on
  recall and only fires per-project; a CLAUDE.md rule is always loaded. Propose
  promoting the memory's content to a user-level or project-level CLAUDE.md rule,
  and pruning the memory once promoted.)

### 5. Score each candidate on 5 axes (low / med / high)
- **Repetition** — how many distinct sessions/days (after correction in step 2).
- **Stability** — is the *procedure* the same each time, or does it vary? (varies → not skill-able).
- **Per-use cost** — how much the user re-explains each time (= the pain removed).
- **Coverage gap** — not already handled by any available skill/command/subagent.
- **Generalizability** — can it be abstracted from work-specific secrets? (also drives placement).

Priority = the product of these, not raw frequency. A frequent-but-trivial or
frequent-but-already-covered pattern is low priority.

### 6. Flag generalizability per candidate
`generalizable` (no work-specific secrets; works anywhere → fits a **user-level
skill**) / `work-specific-sanitize` (belongs in the work repo; sanitize before
extracting → a **project-level skill**) / `personal-env` (machine/setup-specific).
Whether a repo is public or private is orthogonal and irrelevant here — that only
matters for the report's own leak-guard. The skill never decides final placement;
it surfaces the flag so the user chooses later.
