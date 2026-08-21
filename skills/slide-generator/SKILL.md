---
name: slide-generator
description: Markdown・既存PPTX・貼り付けテキストから PowerPoint（.pptx）を生成する。構造化（A）→ デザイン（B）→ 描画（C）の3段サブエージェントパイプラインで、レイアウト・座標・意味色・強調マークアップを確定し pptxgenjs で出力する。「スライドを作って」「パワポにして」「プレゼン資料を生成」「PPTXを更新」などの依頼で使用。
---

Markdown ファイル、既存 PPTX + md メモ、または貼り付けテキストを受け取り、
エージェントワークフローで PowerPoint（.pptx）を生成するスキル。
このファイルは**オーケストレーション（何を聞き、誰を、どの順で呼ぶか）**だけを定める。

## 前提条件

`generate.js` の実行に **Node.js（v18 以上）と npm** が必要。
未インストールの場合は Step C の前にユーザーへ案内する（https://nodejs.org/）。
依存パッケージ `pptxgenjs` は Step C で自動インストールされる。

## 仕様の参照先

SPEC / slideData スキーマ / インラインマークアップ記法 / 座標基準の完全な定義は
`${CLAUDE_PLUGIN_ROOT}/reference/slidedata-schema.md` が正典。各エージェントが必要時に読み込む。
利用者プロジェクトの `CLAUDE.md` ではないので注意。

---

## フェーズ0：ユーザー対話（最初に必ず実行）

### Step 0-1 — 入力タイプの確認

次のいずれかを確認する：

1. **mdファイル単体** でスライドを新規作成したい
2. **既存PPTX + mdメモ** でスライドを更新・改善したい
3. **テキストをそのまま貼り付け** たい（ファイルなし）

ユーザーに聞く：
> 「スライドの元データを教えてください。mdファイルのパス、PPTXのパス、またはテキストをそのまま貼ってもらえますか？」

### Step 0-2 — 補足情報の収集

入力を受け取ったら以下を確認する。未回答・不明な項目だけ聞く。全部まとめて一度に聞いてもよい。
**収集した値は右列のとおり SPEC に格納し、後段に渡す**（聞くだけで捨てない）。

| 項目 | 質問例 | 渡し先 |
|------|--------|--------|
| タイトル | 「スライドのタイトルは？」 | `meta.title` |
| 対象オーディエンス | 「誰向けのスライドですか？（社内・顧客・登壇など）」 | `meta.audience` → A が説得ラインの選択に使う |
| スライド枚数の目安 | 「何枚くらいを想定していますか？（任意）」 | `meta.slideBudget` → A が総枚数を ±20% に収める |
| デザインの雰囲気 | 「デザインの方向性はありますか？（シンプル・プロ・カラフルなど）」 | Step B へ申し送り |
| デザインガイドライン | 「デザインガイドラインファイル（例: `design-guidelines.md`）はありますか？」 | A（`meta.theme` 初期値）と B の両方にパスを渡す |
| 保存先パス | 「出力ファイルの保存先は？（デフォルト: カレントディレクトリ）」 | `meta.output` |

> **デザインガイドラインファイルが指定された場合：**
> 定義されたカラーパレット・フォント・余白・レイアウトルールを全段で厳守する。
> Step A で `meta.theme` の初期値として読み込み、Step B にもパスを渡すこと（配色・意味色はガイドラインが最優先）。

### Step 0-3 — 確認と開始

収集した情報をまとめてユーザーに確認し、OKが出たらフェーズ1以降を実行する。

---

## エージェントワークフロー

```
[0] slide-ocr → [A] subagent-structure → (差分算出) → [B] subagent-design → [C] subagent-pptxgen
 ※PPTX入力時のみ  構造・レイアウト・座標   ※PPTX入力時のみ  色・強調マークアップ   generate.js 実行
```

各段の責務と禁止事項は正典 §1 のとおり。**A は色を塗らず、B は座標を動かさず、C は判断をしない。**

### Step 0 — slide-ocr ※PPTX入力のときのみ

`slide-ocr` サブエージェント（`${CLAUDE_PLUGIN_ROOT}/agents/0-ocr.md`）を起動。
既存PPTXのテキスト・レイアウトを読み取り、`slideData` 配列の雛形を生成する。

### Step A — subagent-structure

`subagent-structure` サブエージェント（`${CLAUDE_PLUGIN_ROOT}/agents/a-structure.md`）を起動。
入力テキスト（md / 貼り付けテキスト / Step 0 の OCR 結果）と Step 0-2 で集めた `meta` を渡し、
**SPEC**（レイアウト確定・全座標算出済み・プレーンテキスト）を生成させる。

### Step A' — refactoring-slides ※PPTX入力のときのみ

`refactoring-slides` スキル（`${CLAUDE_PLUGIN_ROOT}/skills/refactoring-slides/SKILL.md`）を実行し、
Step 0 の `slideData`（before）と Step A の SPEC（after）の対応関係を算出する。

- 差分サマリ（据え置き / 変更 / 削除 / 追加）を**ユーザーに提示する**
- `deleted` があれば**意図した削除かユーザーに確認**する。意図しない欠落なら Step A に差し戻す
- 対応関係は Step B に渡し、既存スライドの意味色・強調の踏襲に使わせる

### Step B — subagent-design

`subagent-design` サブエージェント（`${CLAUDE_PLUGIN_ROOT}/agents/b-design.md`）を起動。
Step A の SPEC に**デザインだけを上乗せ**させる（意味色・強調マークアップ・図形スタイル・装飾・統一性点検）。
座標は変更させない。

#### デザイン所見のユーザー提示

Step B 完了後、`designReport` を必ずユーザーに提示する：

```
🎨 デザイン調整レポート
━━━━━━━━━━━━━━━━━━━━━━━━━
アクセント: #4285F4
意味色: リスク=赤 / コスト削減効果=緑 / 重点施策=アクセント
強調箇所: P2:3 / P3:2 / P4:1（上限3）
山場スライド: P2, P7（装飾1件追加）

セルフチェック:
  強調予算 ✓ / コントラスト ✓ / 統一性 ✓ / 境界 ✓ / 記法整合 ✓

申し送り（issues）:
  [warn] P5 右カラムが8項目で密度過多 → 2枚分割を推奨
━━━━━━━━━━━━━━━━━━━━━━━━━
```

#### issues による分岐

| 状況 | アクション |
|---|---|
| `checks` が全て pass、issues なし | Step C へ進む |
| `issues` に `warn` のみ | 内容を提示し、続行するか A に差し戻すかユーザーに確認 |
| `issues` に `error`（境界違反・項目過多など構造的問題） | **Step A に差し戻し**、該当スライドのレイアウトを再算出 → B を再実行 |

**ループ上限**: 差し戻しは最大2回。解消しない場合は現状の issues を提示し、続行可否をユーザーに確認する。

### Step C — subagent-pptxgen

`subagent-pptxgen` サブエージェント（`${CLAUDE_PLUGIN_ROOT}/agents/c-pptxgen.md`）を起動。
Step B の SPEC をレンダラーテンプレートに埋め込んだ `generate.js` を書き出し、
`npm install pptxgenjs && node generate.js` を実行して出力する。
実行前の preflight 検証結果（error / warn）を必ず報告させる。

---

## 出力

`presentation.pptx`（または `meta.output`）を生成して完了。保存先パスをユーザーに伝える。
