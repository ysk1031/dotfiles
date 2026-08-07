---
name: crit-annotate
description: >-
  Opens a diff in crit with your own plain-Japanese explanation already attached as inline comments, so the user reads the change with the walkthrough sitting next to each hunk instead of asking for it afterwards. Picks the diff scope (unstaged only / branch vs base / a PR / vs another PR's branch), writes one explanation comment per meaningful hunk, verifies the comments actually landed, and only then opens crit. Triggers on requests that pair crit with an explanation: 「critでセルフレビューしたいです。あなたのコード解説もつけた状態で開けますか？」「critでPRのdiffを開いて、変更説明もコメントとしてつけておいて」「解説コメント付きでcritを開いて」. Do NOT use for: opening crit with no annotation (that is plain `crit`); generating a standalone HTML explainer page (explain-diff); judging findings someone else raised (review-triage).
---

# Crit Annotate

The user wants to review a diff themselves, and reads it faster when each hunk carries a short explanation of what it does and why. Writing those comments after the user is already looking at the page means they stare at an unannotated diff first, so the comments go in before the page reaches them.

Why the steps below insist on things that look paranoid — the startup line, the read-back, the two-dot range — is measured in `references/crit-behavior.md`. Read that only when a rule looks wrong or crit does something the steps do not cover.

## Two things to hold on to

**The startup line is the only source of truth about the session.** `crit status` and `crit comments` answer from whatever review is active at the moment you ask, including when that is a different review or none at all. What the server prints when it starts does not:

```
Started crit daemon at http://localhost:61725 (session 4d69fed0dc82, PID 30029)
```

It carries the **URL** to hand over in Step 5 and the **session id**, which is also the review's directory name `~/.crit/reviews/<session>/review.json`. Later rounds print `Connected to crit daemon at … (session …)` instead, with no PID, so do not match on `Started` alone.

**The Step 1 command, verbatim.** Step 6 and every reopen re-run it as-is, and the startup line does not carry it. Once the conversation is long enough to be compacted, `--pr 123` and `--range main..HEAD` are indistinguishable from memory, and reopening with the wrong one shows the user a page your comments do not belong to.

## Step 1: Pick the diff scope

Ask only if the request is ambiguous; otherwise infer and state which one you took in a single line.

| The user means | Command |
|---|---|
| what I have not staged yet | `crit` (auto-detects changed files via git) |
| this branch against its base | `crit --range <base>..HEAD` |
| a pull request | `crit --pr <number-or-url>` |
| what this branch adds on top of another PR's branch | `crit --range <that-branch>..HEAD` |

Get the matching diff with the same coordinates (`git diff`, `git diff <base>..HEAD`, `gh pr diff <n>`) so the comments you write line up with what crit will show. **`--range` is two dots, not three** — crit shows what `git diff <base>..HEAD` shows, and a three-dot diff is a different set of files once the base has moved on.

## Step 2: Start the session as a background task

Start the Step 1 command with the Bash tool's own `run_in_background`, not with a `&` inside the command:

```bash
crit --range <base>..HEAD --no-open
```

`--no-open` suppresses the browser, not the server: the command holds the foreground until the review finishes, and that exit is the signal Step 6 runs on. `run_in_background` keeps it — the tool result names an output file collecting both streams, and the harness re-invokes you when the process ends. A `&` inside the shell orphans the process and nobody is left holding its exit. Read the output file right away; the startup line is there within a fraction of a second. Do not redirect to a log file of your own.

**Start the session before writing any comment.** `crit comment` writes into whichever review is active, so with nothing up the comments land in a separate review that the user's page will never show.

`~/.crit/reviews/<session>/review.json` does not exist yet at this point — crit creates it when the first comment arrives, and its absence now signals nothing.

## Step 3: Write the explanation comments

One comment per hunk worth explaining — not per changed line, and not per file when a file holds several unrelated changes. Skip mechanical hunks (import reordering, formatting); a comment on every hunk buries the ones that matter. A newly added file deserves one, since that is the hunk the reader has the least context for. Where a mechanical edit shares a hunk with a real change, comment the real change and leave the mechanical part unmentioned — the reader can see an import moved.

Each comment answers, in plain Japanese: **what this hunk does**, and **why it is this way** when the reason is not visible in the code. These are explanations, not review findings — do not use them to raise problems with your own change. Follow the machine-wide rule on plain language: no coined terms, no identifiers a reader cannot decode, subject stated in every sentence.

crit draws the body as markdown with smart punctuation on, so wrap code, paths and ranges in backticks. Left bare, `main..HEAD` renders as `main…HEAD` and a sentence explaining a two-dot range ends up contradicting itself.

**Write the payload as a JSON file with the Write tool, then send the file.** Never pass a body as a shell argument: under zsh's double-quote rules the backticks you just added run as command substitution, and the identifiers vanish from the text while `crit comment` still reports success. A file written by the harness never passes through shell quoting at all.

```json
[
  {"path": "app/pkg/usecase/run_batch.go", "line": "42", "body": "…"},
  {"path": "app/pkg/usecase/run_batch.go", "line": "88-95", "body": "…"},
  {"body": "レビュー全体に向けた一言。"}
]
```

```bash
crit comment --author claude --json --file /path/to/payload.json
```

`line` takes a single line (`"42"`) or a range (`"88-95"`). An entry with no `path` attaches to the review itself and appears at the top of the page. `--author` lets the user tell your explanations apart from their own replies, and it applies to every entry in the file. Keep the payload file — Step 4 checks against it, and a repair re-sends it.

**A deleted file cannot hold a comment.** It has no line on the new side, so crit stores and counts the comment but never draws it. Put the explanation where it will be read instead: as its own comment on whatever file records the decision (the README paragraph, the rule that replaced it), or as a review-level entry when the repository holds no such file. Open that comment by naming the removed file, because it is sitting on lines that have nothing to do with it — a reader who is not told will read it as a comment about the code under it.

## Step 4: Verify the comments landed (never skip)

```bash
~/.claude/skills/crit-annotate/scripts/verify-comments.py <session-id> /path/to/payload.json
```

It reads `~/.crit/reviews/<session>/review.json` directly — not `crit comments`, which cannot tell you the comments went somewhere the user will never look — and fails when an entry is missing from the review file or when a stored comment's anchor is empty. The anchor is crit's record of the source text it attached to, so an empty one is the invisible case: accepted, counted, nowhere to draw.

Repair by fixing the payload file, running `crit comment --clear`, and re-sending the whole set; there is no per-comment delete. Then verify again.

**Do not tell the user crit is ready until this passes.** Report the number ("解説コメントを22件つけました") so a mismatch is visible to them immediately.

## Step 5: Hand the page over

Give the user the URL from the Step 2 startup line, the scope you used, and the number of comments attached. Then tell them the one thing they have to do for the loop to work: **read and reply, and press Finish Review when they are done for now — that press is what wakes you.** Individual replies alone do not reach you. Say it plainly, because a reviewer who expects each reply to be picked up will sit there waiting.

(crit can dispatch on each individual comment instead, via the "Send now" button, but that needs `agent_cmd` in `~/.crit.config.json` and it spawns a *separate* headless `claude -p` with none of this conversation's context. It is not this loop, and this skill does not set it up.)

## Step 6: Work the reply rounds

You do not wait for the user to tell you anything. The Step 2 background task ends the moment they press Finish Review, and the harness re-invokes you with the whole round in that task's output file. **Read `references/round-loop.md` then** — how to tell the user's feedback apart from your own explanations (which crit still counts as unresolved), how to reply, and when to stop are all there.

One thing not to do on waking: the output file ends with a `crit --session <id>` line. Ignore it. It restores the review file but not the scope, and the page comes up showing whatever happens to be uncommitted right now. Every reopen is the Step 1 command, verbatim, as a background task again.
