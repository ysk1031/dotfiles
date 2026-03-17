# Design Schemas

JSON Schema definitions for the design skill agent outputs.

See each agent file for inline JSON examples.

---

## design-context-output

JSON Schema for project-profiler agent output (Phase 1 of /design).

```json
{
  "$schema": "https://json-schema.org/draft/2020-12/schema",
  "type": "object",
  "required": ["status"],
  "properties": {
    "status": {
      "type": "string",
      "enum": ["OK", "NO_TASK"],
      "description": "OK: context collection successful, NO_TASK: task not specified"
    },
    "task": { "type": "string", "description": "Task description" },
    "research_file": { "type": "string", "description": "Path to the specified research file ('NONE' if not specified)" },
    "research": {
      "type": "string",
      "enum": ["EXISTS", "NOT_FOUND", "NONE"],
      "description": "Research file status"
    },
    "available_research": {
      "type": "array",
      "items": { "type": "string" },
      "description": "List of research-*.md files in the current directory"
    },
    "output": { "type": "string", "description": "Output filename ('NONE' if not specified)" },
    "claude_md": {
      "type": "string",
      "enum": ["EXISTS", "NOT_FOUND"],
      "description": "Whether CLAUDE.md exists"
    },
    "project_type": { "type": "string", "description": "Detected project type" },
    "directory_structure": { "type": "string", "description": "Directory structure" },
    "recent_commits": {
      "type": "array",
      "items": { "type": "string" },
      "description": "Last 5 commits"
    },
    "message": { "type": "string", "description": "User-facing message (for NO_TASK status)" }
  }
}
```

### Status variants
- `OK`: includes all data fields (`task`, `research_file`, `research`, `available_research`, `output`, `claude_md`, `project_type`, `directory_structure`, `recent_commits`)
- `NO_TASK`: includes `message`

---

## design-generation-output

JSON Schema for plan generation guideline output (Phase 2 of /design). Guidelines: design/generate-plan.md.

```json
{
  "$schema": "https://json-schema.org/draft/2020-12/schema",
  "type": "object",
  "required": ["status"],
  "properties": {
    "status": {
      "type": "string",
      "const": "OK",
      "description": "Always OK"
    },
    "background": { "type": "string", "description": "Background description of the task" },
    "goal": { "type": "string", "description": "Definition of success (specific, measurable outcomes)" },
    "steps": {
      "type": "array",
      "items": {
        "type": "object",
        "required": ["number", "title", "target", "action", "changes", "reason", "detail"],
        "properties": {
          "number": { "type": "integer", "description": "Step number" },
          "title": { "type": "string", "description": "Step title" },
          "target": { "type": "string", "description": "Target file path" },
          "action": {
            "type": "string",
            "enum": ["create", "modify", "delete"],
            "description": "Operation type"
          },
          "changes": { "type": "string", "description": "Specific changes to make" },
          "reason": { "type": "string", "description": "Why this change is needed" },
          "detail": { "type": "string", "description": "Detailed description" }
        }
      },
      "description": "Implementation steps"
    },
    "testing": { "type": "string", "description": "Test plan" },
    "risks": {
      "type": "array",
      "items": {
        "type": "object",
        "properties": {
          "risk": { "type": "string", "description": "Risk description" },
          "mitigation": { "type": "string", "description": "Mitigation strategy" }
        }
      },
      "description": "Risks and mitigations"
    },
    "checklist": {
      "type": "array",
      "items": { "type": "string" },
      "description": "Checklist items (e.g., 'Step 1: brief description')"
    }
  }
}
```

---

## design-revision-output

JSON Schema for plan revision guideline output (annotation cycle of /design). Guidelines: design/revise-plan.md.

Same structure as design-generation-output, with an additional field:

```json
{
  "$schema": "https://json-schema.org/draft/2020-12/schema",
  "type": "object",
  "required": ["status", "revision_summary"],
  "properties": {
    "status": { "type": "string", "const": "OK" },
    "revision_summary": {
      "type": "string",
      "description": "Summary of how each annotation was addressed"
    },
    "background": { "type": "string" },
    "goal": { "type": "string" },
    "steps": {
      "type": "array",
      "items": {
        "type": "object",
        "required": ["number", "title", "target", "action", "changes", "reason", "detail"],
        "properties": {
          "number": { "type": "integer" },
          "title": { "type": "string" },
          "target": { "type": "string" },
          "action": { "type": "string", "enum": ["create", "modify", "delete"] },
          "changes": { "type": "string" },
          "reason": { "type": "string" },
          "detail": { "type": "string" }
        }
      }
    },
    "testing": { "type": "string" },
    "risks": {
      "type": "array",
      "items": {
        "type": "object",
        "properties": {
          "risk": { "type": "string" },
          "mitigation": { "type": "string" }
        }
      }
    },
    "checklist": {
      "type": "array",
      "items": { "type": "string" }
    }
  }
}
```
