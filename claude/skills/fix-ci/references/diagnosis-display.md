# Diagnosis Display Logic

This document defines the detailed display logic and branching for Phase 3 (User Confirmation of Hypothesis) of the fix-ci skill.

## When `"status": "OK"` from Phase 2

Display the hypothesis to the user in a clear format, using JSON fields:

```
## CI失敗の診断結果

**ワークフロー**: <workflow from Phase 1 output>
**カテゴリ**: <category>
**確信度**: <confidence>

### 原因の仮説
<hypothesis>

### 根拠
<evidence array items>

### 影響ファイル
<affected_files array items>
```

### Confidence-based notes

If `confidence` is `"LOW"` and `category` is `"FLAKY"` or `"TIMEOUT"`, add a note:
"この失敗はフレーキーテスト（非決定的な失敗）の可能性があります。再実行で解決する場合があります。"

If `confidence` is `"LOW"` and `category` is NOT `"FLAKY"` or `"TIMEOUT"`, add a warning:
"⚠️ 診断の確信度が低い状態です。修正プランが的外れになる可能性があります。追加のヒントを提供するか、ログを直接確認することを推奨します。"

### User choices

Use AskUserQuestion:
- question: "この診断結果に基づいて修正プランを作成しますか？"
- header: "Diagnosis"
- options:
  1. label: "修正プランを作成", description: "この仮説に基づいて修正プランを作成します"
  2. label: "ヒントを追加して再分析", description: "追加情報を提供して再分析します（Otherで入力）"
  3. label: "キャンセル", description: "診断を終了します"
  4. (LOW confidence + non-FLAKY/TIMEOUT only) label: "ブラウザでログを確認", description: "GitHub Actionsのログをブラウザで開きます"

**If "修正プランを作成"**: Proceed to Phase 4
**If "ヒントを追加して再分析"**: User provides additional context via "Other". Re-run Phase 2 with the original Phase 1 data PLUS user's hint. Do NOT re-run Phase 1.
**If "キャンセル"**: Print "CI診断を終了しました。" and stop.
**If "ブラウザでログを確認"**: Run `gh run view <run-id> --web` via Bash, then print "CI診断を終了しました。" and stop.

## When `"status": "UNCLEAR"` from Phase 2

Display the partial analysis using JSON fields:

```
## CI失敗の部分分析

原因を特定できませんでした。

### 判明していること
<partial_analysis>

### 可能性のある原因
<possible_causes array items>
```

### User choices

Use AskUserQuestion:
- question: "原因を特定できませんでした。どうしますか？"
- header: "Diagnosis"
- options:
  1. label: "ヒントを追加して再分析", description: "追加情報を提供して再分析します（Otherで入力）"
  2. label: "ブラウザでログを確認", description: "GitHub Actionsのログをブラウザで開きます"
  3. label: "キャンセル", description: "診断を終了します"

**If "ヒントを追加して再分析"**: Re-run Phase 2 with hint
**If "ブラウザでログを確認"**: Run `gh run view <run-id> --web` via Bash, then print "CI診断を終了しました。" and stop.
**If "キャンセル"**: Print "CI診断を終了しました。" and stop.
