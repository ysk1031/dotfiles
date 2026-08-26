---
name: trigger-check
description: >-
  Measure whether a skill actually fires when it should, by replaying a file of test prompts through fresh headless `claude` processes and reading the tool calls — never the model's own account of what it did. Use this whenever a skill's description, a CLAUDE.md rule, or a subagent definition has been written or edited and you want evidence before committing, and whenever a skill is suspected of firing at the wrong times or not firing at all. Also use when the user asks 「トリガー検証して」「ちゃんと発動するか測って」「description 直したから確かめたい」 or accepts the standing CLAUDE.md offer to verify triggering after a definition edit. Test prompts live per skill in `claude/skills/<name>/evals/trigger-eval.json`. Do NOT use for measuring the *quality* of what a skill produces once it has fired (that is empirical-prompt-tuning), for optimizing a description's wording via an automated search loop, or for checking whether ordinary source code works.
---

# Trigger Check

## What this measures, and what it does not

One question only: **given this prompt, does the skill fire?** Not whether the output was good, not whether the skill did the right thing afterwards — just whether the routing decision landed where it should. Quality of the produced work belongs to `empirical-prompt-tuning`; keep the two apart.

The answer must come from **fresh `claude -p` processes**, not from the current session. The reason is asymmetric loading: the skill list (name + description) reflects edits immediately, but **CLAUDE.md is snapshotted when a session starts and never re-read** — subagents spawned from this session inherit that stale copy. So a subagent asked to test a CLAUDE.md change holds *the old rules plus the new skill* and behaves correctly without ever needing the skill. That is not a measurement.

Verdicts come from `tool_use` events in `--output-format stream-json`, never from the model saying it used something.

## The test prompt file

Each skill owns its cases at `claude/skills/<name>/evals/trigger-eval.json` — or, for a skill scoped to this repository alone, `.claude/skills/<name>/evals/trigger-eval.json`. Either way it is a flat JSON array. Twenty is the established size: ten that must fire, ten that must not.

```json
[
  {"query": "…", "should_trigger": true},
  {"query": "…", "should_trigger": false,
   "setup": "git checkout -b some-branch && printf '\\n// WIP\\n' >> app/foo.go",
   "prior_turn": "…",
   "expect_text": "…",
   "note": "…"}
]
```

| field | required | meaning |
|---|---|---|
| `query` | yes | the prompt sent to the trial |
| `should_trigger` | yes | what the correct behaviour is |
| `setup` | no | shell run in the trial's working directory first, to create the situation the case assumes |
| `prior_turn` | no | a first turn used only to make the model reach a conclusion; `query` then arrives as turn 2 |
| `expect_text` | no | switches judging from "was the skill called" to "does the reply do this" — see below |
| `max_turns` | no | raises the turn cap for this case alone; a case that has to *do* the task before the behaviour appears needs it, and raising the flag would pay for it on all twenty |
| `note` | no | free text for the human |

**`expect_text` exists because for some skills, calling the skill is the wrong answer.** `second-opinion` says to offer first and run only on consent, so when the user signals doubt the correct behaviour is a sentence — *「別のモデルにも聞いてみますか?」* — and no skill call at all. Scoring those cases by call-or-not marks correct behaviour as failure. With `expect_text` set, a cheap Haiku judge reads the final reply and decides whether it did that thing; wording is free, meaning is what counts. A skill call in such a case is a failure, because the skill acted without asking.

**A case with an `expect_text` has to make the model actually reach the moment being measured.** Written as "add a line to that section", the trial correctly asked which line instead of editing — following the rule that vague instructions get a question, not a guess — and the offer that was supposed to follow the edit never came up. Spell out enough that the work happens.

**Write cases against the skill's own Do NOT clauses.** `explain-diff` excludes changes small enough to say out loud; measured with a 3-file/6-line diff it did not fire 3 times out of 3 — correct behaviour, nearly misdiagnosed as regression. It fired 3 out of 3 on 21 files/760 lines. Give a positive case a target the skill is actually supposed to accept, and where size or kind is part of the rule, measure both ends so the non-firing side is evidence too.

## Running it

**It runs from inside a Claude Code session** — call the script by its `~/.claude` path, exactly as below.

```bash
~/.claude/skills/trigger-check/scripts/run_trigger_eval.py --skill <name> --seed-repo <repo> [--runs 3] [--only 2,7] [--model opus|sonnet] [--jobs 8] [--dry-run]
```

**Pass `--seed-repo`.** Without it each trial starts in a near-empty directory, and a prompt like "explain the diff" has nothing to refer to — so the trial goes looking, finds the real repository and the real `~/.claude`, and spends its turns there. Measured 2026-08-03: 8 of 20 trials escaped that way, which burns the turn budget and makes the result depend on the state of the machine that day. Seeding copies the working tree and `.git` into each trial, so uncommitted work is present and every trial is self-contained. Point it at the repository the prompts talk about. Each copy has its `origin` removed, so a skill whose work needs a remote — opening a PR is the case — hits "remote が無い" and stops before the behaviour being measured; give those cases a `setup` that adds a placeholder origin pointing at a repository that does not exist.

The script owns the parts that used to fail every time — the real `claude` binary path, closed stdin, no `timeout`, broad `--allowedTools`, throwaway per-trial repositories outside its own output directory. Read the header comment before changing any of it; each line there cost a wasted paid batch.

**This costs real money. Show the command and an estimate in chat and get approval before the first run of a session.** `--dry-run` prints the plan and the exact command without spending anything.

### Two stages, not one

1. **All cases, 3 runs.** Cases that agree 3 out of 3 are settled; a fourth run does not change the reading.
2. **Only the split cases, 10 runs** (`--only`). Disagreement is where the information is. One measured case flipped 1 time in 3 — a single run would have been read as a design flaw.

Twenty cases × 10 runs × 2 models is 400 trials and the better part of an hour. Do not do that.

### Model

Measure on **Opus** every time, and let Opus decide pass or fail. Run **Sonnet** only at checkpoints, such as before committing, and read a Sonnet-only drop as *the wording is vague*, not as a failure to fix — deciding whether to act on it is a judgement call each time. Do not pad the description to satisfy Sonnet: the skill list truncates around 1500 characters and the Do NOT clauses, which sit at the end, are the first thing to disappear. Keep descriptions near 1400. **Fable is not measured** — it is used only for design work and second opinions.

### Before and after

Default to measuring **only the edited version**. When wording was added, the goal is met if the fixed version fires; a before/after pair costs twice the time for nothing.

Run a comparison only when the change **removed** something and the question is whether it still works. It has to be sequential: swapping the config directory is impossible here — pointing `HOME` or `CLAUDE_CONFIG_DIR` at a temporary directory fails with `Not logged in` because authentication lives in the keychain and reading it is blocked too, and a script that rewrites the real file is refused by the permission classifier. For a removed CLAUDE.md rule, the workable control arm is putting the deleted text in a project-level CLAUDE.md and running that as a separate arm — discount it slightly, since both wordings then coexist.

## Reading the table

```
idx  期待       試行  発動  pass  測定不能  判定  query
4    呼出+発動  3     3     3     0         安定  explain-diff の description を…
11   呼出+不発  3     1     2     0         割れ  skill-creator の最適化ループで…
```

`判定` is `安定` (every valid trial agreed and passed), `安定(不合格)` (agreed and all failed — a real defect), `割れ` (send it to stage 2), or `測定不能` (nothing valid survived). `発動` counts the trials where the skill fired; `pass` counts the trials that matched what the case expected, so on a case expecting no firing the two move in opposite directions.

Each run clears and re-collects only the trials in its own plan, so the narrow second run shows those cases alone instead of carrying the first run's rows forward. The per-trial columns are documented above `summary.tsv`'s assembly in the script.

**`測定不能` is the column to look at first.** A trial that measured nothing is dropped rather than counted, because counting it produces a wrong diagnosis. Trials are dropped when the case's `setup` failed, so the situation the prompt assumes was never created; when the run exits 127 (wrong `claude` path — every run silently produces an empty transcript that looks like a clean finish); when no result line arrives at all; when a `prior_turn` case produced no answer in turn 1 so there was no conclusion for turn 2 to react to; when the judge returned no verdict on an `expect_text` case; or when a case that expects firing runs out of turns. **Running out of turns is not "did not fire"** — it is the one thing a small cap makes indistinguishable from it. Several of them mean the case needs a bigger cap, or a `setup` that gives the trial something concrete to work with.

A case that expects **no** firing is scored even when the cap runs out, and flagged `turn_capped` in the summary: the trial spent every turn on the work it was asked for and never reached for this skill, which is the observation wanted — but the claim it supports is only "did not fire within the cap", so the flag stays visible. A trial that picks a *different* skill is stopped there and scored the same way, since the prompt has already been routed elsewhere. Leaving those to run produced the opposite of the truth: a trial that correctly chose `empirical-prompt-tuning` in turn 1 worked for three more turns and was then discarded as unmeasurable.

The reported cost excludes trials stopped at the moment of firing; those never reach the API's own accounting. Stopping there is deliberate — the verdict is already known, and letting one run to completion has cost $1.39 and nine minutes.

## After the run

A new or edited skill is not finished until `claude/sync-links.sh` has been run — **a skill with no symlink in `~/.claude/skills/` is invisible to the skill list, so every trial will correctly report that it did not fire.** Check the symlink before believing a zero. A skill under `.claude/skills/` has no symlink by design and is instead visible only when the trial runs inside this repository, so for those, check `--seed-repo` before believing a zero.

Report what the trials did, with the counts and the raw transcript path. Deciding whether a `割れ` result is acceptable is the user's call, not the script's.
