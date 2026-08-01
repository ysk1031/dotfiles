---
name: crit-annotate
description: >-
  Opens a diff in crit with your own plain-Japanese explanation already attached as inline comments, so the user reads the change with the walkthrough sitting next to each hunk instead of asking for it afterwards. Picks the diff scope (unstaged only / branch vs base / a PR / vs another PR's branch), writes one explanation comment per meaningful hunk, verifies the comments actually landed, and only then opens crit. Triggers on requests that pair crit with an explanation: 「critでセルフレビューしたいです。あなたのコード解説もつけた状態で開けますか？」「critでPRのdiffを開いて、変更説明もコメントとしてつけておいて」「解説コメント付きでcritを開いて」. Do NOT use for: opening crit with no annotation (that is plain `crit`); a report-only multi-perspective review delivered as a table (pre-pr-review); generating a standalone HTML explainer page (explain-diff); judging findings someone else raised (review-triage).
---

# Crit Annotate

## What this is for

The user wants to review a diff themselves, and reads it faster when each hunk carries a short explanation of what it does and why. Writing those comments after the user is already looking at the page means they stare at an unannotated diff first, so the comments go in before the page reaches them.

## The one thing to get right: the startup line is the only source of truth

`crit status` is not. It reports a review path whenever you ask, including **before any session exists and after the daemon stops** — and the id it names in those moments is a *different* review than the one you are about to create or just used. Measured: `crit status` said `5dd1731679f8` before starting; the session that actually started was `4d69fed0dc82`; after `crit stop` it said `5dd1731679f8` again. `crit comments` has the same problem, because it answers from whatever review is active at that moment.

What is trustworthy is the single line the server prints when it starts:

```
Started crit daemon at http://localhost:61725 (session 4d69fed0dc82, PID 30029)
```

That one line carries everything the rest of the skill needs: the **URL** to hand over in Step 5, the **session id** — which is also the review's directory name, `~/.crit/reviews/<session>/review.json` — to verify against in Step 4, and the **PID**. Capture it in Step 2 and keep it.

## Step 1: Pick the diff scope

Ask only if the request is ambiguous; otherwise infer and state which one you took in a single line.

| The user means | Command |
|---|---|
| what I have not staged yet | `crit` (auto-detects changed files via git) |
| this branch against its base | `crit --range <base>..HEAD` |
| a pull request | `crit --pr <number-or-url>` |
| what this branch adds on top of another PR's branch | `crit --range <that-branch>..HEAD` |

Get the matching diff with the same coordinates (`git diff`, `git diff <base>..HEAD`, `gh pr diff <n>`) so the comments you write line up with what crit will show.

**Two dots, not three.** `--range` is a two-dot range, and crit shows exactly what `git diff <base>..HEAD` shows. Once the base branch has moved on, a three-dot diff is a different set of files: measured with `main` one commit ahead, crit listed the main-only file as DELETED while `git diff main...HEAD` omitted it entirely — so you would write comments for a page you had never looked at.

## Step 2: Start the session in the background, and keep the startup line

**`crit … --no-open` does not return.** `--no-open` suppresses the browser, not the server: the command runs in the foreground and waits until the review is finished, so calling it plainly just blocks until your tool times out. Run it in the background and wait for the startup line:

```bash
LOG=$(mktemp -t crit-start)
crit --range <base>..HEAD --no-open > "$LOG" 2>&1 &
for _ in $(seq 1 60); do grep -q "Started crit daemon" "$LOG" && break; sleep 0.5; done
cat "$LOG"
```

Give the log its own path with `mktemp`, and bound the wait. A fixed name like `/tmp/crit-start.log` is shared: two reviews started around the same time overwrite each other's startup line, and you read someone else's session id. The bounded loop matters because a start that fails never prints the line — an unbounded `until` would spin until the tool times out, while `cat "$LOG"` after 30 seconds shows you the actual error.

Read the session id and the URL out of that line and hold on to both. Everything below refers to them.

**Start the session before writing any comment.** `crit comment` writes into whichever review is active at that moment; run it with no session up and crit makes a *separate* review, the comments land there, `crit comments` reads them back happily, and the page the user eventually opens shows none of them.

Do not run `crit status` to learn the path — see the section above. And note that `~/.crit/reviews/<session>/review.json` does not exist yet at this point; crit creates it when the first comment arrives. Its absence right now is normal and is not a signal of anything.

## Step 3: Write the explanation comments

One comment per hunk worth explaining — not per changed line, and not per file when a file holds several unrelated changes. Skip mechanical hunks (import reordering, formatting); a comment on every hunk buries the ones that matter. A newly added file and a sizable deletion each deserve one, since those are the hunks the reader has the least context for.

Each comment answers, in plain Japanese: **what this hunk does**, and **why it is this way** when the reason is not visible in the code. These are explanations, not review findings — do not use them to raise problems with your own change. Follow the machine-wide rule on plain language: no coined terms, no identifiers a reader cannot decode, subject stated in every sentence.

crit draws the body as markdown with smart punctuation on, so wrap code, paths and ranges in backticks. Left bare, `main..HEAD` is rendered as `main…HEAD` and a sentence explaining a two-dot range ends up contradicting itself.

Write them as JSON and pipe them in one call. `line` takes a single line (`"42"`) or a range (`"88-95"`), and `--author` lets the user tell your explanations apart from their own replies:

```bash
cat <<'EOF' | crit comment --author claude --json
[
  {"path": "app/pkg/usecase/run_batch.go", "line": "42", "body": "…"},
  {"path": "app/pkg/usecase/run_batch.go", "line": "88-95", "body": "…"}
]
EOF
```

A deleted file has no lines on the new side, so it cannot be anchored — and crit will not stop you from trying. `crit comment` on one answers `Added 1 comment`, the file's badge in the sidebar goes up, and only the empty `anchor` in Step 4 gives it away: the comment is stored and counted but never drawn on the page. Put the explanation where it will be read instead — a comment on whatever file records the decision (the README paragraph, the rule that replaced it), naming the removed file there. When the repository holds no such file, a comment with no path attaches to the review itself and appears at the top of the page. Send it through a quoted heredoc rather than inline — the body carries backticks, and inside double quotes zsh runs them as command substitution and silently eats the text:

```bash
BODY=$(cat <<'EOF'
…
EOF
)
crit comment --author claude "$BODY"
```

## Step 4: Verify the comments landed (never skip)

Read them back **out of `~/.crit/reviews/<session>/review.json`, using the session id from the startup line**. Not through `crit comments`, which answers from the active review and therefore cannot tell you the comments went somewhere the user will never look.

```bash
python3 - <<PY
import json
o = json.load(open("$HOME/.crit/reviews/<session>/review.json"))
n = 0
for path, entry in o["files"].items():
    items = entry.get("comments", []) if isinstance(entry, dict) else entry
    n += len(items)
    for c in items:
        print(path, c.get("start_line"), repr(" ".join(str(c.get("anchor","")).split())[:60]))
for c in o.get("review_comments", []):
    n += 1
    print("(review-level)", repr(" ".join(str(c.get("body","")).split())[:60]))
print("total", n)
PY
```

A comment with no path is stored in the top-level `review_comments`, not under `files` — walk both or the count will never match what you sent.

Check two things: the count matches what you sent, and each `anchor` — crit stores the source text it attached to — is the hunk that comment talks about. A comment sitting on the wrong lines still reports as added, so the anchor is the real check. An **empty** anchor is the invisible case: crit accepted and counted the comment but has nowhere to draw it, so the user will never see it. If the count is short, or an anchor is wrong or empty, fix it and verify again. There is no per-comment delete — `crit comment --clear` empties the whole review file — so the repair is to clear and re-send the corrected set in one go.

**`base_ref` is not a health check.** Its value moves around — a merge-base SHA, a bare branch name, or empty under `--pr` — and none of that tells you where your comments landed. The session id from the startup line is the identity check; `base_ref` is not.

**Do not tell the user crit is ready until this passes.** Report the number ("解説コメントを22件つけました") so a mismatch is visible to them immediately.

## Step 5: Hand the page over

Give the user the URL from the Step 2 startup line. Tell them the scope you used, the number of comments attached, and that replies to individual comments come back to you.

## Step 6: After the user replies

Read the replies with `crit comments --json` while the daemon is still up. Answer each one where an answer is enough; for the ones asking for a change, make the change, then reply and resolve:

```bash
crit comment --author claude --reply-to <id> --resolve "…"
```

**`--author` does not carry over from Step 3** — every `crit comment` call needs its own, and without one crit signs the reply with the repository's `git config user.name`, which is the user. Their own thread then comes back to them apparently written by themselves, and the point of setting an author at all is lost. Resolve only what you actually changed; leave a question you merely answered unresolved so the user can push back.

When the review is done, commit through the `commit` skill — one topic per commit, and one commit per review finding when the replies asked for several unrelated fixes.

## Stopping and reopening

`crit stop` shuts the daemon down; `crit stop --all` gets every one of them. The review file survives, but `crit status` and `crit comments` stop pointing at it the moment the daemon is gone, so keep the session id if the review is not finished.

**Reopen by re-running the Step 2 command, not with `--session`.** The same target yields the same session, so the comments come back either way — but `--session <id>` restores only the review file, not the scope. The daemon comes up as `crit _serve --session-key <id>`, with no `--pr` or `--range`, so crit falls back to auto-detecting the working tree and the page shows whatever happens to be uncommitted right now. Comments on files outside that set stay in the review file with nowhere to appear, which looks to the user like they were lost.

```bash
LOG=$(mktemp -t crit-start)
crit --pr <number> --no-open > "$LOG" 2>&1 &   # whichever Step 2 used, verbatim
for _ in $(seq 1 60); do grep -qE "Started|Restarted" "$LOG" && break; sleep 0.5; done
cat "$LOG"                                     # fresh URL, same session id
```

Confirm the scope survived before handing the URL over — `pgrep -fl "crit _serve"` should show the same flags Step 2 used.

`crit` has no `url` subcommand. Invoking one that does not exist starts another daemon and then errors, leaving a stray server behind.
