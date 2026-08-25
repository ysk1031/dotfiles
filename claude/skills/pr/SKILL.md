---
name: pr
description: "Create a GitHub Pull Request with auto-generated title and description. Use when user says 'PR作って', 'create PR', 'プルリクエスト', or wants to push and open a pull request. ALSO use whenever you (the agent) are about to open a pull request as the culmination of a task — never run `gh pr create` directly; always route through this skill. When creating a PR autonomously without an interactive user available to confirm, invoke with `--auto` (creates a draft and skips the chat confirmation). ALSO use when rewriting the description of a PR that already exists ('PRの説明を更新して', 'PR本文が古いので直して', `gh pr edit --body`) — the same template and body rules apply there. Do NOT use for reviewing existing PRs or merging PRs."
allowed-tools: AskUserQuestion, Bash
argument-hint: "[base-branch to specify target branch] [--draft to create as draft PR] [--auto for autonomous/non-interactive runs: create as draft and skip chat confirmation]"
metadata:
  author: ysk1031
  version: 3.0.0
---

# Pull Request Creation Skill

Analyze the branch's changes, draft a title and description, get the user's confirmation, then create the PR. Run every phase in the main agent — a subagent's output is collapsed in the UI, so the user would never see the draft.

**`--auto`** (agent-initiated PR with no interactive user): run Phase 1 as usual, skip the Phase 2 confirmation, force `--draft`, and never force push. The GitHub draft is the approval gate the human flips to "Ready for review".

## Phase 1: Analyze (read-only)

Use only read-only commands (`git`, `gh`, `cat`) here. Never create, modify, or delete a file in this phase.

1. **Branch**: `git branch --show-current`. Empty (detached HEAD) → print 「現在detached HEAD状態です。`git checkout -b <branch-name>` でブランチを作成してください。」 and stop.
2. **Base branch**: the argument if one was given; otherwise the branch that `git remote show origin 2>/dev/null | grep 'HEAD branch' | awk '{print $NF}'` names. When that output is empty, fall through to whichever of main → master → develop exists (`git show-ref --verify --quiet refs/heads/<name>`). None found → print 「ベースブランチを特定できませんでした。引数でベースブランチを指定してください。」 and stop.
3. **Diff**: `git log <base>..HEAD --oneline` and `git diff <base>...HEAD --stat`. No commits → 「ベースブランチとの差分コミットがありません。変更をコミットしてから再実行してください。」 and stop. No diff → 「ベースブランチとの差分がありません。」 and stop. Otherwise read `git diff <base>...HEAD`. When the stat shows a very large diff, read per-file diffs for the meaningful source files only and skip generated files (lock files, build output, snapshots). Read past the diff when a section of the body will need it — what calls the function you changed is the usual case, and it is evidence like any other file in the repository.
4. **Unpushed commits**: `git log @{u}..HEAD --oneline`, run on its own — with no upstream the command exits non-zero, which kills the rest of an `&&` chain. That failure means there is no remote tracking branch and every commit will be pushed.
5. **PR template**: if `.github/pull_request_template.md` exists, follow its headings and checklist as written — do not replace them with a structure of your own. Only the repository root's template is the one GitHub uses; ignore template-looking files under monorepo subdirectories.
6. **Project conventions**: read the project's `CLAUDE.md` for PR conventions — a required title prefix (issue number, ticket ID), a default draft state, required sections. Apply what you find in Phase 2.
7. **Language**: check `git log --oneline -10` and `gh pr list --limit 5 2>/dev/null || true`. Mostly Japanese → write in Japanese; mostly English → English. Genuinely undecidable → AskUserQuestion (question 「PR説明文をどちらの言語で作成しますか？」, header "Language", options 日本語 / English), then continue with the information already gathered — do not re-run the analysis.

## Phase 2: Draft and confirm

### Title

Single commit: reuse its message. Multiple: summarize them. Apply any prefix convention found in step 6, and keep the whole title under ~72 characters so GitHub does not truncate it. An identifier that only carries meaning inside the code (a column name, a type, a coined term) needs a short parenthetical gloss so a reviewer who did not write the change can read the title: `feat: add consumed_feedback_boundary (どこまでのフィードバックを反映済みか示す境界)`. When the gloss would overflow the line, define the identifier in the body's first paragraph instead.

### Body

**Write for a reader who was not in the room.** The reader is a new participant who knows nothing about the conversation that produced this branch — they see the final diff and this text, nothing else. Every sentence must stand on its own for them. That rules out the whole history of how the change was reached: the approaches tried and abandoned, the mid-session change of plan, the review rounds, the self-review, 「当初は〜だったが」「指摘を受けて〜した」. None of it survives into the body, because none of it is needed to answer the only question the reader has: what changes when this ships. Prior *behaviour* is a different thing — when the diff changes how the code already behaves, describing the before/after is part of describing the diff, and belongs in the body. When you cannot tell which side something falls on, ask whether the diff shows it: the base branch's behaviour is visible there, a rename that happened within the branch is not.

Fill each template section by how well the facts support it: write what the diff and the repository establish, and put 該当なし / N/A where they establish nothing — never a placeholder for someone to come back and fill. Where that blank is something the user could fill (an issue to link, a release note to write), the 該当なし stays and the question goes to them alongside the draft. A checkbox is ticked only by evidence the reviewer can see for themselves, such as a test file or a doc change in the diff; your own recollection of having run something is not that evidence. Everything else stays `[ ]` — a Test Plan among them, since it lists checks nobody has run yet.

In Japanese, write in 常体 (だ・である調), never 丁寧語 — that governs the body you write, not the fixed Japanese strings this skill spells out (the confirmation prompt, the push status), which are used verbatim.

With no PR template in the repository, use:

```markdown
## Summary
[Brief description of what this PR does and why]

## Changes
- [Change 1]
- [Change 2]

## Test Plan
- [ ] [How to verify this change]
```

### Confirmation — display the draft and END THE TURN

Skip this whole step under `--auto` and go to Phase 3 with `--draft` forced.

Text output is only guaranteed visible to the user when it is the final message of the turn with no tool call after it. An AskUserQuestion dialog after the draft redraws the terminal and hides it — this has broken repeatedly. So confirmation happens through the user's next chat message, never through AskUserQuestion.

Output as the final response text of the turn:

```
**Base:** <base>

# <title>

<body — full text, never summarized or truncated>
```

Then the unpushed-commit status — either 「リモートにpushされていないコミットが {count} 件あります:\n{commit list}」 or 「リモートブランチが未設定のため、全コミットがpushされます。」 — then any questions the body left for the user, in the same 常体 as the body, and omitted entirely when there are none. Last:

「この内容でPRを作成してよければ「OK」と返信してください。修正したい場合は修正内容を、中止する場合は「キャンセル」と返信してください。」

**End the turn immediately.** Call no tool after the draft. Then handle the reply: approval → Phase 3; edit request → revise and re-display the full draft, ending the turn again; cancel → print 「PRの作成をキャンセルしました。」 and stop.

## Phase 3: Create the PR

**Push.** Run `git fetch origin`, then:

- Remote branch does not exist, or local is ahead only → `git push -u origin HEAD`
- Local has diverged or is behind (history rewritten by rebase/amend) → under `--auto`, do not force push: print 「リモートブランチと履歴が分岐しているため、自律モードではpushを中止した。手動で確認してほしい。」 and stop. Otherwise ask with AskUserQuestion (question 「リモートブランチとローカルブランチの履歴が分岐しています（rebase/amendなどによる可能性があります）。Force pushしますか？」, header "Push", options: Force push / キャンセル). On approval run `git push --force-with-lease -u origin HEAD`; on cancel print 「PRの作成をキャンセルしました。」 and stop.

Any other push failure: show the error and stop.

**Create.**

```bash
gh pr create --base <base from Phase 1> --title "<confirmed title>" --body "$(cat <<'EOF'
<confirmed body>

---
🤖 Generated with [Claude Code](https://claude.com/claude-code)
EOF
)" [--draft if requested, or always under --auto]
```

Show the PR URL from the output. Under `--auto`, add 「自律作成のためdraftで作成した。レビューして問題なければ GitHub で Ready for review に切り替えてほしい。」 and any questions the body left open — with the confirmation step skipped, this report is the only place the human sees them.

## Rewriting the description of an existing PR

Everything above holds, with these differences:

- Read the current state with `gh pr view --json number,title,body,baseRefName`, and use the PR's own base rather than re-detecting one.
- Rebuild the body from the commits as they stand now, writing it before you look at the old one — an old body carries the framing of whoever wrote it, including the process narrative the Body rules exclude, and reading it first pulls the new text toward it. Read it afterwards, only to catch claims it makes that the code no longer supports. Its headings carry no weight either: the structure comes from the repository's template, or the default format when there is none. Replace the title too when it covers only part of what the commits now do.
- Confirm exactly as in Phase 2, ending the turn on the draft, with 「この内容でPR本文を更新してよければ「OK」と返信してください。修正したい場合は修正内容を、中止する場合は「キャンセル」と返信してください。」 Show the unpushed-commit status too: a body describing commits the remote does not have yet would not match the PR.
- After approval, push whatever is unpushed, then `gh pr edit <number> --body` with the same HEREDOC and footer. Do not open a second PR.

## Rules

- Always append the footer `🤖 Generated with [Claude Code](https://claude.com/claude-code)` — it keeps the origin of the PR traceable.
- Always pass the `base` detected in Phase 1 to `--base`. Do not substitute the "Main branch" value from the system prompt; it can be wrong.
- Pass the body through a HEREDOC. A plain string mangles markdown line breaks and special characters.
- Push without asking — it is a prerequisite for creating the PR. Force push is the exception: it is destructive, so it always needs the user's approval, always uses `--force-with-lease` (never `--force`, which overwrites a remote someone else may have updated), and never happens under `--auto`.
