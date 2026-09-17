---
name: commit-tidy
disable-model-invocation: true
description: >-
  Rewrite the commit history of a branch that is not yet merged: regroup, reorder, squash, drop and reword commits so the log reads as one clean sequence, prove the resulting tree is identical to the original, then force-push. Manual invocation only, because it rewrites history. Use when the user says 「コミットログを綺麗に整理して」「コミット履歴を整理したい」「紆余曲折があったので綺麗なコミットログにしてほしい」「コミットのメッセージが変遷を書きすぎなのでスリムにして」「PRのコミットログが汚いので force push して整えて」「まだ push してないコミットを整理したい、案を考えて」, or asks to squash / reword / reorder / split commits, or to clean up a branch's log before opening or updating a pull request. A new commit layout is proposed and the turn ends there; nothing is rewritten until the user approves it. Do NOT use for committing working-tree changes (that is commit), for opening or rewriting a pull request (pr), for explaining what a change does (explain-diff), or for rewriting commits that are already merged into the default branch.
allowed-tools: AskUserQuestion, Bash
argument-hint: "[range: defaults to @{u}..HEAD; also accepts origin/main..HEAD, HEAD~5, or a PR number] [--push to force-push after verification] [--no-push to hand the push to the user]"
metadata:
  author: ysk1031
  version: 1.0.0
---

# Commit Tidy

Rewrites how a branch's commits are divided and described. The content of the branch never changes: the last step before pushing is a diff against a backup branch that has to come back empty, and that output is the evidence the work is correct.

Commit message wording is not defined here. Read `claude/agents/commit-composer.md` (type selection, title under 72 characters, body at most 5 lines, never a scope) and `claude/skills/commit/SKILL.md` Phase 2 Step 1, and apply those rules unchanged to every message written below.

## Phase 1: Resolve the range, then run the guards

**Range.** Use the first that applies:

1. the argument, if given — `A..B`, `HEAD~N`, or a bare number, which means a PR (`gh pr view <N> --json baseRefName,headRefName`)
2. `@{u}..HEAD` when the branch has an upstream
3. `origin/<default-branch>..HEAD` otherwise

Call the commit the range starts from `<base>`, and report the resolved range in chat before doing anything else — a misread range is the one mistake the later verification cannot catch.

**Guards.** Each of these stops the skill. Report which one fired and what the user can do; do not work around it.

| Condition | Why it stops |
|---|---|
| `git status --porcelain` is not empty | This skill only moves commits. Uncommitted work belongs to `commit` first. |
| The range is empty | Nothing to tidy. |
| `git rev-list <base>..HEAD --not origin/<default-branch>` is shorter than `git rev-list <base>..HEAD` | Part of the range is already on the default branch. Rewriting it would diverge from what others have. |
| The range contains a merge commit (`git rev-list --merges <base>..HEAD`) | Replaying merges is out of scope. |
| More than one author email in `git log --format=%ae <base>..HEAD` | Rebuilding re-authors every commit, which would take someone else's name off their work. |
| `commit-tidy/backup/<branch>` already exists | A previous run did not finish or was never cleaned up. Show the branch and let the user decide. |

**Push intent.** Read it, do not ask for it yet:

- `--push` / `--no-push` in the arguments, or a statement in the user's message (「force push して構わない」「最後の force push は私がやる」) → that is the decision, and it counts as approval for Phase 6.
- Nothing either way → leave it unresolved and ask in Phase 5.

## Phase 2: Back up

```bash
git branch commit-tidy/backup/<branch>
```

## Phase 3: Propose a layout, then end the turn

Read the range (`git log --stat <base>..HEAD`, `git diff <base>..HEAD --stat`) and present the proposal as a table: new commit number, `type: title`, the source commits folded into it, and the files it carries. Put the drafted body under the table for any commit that needs one.

**A file's changes can only be split across two new commits when they came from different source commits.** Splitting one source commit's changes to one file into two new commits needs `git add -p`, which is interactive and unavailable here. If the layout the user wants requires that, say so in the proposal and offer the closest layout that does not.

Note in the proposal that intermediate commits are not built or tested individually, so if the branch has to stay bisectable the groups must be ordered so a dependency lands before its caller.

**Then end the turn with no tool call.** Not `AskUserQuestion` — the user's reply is usually an edit to the layout ("2 と 3 は分けたまま", "1 のタイトルは fix にして"), which a fixed set of options cannot carry. Do not begin Phase 4 in the same turn as the proposal, even when the user's opening message said force push was fine; that permission covers the push, not the layout.

## Phase 4: Rebuild

`git rebase -i` is unavailable in this environment and `git reset --hard` is denied by `~/.claude/settings.json`. Replay with `cherry-pick` instead.

```bash
git switch -C <branch> <base>
```

Then, for each approved commit in order:

```bash
git cherry-pick --no-commit <sha> [<sha> ...]
git commit -m "$(cat <<'EOF'
<type>: <description>

<body>

Co-Authored-By: Claude <model> <noreply@anthropic.com>
EOF
)"
```

Several source SHAs in one `cherry-pick` squash them. Omitting a SHA drops it. Listing them in a different order reorders them.

Carry over any `Co-Authored-By` trailer that the source commits already had, deduplicated, alongside your own.

To split one source commit across two new commits by path:

```bash
git cherry-pick --no-commit <sha>
git restore --staged -- <paths that belong to the later commit>
git commit -m "..."
git add -- <paths that belong to the later commit>
git commit -m "..."
```

If a `cherry-pick` conflicts, stop. Run `git cherry-pick --abort`, restore with `git switch -C <branch> commit-tidy/backup/<branch>`, and report the conflicting commit and paths. A reordering that conflicts is a layout question for the user, not something to resolve alone.

## Phase 5: Verify, and show the evidence

```bash
git diff commit-tidy/backup/<branch> HEAD
git log --oneline <base>..HEAD
```

Paste both into chat, including the empty output of the first. An empty diff is the whole claim this skill makes; asserting it without the output is not a report.

If the diff is **not** empty, the rebuild dropped or duplicated something. Do not push. Restore with `git switch -C <branch> commit-tidy/backup/<branch>`, show the diff, and stop.

Then, in one `AskUserQuestion` call, ask only what is still unresolved:

- push, when Phase 1 left it open — 「force push まで実行しますか？」 with 「実行する」/「自分でやる」
- the backup branch — 「`commit-tidy/backup/<branch>` を削除しますか？」 with 「削除する」/「残す」

## Phase 6: Push

Print the exact command in chat before running it. The decision was already made — in Phase 1 or in Phase 5 — so do not ask a second time.

```bash
git push --force-with-lease origin <branch>
```

A branch with no upstream has nothing to overwrite: use `git push -u origin <branch>`.

When the user is pushing themselves, print the command for them to run and do not run it.

## Phase 7: Report

Give the new log, the empty verification diff, whether the push happened, and what became of the backup branch. If the backup was kept, name it, so the user knows what to delete later.
