# Pipeline Schemas

JSON Schema definitions for the pipeline skill agent outputs (research, design, implement).

See each agent file and guideline for inline JSON examples.

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
