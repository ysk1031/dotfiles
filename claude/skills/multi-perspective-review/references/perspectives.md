# Perspective catalog

Each perspective is a three-part set: role declaration, when it helps, and a
checklist. The prefix is used in finding IDs (e.g. P-1) so findings stay
traceable to their source after merging.

Role declarations and checklist items are written in Japanese because they get
embedded verbatim into the Japanese subagent prompt skeleton (see SKILL.md).
The guidance around them is in English.

Recommendation guidance:

- **Language pro, library pro, and the senior architect are the default slots**
  — recommend all three unless a slot's exclusion condition below is met.
  Language/library content can be concretized from the manifest; the architect
  earns its slot on the deep structural side (dependency direction, boundary
  design), leaving routine convention checks (naming, placement of new public
  types) to pre-pr-check.
  - **Drop the architect** only when the diff has no new or changed public type,
    module boundary, or inter-module dependency, and triggers no placement
    judgment (e.g. a single-purpose bug fix, a constant tweak, or a mechanical
    rename across many files). Number of files touched is not the signal — a
    one-file change can introduce a boundary, and a ten-file rename may hold no
    structural judgment at all.
  - **Drop the library pro** when the diff uses no framework, ORM, task queue,
    or external SDK and touches no name-wired integration (routes, DI
    registration, ORM relations) — its idioms are then covered by the language
    pro. You can judge this from the diff itself; the manifest detected later
    only confirms it. If genuinely unsure, keep it.
  - **The language pro effectively never drops**: any code change has
    language-level structure (types, iteration, error handling) worth a look.
- **The domain expert yields the highest-value findings when a spec doc
  exists.** Without a doc, drop it — running it unprepared only produces
  generic remarks.
- Pick the rest based on which layers the diff touches. When in doubt, use
  "drop it unless the diff touches that layer" to narrow down.
- **Whenever you drop a default slot, say so with a one-line reason** in the
  confirmation step, so the removal is visible to the user rather than silent.

## Language professional (prefix: P)

- **Role declaration**: `{言語} {バージョン} のプロフェッショナル`
  (fill from the detected manifest)
- **When it helps**: almost always; the more new code, the more it pays off
- **Checklist**:
  - データ構造・型の使い方（不変化できる箇所、型注釈の具体化）
  - イテレーション・データ変換の簡潔化と重複排除
  - 例外処理・リソース管理（コンテキストマネージャ等、言語の標準的な後始末パターン）
  - 関数の分割と凝集度（1関数に複数の関心が混ざっていないか）
  - 日時・タイムゾーンの扱い
  - テストコードの品質（fixture 共通化・パラメタライズ・重複）
  - パフォーマンスは「明らかな無駄」のみ（マイクロ最適化は出さない）

## Library professional (prefix: L)

- **Role declaration**: `{主要ライブラリの列挙} のプロフェッショナル`
  (fill from the detected manifest)
- **When it helps**: when the diff includes code using frameworks, ORMs, task
  queues, or external SDKs
- **Checklist**:
  - 各ライブラリのイディオム・推奨パターンとの整合
  - 既存コードベースの慣習とのズレ（**見つけたら必ず指摘**、と観点固有指示に書く）
  - ライブラリの標準機能で自前実装を置き換えられる箇所
  - セッション・接続・トランザクションなどリソース管理のパターン
  - 非推奨 API・古い書き方の使用
  - 設定値・オプションのデフォルト依存が意図的か

## Senior architect (prefix: A)

- **Role declaration**: `このコードベース全体の構造に責任を持つシニアアーキテクト`
- **When it helps**: a default slot — include it unless the exclusion condition
  in the recommendation guidance is met. It pays off on changes that span
  multiple files or introduce a new public type or module boundary, not only on
  brand-new modules.
- **Checklist** (weighted toward deep structure; leave routine convention
  checks to pre-pr-check):
  - レイヤ間の依存方向（循環・レイヤ飛び越え）
  - 境界の型・インターフェースが将来の差し替えに耐えるか
  - 責務分割（大きすぎるモジュール・クラス、関心の混在）
  - テスト構造がリファクタの安全網として十分か
  - 命名の一貫性・定数の置き場所は、**深い構造上の問題を示しているときだけ**触れる
    （単なる表記ゆれ・置き場所の好みは pre-pr-check の担当なので出さない）
- **Perspective-specific instruction**: emphasize "works now but will hurt
  later"; do not raise matters of taste, and defer routine naming/placement
  nits to pre-pr-check
  （`「動くが将来困る」系を重視し、好みの問題は出さない。命名・置き場所の定型指摘は pre-pr-check に譲る` として渡す）

## Domain expert (prefix: D)

- **Role declaration**: `{対象ドメイン} の仕様に精通したドメインエキスパート`
- **When it helps**: when a spec doc exists and the diff implements domain
  rules (decisions, calculations, state transitions). **The most preparation,
  but it surfaces the highest-value findings (code-vs-spec mismatches).**
- **Preparation**: name the spec docs to read explicitly in the prompt (this
  is the crux — do not run it without asking the user).
- **Checklist**:
  - ドメインルールがコード上で仕様と同じ語彙・構造で読めるか
  - ドメイン概念の命名の一貫性（同じ概念に複数の名前が無いか）
  - 外部システムとの契約（enum・コード値・スキーマ）が1箇所の定義元から導出されているか
  - しきい値定数に意味の分かる名前があるか
  - テストが仕様の分岐を文書化しているか
- **Perspective-specific instruction**: report code-vs-spec mismatches as the
  **highest-priority separate bucket**
  （`コードと仕様の食い違いは最重要の別枠として報告する` として渡す）

## Security (prefix: S)

- **Role declaration**: `アプリケーションセキュリティの専門家`
- **When it helps**: when the diff includes authn/authz, handling of external
  input, secrets, or building of SQL/commands/templates
- **Checklist**:
  - 外部入力のバリデーションとエスケープ（SQL・コマンド・パスの組み立て箇所）
  - 認可チェックの漏れ（誰でも呼べるようになっていないか）
  - 秘密情報の扱い（ハードコード・ログ出力・エラーメッセージへの混入）
  - 権限の広すぎるデフォルト
  - 依存ライブラリの既知の危険な使い方
- **Perspective-specific instruction**: report exploitable issues as the
  **top-priority separate bucket** regardless of whether they preserve behavior
  （`攻撃可能な問題は挙動不変かどうかに関係なく別枠の最優先で報告する` として渡す）

## Performance and scale (prefix: PS)

- **Role declaration**: `データ量とトラフィックの伸びに責任を持つパフォーマンスエンジニア`
- **When it helps**: when the diff includes DB queries, batch processing,
  I/O inside loops, or large data structures
- **Checklist**:
  - N+1 クエリ、ループ内の I/O・API 呼び出し
  - データ量が10倍・100倍になったときに壊れる箇所（全件ロード・無制限クエリ）
  - インデックスの効かないクエリパターン
  - 不要な再計算・キャッシュできる箇所
  - メモリに全部載せる前提の処理
- **Perspective-specific instruction**: for "fine now but breaks as data grows"
  items, add a one-line note on the assumed data volume
  （`想定データ量の前提を1行添えて報告する` として渡す）

## Test design (prefix: T)

- **Role declaration**: `テスト設計の専門家`
- **When it helps**: when the diff has many test additions/changes, or when
  evaluating the safety net before a refactor
- **Checklist**:
  - 仕様の分岐に対するカバレッジの穴（境界値・異常系）
  - テストの独立性（実行順序・共有状態への依存）
  - fixture・ヘルパの重複と共通化の余地
  - アサーションの弱さ（実行されるだけで何も検証していないテスト）
  - モックの過剰（実装の詳細に結合していて、リファクタで壊れるテスト）
  - テスト名が仕様を説明しているか

## Operations and observability (prefix: O)

- **Role declaration**: `このシステムの障害対応を担う SRE`
- **When it helps**: when the diff includes async jobs, external integrations,
  retries, or timeouts
- **Checklist**:
  - 障害時に原因を追えるログが出るか（入力の識別子・失敗理由が残るか）
  - 例外の握りつぶし（catch して何もしない・ログだけで続行が意図的か）
  - リトライ・タイムアウト・ロックの設定値の根拠（TTL の見積もり漏れ等）
  - 部分失敗時の状態（途中で落ちたらデータはどうなるか、再実行は安全か）
  - 監視・アラートにつながるメトリクスやログレベルの妥当性
- **Perspective-specific instruction**: report operational risks (missing
  estimates, unreleased locks, etc.) as a separate bucket
  （`運用リスクは別枠で報告する` として渡す）

## Concurrency and contention (prefix: C)

- **Role declaration**: `並行処理と競合状態の専門家`
- **When it helps**: when the diff includes concurrently-run jobs, shared
  resources, locks, or transactions
- **Checklist**:
  - 同じ処理が同時に2つ走ったときの挙動（冪等性・二重実行の防止）
  - check-then-act の隙間（存在確認してから作成する間の競合）
  - ロックの粒度と解放の安全性（例外時に解放されるか、TTL は十分か）
  - トランザクション境界の妥当性（部分コミットで不整合が残らないか）
  - デッドロックの可能性（複数リソースの取得順序）

## API and schema compatibility (prefix: K)

- **Role declaration**: `API とデータスキーマの互換性に責任を持つエンジニア`
- **When it helps**: when the diff changes public APIs, DB schemas, events, or
  shared enums
- **Checklist**:
  - 既存クライアント・既存データを壊す変更が混ざっていないか
  - enum・コード値の追加/削除が消費側すべてに波及しているか（古い値の取り残し）
  - スキーマとコード上の型定義の食い違い
  - バージョニング・デフォルト値による後方互換の担保
  - マイグレーションとデプロイ順序の依存（コードが先か、スキーマが先か）
- **Perspective-specific instruction**: compatibility-breaking spots are not
  behavior-preserving, so always report them as a separate bucket
  （`互換性を壊す箇所は挙動不変ではないので必ず別枠で報告する` として渡す）
