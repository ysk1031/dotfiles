# Report template

Author the candidate report as **markdown** (the canonical, editable source) and write
it to the **current working directory** (the project root where the skill was invoked) as
`skill_candidates_report_<YYYY-MM-DD>.md`. An HTML rendering is optional — see SKILL.md
step 5 for the `md`/`html`/`both` format option (default `md`). The report quotes
work-repo content, so it is not auto-committed; if the directory is a shared/public repo,
suggest gitignoring `skill_candidates_report_*` (covers .md and .html).
Fill the template; keep evidence quotes verbatim; drop empty sections rather than padding.

```markdown
# Skill 候補レポート（直近<N>日・<YYYY-MM-DD> 生成）

> 一時成果物（tracked repo にはコミットしない）。分析対象に仕事リポを含むため社内固有語を引用に含む。
> 採用は人間判断。採用候補のみ後段で「置き場所決定 → サニタイズ → skill-creator で実装」。

## 分析メタ情報 / 信頼性の補正
- 対象: 直近<N>日・<X>セッション（subagent/plugin-cache 除く）→ 人間発話 <Y>ターン / <size>
- 手法: 4レンズ（ワークフロー/訂正・好み/タスク種別/ツール連携）map → 横断 reduce
- 補正1（非オーガニック除外）: <single-turn 近似重複の eval フィクスチャをどう割引いたか>
- 補正2（worktree名寄せ）: <同一タスクの worktree 再入をどう実数化したか>
- 偏り: <この窓で過大/過小評価されるドメインがあれば明記>

## スコアの見方（凡例）
全軸とも **「高」ほど着手価値が高い** 向きに揃えてある。優先度 ＝ 5軸の総合（おおむね積）で、表は優先度の高い順に並べる。頻度だけでは並べない。
- **反復**: 補正後の実数で何セッション/何プロジェクトに跨って繰り返されたか（高=多い）
- **安定**: 毎回「やり方」が同じか（高=定型化していて skill 化しやすい / 低=都度バラつき skill 不向き）
- **都度コスト**: ユーザーが毎回説明し直している手間＝導入で消える痛み（高=痛みが大きい＝やる価値が高い）
- **未カバー**: 既存 skill/slash/subagent で未対応か（高=未対応で新設の意味がある / 低=既存で足りる）
- **汎用化**: 仕事固有の秘密を抜いて型にできるか（高=どこでも使える＝ユーザーSkill向き / 低=特定リポ専用＝プロジェクトSkill）
- **分類**: 行き先＝新Skill / CLAUDE.mdルール / slash-command / subagent（＋既存skill修正）
- **置き場所(後決め)**: 採用時の置き先目安（ユーザーSkill=`claude/skills/` / プロジェクトSkill=そのリポの`.claude/skills/` / user・project CLAUDE.md）。リポの公開/非公開とは無関係。最終決定は採用判断時

## ショートリスト（優先度＝5軸の総合。高い順）
| # | 候補 | 分類 | 反復 | 安定 | 都度コスト | 未カバー | 汎用化 | 置き場所(後決め) |
|---|------|------|:--:|:--:|:--:|:--:|:--:|------|
| 1 | … | … | 高 | 高 | 高 | 高 | 高 | … |

## 詳細
### <#>. <候補名> — <分類>【優先度や収束レンズ数を付記】
<what を1-2文>
- スコア: 反復◯ / 安定◯ / 都度コスト◯ / 未カバー◯ / 汎用◯ — <この評価にした理由を1行（表の値の裏取り）>
- 根拠: <「verbatim 引用」— project (YYYY-MM-DD) / 「…」— project (date)（2-4件）。内部の sNNN は出さない（索引で project・date に変換する。番号は読み手に無意味）>
- 既存との差/重複: <該当 skill 名 or なし>
- 汎用度: <generalizable / work-specific-sanitize / personal-env ＋ 理由>
- 推奨: <skill化 / CLAUDE.mdルール化 / slash / 様子見 ＋ 一言>

（候補ごとに繰り返す。スコア上位から）

## 見送り / 様子見
- <候補>: <なぜ今は見送るか（根拠が弱い・手順が未安定・環境固有 等）>

## 既存資産でカバー済み（新規不要）
<パターン → 既存 skill 名の対応を1行ずつ>

## 次の議論（候補ごとに skill 化するか）
1. <最有力の新Skill候補について決めること>
2. <既存skill拡張 vs 新設の判断が要る候補>
3. <CLAUDE.mdルール化で合意してよいもの>
```

## Presentation note
After writing the file, summarize in chat: the validated headline (is the
frequent pain mostly CLAUDE.md-rules or genuine new skills?), the shortlist
table, your recommended order of action, and the per-candidate decisions to
discuss. **Stop there** — do not create any skill. Skill-ification is a separate,
human-gated step handed to skill-creator.
