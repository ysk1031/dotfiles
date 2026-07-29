# Expert perspective catalog

Each entry is the same four-part schema the two always-on reviewers use in SKILL.md: **role declaration**, **合図**, **checklist**, and (where needed) a **perspective-specific instruction**.

**合図 are the grep-able signals that make the perspective worth running.** They must be things you can confirm by reading the diff or grepping the repo — never an interpretation of whether the code looks wrong. Phase 1 quotes the signal it actually found as the "why this helps" line, which is what keeps the recommendation on the safe side of hard rule 2 (no pre-announcing what reviewers will flag).

Prefixes are used in finding IDs (e.g. `P-1`) so findings stay traceable to their source after merging. The always-on reviewers take `SIM` and `CNV`; a new entry's prefix must collide with neither those nor another entry's — that is why Security is `SEC`.

Role declarations, 合図, and checklist items are written in Japanese because they get embedded verbatim into the Japanese reviewer prompt template (see SKILL.md). The guidance around them is in English.

Recommendation guidance:

- **Language pro, library pro, and the senior architect are the default slots** — recommend all three unless a slot's exclusion condition below is met. Language/library content is concretized from the manifest detected in Phase 2; the architect earns its slot on the deep structural side (dependency direction, boundary design), leaving routine convention checks to `CNV`.
  - **Drop the architect** only when the diff has no new or changed public type, module boundary, or inter-module dependency, and triggers no placement judgment (e.g. a single-purpose bug fix, a constant tweak, or a mechanical rename across many files). Number of files touched is not the signal — a one-file change can introduce a boundary, and a ten-file rename may hold no structural judgment at all.
  - **Drop the library pro** when the diff uses no framework, ORM, task queue, or external SDK and touches no name-wired integration (routes, DI registration, ORM relations) — its idioms are then covered by the language pro. If genuinely unsure, keep it.
  - **The language pro effectively never drops**: any code change has language-level structure (types, iteration, error handling) worth a look.
- **The domain expert yields the highest-value findings when a spec doc exists.** Without a doc, drop it — running it unprepared only produces generic remarks.
- **For the non-default entries, the 合図 decide.** No signal found in the diff, no recommendation; don't reason your way to a perspective the diff doesn't show.
- **Whenever you drop a default slot, say so with a one-line reason** in the confirmation step, so the removal is visible rather than silent.

## Language professional (prefix: P)

- **Role declaration**: `{言語} {バージョン} のプロフェッショナル` (fill from the manifest detected in Phase 2)
- **合図**: 差分に対象言語のコードが含まれている（実質いつでも成立する）
- **Checklist**:
  - データ構造・型の使い方（不変化できる箇所、型注釈の具体化）
  - イテレーション・データ変換の簡潔化と重複排除
  - 例外処理・リソース管理（コンテキストマネージャ等、言語の標準的な後始末パターン）
  - 関数の分割と凝集度（1関数に複数の関心が混ざっていないか）
  - 日時・タイムゾーンの扱い
  - テストコードの品質（fixture 共通化・パラメタライズ・重複）
  - パフォーマンスは「明らかな無駄」のみ（マイクロ最適化は出さない）

## Library professional (prefix: L)

- **Role declaration**: `{主要ライブラリの列挙} のプロフェッショナル` (fill from the manifest detected in Phase 2)
- **合図**: 差分に、マニフェストで検出したライブラリの import・呼び出し・タグがある。または名前で結線している箇所（ルーティング登録・DI 登録・ORM のリレーション定義・テーブル名の指定）がある
- **Checklist**:
  - 各ライブラリのイディオム・推奨パターンとの整合
  - 既存コードベースの慣習とのズレ（**見つけたら必ず指摘**、と観点固有指示に書く）
  - ライブラリの標準機能で自前実装を置き換えられる箇所
  - セッション・接続・トランザクションなどリソース管理のパターン
  - 非推奨 API・古い書き方の使用
  - 設定値・オプションのデフォルト依存が意図的か

## Senior architect (prefix: A)

- **Role declaration**: `このコードベース全体の構造に責任を持つシニアアーキテクト`
- **合図**: 新しい公開型・interface・モジュールが増えている。または差分が2つ以上のレイヤ（ディレクトリ）にまたがっている
- **Checklist** (weighted toward deep structure; routine convention checks belong to `CNV`):
  - レイヤ間の依存方向（循環・レイヤ飛び越え）
  - 境界の型・インターフェースが将来の差し替えに耐えるか
  - 責務分割（大きすぎるモジュール・クラス、関心の混在）
  - テスト構造がリファクタの安全網として十分か
  - 命名の一貫性・定数の置き場所は、**深い構造上の問題を示しているときだけ**触れる（単なる表記ゆれ・置き場所の好みは `CNV` の担当なので出さない）
- **Perspective-specific instruction**: `「動くが将来困る」系を重視し、好みの問題は出さない。命名・置き場所の定型指摘は規約整合レビュアーに譲る`

## Domain expert (prefix: D)

- **Role declaration**: `{対象ドメイン} の仕様に精通したドメインエキスパート`
- **合図**: 仕様ドキュメントが存在し（`specs/`・`docs/` 配下など）、かつ差分にドメインの判定・計算・状態遷移がある
- **Preparation**: name the spec docs to read explicitly in the prompt (this is the crux — do not run it without settling the paths; Phase 1 proposes the candidates it found).
- **Checklist**:
  - ドメインルールがコード上で仕様と同じ語彙・構造で読めるか
  - ドメイン概念の命名の一貫性（同じ概念に複数の名前が無いか）
  - 外部システムとの契約（enum・コード値・スキーマ）が1箇所の定義元から導出されているか
  - しきい値定数に意味の分かる名前があるか
  - テストが仕様の分岐を文書化しているか
- **Perspective-specific instruction**: `コードと仕様の食い違いは最重要の別枠として報告する`

## Security (prefix: SEC)

- **Role declaration**: `アプリケーションセキュリティの専門家`
- **合図**: 差分に外部入力の受け取り、SQL・コマンド・パス・テンプレートの組み立て、認証・認可の分岐、秘密情報（環境変数・トークン・鍵）の読み書きがある
- **Checklist**:
  - 外部入力のバリデーションとエスケープ（SQL・コマンド・パスの組み立て箇所）
  - 認可チェックの漏れ（誰でも呼べるようになっていないか）
  - 秘密情報の扱い（ハードコード・ログ出力・エラーメッセージへの混入）
  - 権限の広すぎるデフォルト
  - 依存ライブラリの既知の危険な使い方
- **Perspective-specific instruction**: `攻撃可能な問題は挙動不変かどうかに関係なく別枠の最優先で報告する`

## Performance and scale (prefix: PS)

- **Role declaration**: `データ量とトラフィックの伸びに責任を持つパフォーマンスエンジニア`
- **合図**: ループの中に DB クエリ・外部 API 呼び出し・I/O がある。または上限のないクエリ・全件取得・大きなデータ構造がある
- **Checklist**:
  - N+1 クエリ、ループ内の I/O・API 呼び出し
  - データ量が10倍・100倍になったときに壊れる箇所（全件ロード・無制限クエリ）
  - インデックスの効かないクエリパターン
  - 不要な再計算・キャッシュできる箇所
  - メモリに全部載せる前提の処理
- **Perspective-specific instruction**: `想定データ量の前提を1行添えて報告する`

## Test design (prefix: T)

- **Role declaration**: `テスト設計の専門家`
- **合図**: 差分のうちテストファイルの変更が3割以上を占める。またはテストの無い新しい分岐が増えている
- **Checklist**:
  - 仕様の分岐に対するカバレッジの穴（境界値・異常系）
  - テストの独立性（実行順序・共有状態への依存）
  - fixture・ヘルパの重複と共通化の余地
  - アサーションの弱さ（実行されるだけで何も検証していないテスト）
  - モックの過剰（実装の詳細に結合していて、リファクタで壊れるテスト）
  - テスト名が仕様を説明しているか

## Operations and observability (prefix: O)

- **Role declaration**: `このシステムの障害対応を担う SRE`
- **合図**: 差分に非同期ジョブ・外部連携・リトライ・タイムアウト・ロック・例外の catch がある
- **Checklist**:
  - 障害時に原因を追えるログが出るか（入力の識別子・失敗理由が残るか）
  - 例外の握りつぶし（catch して何もしない・ログだけで続行が意図的か）
  - リトライ・タイムアウト・ロックの設定値の根拠（TTL の見積もり漏れ等）
  - 部分失敗時の状態（途中で落ちたらデータはどうなるか、再実行は安全か）
  - 監視・アラートにつながるメトリクスやログレベルの妥当性
- **Perspective-specific instruction**: `運用リスクは別枠で報告する`

## Concurrency and contention (prefix: C)

- **Role declaration**: `並行処理と競合状態の専門家`
- **合図**: 差分に goroutine / スレッド / async の起動、ロック、トランザクション、存在確認してから作成する流れがある
- **Checklist**:
  - 同じ処理が同時に2つ走ったときの挙動（冪等性・二重実行の防止）
  - check-then-act の隙間（存在確認してから作成する間の競合）
  - ロックの粒度と解放の安全性（例外時に解放されるか、TTL は十分か）
  - トランザクション境界の妥当性（部分コミットで不整合が残らないか）
  - デッドロックの可能性（複数リソースの取得順序）

## API and schema compatibility (prefix: K)

- **Role declaration**: `API とデータスキーマの互換性に責任を持つエンジニア`
- **合図**: enum・コード値の変更、スキーマ定義やマイグレーションファイルの変更、公開 API のシグネチャ変更、イベント定義の変更がある
- **Checklist**:
  - 既存クライアント・既存データを壊す変更が混ざっていないか
  - enum・コード値の追加/削除が消費側すべてに波及しているか（古い値の取り残し）
  - スキーマとコード上の型定義の食い違い
  - バージョニング・デフォルト値による後方互換の担保
  - マイグレーションとデプロイ順序の依存（コードが先か、スキーマが先か）
- **Perspective-specific instruction**: `互換性を壊す箇所は挙動不変ではないので必ず別枠で報告する`
