# Investigation Guidelines

Guidelines for the codebase investigation subagent to follow when conducting deep research.

---

## Investigation Process

### Step 1: Read Entry Points Thoroughly

For each entry point file from the Scope Data:
- Read the ENTIRE file using the Read tool (do NOT skip or skim)
- Identify: exports, public API, key functions/methods, types/interfaces, class hierarchy

If CLAUDE.md exists, read it first to understand project conventions.

### Step 2: Trace Dependencies (at least 2 levels deep)

For each entry point:

**Outgoing dependencies (what this file imports/uses)**:
1. Identify all imports/requires/uses
2. Read each imported module (Level 1)
3. For critical dependencies, read THEIR imports too (Level 2)
4. Record the dependency chain

**Incoming dependencies (what uses this file)**:
1. Use Grep to find all files that import/reference the entry point
2. Read the most relevant callers to understand usage patterns
3. Note how the public API is consumed

### Step 3: Understand Data Flow

Trace how data moves through the system for this topic:
1. Identify entry points (API endpoints, UI events, CLI commands, etc.)
2. Follow the data through each layer (controller → service → repository, etc.)
3. Note transformations, validations, and side effects at each step
4. Identify where state is stored and how it's accessed

### Step 4: Identify Patterns and Conventions

Look for:
- Design patterns used (repository, factory, observer, middleware, etc.)
- Naming conventions (file names, function names, variable names)
- Error handling patterns
- Testing patterns (unit, integration, mocking strategies)
- Configuration patterns

### Step 5: Assess Risks and Technical Debt

Note:
- Complex or fragile code that could break easily
- Missing error handling or edge cases
- Tight coupling between components
- Performance concerns (N+1 queries, unnecessary re-renders, etc.)
- Security considerations
- Outdated dependencies or deprecated API usage

**Output schema**: See `~/.claude/skills/develop/references/schemas.md#research-investigation-output` for the canonical format.

### Step 6: Compile Research Report

Return your output as a JSON code block.

Success:
```json
{
  "status": "OK",
  "topic": "認証フロー",
  "files_investigated": 12,
  "overview": "認証はJWTベースで実装されており、middlewareでトークン検証を行う。セッション管理はRedisに委譲されている。",
  "architecture": "3層アーキテクチャ: Controller → Service → Repository。認証はmiddlewareとしてController層の前段に配置。",
  "components": [
    {
      "name": "AuthMiddleware",
      "file": "src/auth/middleware.ts",
      "role": "リクエストのJWTトークンを検証し、ユーザー情報をコンテキストに注入する",
      "depends_on": [
        { "name": "TokenService", "path": "src/auth/token.ts", "why": "JWT検証ロジック" }
      ],
      "depended_by": [
        { "name": "Router", "path": "src/api/routes.ts", "how": "全認証必須エンドポイントで使用" }
      ],
      "key_functions": [
        { "name": "authenticate", "description": "JWTトークンを検証してユーザーを返す" }
      ],
      "notes": "エラー時は401を返す"
    }
  ],
  "data_flow": [
    "1. クライアントがAuthorizationヘッダーにJWTを付与してリクエスト",
    "2. AuthMiddlewareがトークンを検証",
    "3. 検証成功時、req.userにユーザー情報を格納",
    "4. Controllerがreq.userを参照して処理を実行"
  ],
  "patterns": ["Repository パターン: データアクセスはRepository層に集約", "Middleware チェーン: Express middlewareで横断的関心事を処理"],
  "risks": ["JWT秘密鍵がハードコードされている (src/config.ts:15)", "トークン失効チェックが未実装"],
  "file_list": [
    { "group": "認証コア", "files": ["src/auth/middleware.ts", "src/auth/token.ts"] },
    { "group": "テスト", "files": ["tests/auth.test.ts"] }
  ]
}
```

If the investigation is inconclusive or the topic is too broad:
```json
{
  "status": "PARTIAL",
  "topic": "認証フロー",
  "files_investigated": 5,
  "findings": "認証ミドルウェアの基本構造は把握できたが、OAuth連携部分は別モジュールに分離されている",
  "unclear": "OAuth2.0のトークンリフレッシュフローの詳細",
  "suggested_narrowing": "OAuth連携に絞って /research src/auth/oauth/ で再調査を推奨"
}
```

---

## Important Rules

- NEVER modify any files — read-only investigation
- Read files in FULL — do NOT use partial reads unless the file exceeds 1000 lines
- When a file exceeds 1000 lines, read it in chunks but DO read all of it
- Trace dependencies at LEAST 2 levels deep
- If you make assumptions, prefix them with "[ASSUMPTION]"
- Investigate at least 3 callers/consumers for each major component
- For "broad" scope: investigate all entry points and related tests, configs, and types
- For "focused" scope: concentrate on the core files and their immediate dependencies
- If previous findings are provided, build on them — do NOT repeat the same investigation
- Prioritize understanding the "why" behind design decisions, not just the "what"
