# Research → Plan → Implement パイプライン

Boris Tane氏の記事 [How I use Claude Code](https://boristane.com/blog/how-i-use-claude-code/) に触発されて作成した3つのSkill。
「コードを書く前に調べろ、調べたら計画を立てろ、計画が完璧になってから一気に実装しろ」というワークフローを Claude Code の Skill として形式化したもの。

---

## 3つのSkillの概要

| Skill | 役割 | 出力 |
|-------|------|------|
| `/research` | コードベースの深掘り調査 | `research-<topic>.md` |
| `/plan` | 注釈サイクル付き計画策定 | `plan.md` |
| `/implement` | 計画に基づく一気通貫実装 | コードの変更 + チェックリスト更新 |

### パイプラインの流れ

```
/research → 人間がレビュー → /plan → 注釈サイクル → /implement → /commit
```

各Skillは独立して使えるが、前のSkillの出力を次のSkillに引き渡すことで最大の効果を発揮する。

---

## `/research` — コードベース調査

### 概要

実装や計画の前に、対象領域のコードベースを深く調査し、構造化されたドキュメントとして出力する。
「理解していないコードを変更しない」ための最初のステップ。

### ファイル構成

```
.claude/skills/research/
├── SKILL.md
└── prompts/
    └── investigate.md    # 深掘り調査用subagentプロンプト
```

### フェーズ

1. **スコープ決定**（Bash subagent）— 関連ファイルの特定、プロジェクト構造の把握
2. **深掘り調査**（general-purpose subagent）— 全文読み、依存関係2階層追跡、データフロー分析
3. **ユーザーレビュー**（AskUserQuestion）— サマリー表示、追加調査 or ファイル出力
4. **ファイル出力**（main agent）— `research-<topic>.md` を生成、VSCodeで自動オープン

### 使い方

```bash
# 基本: キーワードで調査
/research "認証フロー"

# 特定ファイルを起点に調査
/research src/auth/middleware.ts

# スコープを絞って調査（上位5ファイルに限定）
/research "決済処理" --scope focused

# 出力ファイル名を指定
/research "API設計" --output api-research.md
```

### 出力ファイルの構成

| セクション | 内容 |
|-----------|------|
| 概要 | 2-3文の要約 |
| アーキテクチャ | コンポーネント関係、レイヤー構造 |
| 主要コンポーネント | 各コンポーネントの責務・依存先・依存元 |
| データフロー | データの流れをステップバイステップで記述 |
| 既存パターンと規約 | コードベースで使われているパターン |
| 依存関係 | 外部・内部の依存関係 |
| 注意点・リスク | 技術的負債やハマりポイント |
| 関連ファイル一覧 | 役割別にグループ化したファイル一覧 |

### 特徴

- ファイルは全文読み（head/tailでの部分読み禁止）
- 依存関係を最低2階層まで追跡（A→B→Bの依存先）
- 仮定を置く場合は `[ASSUMPTION]` プレフィックスで明示
- 追加調査で再実行する際は前回の結果を引き継ぎ、重複調査を防止

---

## `/plan` — 注釈サイクル付き計画策定

### 概要

タスクの実装計画を生成し、人間がインライン注釈を書き込んで改訂するサイクルを繰り返す。
計画が承認されるまで実装に進まない。

### ファイル構成

```
.claude/skills/plan/
├── SKILL.md
└── prompts/
    ├── generate-plan.md  # 初回計画生成用subagentプロンプト
    └── revise-plan.md    # 注釈反映・計画改訂用subagentプロンプト
```

### フェーズ

1. **コンテキスト収集**（Bash subagent）— 引数パース、research ファイル検索、プロジェクト構造把握
2. **計画生成**（general-purpose subagent）— タスク分析、コードベース調査、実装ステップ生成
3. **注釈サイクル**（main agent ループ）— plan.md 出力 → VSCode表示 → ユーザーレビュー → 注釈反映 → 再生成（繰り返し）
4. **確定**（main agent）— チェックリスト整合性確認、完了メッセージ

### 使い方

```bash
# 基本: タスクを説明して計画作成
/plan "ユーザー認証機能の追加"

# research の出力を活用
/plan "OAuth2.0対応の追加" --research research-認証フロー.md

# 出力ファイル名を指定
/plan "API v2 マイグレーション" --output migration-plan.md
```

### 注釈サイクルの流れ

1. Claude が `plan.md` を生成
2. VSCode で自動的に開かれる
3. ユーザーがファイルにインライン注釈を書き込む
4. Claude Code に戻って「注釈を反映」を選択
5. Claude が注釈を読み取り、計画を改訂
6. 2-5 を満足するまで繰り返す
7. 「承認」を選択して確定

### 対応する注釈フォーマット

ユーザーは以下の**どのフォーマットでも**注釈を書ける:

```markdown
<!-- これは必須にすべき -->
> NOTE: ここは不要
TODO: エラーハンドリングを追加
MEMO: 既存の UserService を使うべき
~~このステップは削除~~
[NOTE]: 別関数に分離すべき
```

注釈は以下の意図に分類されて反映される:
MODIFY（変更）、DELETE（削除）、ADD（追加）、QUESTION（質問）、REORDER（順序変更）、SPLIT（分割）、MERGE（結合）

### 出力ファイルの構成

| セクション | 内容 |
|-----------|------|
| 背景 | なぜこのタスクが必要か |
| ゴール | 成功の定義 |
| 実装ステップ | 対象ファイル・変更内容・理由・詳細（ステップごと） |
| テスト計画 | 検証方法 |
| リスクと考慮事項 | 注意点 |
| チェックリスト | `/implement` で使うチェックリスト |

---

## `/implement` — 計画ベースの一気通貫実装

### 概要

承認された計画ファイルを読み込み、チェックリストに沿ってステップバイステップで実装する。
各ステップ後に型チェック・lintを実行し、全ステップ完了まで止まらない。

### ファイル構成

```
.claude/skills/implement/
└── SKILL.md    # promptsは不要（main agentが直接実装）
```

### フェーズ

1. **計画読み込み & ツール検出**（Bash subagent）— plan.md のチェックリスト抽出、type check/lint/test コマンド自動検出
2. **スコープ確認**（AskUserQuestion）— 全ステップ or 部分実装の選択
3. **実装ループ**（main agent）— 各ステップ: 実装 → バリデーション → チェックリスト更新 → 次へ（確認なし）
4. **検証 & サマリー**（main agent）— テスト実行、git diff --stat、完了メッセージ

### 使い方

```bash
# 基本: デフォルトの plan.md を実装
/implement

# 特定の計画ファイルを指定
/implement migration-plan.md

# 特定のステップだけ実装
/implement --steps 1,3,5

# 途中再開（完了済みステップは自動スキップ）
/implement
```

### 自動検出されるバリデーションツール

| 言語 | Type Check | Lint | Test |
|------|-----------|------|------|
| TypeScript | `npx tsc --noEmit` | `npm run lint` | `npm run test` |
| Go | `go build ./...` | `golangci-lint run` | `go test ./...` |
| Python | `mypy .` | `ruff check .` | `pytest` |
| Rust | `cargo check` | `cargo clippy` | `cargo test` |

### 実装ループの動作

```
ステップ詳細を読む → 実装（Edit/Write）→ type check + lint
    ↑                                         ↓
    ↑                          失敗 → 修正 → 再バリデーション
    ↑                          成功 ↓
    ←←← チェックリスト更新 ←← 次のステップへ
```

- ステップ間でユーザー確認しない（「止まるな」の精神）
- type check + lint は毎ステップ実行（壊れたまま進まない）
- テストは最後に1回だけ（毎ステップだと遅すぎる）
- 計画にないこと（コメント追加、余計なリファクタ等）はしない

---

## 利用例: 完全なパイプライン

### 例1: 新機能追加

```bash
# 1. まず対象領域を調査
/research "ユーザープロフィール機能"
# → research-ユーザープロフィール機能.md が生成される
# → 内容を確認し、認識の誤りがないかチェック

# 2. 調査結果を基に計画を策定
/plan "プロフィール画像アップロード機能の追加" --research research-ユーザープロフィール機能.md
# → plan.md が生成され、VSCodeで開かれる
# → インライン注釈を書き込んで改訂を繰り返す
# → 計画が完璧になったら承認

# 3. 計画に沿って一気に実装
/implement
# → チェックリストに沿って全ステップ実装
# → 型チェック・lintが毎ステップ走る
# → 最後にテスト実行

# 4. コミット
/commit
```

### 例2: 部分的に使う

```bash
# 調査だけ使う（計画は自分で立てる）
/research "GraphQL resolvers" --scope focused

# 計画だけ使う（調査なしで直接計画）
/plan "エラーハンドリングの統一"

# 実装だけ使う（手書きの計画ファイルを渡す）
/implement my-plan.md

# 特定ステップだけ実装
/implement --steps 3,4,5
```

### 例3: 途中再開

```bash
# 前回の /implement が途中で止まった場合
/implement
# → チェックリストの完了済みステップは自動スキップ
# → 未完了のステップから再開
```
