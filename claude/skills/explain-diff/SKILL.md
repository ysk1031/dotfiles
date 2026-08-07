---
name: explain-diff
description: >-
  Generates a self-contained HTML explainer page, written in Japanese, that helps a human deeply understand a code change (a working-tree diff, a branch, a commit range, or a PR). Triggers on: "この変更を解説して", "この PR / diff / ブランチを理解したい", "explain this diff/PR", "前に作った解説ページを最新のコミットに合わせて更新して", or any request whose goal is understanding a change rather than judging it. Proactively suggest this before a user reviews/approves an AI-implemented change. Do NOT use for: bug-hunting code review, judging whether review comments are worth acting on (review-triage), writing commit messages or PR descriptions (commit / pr), or a change small enough to explain in a sentence out loud.
---

# Explain Diff

## Purpose

This skill produces an explainer page a reader can check their understanding against, so the user reviews or merges a change only after genuinely understanding it. It is not a summary: it builds background, then intuition, then closes with a quiz, specifically to prevent the feeling of having understood without the substance of it.

## Overview

1. Identify the target diff, record its metadata, and decide whether the change is trusted
2. Generate the explainer HTML — written by a subagent that sees only the diff
3. Verify — the `diff-verifier` subagent checks the page against the change
4. Revise through the writer, then hand off

What the page must contain lives in `references/page-contract.md` and the scaffold in `assets/page-template.html`, both read by the writer, not by you. The writer agents pin `model: opus` in their own frontmatter, so the explanation's quality doesn't depend on which model runs the main agent.

### Step 1: Identify the target diff, record metadata, decide trust

If the target isn't stated, infer it in this order:

- uncommitted changes exist in the working tree → those changes
- working tree is clean → diff between the current branch and main (or the repo's default branch)
- a PR number or URL was given → fetch with `gh pr diff <number>` / `gh pr view <number>`

Then record the branch name, the base and head short hashes, and the `git diff --stat` and `--numstat` output. This metadata answers "which snapshot of the code does this explanation describe?" A branch keeps moving after the page is generated, so the page silently goes stale without a recorded coordinate — always keep one.

**Note who wrote the change, because it decides where the writer works.** A change the user did not write gets a checkout of its own, so nothing it carries can reach their working tree. Authorship changes the location, not the depth: the page is grounded in reading and quoting source either way.

For a PR, settle authorship mechanically rather than by guessing:

```
gh pr view <number-or-url> --json author,headRepositoryOwner
gh api user --jq .login
```

**When the change is not the user's own**, keep it away from their working tree:

- Materialise it: `gh pr diff <number-or-url>` and the commit messages (`gh pr view <number-or-url> --json commits`) into files under the scratch directory.
- Give the writer a checkout of its own — `git worktree add --detach <scratch-path> <ref>` — and tell it to do all of its scratch-writing there. Its own working tree stays untouched.
- **After Steps 2–4 finish, run `git status --porcelain` in the real repository.** Anything unexpected is the finding that matters: a change can plant a git hook, a `Makefile`, or an `.envrc` that fires later outside any sandbox, and that write path — not autonomous execution — is the risk worth watching for. Report anything it prints instead of quietly cleaning it up.

**A PR from someone outside the user's own team or company is different in kind.** The writer reads rather than runs, so the ordinary case needs no warning at all. Raise it only if the writer reports back that a question can be settled no other way: say plainly that this would mean executing a stranger's code on this machine, and let the user choose between that and leaving the question open on the page.

**Update mode.** When the user hands you a page generated earlier — a path to one, or 「前に作った解説を更新して」 — read the commit range out of its `diff-range` meta tag and compare it with the current head of the same target. If they match, say the page is still current and stop. If they differ, run Steps 2–4 again over the **full** range (old base → new head) and have the writer overwrite the existing file's path. Do not hand-edit only the part that changed: a later commit can invalidate a claim, a risk, or a quiz answer anywhere on the page, and editing it yourself in the main session throws away the blind independence Step 2 exists for. If the file is gone (pages live in temporary directories the OS clears), say so and generate a fresh one.

### Step 2: Generate the explanation (blind subagent)

**Do not put your own summary of the change, its intent, or the conversation history into the writer's prompt.** Doing so destroys the independence this step exists for, and the delegation becomes pointless. If the current session is the one that implemented this change, writing the explanation in the same context would carry over its blind spots unchanged; the writer reads intent for itself from the diff, the surrounding code, and the commit messages.

Launch the writer chosen in Step 1 via the Agent tool, passing only these mechanically-obtained facts:

- Where the code is: the repository path for the user's own changes, or the materialised diff, commit messages, and detached checkout for someone else's
- How to obtain the diff, e.g. `git diff main...feature-x` / `gh pr diff 123`
- Metadata to embed: generation date, branch name, commit range, per-file insertion and deletion counts

**Pass nothing about what happened after the head commit.** Mentioning that a later commit reverted a file, or that the approach was since abandoned, reads to the writer as licence to discuss it — measured on this skill, that is exactly what happened, and the page narrated events past its own endpoint. If the writer needs a file the working tree no longer has, say only how to read it at that revision (`git show <rev>:<path>`), not why it is missing.
- Output path: `<YYYY-MM-DD>-explanation-<short-english-slug>.html`, outside the repository — in the session's scratchpad directory when the harness gives you one, otherwise `/tmp`
- Absolute paths to `references/page-contract.md` and `assets/page-template.html` in this skill's directory

### Step 2.5: Fill the quotes

Run `scripts/embed_quotes.py <page> --root <repo-or-checkout>` (add `--rev <sha>` when the change's files are not in the working tree). It fills every quote element the writer left from the source files, computing the elision markers and skipped-line counts. You run it, not the writer, so the untrusted path gets the same guarantee without a shell.

A non-zero exit means a quote names a file, revision, or line range that does not exist — send it back to the writer rather than editing the marker yourself.

### Step 3: Verify

Launch `diff-verifier` with the generated HTML path and the same inputs the writer received. Don't skip this step. For someone else's change, point it at the same detached checkout rather than the user's working tree.

### Step 4: Revise through the writer, then hand off

**Send the issue list back to the writer that produced the page** — reply to that same agent so it keeps its investigation context — and have it fix the file. Don't apply the fixes yourself: you are the one participant who never read the change closely, and several kinds of fix (re-running a command to get its real output, deciding whether a claim should be softened or dropped) need what the writer knows.

**One verification pass is the default; a second is the exception you have to earn.** Buy one only when the first pass found a claim that was wrong in *direction* — a monitoring target that was backwards, a duration that came out of the wrong code path, a quiz answer that was simply false. A page that produced one of those has usually produced another. When the first pass turned up only miscounts, unlabelled inferences, and wording, fix them and hand off, saying in the handoff that no second pass ran.

Measured on this skill, a run that spent two full passes found its two reversed conclusions only in the second — which argues for making the first pass hunt for them, not for always buying a second. The verifier is now pointed at exactly that.

**If you do run a second pass, wait for the writer to finish first.** A revision lands as a series of edits, so the first write to the file is the start of the round, not the end of it — check on that signal and the verifier reads a half-revised page and reports fixes as unfixed. Measured on this skill: two of five issues came back as "reworded, not corrected" when both were in fact already corrected in the finished file. Wait for the agent's own completion, then re-check.

Stop after two revision rounds. If issues remain, hand off anyway and list what is still open — an explainer page with three known caveats is more useful than a fourth round. If the page is fundamentally broken instead, throw it away and redo Step 2 with the issue list attached.

Then:

1. **Clean up what the run created.** Remove the scratch checkout with `git worktree remove <scratch-path>`, and delete any ref you fetched only to reach the change (`git branch -D <temp-ref>`). Nothing on the page depends on either surviving: quotes carry `file:line` and were embedded into the HTML at generation time. Leave the repository as you found it — a stale worktree per explained PR is exactly the kind of debris nobody goes back to sweep up. Do this after the `git status --porcelain` check, so anything the change planted is still reported.
2. Open the file in a browser (`open <file path>`)
3. Report the file path, a metadata summary (target branch, commit range, size of the change), anything the verification changed or left open, and whether a second pass ran
4. Encourage taking the quiz to confirm understanding. The intended use is: read the explanation, pass the quiz, then move on to review or merge
