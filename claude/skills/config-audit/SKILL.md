---
name: config-audit
disable-model-invocation: true
description: >-
  Cross-artifact health check of this machine's Claude Code configuration: reads every skill, subagent, CLAUDE.md, memory file and settings.json together, and reports duplication, contradiction, dead weight and tangled dependencies as a three-bucket adjudication table (削除推奨 / 要判断 / 要更新). Deletion happens only after the user approves each row. Manual invocation only. Auditing one artifact type alone belongs elsewhere: CLAUDE.md wording → claude-md-improver, memory files → consolidate-memory, mining session history for new candidates → skill-scout.
---

# Config Audit

## What this is for and what it is not

Each artifact type already has its own auditor. What none of them can see is the space **between** artifacts: two skills claiming the same trigger, a CLAUDE.md rule that contradicts a skill's body, a memory pointing at a document that was deleted, a chain of definitions that all defer to each other. That gap is the whole subject here.

So do not re-do the single-artifact audits. If the finding is "this CLAUDE.md sentence is unclear" or "this memory is stale on its own terms", name it and hand it to `claude-md-improver` / `consolidate-memory` rather than fixing it here.

**This skill never deletes anything on its own.** It produces a table; the user decides each row; only then do you act.

## Step 1: Inventory

Enumerate, and record where the real file lives (most of `~/.claude` is symlinks — `readlink` each one, since editing or deleting the link is not the same as editing the source):

- `~/.claude/skills/*` — note which resolve into the dotfiles repo and which into `~/.agents/skills`
- Skills present in the repo but **not** linked (a `.sync-ignore` marker, or a missing symlink) — these are retired or broken, and telling the two apart matters
- `~/.claude/agents/*.md`
- `~/.claude/CLAUDE.md` and `~/.claude/CLAUDE.local.md`
- The `CLAUDE.md` of each repository worked in recently. `~/.claude/projects/*` holds session logs rather than CLAUDE.md files, but its directory names encode repository paths — with `/`, `.`, `_` and any literal `-` all flattened to `-`, so a single `-` is ambiguous and reading it as `/` throughout almost never resolves. Generate the candidates and keep whichever exists on disk (`github-com` wants `.`, `project-green` may want `_`, `--claude` is `/.claude`). Only call a directory dead after `_` and `.` were tried too; skipping them invents deleted repositories that are still there.
- Treat that list as partial, not complete. It reaches only repositories with recent sessions, a repository may keep its CLAUDE.md outside the root (this one keeps it at `claude/CLAUDE.md`), and a CLAUDE.md holding just `@AGENTS.md` means the content lives in the imported file. Scanning the source root directly finds the rest.
- `~/.claude/projects/*/memory/` — the `MEMORY.md` index and every entry
- `~/.claude/settings.json` — read it, but do **not** look for a repo counterpart: the dotfiles repo deliberately stopped tracking this file (the app rewrites it, and some of what it writes is workplace-specific). Its absence from the repo is the intended state, not drift. What is still worth reporting here is its content contradicting a rule elsewhere — a `permissions.deny` entry a CLAUDE.md rule relies on having been dropped, or a hook pointing at a path that no longer exists.
- Anything else under `~/.claude` whose `readlink` comes back empty: a file that looks synced but is not is exactly where divergence hides. Compare three states, not two — the live file, the repo's working tree, and its committed version — because a change sitting uncommitted in the working tree is already live, so a two-way diff shows nothing.
- The skills actually loaded, read off **the session's own skill listing** rather than settings.json — a plugin enabled in settings can be absent from the session, and skills nobody enabled can be present. Plugin skills cannot be edited from here, but they can collide with a user skill, which is a finding.
- A skill whose frontmatter carries `disable-model-invocation: true` never appears in that listing, because the listing shows what the model may invoke. It is manual-only, not dead — reading its absence as retirement is wrong. Retirement is decided by the link (Step 1's `.sync-ignore` / missing-symlink check), never by the listing.

For anything owned by the dotfiles repo, `git log --diff-filter=A` on the file gives its creation date, and the commit message usually states why it exists. Use that instead of guessing at intent. When it returns nothing, run `git status --porcelain` before concluding anything: the file may simply be untracked, which is its own finding.

## Step 2: The four cross-checks

Look for evidence, not impressions. Every row cites something checkable — a file path with a quoted line, or the command output that shows the state when the finding is about the filesystem rather than a file's contents (a path that no longer exists, a marketplace registered but never installed).

- **重複** — two artifacts that would fire on the same request, or two rules saying the same thing in different homes. Check the `description` trigger phrases against each other, and check whether a CLAUDE.md rule is also spelled out inside a skill body.
- **矛盾** — a rule in one place that a rule elsewhere forbids, or a procedure that references a step another artifact removed. The dangerous form is where both look reasonable alone.
- **死蔵** — pointers to files, skills or docs that no longer exist; memory entries recording work that finished; `.sync-ignore` markers nobody remembers setting; skills whose `description` runs long enough to be cut off in the listing, which silently drops the trailing Do-NOT list. **Report every description over 1400 characters.** That is the line to judge against — you are not expected to prove a given description gets truncated, and the exact cut-off is only known to sit between two measurements (1476 shown in full, 1604 truncated). Measure the description's own text with the YAML folding expanded and the `description:` key excluded — counting raw file characters includes the scalar markers and gives the wrong number. The listing prints the name beside it, so anything close to the line is already at risk.
- **依存の絡まり** — A tells you to read B, which defers to C. Report the chain and the depth; a rule that only works when three files are all correct is fragile.

## Step 3: The report

One table, most consequential first:

| 分類 | 種別 | 対象 | 根拠 | 提案 |
|---|---|---|---|---|
| 削除推奨 | 死蔵 | `<path>` | 引用と、なぜ役目が終わったか | 削除 |
| 要判断 | 重複 | `<path>` | 引用と、判断が要る理由 | ユーザーに問う一文 |
| 要更新 | 矛盾 | `<path>` | 引用と、どこがずれているか | 具体的な直し方 |

`種別` is which of the four checks surfaced the row, so the reader can see which lens is producing findings; name every one that applies when a row sits under two. `対象` is the path of the real file, not the symlink.

Rules for the table: 削除推奨 is only for things whose purpose is provably over (the thing they point at is gone, the skill they duplicate absorbed them). Anything where a reasonable person could disagree is 要判断 — it is not your call. Say plainly when a row rests on a guess about intent. **An empty 削除推奨 bucket is a normal result** on a well-kept config; report it as such rather than promoting a 要判断 row to fill it.

## Step 4: Act only on approved rows

- When a row holds a reason or a lesson worth keeping, get the content out before it goes. `obsidian-learning-note` is manual-only, so you cannot run it yourself: quote what should be preserved and ask the user to run `/obsidian-learning-note`, then delete once they confirm it landed.
- Deleting a skill means removing the real directory **and** its symlink in `~/.claude/skills`; run `claude/sync-links.sh` afterwards and confirm the skill is gone from the listing.
- Deleting a memory means removing its file and its line in `MEMORY.md`. Do not leave a note in the index saying it was deleted — an index line reads as a live instruction.
- Commit through the `commit` skill, one topic per commit.

## Step 5: Record the run

Write the date so the next audit — and skill-scout's report — can see how long it has been:

```bash
date +%Y-%m-%d > ~/.claude/.config-audit-last-run
```

This write belongs to the audit itself, not to Step 4's approved rows — run it even when the user approved nothing, and even when the table was empty.

This is the only thing keeping a manually-invoked audit from being forgotten, which is how the previous session-retrospective skill died. Do not skip it.
