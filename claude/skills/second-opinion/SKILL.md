---
name: second-opinion
description: >-
  Blind cross-check of a technical conclusion: ask a different model (Fable 5) the same question with your own answer hidden, then lay both views side by side for the USER to judge. Offer in one line and run only once the user agrees — never unasked. Offer proactively right after you deliver a non-trivial judgment (design/architecture call, root-cause diagnosis, security or data-integrity call, "which approach" recommendation, any conclusion with real trade-offs), and equally when you lay out competing options and ask the user to pick — a blind read is most useful before they choose. Also offer whenever the user signals doubt (「本当にそう?」「念のため」「別の視点」and the like). Only when the user outright asks for another model (「セカンドオピニオン」「他のモデルにも聞いて」and the like) do you skip the offer and run it. Defer to `/advisor` when the user wants a stronger model assisting with full context rather than an independent check. Do NOT fire for simple factual lookups, mechanical edits (refactor/rename/write-tests/translate), questions with one objectively correct answer, or a plain "review this PR"; and do not re-offer for the same conclusion once the user has declined it.
---

# Second Opinion

## What this skill is for

You just reached a technical conclusion. Left to your own devices you will tend to *defend* it — re-reading your own reasoning finds the same reasoning persuasive. That is the single-model blind spot. This skill breaks it by putting the same problem in front of a **different model (Fable 5)**, deliberately **without telling it what you concluded or which way you lean**, and then laying both views side by side for the user.

The value lives entirely in *bias removal*. A second model that can see your answer will anchor to it and rubber-stamp it — worthless. A second model that gets the same evidence but none of your framing gives a genuinely independent read. Everything below exists to protect that independence.

## How this differs from the built-in `/advisor` — and when to defer to it

Claude Code ships an official advisor tool (`/advisor`). It is the right tool for many "consult a second model" situations, so know the boundary:

- **`/advisor`** pairs the main model with a stronger-or-equal advisor that Claude consults at decision points. The advisor **receives the full conversation, including your reasoning and your conclusion**, and its job is to *guide Claude* (Claude generally then follows the guidance). Because it sees your answer, it can anchor to it — that is fine for "help me get this right," but it is *not* an independent check.
- **This skill** does the one thing `/advisor` structurally cannot: it hides your conclusion, gives the other model a **blind** view of the same evidence, and hands **both reads to the human** to judge rather than folding the second view back into Claude's own answer.

So: if the user just wants a stronger model to assist with full context at hard moments, that is `/advisor`'s job — say so and don't reinvent it. Reach for this skill specifically when *independence from your own answer* is the point: you want to know what a fresh model concludes without being told what you concluded, and you want the user (not Claude) to arbitrate.

## When to offer it (and how)

**Notice the moment yourself.** Right after you deliver a conclusion of real weight — a design decision, a root-cause diagnosis, a trade-off call, a "use A not B" recommendation — that is the moment to offer. Also offer the instant the user signals doubt (「本当に?」「念のため」「自信ある?」). Skip it for trivia, lookups, and questions with one correct answer.

**Offer lightly; don't just do it.** Calling another model costs time and tokens, so don't run it unprompted. Add one short line after your conclusion, e.g. *「この判断、Fable 5 でセカンドオピニオンも取れます。取りますか?」* — no heavy prompt or menu. Run the check only once the user says yes.

**Don't nag.** If the user declines, drop it — do not re-offer for that same conclusion later in the session. Offer again only for a genuinely new decision.

**When the user asks directly** (「別のモデルにも聞いて」「セカンドオピニオン取って」), skip the offer and go straight to running it.

## The one rule that matters: strip your bias before asking

When you assemble the prompt for Fable 5, your job is to hand over **the problem and the evidence, not your answer**. If any trace of your conclusion leaks in, the second opinion is contaminated and the whole exercise is pointless.

Concretely, the prompt you send MUST NOT contain:

- **Your conclusion or recommendation.** No "I decided to use X", "I think X is best", "my plan is X". The other model must not know which option you picked.
- **Leaning language.** No "X seems cleaner, right?", "X should be fine", "we probably want X". No adjectives that grade the options.
- **Leading / yes-no framing.** Don't ask "Is X the right choice?" or "X won't cause problems, correct?" — those invite agreement. Ask open questions.
- **Which option came from you.** If you list candidate options, present them in neutral order with equal detail; don't signal a favorite by ordering, length, or tone.

The prompt you send MUST contain:

- **The concrete problem**, stated neutrally — what is being decided and why it matters.
- **The real evidence** — relevant code excerpts (paste them, with file paths), constraints, requirements, error messages, data. Enough that the model can reason from primary material, not from your summary of it.
- **The genuine options on the table**, described evenhandedly (if the decision is open-ended, ask the model to generate its own).
- **An open question**: *"Which approach would you choose and why? What risks, trade-offs, or options am I missing?"* — phrased to invite disagreement, not consent.

Think of it as a blind review: the reviewer sees the code and the question, not the author's preferred answer.

## How to run it

Use the **Agent tool** with the model overridden to Fable 5. Use `subagent_type: "general-purpose"` so it can open a file if the excerpt you pasted turns out to be insufficient, but keep it focused on the question.

```
Agent(
  subagent_type: "general-purpose",
  model: "fable",
  description: "Second opinion on <topic>",
  prompt: <the bias-stripped prompt assembled per the rules above>
)
```

**Reasoning depth (the "effort" knob).** The Agent tool does not expose a reasoning-effort parameter, so control depth through the prompt instead: for a weighty or subtle decision, tell the sub-agent to *"think hard"* / *"ultrathink"* before answering; for a quick sanity check, leave it out. If the user asked for a specific effort level, translate it this way.

**Ask for a structured answer** so it's easy to compare against yours — request: (1) the model's own recommendation, (2) its reasoning, (3) risks or missed options it sees, (4) its confidence.

### Prompt template for the sub-agent

```
You are giving an independent technical opinion. Reason only from the evidence
below — there is no "expected" answer, and disagreeing is valuable.

## Problem
<neutral statement of what's being decided and why it matters>

## Context / evidence
<code excerpts with file paths, constraints, requirements, errors, data>

## Options on the table
<evenhanded list, or: "Propose the approach you'd take.">

## Your task
Think hard, then answer:
1. Which approach would you choose, and why?
2. What risks, trade-offs, or edge cases stand out?
3. What options am I not considering?
4. How confident are you, and what would change your mind?
```

## How to present the result

Lay the two views side by side and be honest about where they land:

- **They agree** → say so plainly; the agreement is real signal that raises confidence. Don't inflate it into more than it is.
- **They disagree** → this is the payoff. Present Fable 5's view fairly (don't soften it to protect your own), state where and why you differ, and give the user what they need to decide. Do not silently switch to the other answer, and do not dismiss it — surface the disagreement and reason about it openly.
- **It raised something new** (a risk, an option) → call it out explicitly, even if the overall recommendation is unchanged.

Attribute clearly which view is yours and which is Fable 5's. The user is the judge; your job is to give them two honest, independent reads — not to manufacture a consensus.
