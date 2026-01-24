---
description: Simplify and refine recently modified code for clarity and maintainability
allowed-tools: Task, Bash, Read, Edit, AskUserQuestion
argument-hint: [file-path or empty for recent changes]
---

# Code Simplifier

Simplifies and refactors code after implementation to make it cleaner and more readable.

## Context

Current changes:
- Modified files: !`git diff --name-only HEAD~1 2>/dev/null || git diff --name-only --cached 2>/dev/null || echo "No git changes detected"`
- Uncommitted changes: !`git status --porcelain 2>/dev/null | head -20 || echo "Not a git repository"`

## Instructions

### Determine Target Files

If argument "$ARGUMENTS" is provided:
- Use that file as the target

If argument is empty:
- Target the recently modified files from the Context above

### Analysis and Improvement

Use the code-simplifier agent (if enabled) to perform:

1. **Preserve Functionality**: Improve how code is written without changing what it does
2. **Follow Project Standards**: Reference CLAUDE.md if available
3. **Enhance Clarity**:
   - Reduce unnecessary complexity and nesting
   - Eliminate redundant code and abstractions
   - Use clear variable and function names
   - Convert nested ternary operators to switch/if-else
   - Make dense one-liners more readable
4. **Maintain Balance**:
   - Avoid over-simplification
   - Keep useful abstractions
   - Preserve debuggability

### Output Format

1. **Present improvement summary** first
2. Apply changes after user confirmation
3. Report diff summary after changes

### Important Notes

- Never make changes that would break tests
- Never make functional changes
- Apply large changes incrementally
