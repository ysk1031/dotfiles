# カスタムsubagentに関する設計方針

## Skill と カスタムsubagent の違い

| | Skill (`skills/`) | カスタムsubagent (`agents/`) |
|---|---|---|
| **役割** | ワークフローの**オーケストレーション**（フェーズの流れ、ユーザー確認ゲート） | 特定の作業を実行する**専門家** |
| **起動方法** | ユーザーが `/command` で呼ぶ | Skillやmain agentが `Task` ツールで呼ぶ |
| **持つもの** | フロー定義、引数、allowed-tools | ペルソナ、専門知識、行動原則、tools制限、model指定 |
| **例え** | プロジェクトマネージャー | ドメイン専門家 |

Skill と カスタムsubagent は**競合関係ではなく補完関係**で、関係性は**双方向**。

---

## 双方向の関係性

### パターン A: Skill → subagent を呼ぶ

Skill の frontmatter で `context: fork` + `agent:` を指定すると、そのSkill自体がカスタムsubagentとして実行される。

```yaml
# skills/deep-research/SKILL.md
---
name: deep-research
context: fork
agent: explorer     # agents/explorer.md を使って実行
---
探索を実施してください...
```

```yaml
# agents/explorer.md
---
name: explorer
description: Codebase exploration specialist
tools: Read, Grep, Glob, Bash
model: haiku
---
You are a codebase explorer...
```

この場合、Skillの内容が `explorer` subagent のコンテキストで実行される。

### パターン B: subagent が Skill を持つ

subagent の frontmatter で `skills:` を指定すると、Skillの内容がsubagentのコンテキストに**事前注入**される。

```yaml
# agents/api-developer.md
---
name: api-developer
description: API endpoint implementation specialist
tools: Read, Write, Edit, Bash
model: sonnet
skills:
  - rest-conventions     # skills/rest-conventions/ の内容を preload
  - error-handling       # skills/error-handling/ の内容を preload
---
You are an API developer. Follow the preloaded convention skills...
```

この場合、subagent は最初から Skill の知識を持った状態で起動する（呼び出すのではなく、コンテキストに注入）。

### 関係図

```
Main Conversation
    │
    ├── /command でSkill起動
    │   ├── context: default → main agentが直接実行
    │   ├── context: fork → forked agentとして隔離実行（メインコンテキスト非消費）
    │   └── context: fork + agent: <name> → カスタムsubagentとして実行（パターンA）
    │
    └── Task ツールでsubagent起動
        └── subagent の skills: [...] → Skillの知識を事前注入（パターンB）
```

`context: fork`（`agent:` なし）は、Skillをforked agentで実行するがカスタムsubagentは使わない。Skill内部のプロンプトがそのままforked agentの指示として使われ、その中からさらにTask経由でsubagentを呼べる。現在 `/research`、`/plan` がこのパターンで実行されている。

---

## カスタムsubagent の frontmatter 仕様

| フィールド | 必須 | 説明 |
|-----------|------|------|
| `name` | Yes | agent ID（lowercase-hyphenated） |
| `description` | Yes | Claude が agent を選択する際の判断基準 |
| `tools` | No | 使用許可ツールのホワイトリスト。省略時は全ツール継承 |
| `disallowedTools` | No | 使用禁止ツールのブラックリスト |
| `model` | No | `sonnet`, `opus`, `haiku`, `inherit`（デフォルト: inherit） |
| `permissionMode` | No | `default`, `acceptEdits`, `dontAsk`, `bypassPermissions`, `plan` |
| `maxTurns` | No | 最大 agentic turn 数。超過時に自動停止 |
| `skills` | No | preload する Skill リスト |
| `mcpServers` | No | 利用可能な MCP server リスト |
| `hooks` | No | subagent 固有のライフサイクルフック |
| `background` | No | `true` 時は常にバックグラウンド実行 |
| `isolation` | No | `worktree` 時は隔離された Git worktree で実行 |

### 制約事項

- subagent は さらに subagent を spawn できない（ネスト不可）
- subagent は親の Skill を自動継承しない（明示的に `skills:` で指定が必要）
- `description` に「Proactively」を含めると自動委譲が増える

---

## 現在の設計

`prompts/*.md` ファイルがsubagentの「キャラ付け」を実質的に担い、`/research` と `/plan` は `context: fork` でメインコンテキストから隔離実行される。

```
/research (Skill, context: fork)
  └→ forked agent がオーケストレーション
      ├→ Bash subagent（スコープ決定）
      └→ general-purpose subagent + prompts/investigate.md（深掘り調査）

/plan (Skill, context: fork)
  └→ forked agent がオーケストレーション
      ├→ Bash subagent（コンテキスト収集）
      ├→ general-purpose subagent + prompts/generate-plan.md（計画生成）
      └→ general-purpose subagent + prompts/revise-plan.md（注釈反映）

/implement (Skill, disable-model-invocation)
  └→ main agent が直接実装（Bash subagentで計画読み込み・ツール検出）
```

この方式で現時点では十分に機能しており、カスタムsubagentを導入する必要性は低い。

---

## カスタムsubagentが活きるケース

### 1. 横断的な専門家

複数のSkillから共通で呼びたい専門家がいる場合。

例: `security-reviewer` subagent
- `/implement` の実装後チェックで呼ぶ
- `/code-simplifier` の分析フェーズで呼ぶ
- `/fix-ci` の原因分析で呼ぶ

→ セキュリティの観点が1箇所で定義され、全Skillで一貫した品質基準を保てる。

### 2. ドメイン特化の知識

特定のツールやフレームワークに深い知識を持つ専門家。

例: `database-migration-expert` subagent
- 特定のORM（Prisma, GORM等）のベストプラクティスを知っている
- マイグレーションの安全な手順を熟知している
- データ整合性のリスクを評価できる

### 3. チーム固有の規約の守護者

「うちのチームではこう書く」を知っている存在。

例: `style-enforcer` subagent
- コーディング規約、アーキテクチャルール、命名規則を把握
- 複数のSkillから共通で呼ばれ、一貫したスタイルを維持

### 4. 外部API連携の専門家

例: `github-api-specialist` subagent
- `/pr`, `/fix-ci`, `/weekly-report` で共通して使うGitHub操作のパターンを集約

### 5. 知識を持つ実装者（パターンBの活用）

Skillをpreloadすることで、コーディング規約やパターン集を「知っている」状態で実装できる。

例: `frontend-developer` subagent
```yaml
---
name: frontend-developer
skills:
  - component-patterns    # コンポーネント設計規約
  - styling-conventions   # CSS/スタイリング規約
---
```

→ Skill を「呼び出す」のではなく「知識として持つ」ので、実装中に自然に規約に従える。

---

## カスタムsubagentが不要なケース

1. **そのsubagentを使うSkillが1つだけ** → `prompts/*.md` で十分
2. **ビルトインsubagent（general-purpose, Bash, code-simplifier）で事足りる** → カスタム化の恩恵が薄い
3. **「専門知識」が実はタスク固有の指示** → subagentではなくプロンプトに書くべき

---

## 方針

### 今すぐやること: なし

現在の `prompts/*.md` 方式で十分機能している。
カスタムsubagentを導入しても、間接層が増えるだけで実質的な改善は少ない。

### 導入のタイミング

**3つのSkillを実際に使い込んで、以下のサインが見えたら**subagent化を検討する:

1. **同じ行動原則を複数の `prompts/*.md` にコピペしている** → 共通のsubagentに抽出
2. **「この専門知識は他のSkillでも使いたい」と感じる** → ドメイン特化subagentを作成
3. **Skillのプロンプトが肥大化して見通しが悪い** → 専門家の責務をsubagentに分離
4. **Skillの知識をsubagentに持たせたい** → `skills:` preload パターンを活用

### 最初の候補

導入するとしたら `deep-research` subagent が最有力:
- `/research` と `/plan` の両方で「コードベースを深く読む」作業がある
- 「全文読み、2階層追跡、仮定明示」という行動原則が共通
- 現状は `prompts/investigate.md` と `prompts/generate-plan.md` に重複して記述がある

ただしこれも「使ってみて共通化の必要性を実感してから」で遅くない。
