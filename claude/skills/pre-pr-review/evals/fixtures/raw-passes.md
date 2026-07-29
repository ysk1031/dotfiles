# 4体のレビュアーが返した最終メッセージ（生のまま）

`setup-reco.sh` で作った fixture の `main...feature/criteria-proposal` に対して、
常時2体（SIM / CNV）＋言語プロ（P）＋セキュリティ（SEC）を走らせた結果。

このファイルは Phase 4（統合）の eval 用で、次の性質を意図的に含んでいる。書き換えると eval が測るものが変わる。

- 同じ問題を2体が別の行で指摘している（DAO の置き場: CNV は型宣言の11行目、P はメソッドの19行目）
- 同じ問題を2体が同じ行で指摘している（リトライ: SIM-1 と P-1）
- 確信度低で、実物を見ると**誤り**の指摘（P-3。既存 DAO に同名メソッドは無い）
- 差分が触っていない既存ファイルだけを対象にした指摘（P-4）
- 指摘先は正しいが根拠の記述が誤っている指摘（P-1 の gorm の挙動）
- 別枠に入れられた仕様との食い違い（SIM-4）
- 別枠節ではなく本文で「厳密には挙動が変わる」と自認している指摘（SEC-1）
- 本体が別枠へ格上げすべき指摘（リトライを外すと書き込み回数が3→1に変わる）

---

## SIM（簡素化）

- **[SIM-1] 3回リトライのループに消費者がいない**（infrastructure/dao/ml_job_offer_criteria_proposal.go:62）
- 確信度: 高
- 同じ `row` を最大3回 `Create` するが、リトライを要求する呼び出し元も設定値も無く、失敗理由で分岐もしない。同じエラーで3回叩くだけ。
- 改善案: ループを外して1回の `Create` にする。必要になった時点で回数を設定値として外から渡す。
- 挙動不変であることの根拠: 成功時は1回目で return、失敗時も最後のエラーを返すので呼び出し元から見た結果は同じ。

- **[SIM-2] payload の中間変数が変換のためだけに存在する**（infrastructure/dao/ml_job_offer_criteria_proposal.go:53）
- 確信度: 中
- `json.Marshal` の結果を `string()` にして `payload` に入れ、直後の構造体リテラルで1回だけ使っている。
- 改善案: 構造体リテラル内で `string(encoded)` を直接書く。
- 挙動不変であることの根拠: 変数の生存期間だけが変わる。

- **[SIM-3] ORDER BY created_at DESC に依存する呼び出し元がいない**（infrastructure/dao/criteria_proposal_id_dao.go:24）
- 確信度: 中
- `ListTargetJobOfferIDs` の結果は `ProposeCriteria.Run` が for でそのまま回すだけで、順序に依存していない。
- 改善案: 並び順の要件が無いなら `Order` を外す。
- 挙動不変であることの根拠: 呼び出し元は順序を使っていない。

⚠️別枠（挙動が変わる / 仕様との食い違い / 運用リスク）

- **[SIM-4] LIMIT + ORDER BY で対象が「新しい求人だけ」に狭まっている**（infrastructure/dao/criteria_proposal_id_dao.go:24）
- 設計メモの処理の流れは「対象求人 ID を集める」で、新しい順に絞る記述が無い。実装は created_at DESC + limit なので、古い求人には永久に提案が作られない。仕様との食い違いの可能性。

---

## CNV（規約整合）

- **[CNV-1] 置き場: 1メソッドだけの DAO 新設が規約に反する**（infrastructure/dao/criteria_proposal_id_dao.go:11）
- 確信度: 高
- `CriteriaProposalIDDAO` は求人 ID を返すクエリ1本だけを持つ。CLAUDE.md は「同じ集約の ID を引くクエリは既存 DAO に足す（1メソッドだけの DAO を新設しない）」で、既存 `JobOfferIDDAO` が求人 ID クエリを集めている。
- 改善案: `ListTargetJobOfferIDs` を `JobOfferIDDAO` のメソッドに移し、新 DAO と DI 登録を消す。
- 挙動不変であることの根拠: クエリ本体は変えず、レシーバだけ移す。

- **[CNV-2] 層: アプリケーションが決める版番号が infrastructure にある**（infrastructure/dao/ml_job_offer_criteria_proposal.go:12）
- 確信度: 高
- `CriteriaSchemaVersion = 3` は保存形式の版をアプリケーションが決めた値。CLAUDE.md は「アプリケーションが決める値の定義元は domain」「infrastructure は DB のデフォルト値だけ」としている。
- 改善案: `domain` に移し、dao は domain の定数を参照する。
- 挙動不変であることの根拠: 値は同じで参照元が変わるだけ。

- **[CNV-3] 型: JobOfferID が int で宣言されている**（application/usecase/propose_criteria.go:16）
- 確信度: 高
- `proposalTarget.JobOfferID` が `int`。CLAUDE.md は「ID はすべて uint」で、`domain.JobOfferID` も uint 由来。`int(id)` → `uint(...)` の往復変換が生まれている。
- 改善案: `domain.JobOfferID` をそのまま持つ。
- 挙動不変であることの根拠: 現実の ID 値域では変換結果が一致する。

- **[CNV-4] 命名: 同じテーブルに属する型が接頭辞を共有していない**（infrastructure/dao/ml_job_offer_criteria_proposal.go:26）
- 確信度: 中
- 行の型は `MLJobOfferCriteriaProposal` だが、payload を構成する `CriteriaItem` と `proposalMeta` に `ML` 接頭辞が無い。
- 改善案: `MLCriteriaItem` / `mlProposalMeta` に揃える。
- 挙動不変であることの根拠: 型名の変更だけで、JSON タグは変えない。

- **[CNV-5] 置き場: 未公開型を返す公開コンストラクタ**（infrastructure/dao/ml_job_offer_criteria_proposal.go:36）
- 確信度: 低
- `NewProposalMeta` は公開関数だが、戻り値の `proposalMeta` は未公開型。パッケージ外から呼べるのに戻り値の型名を書けない。
- 改善案: `proposalMeta` を公開するか、コンストラクタを未公開にする。
- 挙動不変であることの根拠: 可視性の変更のみ。

---

## P（Go 1.22 のプロフェッショナル）

- **[P-1] リトライループが同一の row を再利用している**（infrastructure/dao/ml_job_offer_criteria_proposal.go:62）
- 確信度: 高
- 3回ループの中で同じ `&row` を渡している。gorm は `Create` のたびに主キーを書き戻すので、2回目以降は ID 付きの行を挿入しようとする。そもそもリトライを誰も要求していない。
- 改善案: ループを削除する。
- 挙動不変であることの根拠: 1回目成功時の経路は同じ。

- **[P-2] Insert が受け取った meta を一度も使っていない**（infrastructure/dao/ml_job_offer_criteria_proposal.go:48）
- 確信度: 高
- `meta` はシグネチャにしか現れず、`row` にも payload にも入らない。呼び出し側は `NewProposalMeta("gpt", 1)` 固定。
- 改善案: 引数と `NewProposalMeta` を落とすか、payload に載せる。
- 挙動不変であることの根拠: 使われていない値の削除。

- **[P-3] 既存の JobOfferIDDAO に同名メソッドがあり実装が重複している**（infrastructure/dao/criteria_proposal_id_dao.go:19）
- 確信度: 低
- `JobOfferIDDAO` に既に `ListTargetJobOfferIDs` が定義されていて、新しい DAO はそれをコピーしたように見える。
- 改善案: 既存メソッドを呼ぶ。
- 挙動不変であることの根拠: 同じクエリのはず。

- **[P-4] 既存 DAO のエラーにラップが無い**（infrastructure/dao/job_offer_id_dao.go:21）
- 確信度: 中
- 既存の `ListActiveIDs` はエラーをそのまま返すので、呼び出し元でどのクエリが失敗したか分からない。
- 改善案: `fmt.Errorf` でラップする。
- 挙動不変であることの根拠: エラーメッセージだけが変わる。

- **[P-5] titleOf の uint 変換が不要**（application/usecase/propose_criteria.go:59）
- 確信度: 中
- `uint(id)` の変換は `%d` には不要。
- 改善案: `fmt.Sprintf("job offer %d", id)` にする。
- 挙動不変であることの根拠: 出力文字列は同じ。

---

## SEC（アプリケーションセキュリティ）

- **[SEC-1] LLM 出力をそのまま JSON カラムに保存している**（infrastructure/dao/ml_job_offer_criteria_proposal.go:49）
- 確信度: 中
- `items`（LLM の生成物）を検証せずに `json.Marshal` して保存している。読み出し側がそのまま画面に出す場合、格納型 XSS の入口になる。なお検証を追加すると厳密には挙動が変わる。
- 改善案: 保存前に軸名のホワイトリスト検証を入れる。
- 挙動不変であることの根拠: なし（検証の追加は挙動変更）。

- **[SEC-2] エラーに求人 ID が乗らずログから追えない**（application/usecase/propose_criteria.go:48）
- 確信度: 中
- `fmt.Errorf("propose criteria: %w", err)` に求人 ID が入っていないため、どの求人で失敗したか分からない。
- 改善案: ID をエラーに含める。
- 挙動不変であることの根拠: エラー文言のみ変わる。
