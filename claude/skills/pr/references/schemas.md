# PR Schemas

JSON Schema definitions for the pr skill agent outputs.

See each agent file for inline JSON examples.

---

## pr-analyze-output

JSON Schema for pr-composer agent output.

```json
{
  "$schema": "https://json-schema.org/draft/2020-12/schema",
  "type": "object",
  "required": ["status"],
  "properties": {
    "status": {
      "type": "string",
      "enum": ["OK", "ASK_LANGUAGE", "NOT_ON_BRANCH", "NO_BASE", "NO_COMMITS", "NO_CHANGES"]
    },
    "base": { "type": "string", "description": "Base branch name" },
    "draft": { "type": "boolean", "description": "Whether it is a draft PR" },
    "unpushed_count": {
      "oneOf": [
        { "type": "integer" },
        { "type": "string", "const": "all" }
      ],
      "description": "Number of unpushed commits ('all' when remote not set)"
    },
    "unpushed_commits": {
      "type": "array",
      "items": { "type": "string" },
      "description": "List of unpushed commit one-liners"
    },
    "title": { "type": "string", "description": "PR title" },
    "body": { "type": "string", "description": "PR description (Markdown)" },
    "commits": {
      "type": "array",
      "items": { "type": "string" },
      "description": "List of commits (for ASK_LANGUAGE status)"
    },
    "diff_stat": { "type": "string", "description": "Diff stat output (for ASK_LANGUAGE status)" },
    "message": { "type": "string", "description": "User-facing message (for error statuses)" }
  }
}
```

### Status variants
- `OK`: includes `base`, `draft`, `unpushed_count`, `unpushed_commits`, `title`, `body`
- `ASK_LANGUAGE`: includes `base`, `commits`, `diff_stat`, `message`
- Error statuses (`NOT_ON_BRANCH`, `NO_BASE`, `NO_COMMITS`, `NO_CHANGES`): includes `message` only
