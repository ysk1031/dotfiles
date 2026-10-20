# Rewriting the description of an existing PR

Everything in `SKILL.md` holds, with these differences:

- Read the PR with `gh pr view --json number,title,baseRefName` — leave `body` out for now — and use the PR's own base rather than re-detecting one.
- Rebuild the body from the commits as they stand now, writing it before you look at the old one — an old body carries the framing of whoever wrote it, including the process narrative the Body rules exclude, and reading it first pulls the new text toward it. Fetch it afterwards with `gh pr view --json body`, only to catch claims it makes that the code no longer supports. Its headings carry no weight either: the structure comes from the repository's template, or the default format when there is none. Replace the title too when it no longer covers what the commits now do.
- Confirm exactly as in Phase 2, ending the turn on the draft, with 「この内容でPR本文を更新してよければ「OK」と返信してください。修正したい場合は修正内容を、中止する場合は「キャンセル」と返信してください。」 Show the unpushed-commit status too: a body describing commits the remote does not have yet would not match the PR.
- After approval, push whatever is unpushed, then `gh pr edit <number> --body` with the same HEREDOC and footer, adding `--title` when the title changed. Do not open a second PR.

## Fixing a few lines of an existing body

When the user names specific lines or values to correct (a stale hash, a wrong count, one sentence) rather than asking for the body to be brought up to date, the rebuild above does not apply. Read the body first with `gh pr view <number> --json body -q .body`, keep its sha (`… | shasum -a 256`), and change only the lines the request covers. Every other rule above still holds.

The confirmation shows a diff instead of the full body — a few changed lines are lost inside several full bodies. For each PR, output its number and title, then a ```` ```diff ```` block with the changed lines as `-`/`+` pairs and one line of context where a line alone would be ambiguous. Name each PR that needs no change in one line, without a block. The unpushed-commit status and the confirmation prompt stay as above. An edit request re-displays the diff, not the full body.

After approval, fetch the body again and compare its sha with the one you kept. When it differs — the user or someone else edited the PR in the meantime — apply the same change to the new body and show the diff again before writing it. When it matches, write the whole new body with `gh pr edit <number> --body` as above, adding the footer only if the old body lacked it.
