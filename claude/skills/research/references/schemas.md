# Research Schemas

JSON Schema definitions for the research skill agent outputs.

See each agent file for inline JSON examples.

---

## research-scope-output

JSON Schema for research-planner agent output (Phase 1 of /research).

```json
{
  "$schema": "https://json-schema.org/draft/2020-12/schema",
  "type": "object",
  "required": ["status"],
  "properties": {
    "status": {
      "type": "string",
      "enum": ["OK", "NO_TOPIC"],
      "description": "OK: topic identified, NO_TOPIC: topic unclear"
    },
    "topic": { "type": "string", "description": "Topic string for analysis" },
    "scope": {
      "type": "string",
      "enum": ["broad", "focused"],
      "description": "Investigation scope"
    },
    "output": { "type": "string", "description": "Output filename (empty if not specified)" },
    "claude_md": {
      "type": "string",
      "enum": ["EXISTS", "NOT_FOUND"],
      "description": "Whether CLAUDE.md exists"
    },
    "project_type": { "type": "string", "description": "Detected project type" },
    "directory_structure": { "type": "string", "description": "Project directory structure (top 2 levels)" },
    "entry_points": {
      "type": "array",
      "items": { "type": "string" },
      "description": "List of file paths as investigation starting points"
    },
    "entry_point_count": { "type": "integer", "description": "Number of entry points" },
    "message": { "type": "string", "description": "User-facing message (for NO_TOPIC status)" }
  }
}
```

### Status variants
- `OK`: includes `topic`, `scope`, `output`, `claude_md`, `project_type`, `directory_structure`, `entry_points`, `entry_point_count`
- `NO_TOPIC`: includes `message`

---

## research-investigation-output

JSON Schema for research investigation guideline output (Phase 2 of /research).

```json
{
  "$schema": "https://json-schema.org/draft/2020-12/schema",
  "type": "object",
  "required": ["status"],
  "properties": {
    "status": {
      "type": "string",
      "enum": ["OK", "PARTIAL"],
      "description": "OK: investigation complete, PARTIAL: partial results"
    },
    "topic": { "type": "string", "description": "Investigation topic" },
    "files_investigated": { "type": "integer", "description": "Number of files investigated" },
    "overview": { "type": "string", "description": "Overview (2-3 sentences)" },
    "architecture": { "type": "string", "description": "Architecture description" },
    "components": {
      "type": "array",
      "items": {
        "type": "object",
        "properties": {
          "name": { "type": "string" },
          "file": { "type": "string" },
          "role": { "type": "string" },
          "depends_on": {
            "type": "array",
            "items": {
              "type": "object",
              "properties": {
                "name": { "type": "string" },
                "path": { "type": "string" },
                "why": { "type": "string" }
              }
            }
          },
          "depended_by": {
            "type": "array",
            "items": {
              "type": "object",
              "properties": {
                "name": { "type": "string" },
                "path": { "type": "string" },
                "how": { "type": "string" }
              }
            }
          },
          "key_functions": {
            "type": "array",
            "items": {
              "type": "object",
              "properties": {
                "name": { "type": "string" },
                "description": { "type": "string" }
              }
            }
          },
          "notes": { "type": "string" }
        }
      },
      "description": "Details of major components"
    },
    "data_flow": {
      "type": "array",
      "items": { "type": "string" },
      "description": "Data flow steps"
    },
    "patterns": {
      "type": "array",
      "items": { "type": "string" },
      "description": "Discovered patterns and conventions"
    },
    "risks": {
      "type": "array",
      "items": { "type": "string" },
      "description": "Risks and technical debt"
    },
    "file_list": {
      "type": "array",
      "items": {
        "type": "object",
        "properties": {
          "group": { "type": "string" },
          "files": {
            "type": "array",
            "items": { "type": "string" }
          }
        }
      },
      "description": "File list by role"
    },
    "findings": { "type": "string", "description": "What was found (when PARTIAL)" },
    "unclear": { "type": "string", "description": "Unclear points (when PARTIAL)" },
    "suggested_narrowing": { "type": "string", "description": "Suggestions for narrowing scope (when PARTIAL)" }
  }
}
```

### Status variants
- `OK`: includes all data fields (`topic`, `files_investigated`, `overview`, `architecture`, `components`, `data_flow`, `patterns`, `risks`, `file_list`)
- `PARTIAL`: includes `topic`, `files_investigated`, `findings`, `unclear`, `suggested_narrowing`
