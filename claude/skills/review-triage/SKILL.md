---
name: review-triage
description: "Triage external code-review findings (AI reviewers like Codex/GitHub AI review, review comments from another AI session, or human reviewers) BEFORE acting on them: form an independent judgment on each finding's validity, explain it in plain language, recommend act/skip/discuss per finding, and only start fixing after the user approves specific items. Use when the user pastes review comments or a PR URL and asks things like '対応すべき？', '対応の是非を判断して', 'このレビュー指摘どう思う？', '意見だけまずください', 'triage this review', or wants to know which review comments are worth addressing. Do NOT use for performing a fresh code review of a diff (use code-review/review skills), for blind cross-model verification of your own conclusion (use second-opinion), or when the user has already decided and just says 'この指摘を直して' (just fix it directly)."
allowed-tools: Bash, Read, Grep, Glob, Edit, Write
argument-hint: "[PR URL or paste the review findings]"
metadata:
  author: ysk1031
  version: 1.0.0
---

# Review Triage

External review findings — from Codex, GitHub's AI review, another AI session, or a human — are *claims, not facts*. Some are sharp catches; others misread the code, miss project context, or optimize for generic best practices that don't apply here. Acting on all of them wastes effort and can make the code worse; ignoring all of them wastes the review. The job of this skill is the step in between: **judge each finding on its merits, explain it so the user can decide quickly, and touch no code until the user picks what to act on.**

The whole flow is two phases with a hard stop between them. Phase 1 is read-only analysis ending in a triage table. Phase 2 happens only after the user approves specific items.

## Phase 1: Triage (read-only — no file modifications)

### Step 1: Collect the findings

Identify where the review lives:

- **Pasted text** (Codex output, another session's review, copied comments): use as-is.
- **PR URL or number**: fetch review comments and reviews:
  ```bash
  gh pr view <number-or-url> --comments
  gh api repos/{owner}/{repo}/pulls/{number}/comments --paginate   # inline review comments with file/line
  ```
  Ignore resolved threads and pure approvals ("LGTM") — triage only actionable findings.
- **Mixed/unclear**: ask the user to paste or point at the source rather than guessing.

Split the input into discrete findings. One reviewer paragraph often contains several independent claims — split them so each can be judged and approved separately. Number them F1, F2, ... — the user will reply with these numbers.

### Step 2: Understand the code under review

Judging a finding without reading the code it points at produces rubber-stamping. For each finding, read the actual current code (the PR diff via `gh pr diff`, or the working-tree files). Check:

- Does the code the reviewer describes actually exist as described? (Reviewers — especially AI ones — sometimes hallucinate code or review an outdated version.)
- Is there surrounding context the reviewer couldn't see that changes the verdict (project conventions, an existing guard clause, a deliberate trade-off discussed elsewhere in the PR)?

### Step 3: Judge each finding independently

For each finding, form your own opinion before deciding a recommendation. The reviewer's confidence is not evidence; your reading of the code is. It is normal and expected that some findings get a "対応不要" verdict — a triage where everything is "対応する" usually means you deferred to the reviewer instead of judging.

Classify each finding:

- **対応する** — the finding is correct and the fix is worth it.
- **対応不要** — the finding is factually wrong, doesn't apply to this codebase, or the cost/churn outweighs the benefit. Say *why* plainly.
- **要相談** — validity depends on a judgment call only the user can make (product intent, team convention, priorities), or you genuinely can't determine correctness. State exactly what the open question is.

### Step 4: Present the triage table and STOP

Output this structure (in the user's language; plain wording, no reviewer jargon — if the reviewer used an obscure term, translate it):

```
## レビュー指摘のトリアージ

| # | 指摘の要約 | 妥当性 | 推奨 |
|---|-----------|--------|------|
| F1 | <平易な一文> | 正しい / 誤り / 判断による | 対応する / 対応不要 / 要相談 |

### F1: <指摘の要約>
- **指摘の内容**: <レビュアーが何を言っているか、平易に>
- **実際のコード**: <該当コードを読んだ結果わかったこと>
- **判断**: <あなた自身の意見と根拠。レビュアーと意見が違うならはっきりそう言う>
- **推奨**: <対応する/対応不要/要相談 + 対応する場合はおおまかな修正方針を1-2文>

（F2 以降も同様）

対応する番号を教えてください（例:「F1とF3だけ」「全部」「F2は別の方針で」）。
```

Then **end the turn**. Do not start fixing, do not stage, do not "just quickly fix the obvious one". The stop exists because the user routinely approves only a subset, and an unapproved edit — even a correct one — costs them a review-and-revert cycle.

## Phase 2: Fix approved items only

When the user replies with their selection:

1. Fix **only** the approved findings. If the user modified the approach for an item ("F2は別の方針で"), follow their approach, not the reviewer's.
2. Keep each fix minimal and scoped to its finding — this is not an invitation to refactor nearby code.
3. After the fixes, summarize what changed per finding number.
4. Do not commit. If the user wants a commit, they'll ask (commits go through the commit skill). Do not reply to the review comments on GitHub unless explicitly asked.

If the user instead disagrees with a verdict and provides new context, re-judge that finding with the new information — updating a verdict on new evidence is the point of triage, not a failure.

## Notes

- **Combining with your own review**: if the user asks to "総合して" (merge the external findings with your own observations), add your own findings to the same table with ids like C1, C2, clearly marked as yours, and triage them by the same standard.
- **Volume**: for a review with many findings (>10), group trivial/identical ones (e.g. same typo pattern in 5 files) into a single row so the table stays scannable.
- **Confidence honesty**: when your verdict relies on something you couldn't verify (e.g. behavior of an external service), say so in the 判断 line instead of projecting false certainty.
