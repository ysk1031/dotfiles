# Page contract

What every explainer page must be, whichever writer produces it. Read this before writing anything.

## The scaffold does the drawing

Copy `assets/page-template.html` (its path is in your prompt) to the output path, then replace each `FILL` block. Copy the file — never reproduce it by writing the page from scratch, or its CSS and script come back from memory slightly wrong. Do not rewrite its CSS or its script: the diff-stat bars are computed from the `data-add` / `data-del` numbers you put on each row, and the quiz behaviour is wired from `data-correct`. Hand-drawing either of those is how they end up inconsistent with the numbers they claim to show. Add styles only for something the scaffold genuinely lacks.

## Provenance — the rule that matters most

Every factual statement on the page is one of three things, and the reader must be able to tell which:

1. **Read in the diff or the surrounding code.** Never type a code quote. Name the file and the line ranges in an empty element and let the embedder fill it:

   ```
   <pre data-quote="claude/hooks/before-git.sh" data-lines="25-26,33-34"></pre>
   ```

   Add `data-rev="<sha>"` when the lines must come from a revision rather than the working tree. The elision marker between ranges and its skipped-line count are computed for you. This exists because you cannot copy: every quote you write out is regenerated from context, and regeneration silently merges non-contiguous lines and drops what sat between them — measured twice on this skill, in independent runs. A quote you did not type cannot drift from the file.

   **A claim about how the code behaved *before* the change needs a base-revision quote** — `data-rev="<base sha>"`, on the same footing as any other. Not symmetry for its own sake: the before/after comparison is the centre of the page, its left-hand column consists entirely of claims about code that is no longer there, and head does not contain the answer. Measured on this skill, a page asserted that the old worker started with a nil logger and quietly logged nothing, when the old constructor in fact returned a live client *alongside* its error — so every log line blocked for over a minute and stalled the whole batch. It is the worst error this skill has produced: a reader would have walked away believing the old code was harmless. It came from describing base without opening base. Read it, quote it, and the error cannot form.

   **This applies inside the quiz too.** An identifier named in passing is fine, but a line of source typed into a choice or an explanation is a quote that matches nothing and that the checker never sees. Measured on this skill: a choice carried `log.Fatalf("create LLM judge log sender failed")` when the real line ends `: %v", err)`. Name the function and say what it does.

   **Numbers describing the change are computed, not written.** Per-file additions and deletions come from the `data-add`/`data-del` attributes; elided-line counts come from the embedder. If a sentence needs some other number, show the command that produced it rather than counting by eye.
2. **Observed by running something.** The page is grounded in reading, so this is the rare case, not the default — see the writer's own definition for when a run is worth it. When you do include one: paste the transcript verbatim, as the command actually printed it; if you reformat it for readability, say so in the same breath; and never present output you did not see as though you ran it. A transcript is one observation under one configuration, not proof, and the page should read that way.

   Reading is the expected source, so it needs no disclaimer — a page whose every paragraph announces that it was not executed just adds noise. The one place to speak up is a question that reading genuinely could not settle: name it in the risks section and say what would settle it.
3. **Your inference.** A rationale that appears nowhere in the code, the comments, or the commit messages is your reading, not a fact. Put it in a `<div class="note infer">` callout, which labels itself as unwritten in the code, and say what would confirm it.

**Every claim about why the code is the way it is, or about how it behaves, carries its source** — a `file:line`, the commit message, or a command whose output the page shows. Asking you to notice which of your own statements are secretly inferences does not work; you assert them precisely because you believe them, and a measured page confidently described a boundary condition that did not exist. Requiring a citation turns that into something checkable: anything you cannot cite is an inference by definition, and goes in the callout.

You are asked to work out intent for yourself, which means you will infer a lot. That is wanted. Presenting an inference as settled fact is not.

**Citing a commit message is allowed and is not narrating the journey.** "The commit message states this was rejected for reason X" is a legitimate source. What you must not do is walk the reader through the sequence of commits, the detours, or what was tried and abandoned. The page explains two endpoints, base and head; the road between them is not part of it.

## The page is a 本論 and a 補足, and the quiz is the seam

Everything up to and including the quiz is 本論 — the part a reader is asked to read. After the quiz comes 補足: コードリーディング, which is where they go when they want to see the code behind a claim, or when a quiz question caught them out. Nobody is asked to read it end to end.

**The test for what belongs in 本論: a reader who read only 本論 must be able to answer every quiz question.** This is what makes 本論 a place you can honestly stop. It also takes the boundary out of your hands — 「本質か詳細か」 is a judgement call you will get wrong, while 「would they still get Q2 right」 is something you can check. Measured on this skill: a page buried its single most counter-intuitive finding — that a constructor cannot fail, so the `log.Fatalf` guarding it never fires — in a code-walkthrough subsection, then quizzed on it. Under this rule that finding moves into 本論, which is where it always belonged.

Putting the quiz at the seam rather than at the end is deliberate: reaching it tells the reader they have finished a whole thing, so they can stop without wondering what they skipped. The 補足 sitting after it is the natural next step for anyone who wants more, not a section they abandoned.

## Sections

The scaffold fixes the order. What belongs in each:

1. **Metadata** — generation date, branch, commit range, per-file numbers. Also set the `diff-range` meta tag; update mode reads it to tell whether the page has gone stale.
2. **Table of contents** — already wired to the section ids.
3. **背景** — the existing system this change touches, researched by exploring the surrounding code. Two layers: a collapsible deep background for a reader with no prior knowledge, then the narrower background that bears directly on the change.

   **Where the change alters behaviour, the old behaviour belongs in the before/after comparison, not here as well.** Measured on this skill: a page spent 800 characters here on how the old synchronous client blocked its caller, then said the same thing again in the left column of the comparison table a section later. Background is what the reader needs in order to follow the change — the system it sits in, the constraint it lives under, the precedent it follows — not a first pass at the change itself.
4. **この変更の考え方** — the core idea, carried by a before/after comparison of one concrete scenario and by the scaffold's diagram families. Never title this section 「直感」. This is where the change is actually explained: the settings, the numbers and the surprises that change how a reader thinks all belong here, not held back for the 補足.
5. **リスクと確認したいこと** — assumptions the implementation makes, untested paths, boundaries where behaviour changes, what a reviewer should look hardest at. If nothing comes to mind, look again before writing 「なし」. Keep it as a list a reader can take in whole; anything that needs a long justification gets its reasoning in the 補足 and a sentence here.
6. **理解度クイズ** — 3 questions, medium difficulty: answerable only by having understood the substance, but not trick questions. At least 1 must probe an edge case, a place where behaviour changes, or somewhere bugs hide. Every choice needs its own explanation, wrong ones included. These explanations are written last, when you are most likely to contradict something you wrote earlier — before you finish, check them against the risks section.

   Mark the right choice with `data-correct="true"` and ignore where it sits: the page shuffles the choices when it loads, so position carries no information either way.

   **Every question must be answerable from 本論 alone.** When you find one that is not, you have located something misfiled — move the fact up, rather than softening the question.
7. **補足: コードリーディング** — where everything above lives in the code, regrouped so it reads as a narrative rather than in filename order. Its job is to show, not to teach again: the reader arrives already knowing what the change does, so a passage here that re-explains the reasoning is one to cut down to the code and a sentence.

   **Spend it on the files where behaviour changes.** Everything else gets one line each in a 「細かい変更」 list, and no quote: a signature that grew a parameter because its caller did, a field renamed on both sides, a record assembled in two functions instead of one with the same keys coming out. Behaviour-preserving follow-on edits are churn even when they touch many lines and many files — the reader needs to know they exist and hold no surprises, not to be walked through them.

   **Every changed file appears somewhere here**, one line or ten. What varies is how much each gets, never whether it is there: the reader's trust that nothing went unexplained is what makes the page worth reading. The metadata table at the top already shows all of them with their line counts, so 本論 does not owe the reader a second inventory.

   This is the one section with no length budget. It is also the one nobody has to read, which is what makes that acceptable — but the rules on quoting and on not repeating yourself still apply.

## One home per fact

Each load-bearing fact is explained once, in the section where the reader first needs it. Everywhere else it is a sentence and a pointer — 「本論で見たとおり発火しない」 — never a second explanation.

Between 本論 and 補足 the division is by job, not by depth: 本論 says what happens and why it matters, 補足 shows the lines that make it so. The 補足 may quote code for something 本論 already explained — that is precisely what it is for — but the moment it starts re-arguing the point, it has become a second telling. Measured on this skill: 「この変更の考え方」 and 「コードを読む」 came out as the same decomposition told twice, once in prose and once against quotes, and together they were 72% of the body.

Measured on this skill: one page established that a constructor cannot return an error, and therefore that the `log.Fatalf` guarding it never fires, in three separate places at full length, then a fourth time across two quiz choices. Nothing in it was wrong. The page was simply a third longer than its own facts required. Restatement is the largest single source of bulk in a page whose content is otherwise sound, and it is invisible while you write, because every passage is locally justified — you are explaining something relevant, in a place it genuinely matters. Only the whole page shows the cost.

**The quiz is exempt.** Its explanations may restate anything the body established: recalling a fact is what that section is for, and a choice explained only by a cross-reference cannot tell a reader why they got it wrong.

## Style

Japanese body text. Write with flow, so each section follows from the one before. Back every abstract claim with a concrete example. Avoid unexplained loanwords and acronyms, or define them on first use. Reuse the scaffold's diagram families rather than inventing a shape per case; no ASCII art. The page is one self-contained file — no external resources, ever.

**Quote what carries the argument, not everything you read.** Every excerpt is a block of code the reader has to parse, so one they could skip without losing the thread is one the page is better without.

**Budgets, because rules that only relocate content are not reductions.** Measured on this skill: a round of trimming cut about a thousand characters from the sections it targeted and the page shrank by nine percent, because the material reappeared in the sections that had no ceiling — including the quiz, which had been exempted from everything and grew by a fifth.

| | budget |
|---|---|
| 本論 (背景 + 考え方 + リスク) | ~3,000 characters, about six minutes |
| quoted lines visible in 本論 without clicking | ~30 |
| 理解度クイズ | ~1,800 characters |
| 補足: コードリーディング | none |

These are targets, not hard limits — but going over one is a signal to cut, not to note the excess and move on. What overflows 本論 goes to the 補足, and what will not fit the 補足's purpose was probably never worth writing. This page competes with the reader simply opening the diff themselves, and it wins on being shorter and better ordered, not on being complete.

**Long evidence belongs behind a `<details>`, not in the reading path.** The provenance rule is satisfied either way — a reader who wants to check you can still open it — but an excerpt sitting inline is one that every reader pays for, including the ones who believed you. Keep inline only what the surrounding sentences walk through line by line; put the rest behind a summary that says what it would show, along with any transcript longer than a few lines and any derivation the argument does not turn on. As a rough budget, the excerpts a reader meets without clicking should total well under a hundred lines.

## Finishing

Save at the output path you were given. It sits outside the repository and its filename starts with `YYYY-MM-DD-`. Return only that path.
