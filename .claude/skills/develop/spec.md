# `/develop` スキル仕様書

## 概要

`/research` → `/plan` → `/implement` パイプラインを一気通貫で実行するオーケストレータースキル。
既存の3スキルを個別に残しつつ、同じ `prompts/*.md` を再利用してパイプライン全体のフローを1つの SKILL.md に記述する。

---

## 基本情報

| 項目 | 値 |
|------|-----|
| スキル名 | `develop` |
| context | なし（メインコンテキストで実行） |
| disable-model-invocation | `true`（明示的な `/develop` でのみ起動） |
| allowed-tools | `Task, AskUserQuestion, Bash, Read, Edit, Write, Glob, Grep` |
| ファイル構成 | `.claude/skills/develop/SKILL.md` のみ（1ファイル） |

---

## 引数

```
/develop "タスク説明" [--from research|plan|implement] [--research file.md] [--output plan-filename]
```

| 引数 | 必須 | デフォルト | 説明 |
|------|------|-----------|------|
| タスク説明 | Yes（`--from implement` 時は不要） | — | 調査・計画・実装の対象タスク |
| `--from` | No | `research` | パイプラインの開始フェーズ |
| `--research` | No | — | 既存の research ファイルパス。`--from plan` 時に使用 |
| `--output` | No | `plan.md` | 計画ファイルの出力ファイル名 |

### 引数の組み合わせ例

```bash
# フルパイプライン
/develop "ユーザー認証機能の追加"

# research 済み → plan から開始
/develop "OAuth2.0対応" --from plan --research research-認証フロー.md

# plan 済み → implement から開始
/develop --from implement

# plan ファイル名を指定して implement
/develop --from implement --output migration-plan.md
```

---

## パイプラインフロー

```
Phase R (Research)
  ├─ Task(Bash): スコープ決定
  ├─ Task(general-purpose) + research/prompts/investigate.md: 深掘り調査
  └─ research-<topic>.md 自動出力 ← レビューゲートなし
      │
Phase P (Plan)
  ├─ Task(general-purpose) + plan/prompts/generate-plan.md: 計画生成
  ├─ 注釈サイクル ← ★唯一の確認ゲート（承認まで繰り返し）
  ├─ Task(general-purpose) + plan/prompts/revise-plan.md: 注釈反映
  └─ plan.md 確定
      │
Phase I (Implement)
  ├─ Task(Bash): 計画読み込み & ツール検出
  └─ 実装ループ（Edit/Write → type check + lint → チェックリスト更新）
      └─ テスト実行 → 完了サマリー
```

---

## フェーズ詳細

### Phase R: Research

既存の `/research` スキルと同等の処理を行うが、以下の点が異なる:

| 項目 | `/research` 単体 | `/develop` 内の Phase R |
|------|-----------------|----------------------|
| レビューゲート（Phase 3） | あり（AskUserQuestion で確認） | **なし**（自動でファイル出力） |
| 追加調査の選択肢 | あり | **なし**（1回の調査で次へ進む） |
| ファイル出力 | ユーザーが選択 | **自動出力** |
| エディタで開く | する | **しない**（パイプラインが続くため） |

**処理フロー:**

1. **スコープ決定**: Task(Bash) で引数パース、プロジェクト構造把握、エントリーポイント特定
   - エラー（NO_TOPIC, ENTRY_POINT_COUNT: 0）時は AskUserQuestion で対応（既存と同じ）
2. **深掘り調査**: Task(general-purpose) で `.claude/skills/research/prompts/investigate.md` を使用
3. **ファイル出力**: `research-<sanitized-topic>.md` を自動で Write
4. **サマリー表示**: 調査結果の要約を表示し、そのまま Phase P へ遷移

### Phase P: Plan

既存の `/plan` スキルと同等の処理を行う。確認ゲートを維持する。

| 項目 | `/plan` 単体 | `/develop` 内の Phase P |
|------|------------|----------------------|
| research ファイル指定 | `--research` フラグで手動指定 | Phase R の出力を**自動引き渡し** |
| 注釈サイクル | あり（承認まで繰り返し） | **同じ**（承認まで繰り返し） |
| 確定後の次のステップ案内 | 「実装に進めます」と表示 | **自動で** Phase I へ遷移 |

**処理フロー:**

1. **コンテキスト収集**: Task(Bash) で引数パース、プロジェクト構造把握
   - Phase R の出力ファイルを自動的に RESEARCH_FILE として設定
2. **計画生成**: Task(general-purpose) で `.claude/skills/plan/prompts/generate-plan.md` を使用
3. **注釈サイクル**（★唯一の確認ゲート）:
   - plan ファイルを Write → エディタで開く
   - AskUserQuestion: 「承認」「注釈を反映」「キャンセル」
   - 「注釈を反映」: `.claude/skills/plan/prompts/revise-plan.md` で再生成 → ループ
   - 「承認」: Phase I へ遷移
   - 「キャンセル」: パイプライン全体を終了
4. **確定**: チェックリスト整合性確認後、Phase I へ自動遷移

### Phase I: Implement

既存の `/implement` スキルと同等の処理を行うが、以下の点が異なる:

| 項目 | `/implement` 単体 | `/develop` 内の Phase I |
|------|------------------|----------------------|
| スコープ確認（AskUserQuestion） | あり（「すべて実装」or「ステップ選択」） | **なし**（全ステップ自動実行） |
| 計画ファイル指定 | 引数で指定可能 | Phase P の出力を**自動引き渡し** |

**処理フロー:**

1. **計画読み込み & ツール検出**: Task(Bash) で plan ファイルのチェックリスト抽出、バリデーションツール自動検出
2. **実装ループ**: 各ステップを順番に実行
   - ステップ詳細を plan から読み取り
   - Edit/Write でコード変更
   - type check + lint 実行（毎ステップ）
   - チェックリスト更新
   - 次のステップへ（確認なし）
3. **検証 & サマリー**: テスト実行、git diff --stat、完了メッセージ
   - テスト失敗時は AskUserQuestion で「修正する」or「スキップ」を選択

---

## 途中開始（`--from` オプション）

### `--from research`（デフォルト）

フルパイプライン実行。タスク説明が必須。

### `--from plan`

Phase R をスキップし、Phase P から開始。

- タスク説明が必須
- `--research` で既存の research ファイルを渡せる（任意）
- research ファイルが指定されない場合、カレントディレクトリの `research-*.md` を検索して候補表示（既存 `/plan` と同じ動作）

### `--from implement`

Phase R・P をスキップし、Phase I から開始。

- タスク説明は不要（plan ファイルから読み取る）
- `--output` で plan ファイルのパスを指定可能（デフォルト: `plan.md`）

---

## 既存スキルとの関係

```
.claude/skills/
├── research/          # そのまま維持（個別に /research で使える）
│   ├── SKILL.md
│   └── prompts/
│       └── investigate.md    ← /develop が再利用
├── plan/              # そのまま維持（個別に /plan で使える）
│   ├── SKILL.md
│   └── prompts/
│       ├── generate-plan.md  ← /develop が再利用
│       └── revise-plan.md    ← /develop が再利用
├── implement/         # そのまま維持（個別に /implement で使える）
│   └── SKILL.md
└── develop/           # 新規作成
    └── SKILL.md       # パイプラインオーケストレーター
```

- `/develop` は既存スキルを**呼び出さない**（Skill chaining は使わない）
- `/develop` は既存の `prompts/*.md` を**直接参照して** Task 経由で subagent に渡す
- 既存スキルの `prompts/*.md` を変更すれば `/develop` にも自動反映される

---

## エラーハンドリング

| 状況 | 対応 |
|------|------|
| Phase R でトピック未指定 | エラーメッセージ表示して停止 |
| Phase R でエントリーポイント 0 件 | AskUserQuestion でキーワード変更 or キャンセル |
| Phase P で注釈サイクル中にキャンセル | パイプライン全体を終了 |
| Phase I でバリデーション失敗 | 即座に修正 → 再バリデーション（既存と同じ） |
| Phase I でテスト失敗 | AskUserQuestion で修正 or スキップ |
| `--from plan` で research ファイルが見つからない | AskUserQuestion で「なしで続行」or「パス変更」or「キャンセル」 |
| `--from implement` で plan ファイルが見つからない | エラーメッセージ表示して停止 |

---

## ルール

- ALWAYS display messages in Japanese
- NEVER modify existing skills — `/develop` は独立した新規スキル
- NEVER skip the plan annotation cycle — 計画の承認は必須
- Research phase のレビューゲートは省略する（自動出力）
- Implement phase のスコープ確認は省略する（全ステップ自動実行）
- 既存の `prompts/*.md` を直接参照し、ロジックの重複を最小化する
- `--from` で途中開始する場合、スキップされたフェーズの前提条件（ファイルの存在等）を検証する
