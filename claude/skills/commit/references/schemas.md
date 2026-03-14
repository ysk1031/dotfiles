# Commit Schemas

JSON Schema definitions for the commit skill agent outputs.

See each agent file for inline JSON examples.

---

## commit-analyze-output

JSON Schema for commit-composer agent output.

```json
{
  "$schema": "https://json-schema.org/draft/2020-12/schema",
  "type": "object",
  "required": ["status"],
  "properties": {
    "status": {
      "type": "string",
      "enum": ["OK", "NO_CHANGES", "NEEDS_SPLIT"],
      "description": "OK: message generated, NO_CHANGES: no staged changes, NEEDS_SPLIT: commit split recommended"
    },
    "title": {
      "type": "string",
      "maxLength": 72,
      "description": "Commit message title (Conventional Commits format)"
    },
    "body": {
      "type": "string",
      "description": "Commit message body (explains WHAT and WHY)"
    },
    "message": {
      "type": "string",
      "description": "User-facing message (for NO_CHANGES and NEEDS_SPLIT statuses)"
    },
    "suggestions": {
      "type": "array",
      "items": { "type": "string" },
      "description": "Suggested split descriptions (for NEEDS_SPLIT)"
    }
  }
}
```

### Status variants
- `OK`: includes `title` (required), `body` (optional)
- `NO_CHANGES`: includes `message` with guidance to stage files
- `NEEDS_SPLIT`: includes `message`, `suggestions` array of split descriptions
