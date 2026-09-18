# Writing trigger-eval cases

Read this when adding or editing cases. The file's location, its JSON shape and the field table are in `SKILL.md`.

**`expect_text` exists because for some skills, calling the skill is the wrong answer.** `second-opinion` says to offer first and run only on consent, so when the user signals doubt the correct behaviour is a sentence — *「別のモデルにも聞いてみますか?」* — and no skill call at all. Scoring those cases by call-or-not marks correct behaviour as failure. With `expect_text` set, a cheap Haiku judge reads the final reply and decides whether it did that thing; wording is free, meaning is what counts. A skill call in such a case is a failure, because the skill acted without asking.

**A case with an `expect_text` has to make the model actually reach the moment being measured.** Written as "add a line to that section", the trial asked which line instead of editing, and the offer that was supposed to follow the edit never came up. Spell out enough that the work happens.

**A `prior_turn` must not itself fire the skill under test.** Once the skill has been called in turn 1 its body is in context, and turn 2 follows the procedure without calling the Skill tool again — the transcript shows the work being done and the verdict reads `no_call`. Measured 2026-09-16 on `second-opinion`: a consent case whose turn 1 also asked for a judgment scored 0 of 3 while every trial consulted the second model; with turn 1 reduced to an explanation and the judgment moved to turn 2, it scored 3 of 3. Put only the setup — the permission, the context — in turn 1, and the first decision point in `query`.

**Don't put an `expect_text` on a case where another skill is the likely answer.** A trial that fires a different skill is stopped there, so no final reply survives for the judge to read and the case scores `測定不能`. Score those by call-or-not.

**Write cases against the skill's own Do NOT clauses.** `explain-diff` excludes changes small enough to say out loud; measured with a 3-file/6-line diff it did not fire 3 times out of 3 — correct behaviour, nearly misdiagnosed as regression. It fired 3 out of 3 on 21 files/760 lines. Give a positive case a target the skill is actually supposed to accept, and where size or kind is part of the rule, measure both ends so the non-firing side is evidence too.
