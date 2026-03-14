# Fix-CI Schemas

JSON Schema definitions for the fix-ci skill agent outputs.

See each agent file and guideline for inline JSON examples.

---

## fix-ci-collect-output

JSON Schema for ci-log-collector agent output.

```json
{
  "$schema": "https://json-schema.org/draft/2020-12/schema",
  "type": "object",
  "required": ["status"],
  "properties": {
    "status": {
      "type": "string",
      "enum": ["OK", "GH_AUTH_REQUIRED", "NO_REPO", "NO_REMOTE", "NO_FAILED_RUNS", "RUN_NOT_FOUND"],
      "description": "Collection result status"
    },
    "repo": { "type": "string", "description": "Repository name (owner/repo format)" },
    "branch": { "type": "string", "description": "Current branch name" },
    "run_id": { "type": "integer", "description": "Workflow run ID" },
    "run_url": { "type": "string", "description": "Run URL on GitHub" },
    "workflow": { "type": "string", "description": "Workflow name" },
    "log_truncated": { "type": "boolean", "description": "Whether the log was truncated" },
    "workflow_file": { "type": "string", "description": "Workflow YAML content (or 'WORKFLOW_FILE_NOT_FOUND')" },
    "failed_jobs": {
      "type": "array",
      "items": {
        "type": "object",
        "required": ["job_name", "job_id"],
        "properties": {
          "job_name": { "type": "string", "description": "Failed job name" },
          "job_id": { "type": "string", "description": "Failed job ID" },
          "failed_step": { "type": "string", "description": "Failed step name (or 'unknown')" },
          "log": { "type": "string", "description": "Log output" }
        }
      },
      "description": "List of failed jobs with their logs"
    },
    "message": { "type": "string", "description": "User-facing message (for error statuses)" }
  }
}
```

### Status variants
- `OK`: includes `repo`, `branch`, `run_id`, `run_url`, `workflow`, `log_truncated`, `workflow_file`, `failed_jobs`
- Error statuses (`GH_AUTH_REQUIRED`, `NO_REPO`, `NO_REMOTE`, `NO_FAILED_RUNS`, `RUN_NOT_FOUND`): includes `message` only

---

## fix-ci-analyze-output

JSON Schema for analyze-failure guideline output.

```json
{
  "$schema": "https://json-schema.org/draft/2020-12/schema",
  "type": "object",
  "required": ["status"],
  "properties": {
    "status": {
      "type": "string",
      "enum": ["OK", "UNCLEAR"],
      "description": "OK: cause identified, UNCLEAR: cause unknown"
    },
    "category": {
      "type": "string",
      "enum": ["BUILD_ERROR", "TEST_FAILURE", "LINT_ERROR", "DEPENDENCY_ERROR", "ENV_CONFIG_ERROR", "WORKFLOW_ERROR", "TIMEOUT", "FLAKY", "OTHER"],
      "description": "Failure category"
    },
    "hypothesis": { "type": "string", "description": "Hypothesis for the cause (in Japanese)" },
    "evidence": {
      "type": "array",
      "items": { "type": "string" },
      "description": "List of evidence"
    },
    "affected_files": {
      "type": "array",
      "items": { "type": "string" },
      "description": "List of affected file paths"
    },
    "confidence": {
      "type": "string",
      "enum": ["HIGH", "MEDIUM", "LOW"],
      "description": "Confidence level"
    },
    "suggested_action": { "type": "string", "description": "Recommended action" },
    "partial_analysis": { "type": "string", "description": "Partial analysis result (when UNCLEAR)" },
    "possible_causes": {
      "type": "array",
      "items": { "type": "string" },
      "description": "List of possible causes (when UNCLEAR)"
    }
  }
}
```

### Status variants
- `OK`: includes `category`, `hypothesis`, `evidence`, `affected_files`, `confidence`, `suggested_action`
- `UNCLEAR`: includes `partial_analysis`, `evidence`, `possible_causes`

---

## fix-ci-plan-output

JSON Schema for create-fix-plan guideline output.

```json
{
  "$schema": "https://json-schema.org/draft/2020-12/schema",
  "type": "object",
  "required": ["status"],
  "properties": {
    "status": {
      "type": "string",
      "enum": ["OK", "NEEDS_INFO"],
      "description": "OK: plan created, NEEDS_INFO: additional information required"
    },
    "changes": {
      "type": "array",
      "items": {
        "type": "object",
        "required": ["file", "action", "description", "detail"],
        "properties": {
          "file": { "type": "string", "description": "Target file path" },
          "action": {
            "type": "string",
            "enum": ["modify", "create", "delete"],
            "description": "Operation type"
          },
          "description": { "type": "string", "description": "Change description and reason (in Japanese)" },
          "detail": { "type": "string", "description": "Specific code change description" }
        }
      },
      "description": "List of changes"
    },
    "verification": { "type": "string", "description": "Local verification method (in Japanese)" },
    "question": { "type": "string", "description": "Required additional information (when NEEDS_INFO, in Japanese)" }
  }
}
```

### Status variants
- `OK`: includes `changes` array, `verification`
- `NEEDS_INFO`: includes `question`
