# Fix-CI Schemas

Subagent I/O format definitions for the fix-ci skill.

---

## fix-ci-collect-output

Output format for fix-ci/prompts/collect-logs.md.

```
STATUS: OK | GH_AUTH_REQUIRED | NO_REPO | NO_REMOTE | NO_FAILED_RUNS | RUN_NOT_FOUND
REPO: <owner/repo>
BRANCH: <branch>
RUN_ID: <number>
RUN_URL: <url>
WORKFLOW: <workflow-name>
LOG_TRUNCATED: true | false
FAILED_JOBS: <number>

=== WORKFLOW_FILE ===
<YAML content or WORKFLOW_FILE_NOT_FOUND>

=== FAILED_JOB: <job-name> (ID: <job-id>) ===
FAILED_STEP: <step-name or unknown>
LOG:
<log output>
```

**Fields:**
- `STATUS` — Collection result status
- `REPO` — Repository name (owner/repo format)
- `BRANCH` — Current branch name
- `RUN_ID` — Workflow run ID
- `RUN_URL` — Run URL on GitHub
- `WORKFLOW` — Workflow name
- `LOG_TRUNCATED` — Whether the log was truncated
- `FAILED_JOBS` — Number of failed jobs
- `WORKFLOW_FILE` — Workflow YAML content
- `FAILED_JOB` — Section for each failed job (may appear multiple times)

---

## fix-ci-analyze-output

Output format for fix-ci/prompts/analyze-failure.md.

Success:
```
STATUS: OK
CATEGORY: BUILD_ERROR | TEST_FAILURE | LINT_ERROR | DEPENDENCY_ERROR | ENV_CONFIG_ERROR | WORKFLOW_ERROR | TIMEOUT | FLAKY | OTHER
HYPOTHESIS: <string>
EVIDENCE:
- <evidence>
AFFECTED_FILES:
- <file path>
CONFIDENCE: HIGH | MEDIUM | LOW
SUGGESTED_ACTION: <string>
```

Unclear:
```
STATUS: UNCLEAR
PARTIAL_ANALYSIS: <string>
EVIDENCE:
- <evidence>
POSSIBLE_CAUSES:
- <possible cause>
```

**Fields:**
- `STATUS` — `OK`: cause identified, `UNCLEAR`: cause unknown
- `CATEGORY` — Failure category
- `HYPOTHESIS` — Hypothesis for the cause (in Japanese)
- `EVIDENCE` — List of evidence
- `AFFECTED_FILES` — List of affected files
- `CONFIDENCE` — Confidence level
- `SUGGESTED_ACTION` — Recommended action
- `PARTIAL_ANALYSIS` — Partial analysis result (when UNCLEAR)
- `POSSIBLE_CAUSES` — List of possible causes (when UNCLEAR)

---

## fix-ci-plan-output

Output format for fix-ci/prompts/create-fix-plan.md.

Success:
```
STATUS: OK
CHANGES:
1. FILE: <path>
   ACTION: modify | create | delete
   DESCRIPTION: <string>
   DETAIL: <string>

VERIFICATION: <string>
```

Insufficient information:
```
STATUS: NEEDS_INFO
QUESTION: <string>
```

**Fields:**
- `STATUS` — `OK`: plan created, `NEEDS_INFO`: additional information required
- `CHANGES` — List of changes (numbered)
  - `FILE` — Target file path
  - `ACTION` — Operation type
  - `DESCRIPTION` — Change description and reason (in Japanese)
  - `DETAIL` — Specific code change description
- `VERIFICATION` — Local verification method (in Japanese)
- `QUESTION` — Required additional information (when NEEDS_INFO, in Japanese)
