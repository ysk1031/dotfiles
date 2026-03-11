# PR Schemas

Subagent I/O format definitions for the pr skill.

---

## pr-analyze-output

Output format for pr/prompts/analyze-branch.md.

Success:
```
STATUS: OK
BASE: <base-branch>
DRAFT: true | false
UNPUSHED_COUNT: <number or "all">
UNPUSHED_COMMITS:
<commit list or "(リモートブランチ未設定 — 全コミットがpushされます)">
TITLE: <string>
BODY:
<markdown body>
```

Language unclear:
```
STATUS: ASK_LANGUAGE
BASE: <base-branch>
COMMITS:
<commit list>
DIFF_STAT:
<diff stat>
言語の判定ができませんでした。日本語と英語のどちらで作成しますか？
```

Error:
```
STATUS: NOT_ON_BRANCH | NO_BASE | NO_COMMITS | NO_CHANGES
<error message in Japanese>
```

**Fields:**
- `STATUS` — `OK`: analysis complete, `ASK_LANGUAGE`: language undetermined, `NOT_ON_BRANCH`: detached HEAD, `NO_BASE`: base branch unknown, `NO_COMMITS`: no commits, `NO_CHANGES`: no diff
- `BASE` — Base branch name
- `DRAFT` — Whether it is a draft PR
- `UNPUSHED_COUNT` — Number of unpushed commits ("all" when remote is not set)
- `UNPUSHED_COMMITS` — List of unpushed commits
- `TITLE` — PR title
- `BODY` — PR description (Markdown)
