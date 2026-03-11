# CI Failure Analysis Guidelines

Guidelines for the CI failure analysis subagent to follow when diagnosing workflow failures.

**Step 1: Error Pattern Analysis**

Analyze the failure logs and classify the error into one of these categories:
- BUILD_ERROR: Compilation or build failure
- TEST_FAILURE: Test assertion or test execution failure
- LINT_ERROR: Linting or formatting violation
- DEPENDENCY_ERROR: Missing or incompatible dependency
- ENV_CONFIG_ERROR: Environment variable or configuration issue
- WORKFLOW_ERROR: GitHub Actions workflow YAML issue
- TIMEOUT: Job or step timeout
- FLAKY: Intermittent/non-deterministic failure (race condition, network, etc.)
- OTHER: None of the above

**Step 2: Codebase Investigation**

Based on error messages, investigate the codebase:
- Search for file paths and line numbers mentioned in the error logs using Read, Grep, and Glob
- Check if the error references specific functions or modules
- Look at recent changes: run `git diff HEAD~3..HEAD -- <affected-files>` via Bash to see if recent commits caused the issue

**Step 3: Flaky Test Detection**

If the error looks like a timeout, race condition, or network-related intermittent failure:
- Set CONFIDENCE to LOW
- Note that a re-run might resolve it

**Step 4: Multiple Job Failure Analysis**

If multiple jobs failed:
- Determine if failures are independent (different root causes) or cascading (one root cause)
- If independent, form separate hypotheses for each
- If cascading, identify the root cause

**Output schema**: See `~/.claude/skills/fix-ci/references/schemas.md#fix-ci-analyze-output` for the canonical format.

**Step 5: Form Hypothesis**

Return in this format:
```
STATUS: OK
CATEGORY: <failure category from Step 1>
HYPOTHESIS: <1-3 sentence explanation of the root cause in Japanese>
EVIDENCE:
- <evidence 1>
- <evidence 2>
- <evidence 3>
AFFECTED_FILES:
- <file path 1>
- <file path 2>
CONFIDENCE: <HIGH/MEDIUM/LOW>
SUGGESTED_ACTION: <brief description of what needs to change>
```

If the cause cannot be determined:
```
STATUS: UNCLEAR
PARTIAL_ANALYSIS: <what you could determine in Japanese>
EVIDENCE:
- <evidence 1>
POSSIBLE_CAUSES:
- <possible cause 1>
- <possible cause 2>
```
