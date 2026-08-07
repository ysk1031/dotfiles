# Working a review round

Read this when the Step 2 background task ends — the user pressed Finish Review and the harness woke you. Everything below assumes you still hold the session id and the verbatim Step 1 command.

## What the wake-up carries

The task's output file has the whole round already. Read it rather than re-deriving any of it; `crit comments --json` is only the fallback for when the output is gone.

```
approved: false
The review finished with 2 unresolved comments.

[{"scope":"line","path":"README.md","id":"c_0f1e84", … ,"author":"claude","replies":[{ … ,"author":"Yusuke Aono", … }]}, … ]

Address each comment. For each one, reply explaining what you did using `crit comment --reply-to <comment-id> …`.

When you're done, run:

  crit --session 404d2a41d8d2
```

**Ignore the `crit --session <id>` line.** It restores the review file but not the scope, so crit falls back to auto-detecting the working tree and the page shows whatever happens to be uncommitted right now — your comments on files outside that set stay stored with nowhere to appear, which looks to the user like they were lost. Re-run the Step 1 command instead.

## Pick out what is actually addressed to you

Every explanation written in Step 3 is still unresolved, so crit counts all of them and the prompt says "address each comment". It is wrong about that: 22 explanations plus one real reply arrives as "23 unresolved comments". crit cannot create a comment already resolved, so Step 3 cannot avoid it.

Select on **who spoke last in the thread**: the newest entry is the last element of `replies`, or the comment itself when it has none. A thread is addressed to you when that last speaker is not `claude`. That leaves out your untouched explanations and the threads you already answered, while catching both the user's new comments and their replies to your explanations.

Do not select on `review_round` — it marks replies rather than rounds (`references/crit-behavior.md`). Treat a missing `resolved` field as unresolved; crit omits it rather than writing `false`.

## Answer, change, reply

Answer where an answer is enough. Where the reply asks for a change, make the change first, then reply saying what you did.

Replies go through a JSON payload file written with the Write tool, exactly as Step 3 sends comments and for the same reason — a body passed as a shell argument has its backticks run as command substitution. One file can carry the whole round:

```json
[
  {"reply_to": "c_0f1e84", "body": "README から数字を消し、`main.go` の `retryLimit` を見てもらう書き方に変えました。"}
]
```

```bash
crit comment --author claude --json --file /path/to/replies.json
```

Verify the replies the same way Step 4 verifies comments — the script takes a reply payload too, and checks each `reply_to` against the parent's stored replies:

```bash
~/.claude/skills/crit-annotate/scripts/verify-comments.py <session-id> /path/to/replies.json
```

**`--author` does not carry over** from Step 3 — every `crit comment` call needs its own, or crit signs the reply with the repository's `git config user.name`, which is the user, and their own thread comes back to them apparently written by themselves.

**Do not pass `--resolve`.** Resolving is the reviewer's call, and the last-speaker rule already keeps an answered thread out of the next round.

There is no per-reply delete, so a bad reply is repaired only by a second reply that corrects it.

## Open the next round, or stop

Re-run the Step 1 command as a background task again. crit signals the previous round complete, the user's page picks up your edits and shows "Round #2", and it blocks until the next Finish Review — then you are back at the top of this file. The output file carries a fresh URL and the same session id, on a `Connected to` line while the daemon is still up. Confirm the scope survived before handing the URL over: `pgrep -fl "crit _serve"` should show the same flags Step 1 used.

Stop the loop, and say why in one line, on any of these:

| What the output shows | What it means |
|---|---|
| `approved: true` plus "Review approved. All comments are resolved" | The user approved. Move on to committing. |
| Nothing addressed to you after the last-speaker rule | They pressed Finish with no new feedback. Report that and let them decide. |
| No `approved:` line at all | crit failed to start or lost the daemon — it exits non-zero on those paths too. Report the output; do not relaunch blindly. |

Stopping is not the same as ending. `crit stop` shuts the daemon down and `crit stop --all` gets every one of them, neither touching the review file — so a review the user wants to come back to later can be stopped safely, as long as you keep the session id and the Step 1 command.

The user has a one-click way out of the unresolved explanations: pressing Finish Review with nothing new opens crit's own "No changes this round" dialog, whose **Resolve all & approve** closes every thread and returns `approved: true`. Mention it when they ask how to end a review that still shows your 22 comments as open. Approving is final — it deletes the review file, unlike `crit stop`, which only shuts the daemon down and leaves the review reopenable.

When the review is done, commit through the `commit` skill — one topic per commit, and one commit per review finding when the replies asked for several unrelated fixes.
