# Plan Generation Guidelines

Guidelines for the plan generation subagent to follow when creating implementation plans.

---

## Planning Process

### Step 1: Understand the Task

Parse the task description and identify:
- What needs to be built or changed
- What the expected outcome is
- Any constraints or requirements mentioned

### Step 2: Investigate the Codebase

If a research file exists, read it thoroughly — it contains pre-analyzed codebase information.

Regardless of whether a research file exists, perform targeted investigation:
1. Read CLAUDE.md if it exists to understand project conventions
2. Use Grep/Glob to find files related to the task
3. Read the most relevant files to understand current implementation
4. Identify existing patterns that the new implementation should follow
5. Check for existing tests to understand the testing approach

### Step 3: Design the Solution

Based on your investigation:
1. Determine which files need to be created or modified
2. Design the changes to align with existing patterns and conventions
3. Identify the correct order of implementation (dependencies first)
4. Consider edge cases and error handling
5. Plan how to test the changes

**Output schema**: See `~/.claude/skills/develop/references/schemas.md#design-generation-output` for the canonical format.

### Step 4: Generate the Plan

Return your output as a JSON code block.

```json
{
  "status": "OK",
  "background": "現在の認証はセッションベースで実装されているが、マイクロサービス化に伴いJWTベースに移行する必要がある。",
  "goal": "JWT認証ミドルウェアを実装し、既存の全APIエンドポイントで動作することを確認する。",
  "steps": [
    {
      "number": 1,
      "title": "JWT型定義の追加",
      "target": "src/types/auth.ts",
      "action": "create",
      "changes": "JWTペイロードとトークンレスポンスの型定義を追加",
      "reason": "型安全性を確保するため、実装前に型を定義する",
      "detail": "JwtPayload interface (sub, iat, exp) と TokenResponse interface (access_token, refresh_token, expires_in) を定義する。"
    },
    {
      "number": 2,
      "title": "認証ミドルウェアの実装",
      "target": "src/auth/middleware.ts",
      "action": "create",
      "changes": "JWTトークン検証ミドルウェアを実装",
      "reason": "全APIエンドポイントで共通の認証処理が必要",
      "detail": "Express middleware として実装。Authorization ヘッダーから Bearer トークンを抽出し、jsonwebtoken で検証する。"
    }
  ],
  "testing": "1. npm run test で全テストが通ることを確認\n2. curl でJWT付きリクエストが認証されることを確認",
  "risks": [
    { "risk": "既存セッション認証との併存期間が必要", "mitigation": "Feature flagで切り替え可能にする" }
  ],
  "checklist": [
    "Step 1: JWT型定義の追加",
    "Step 2: 認証ミドルウェアの実装"
  ]
}
```

---

## Important Rules

- NEVER modify any files — read-only analysis and planning
- Each step MUST specify concrete file paths, not vague references
- Each step MUST be atomic — one logical change per step
- Order steps by dependency — foundational changes first
- Include type definitions and interfaces before implementations
- Reference existing code patterns: "Follow the pattern in `<file>`"
- If the task is too large, break it into phases with clear boundaries
- If critical information is missing, note it as `[NEEDS_CLARIFICATION]: <question>`
- Include code snippets in DETAIL when they help clarify intent, but keep them focused on structure rather than complete implementations
- Consider backwards compatibility and migration needs
