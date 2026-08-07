# Measured crit behaviour

The evidence behind the rules in SKILL.md. Read this only when a rule there looks wrong, when crit behaves in a way the steps do not cover, or before changing one of those rules — the steps themselves are enough to run the skill.

## `crit status` and `crit comments` name the wrong review

Both answer from whatever review is active at the moment you ask, and they answer even when no session exists. Measured: `crit status` said `5dd1731679f8` before anything was started; the session that actually started was `4d69fed0dc82`; after `crit stop` it said `5dd1731679f8` again. Neither of those ids was the review being worked on.

This is why the startup line is the only identity the skill trusts, and why Step 4 reads `review.json` by session id instead of calling `crit comments`.

`base_ref` is not a substitute. Its value moves around — a merge-base SHA, a bare branch name, or empty under `--pr` — and none of it says where the comments landed.

## `--range` is two dots, and the difference is visible

crit shows exactly what `git diff <base>..HEAD` shows. Measured with `main` one commit ahead of the branch: crit listed the main-only file as DELETED, while `git diff main...HEAD` omitted that file entirely. Preparing comments from a three-dot diff means writing them for a page you never looked at.

## `--no-open` suppresses the browser, not the server

The command runs in the foreground until the review finishes. Called plainly it blocks until the tool times out.

Do not redirect it into a log file of your own either: crit prints the startup line on stderr and the harness's background-task output file already carries it, so a `mktemp` log only adds a path to thread through later calls — and shell state does not survive between Bash calls, so `LOG=$(mktemp)` cannot even reach the next one.

## A comment sent with no session up goes to a different review

`crit comment` writes into whichever review is active. With no session running, crit makes a separate review, the comments land there, `crit comments` reads them back happily, and the page the user eventually opens shows none of them.

## A comment on a deleted file is stored but never drawn

A deleted file has no line on the new side, so nothing can anchor to it — and crit does not stop you. Measured 2026-08-07 on a file removed with `git rm`: `crit comment --json` answered `Added 1 comment`, the review file gained the comment, and its `anchor` was the empty string. Nothing in the success output distinguishes this from a comment that will appear on the page. `scripts/verify-comments.py` fails on exactly this.

## `review_round` marks replies, not rounds

Measured 2026-08-07: a comment created with `crit comment --json` carries no `review_round` field, while a reply created by the same command carries `review_round: 1`. The field tracks whether an entry is a reply, not which round a thread belongs to and not where the entry came from — so it cannot separate this round's feedback from last round's. `resolved` is likewise absent rather than `false` on an unresolved comment; treat a missing field as unresolved.

That is why Step 6 selects on who spoke last in the thread.

## Approving deletes the review file; stopping the daemon does not

While comments are unresolved the button reads "Finish Review", and pressing it ends the round but keeps `review.json` — that is the ordinary reopen case. Once every comment is resolved the same button relabels to "Approve", and pressing that one sends `approved: true`, deletes `~/.crit/reviews/<session>/review.json`, and stops the server. Measured 2026-08-04: a fully-resolved review's file was gone within moments of the Approve click, while `crit stop --all` alone left an identical file untouched. There is no `--session` to reopen after that — the review is over, not paused.

## The next round shows your uncommitted fixes

Under `--range`, crit layers the working tree over the commit range rather than showing the range alone, so a fix you make between rounds appears without being committed. Measured 2026-08-07 with an edit left unstaged: reopening `--range main..HEAD` moved the file from `+9 -2` to `+12 -2`, drew the added lines, re-anchored the comment sitting on them from line 9 to line 12, and labelled the page "Round #2". Nothing has to be committed to let the reviewer see what you did.

## `--session <id>` restores the review file but not the scope

The daemon comes up as `crit _serve --session-key <id>`, with no `--pr` or `--range`, so crit falls back to auto-detecting the working tree and the page shows whatever happens to be uncommitted right now. Comments on files outside that set stay in the review file with nowhere to appear, which looks to the user like they were lost. Reopen by re-running the original scope command instead.

## `crit` has no `url` subcommand

Invoking one that does not exist starts another daemon and then errors, leaving a stray server behind.

## Per-comment deletion does not exist

`crit comment --clear` empties the whole review file; there is no way to remove one comment or one reply. So the repair for a bad comment is to clear and re-send the corrected payload, and the repair for a bad reply is a second reply that corrects the first.
