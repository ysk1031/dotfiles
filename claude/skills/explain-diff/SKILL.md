---
name: explain-diff
description: >-
  Generates a self-contained HTML explainer page, written in Japanese, that helps a human deeply understand a code change (a working-tree diff, a branch, a commit range, or a PR). Structure: metadata → background → intuition → code walkthrough → risks and open questions → an interactive comprehension quiz. The explanation is written from scratch by a subagent that receives only the diff, so the implementing session's own assumptions and blind spots don't leak into it. A second subagent then verifies coverage (every changed file is mentioned) and accuracy (claims and quiz answers match the diff). Triggers on: "この変更を解説して", "この PR / diff / ブランチを理解したい", "変更内容の解説ページを作って", "explain this diff/PR", "何が変わったのかちゃんと理解したい", or any request whose goal is understanding a change rather than judging it. Proactively suggest this before a user reviews/approves an AI-implemented change. Do NOT use for: bug-hunting code review (code-review), judging whether review comments are worth acting on (review-triage), writing commit messages or PR descriptions (commit / pr), or a change small enough to explain in a sentence out loud.
---

# Explain Diff

## Purpose

AI can write code faster than a human can understand it, so understanding — not code generation — is the bottleneck now. This skill produces an explainer page a reader can actually read and check their understanding against, so the user reviews or merges a change only after genuinely understanding it. It's not a summary: it builds background, then intuition, then closes with a quiz, specifically to prevent the feeling of having understood without the substance of it.

## Overview

1. Identify the target diff and record its metadata
2. Generate the explainer HTML — written by a **subagent that receives only the diff**
3. Verify — a second subagent checks coverage, accuracy, and the quiz
4. Fix and hand off

### Step 1: Identify the target diff and record metadata

If the target isn't stated, infer it in this order:

- uncommitted changes exist in the working tree → those changes
- working tree is clean → diff between the current branch and main (or the repo's default branch)
- a PR number or URL was given → fetch with `gh pr diff <number>` / `gh pr view <number>`

Once decided, gather the metadata that goes at the top of the page:

```bash
git branch --show-current
git rev-parse --short HEAD        # for a commit range, both base and head hashes
git diff --stat <target>          # changed files and size
```

This metadata answers "which snapshot of the code does this explanation describe?" A branch keeps moving after the page is generated, so the page silently goes stale without a recorded coordinate — always keep one.

### Step 2: Generate the explanation (blind subagent)

Have a subagent, launched via the Agent tool, write the explanation. Two reasons:

- **Cutting off inherited assumptions**: if the current session is the one that implemented this change, writing the explanation in the same context carries over its blind spots and assumptions unchanged. Having a subagent write from the diff and the repo alone makes it an independent reader's account instead.
- **Keeping the main context clean**: the explainer HTML is large. Delegating keeps it out of the main conversation even when you didn't implement the change yourself.

**Do not put your own summary of the change, its intent, or the conversation history into the subagent's prompt.** Doing so destroys the independence this step exists for, and the delegation becomes pointless. Only pass facts mechanically obtained from git (branch name, hashes, how to get the diff). The subagent reads intent for itself from the diff, the surrounding code, and commit messages.

```
Agent(
  subagent_type: "general-purpose",
  description: "Generate diff explainer page",
  prompt: <template below>
)
```

Prompt template:

```
Write a code-change explainer page (self-contained HTML), in Japanese.

- Repository: <absolute path>
- Target change: <how to get the diff, e.g. `git diff main...feature-x` / `gh pr diff 123`>
- Metadata to embed at the top of the page: generated on <YYYY-MM-DD> / branch <name> / commit range <base...head hashes> / diff --stat summary
- Output path: /tmp/<YYYY-MM-DD>-explanation-<short-english-slug>.html

Follow the "Page structure and style" section of <absolute path to this SKILL.md> for the page's structure and style (follow only that section — ignore the rest of that file's workflow steps).

Read the change's intent and merit yourself, from the diff, the surrounding code, and commit messages. When done, return only the output file's path.
```

### Step 3: Verify (a separate subagent)

Have a second subagent check the generated HTML against the actual diff. Explanations can be "plausible but wrong," and a wrong quiz answer is worse than no quiz — it actively undermines the comprehension check. Don't skip this step.

Verification prompt template:

```
Verify this code-change explainer HTML against the actual diff.

- Explainer HTML: <path>
- Repository: <absolute path>
- Target change: <how to get the diff — same as Step 2>

Checks:
a. Coverage — does every file in `git diff --stat` appear somewhere in the "code walkthrough" section? If one is intentionally skipped, is it listed under "minor changes"? Is anything silently missing?
b. Accuracy — do the claims, diagrams, and code quotes match the diff and the actual code? Any function names that don't exist, or behavior described incorrectly?
c. Quiz — is the choice marked correct actually correct, given the diff? Are the explanations for the incorrect choices also correct?
d. Formatting — does every code block's CSS include white-space: pre or pre-wrap so line breaks don't collapse? Do the table-of-contents links work?

Return a list of issues as "location / problem / suggested fix". If there are none, say so.
```

When issues come back, the main session fixes the HTML with Edit. If the explanation is fundamentally broken — e.g. riddled with factual errors — redo Step 2's generation, attaching the issue list.

### Step 4: Hand off

1. Open the file in a browser (`open <file path>`)
2. Report to the user: the file path, a metadata summary (target branch, commit range, size of the change), and a summary of anything the verification step fixed
3. Encourage taking the quiz to confirm understanding. The intended use is: read the explanation, pass the quiz, then move on to review or merge

## Page structure and style

### Structure (one long page, in this order)

1. **Metadata block** (top): generation date, branch, commit-range hashes, `git diff --stat` summary. States plainly which snapshot this explains.
2. **Table of contents**: in-page links to each section.
3. **Background**: explain the existing system relevant to this change, researched by broadly exploring the surrounding code. The reader's prior knowledge is unknown, so use two layers — deep background for beginners (collapsible, so a knowledgeable reader can skip it) and a narrower background directly relevant to the change.
4. **Intuition**: explain the core idea behind the change as its essence, not its full detail. Lean heavily on small concrete examples (simplified just enough that only the essence is visible) and diagrams. On the page itself, title this section with natural Japanese such as 「この変更の考え方」— do **not** translate "Intuition" literally as 「直感」, which reads awkwardly as a Japanese heading.
5. **Code walkthrough**: walk through the changes at a high level, regrouped and reordered for readability — not alphabetical by filename, but in whatever order tells the story most naturally. **Every changed file must appear somewhere in this section.** Trivial changes (typo fixes, import reordering) don't need individual explanation and can be grouped under "minor changes," but never silently dropped. The reader's trust that "nothing went unexplained" is the whole basis of this page's value.
6. **Risks and open questions**: assumptions the implementation is making, untested code paths, boundary conditions where behavior changes, spots a human reviewer should pay special attention to. This section answers "is this actually okay?" — the question that comes after "I understood it." If nothing comes to mind, actually double-check before writing "none."
7. **Comprehension quiz**: 5 multiple-choice questions, medium difficulty — hard enough that answering requires having understood the substance, but not gotchas. **At least 2 of the 5 should probe an edge case, a spot where behavior changes, or a place bugs tend to hide** (so the quiz doubles as a review nudge, not just a comprehension check). Clicking a choice shows correct/incorrect plus an explanation for every choice. Write the JavaScript inline.

### Style

- A single self-contained HTML file (CSS and JavaScript fully inline). No external resources.
- One long page with section headings. Don't use tabs for the top-level structure.
- Basic responsive styling so it's readable on a phone.
- Body text is in Japanese. Write with clarity and flow, with smooth transitions between sections. Back every abstract claim with a concrete example. Avoid unexplained loanwords/jargon/acronyms; define them briefly on first use if you must use them.
- Pick a small number of diagram "families" and reuse them throughout, rather than inventing a new diagram shape for every case. Useful families: a heavily simplified sketch of the app's UI (for UI changes), a diagram of data flow between components (always include example data). No ASCII art — draw with HTML and CSS.
- Use callouts (boxed notes) for key concepts, definitions, and edge cases.
- Code blocks use `<pre>` tags. If you style a custom div instead, its CSS must include `white-space: pre-wrap` (otherwise the browser collapses line breaks into one line). Check every code block's CSS before saving.
- Save the file outside the repository, with a filename that always starts with `YYYY-MM-DD-` (keeps files time-sorted and out of version control). Example: `/tmp/2026-07-07-explanation-add-retry-logic.html`
