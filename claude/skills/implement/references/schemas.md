# Implement Schemas

JSON Schema definitions for the implement skill agent outputs.

See each agent file for inline JSON examples.

---

## implement-load-output

JSON Schema for plan-reader agent output (Phase 1 of /implement).

```json
{
  "$schema": "https://json-schema.org/draft/2020-12/schema",
  "type": "object",
  "required": ["status"],
  "properties": {
    "status": {
      "type": "string",
      "enum": ["OK", "NO_PLAN"],
      "description": "OK: plan loaded successfully, NO_PLAN: plan file not found"
    },
    "plan_file": { "type": "string", "description": "Path to the plan file" },
    "selected_steps": {
      "type": "string",
      "description": "Steps to execute (comma-separated or 'ALL')"
    },
    "total_steps": { "type": "integer", "description": "Total number of steps" },
    "completed_steps": { "type": "integer", "description": "Number of completed steps" },
    "remaining_steps": { "type": "integer", "description": "Number of remaining steps" },
    "claude_md": {
      "type": "string",
      "enum": ["EXISTS", "NOT_FOUND"],
      "description": "Whether CLAUDE.md exists"
    },
    "tooling": {
      "type": "object",
      "properties": {
        "typecheck": { "type": "string", "description": "Type check command (or 'NONE')" },
        "lint": { "type": "string", "description": "Lint command (or 'NONE')" },
        "test": { "type": "string", "description": "Test command (or 'NONE')" }
      },
      "description": "Detected validation commands"
    },
    "checklist": {
      "type": "array",
      "items": { "type": "string" },
      "description": "Checklist lines with line numbers"
    },
    "message": { "type": "string", "description": "User-facing message (for NO_PLAN status)" }
  }
}
```

### Status variants
- `OK`: includes all data fields (`plan_file`, `selected_steps`, `total_steps`, `completed_steps`, `remaining_steps`, `claude_md`, `tooling`, `checklist`)
- `NO_PLAN`: includes `message`
