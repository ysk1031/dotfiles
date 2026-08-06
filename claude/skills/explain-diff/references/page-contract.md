# Page contract

What every explainer page must be, whichever writer produces it. Read this before writing anything.

## The scaffold does the drawing

Copy `assets/page-template.html` (its path is in your prompt) to the output path, then replace each `FILL` block. Do not rewrite its CSS or its script: the diff-stat bars are computed from the `data-add` / `data-del` numbers you put on each row, and the quiz behaviour is wired from `data-correct`. Hand-drawing either of those is how they end up inconsistent with the numbers they claim to show. Add styles only for something the scaffold genuinely lacks.

## Provenance — the rule that matters most

Every factual statement on the page is one of three things, and the reader must be able to tell which:

1. **Read in the diff or the surrounding code.** Never type a code quote. Name the file and the line ranges in an empty element and let the embedder fill it:

   ```
   <pre data-quote="claude/hooks/before-git.sh" data-lines="25-26,33-34"></pre>
   ```

   Add `data-rev="<sha>"` when the lines must come from a revision rather than the working tree. The elision marker between ranges and its skipped-line count are computed for you. This exists because you cannot copy: every quote you write out is regenerated from context, and regeneration silently merges non-contiguous lines and drops what sat between them — measured twice on this skill, in independent runs. A quote you did not type cannot drift from the file.

   **Numbers describing the change are computed, not written.** Per-file additions and deletions come from the `data-add`/`data-del` attributes; elided-line counts come from the embedder. If a sentence needs some other number, show the command that produced it rather than counting by eye.
2. **Observed by running something.** Paste the transcript verbatim, as the command actually printed it. If you reformat it for readability, say so in the same breath. Never present output you did not see as though you ran it.

   **Where you describe behaviour you did not run, say that you did not run it.** This holds whether you were told not to execute anything or simply chose not to chase a particular path: 「動作は未実行で、コードを読んだ範囲の記述」 in the risks section costs one line and stops a reader from taking a reading for a test. Where running something would have settled a question and you didn't, say what you would have run and what it would have told you.
3. **Your inference.** A rationale that appears nowhere in the code, the comments, or the commit messages is your reading, not a fact. Put it in a `<div class="note infer">` callout, which labels itself as unwritten in the code, and say what would confirm it.

**Every claim about why the code is the way it is, or about how it behaves, carries its source** — a `file:line`, the commit message, or a command whose output the page shows. Asking you to notice which of your own statements are secretly inferences does not work; you assert them precisely because you believe them, and a measured page confidently described a boundary condition that did not exist. Requiring a citation turns that into something checkable: anything you cannot cite is an inference by definition, and goes in the callout.

You are asked to work out intent for yourself, which means you will infer a lot. That is wanted. Presenting an inference as settled fact is not.

**Citing a commit message is allowed and is not narrating the journey.** "The commit message states this was rejected for reason X" is a legitimate source. What you must not do is walk the reader through the sequence of commits, the detours, or what was tried and abandoned. The page explains two endpoints, base and head; the road between them is not part of it.

## Sections

The scaffold fixes the order. What belongs in each:

1. **Metadata** — generation date, branch, commit range, per-file numbers. Also set the `diff-range` meta tag; update mode reads it to tell whether the page has gone stale.
2. **Table of contents** — already wired to the section ids.
3. **背景** — the existing system this change touches, researched by exploring the surrounding code. Two layers: a collapsible deep background for a reader with no prior knowledge, then the narrower background that bears directly on the change.
4. **この変更の考え方** — the core idea as its essence rather than its full detail. Lean on small concrete examples, simplified until only the essence shows, and on the scaffold's diagram families. Never title this section 「直感」.
5. **コードを読む** — the changes at a high level, regrouped and reordered so they tell a story, not in filename order. **Every changed file must appear somewhere here.** Trivial ones can be grouped under 「細かい変更」, but nothing is dropped silently: the reader's trust that nothing went unexplained is what makes the page worth reading.
6. **リスクと確認したいこと** — assumptions the implementation makes, untested paths, boundaries where behaviour changes, what a reviewer should look hardest at. If nothing comes to mind, look again before writing 「なし」.
7. **理解度クイズ** — 5 questions, medium difficulty: answerable only by having understood the substance, but not trick questions. At least 2 must probe an edge case, a place where behaviour changes, or somewhere bugs hide. Every choice needs its own explanation, wrong ones included. These explanations are written last, when you are most likely to contradict something you wrote earlier — before you finish, check them against the risks section.

   Mark the right choice with `data-correct="true"` and ignore where it sits: the page shuffles the choices when it loads, so position carries no information either way.

## Style

Japanese body text. Write with flow, so each section follows from the one before. Back every abstract claim with a concrete example. Avoid unexplained loanwords and acronyms, or define them on first use. Reuse the scaffold's diagram families rather than inventing a shape per case; no ASCII art. The page is one self-contained file — no external resources, ever.

## Finishing

Save at the output path you were given. It sits outside the repository and its filename starts with `YYYY-MM-DD-`. Return only that path.
