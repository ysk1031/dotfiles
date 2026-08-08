---
name: second-opinion
description: >-
  Blind cross-check of a technical conclusion: a second model (Fable 5) answers the same question without seeing your answer, and the user judges both reads side by side. Offer it in one line after any judgment with real trade-offs (design call, root-cause diagnosis, "which approach" recommendation) — including when you lay out competing options for the user to pick between — or when the user signals doubt (「本当にそう?」「念のため」), and run it only once they agree — unless they asked for another model outright, in which case just run it. Don't re-offer for a conclusion the user already declined. Skip lookups, mechanical edits, one-right-answer questions, and plain PR review. Defer to `/advisor` when the user wants a stronger model assisting with full context rather than an independent check.
---

# Second Opinion

## Why this exists

Left to your own devices you will tend to *defend* a conclusion you just reached — re-reading your own reasoning finds it persuasive. This skill breaks that by putting the same problem in front of a different model **without telling it what you concluded**, and handing both reads to the user.

The value is entirely in bias removal. A second model that can see your answer anchors to it and rubber-stamps it. Everything below protects that independence.

This is also the one thing `/advisor` structurally cannot do: the advisor receives the full conversation including your conclusion, and folds its guidance back into your answer. Here the second model is blind and the human arbitrates.

## Strip your bias before asking

You hand over the problem and the evidence, not your answer. Any trace of your conclusion contaminates the result.

The prompt you send MUST NOT reveal: which option you picked, which way you lean (grading adjectives, "X should be fine"), a yes/no or leading framing that invites agreement, or which option originated with you (via ordering, length, or tone).

The prompt you send MUST contain: the decision stated neutrally and why it matters; the real evidence as primary material (code excerpts with file paths, constraints, errors, data — not your summary of it); the genuine options described evenhandedly, or an invitation to propose its own; and an open question that invites disagreement.

Think of it as a blind review: the reviewer sees the code and the question, never the author's preferred answer.

## How to run it

```
Agent(
  subagent_type: "general-purpose",
  model: "fable",
  description: "Second opinion on <topic>",
  prompt: <the bias-stripped prompt>
)
```

`general-purpose` lets it open a file if your excerpt turns out to be insufficient.

The Agent tool exposes no reasoning-effort parameter, so control depth through the prompt: tell it to *"think hard"* / *"ultrathink"* for a weighty decision, omit that for a quick sanity check, and translate the user's request if they asked for a specific level.

Ask for a structured answer so it is comparable to yours: its recommendation, its reasoning, risks or options it sees that you may have missed, and its confidence with what would change its mind.

## How to present the result

Lay the two views side by side and attribute each clearly. The user is the judge; do not manufacture a consensus.

- **Agreement** — say so plainly. It is real signal, but don't inflate it.
- **Disagreement** — the payoff. Present the other view fairly without softening it, state where and why you differ, and let the user decide. Never silently switch answers, never dismiss it.
- **Something new** — call out a surfaced risk or option explicitly, even when the overall recommendation is unchanged.
