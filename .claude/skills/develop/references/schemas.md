# Pipeline Schemas

Subagent I/O format definitions for the pipeline skills (research, plan, implement).

---

## research-scope-output

Output format for research/prompts/analyze-scope.md.

```
STATUS: OK | NO_TOPIC
TOPIC: <string>
SCOPE: broad | focused
OUTPUT: <filename or empty>
CLAUDE_MD: EXISTS | NOT_FOUND
PROJECT_TYPE: <string>
DIRECTORY_STRUCTURE:
<structure output>

ENTRY_POINTS:
<file1>
<file2>
...

ENTRY_POINT_COUNT: <number>
```

**Fields:**
- `STATUS` — Scope analysis result. `OK`: topic identified, `NO_TOPIC`: topic unclear
- `TOPIC` — Topic string for analysis
- `SCOPE` — Investigation scope. `broad`: wide-ranging investigation, `focused`: investigation narrowed to a specific area
- `OUTPUT` — Output filename (empty if not specified)
- `CLAUDE_MD` — Whether CLAUDE.md exists
- `PROJECT_TYPE` — Detected project type
- `DIRECTORY_STRUCTURE` — Project directory structure (top 2 levels)
- `ENTRY_POINTS` — List of file paths as investigation starting points
- `ENTRY_POINT_COUNT` — Number of entry points

---

## research-investigation-output

Output format for research/prompts/investigate.md.

```
STATUS: OK | PARTIAL
TOPIC: <string>
FILES_INVESTIGATED: <number>

=== OVERVIEW ===
<2-3 sentence overview>

=== ARCHITECTURE ===
<architecture description>

=== COMPONENTS ===

--- COMPONENT: <name> ---
FILE: <path>
ROLE: <description>
DEPENDS_ON:
- <dependency> (<path>): <why>
DEPENDED_BY:
- <dependent> (<path>): <how>
KEY_FUNCTIONS:
- <function>: <description>
NOTES: <observations>

=== DATA_FLOW ===
1. <entry> → <what happens>
2. <next> → <what happens>

=== PATTERNS ===
- <pattern>: <where and how>

=== RISKS ===
- <risk>: <description and affected files>

=== FILE_LIST ===
GROUP: <role>
- <file path>
```

**Fields:**
- `STATUS` — `OK`: investigation complete, `PARTIAL`: partial results (e.g., topic too broad)
- `TOPIC` — Investigation topic
- `FILES_INVESTIGATED` — Number of files investigated
- `OVERVIEW` — Overview (2-3 sentences)
- `ARCHITECTURE` — Architecture description
- `COMPONENTS` — Details of major components (multiple)
- `DATA_FLOW` — Data flow description
- `PATTERNS` — Discovered patterns and conventions
- `RISKS` — Risks and technical debt
- `FILE_LIST` — File list by role

Additional fields when PARTIAL:
- `FINDINGS` — What was found
- `UNCLEAR` — Unclear points
- `SUGGESTED_NARROWING` — Suggestions for narrowing scope

---

## plan-context-output

Output format for plan/prompts/gather-context.md.

```
STATUS: OK | NO_TASK
TASK: <string>
RESEARCH_FILE: <path or NONE>
RESEARCH: EXISTS | NOT_FOUND | NONE
AVAILABLE_RESEARCH: <list or NONE>
OUTPUT: <filename or NONE>
CLAUDE_MD: EXISTS | NOT_FOUND
PROJECT_TYPE: <string>
DIRECTORY_STRUCTURE:
<structure>

RECENT_COMMITS:
<last 5 commits>
```

**Fields:**
- `STATUS` — `OK`: context collection successful, `NO_TASK`: task not specified
- `TASK` — Task description
- `RESEARCH_FILE` — Path to the specified research file (NONE if not specified)
- `RESEARCH` — Research file status
- `AVAILABLE_RESEARCH` — List of research-*.md files in the current directory
- `OUTPUT` — Output filename (NONE if not specified)
- `CLAUDE_MD` — Whether CLAUDE.md exists
- `PROJECT_TYPE` — Detected project type
- `DIRECTORY_STRUCTURE` — Directory structure
- `RECENT_COMMITS` — Last 5 commits

---

## plan-generation-output

Output format for plan/prompts/generate-plan.md.

```
STATUS: OK

=== BACKGROUND ===
<background description>

=== GOAL ===
<goal description>

=== STEPS ===

--- STEP 1: <title> ---
TARGET: <file path> (create | modify)
CHANGES: <specific changes>
REASON: <why>
DETAIL:
<detailed description>

=== TESTING ===
<verification plan>

=== RISKS ===
- <risk>: <description and mitigation>

=== CHECKLIST ===
- [ ] Step 1: <brief>
- [ ] Step 2: <brief>
```

**Fields:**
- `STATUS` — Always `OK`
- `BACKGROUND` — Background description of the task
- `GOAL` — Definition of success (specific, measurable outcomes)
- `STEPS` — Implementation steps (each step includes TARGET, CHANGES, REASON, DETAIL)
- `TESTING` — Test plan
- `RISKS` — Risks and mitigations
- `CHECKLIST` — Checklist

---

## plan-revision-output

Output format for plan/prompts/revise-plan.md.

Same format as plan-generation-output, with the following section prepended:

```
=== REVISION_SUMMARY ===
<changes made, listing each annotation and how it was addressed>
```

**Additional Fields:**
- `REVISION_SUMMARY` — Summary of how each annotation was addressed

---

## implement-load-output

Output format for implement/prompts/load-plan.md.

```
STATUS: OK | NO_PLAN
PLAN_FILE: <path>
SELECTED_STEPS: <comma-separated numbers or ALL>
TOTAL_STEPS: <number>
COMPLETED_STEPS: <number>
REMAINING_STEPS: <number>
CLAUDE_MD: EXISTS | NOT_FOUND

TOOLING:
TYPECHECK: <command or NONE>
LINT: <command or NONE>
TEST: <command or NONE>

CHECKLIST:
<raw checklist lines with line numbers>
```

**Fields:**
- `STATUS` — `OK`: plan loaded successfully, `NO_PLAN`: plan file not found
- `PLAN_FILE` — Path to the plan file
- `SELECTED_STEPS` — Steps to execute (comma-separated or ALL)
- `TOTAL_STEPS` — Total number of steps
- `COMPLETED_STEPS` — Number of completed steps
- `REMAINING_STEPS` — Number of remaining steps
- `CLAUDE_MD` — Whether CLAUDE.md exists
- `TOOLING` — Detected validation commands
- `CHECKLIST` — Checklist with line numbers
