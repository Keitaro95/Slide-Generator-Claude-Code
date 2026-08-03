---
name: slide-generator
description: mdファイル、またはPPTX+mdメモを受け取り、エージェントワークフローでPowerPoint（.pptx）を生成するスキル。
---

mdファイル、またはPPTX+mdメモを受け取り、エージェントワークフローでPowerPoint（.pptx）を生成するスキル。

---

## フェーズ0：ユーザー対話（最初に必ず実行）

ワークフローを開始する前に、以下の手順でユーザーから情報を収集する。

### Step 0-1 — 入力タイプの確認

まず次のいずれかを確認する：

1. **mdファイル単体** でスライドを新規作成したい
2. **既存PPTX + mdメモ** でスライドを更新・改善したい
3. **テキストをそのまま貼り付け** たい（ファイルなし）

ユーザーに聞く：
> 「スライドの元データを教えてください。mdファイルのパス、PPTXのパス、またはテキストをそのまま貼ってもらえますか？」

### Step 0-2 — 補足情報の収集

入力を受け取ったら、以下を確認する。未回答・不明な項目だけ聞く。

| 項目 | 質問例 |
|------|--------|
| タイトル | 「スライドのタイトルは？」 |
| 対象オーディエンス | 「誰向けのスライドですか？（社内・顧客・登壇など）」 |
| スライド枚数の目安 | 「何枚くらいを想定していますか？（任意）」 |
| デザインの雰囲気 | 「デザインの方向性はありますか？（シンプル・プロ・カラフルなど）」 |
| デザインガイドライン | 「デザインガイドラインファイル（例: `design-guidelines.md`）はありますか？指定すると、カラー・フォント・レイアウトなどのルールを全スライドに統一適用します」 |
| 保存先パス | 「出力ファイルの保存先はどこにしますか？（デフォルト: カレントディレクトリ）」 |

全部まとめて一度に聞いてもよい。ユーザーが既に答えている項目は聞き直さない。

> **デザインガイドラインファイルが指定された場合：**
> ガイドラインに定義されたカラーパレット・フォント・余白・レイアウトルールを全段で厳守する。Step A で `meta.theme` の初期値として読み込み、Step B にもガイドラインファイルのパスを渡すこと（配色・意味色はガイドラインが最優先）。

### Step 0-3 — 確認と開始

収集した情報をまとめてユーザーに確認し、OKが出たらフェーズ1以降を実行する。

---

## 入力

- mdファイル単体
- または PPTX + mdメモのセット
- またはユーザーが直接貼り付けたテキスト

---

## SPEC オブジェクト

A → B → C を貫いて受け渡される中央オブジェクト（詳細は `CLAUDE.md`）。

```json
{
  "meta": {
    "title": "", "date": "", "audience": "", "output": "presentation.pptx",
    "theme": { "accent": "4285F4", "font": "Meiryo", "logo": "", "footerText": "", "colors": {} }
  },
  "slides": [
    {
      "slideIndex": 0,
      "type": "title | section | content | compare | process | timeline | diagram | cards | table | progress | closing",
      "page": 1,
      "background": "white",
      "layout": { "template": "A", "description": "", "regions": {} },
      "elements": [{ "id": "", "role": "", "method": "addText", "content": "", "format": "plain", "props": {} }],
      "arrows": [],
      "notes": "",
      "boundsCheck": { "allWithinBounds": true, "violations": [] }
    }
  ],
  "designReport": {}
}
```

- **A** が `meta` / `slides`（座標・プレーンテキスト）を生成
- **B** が `elements[].content` にマークアップを付与し `designReport` を追加
- **C** は SPEC を描画するのみ

---

## エージェントワークフロー（A → B → C）

```
[Step 0: 0ocr] → A: 2coding.md → B: 3scoring.md → C: 4pptxgen.md
 既存PPTX読取     構造・レイアウト   色・強調マークアップ  generate.js 実行
 → slideData      → SPEC(JSON)     → SPEC(装飾付き)     → presentation.pptx
```

### Step 0 — slide-ocr（`agents/0ocr.md`）※PPTX入力のときのみ

`slide-ocr` サブエージェントを起動。
既存PPTXのテキスト・レイアウトを読み取り、slideData 配列の雛形を生成する。
出力は `const slideData = [...]` の JavaScript 配列リテラルのみ。

---

### Step A — subagent-structure（`agents/2coding.md`）

`subagent-structure` サブエージェントを起動。
入力テキスト（md / 貼り付けテキスト / Step 0 の OCR 結果）から、**デザイン構造化JSON（SPEC）**を生成する：

1. **コンテキスト分解・正規化** — 目的・意図・聞き手を把握し、章→節→要点の階層にマッピング
2. **パターン選定・ストーリー再構築** — 章・節ごとに最適なスライドタイプを選定し、説得ラインへ再配列
3. **レイアウト確定・座標算出** — テンプレート（A〜H）を選び、全要素の座標を LAYOUT_WIDE（13.33" × 7.5"）上で算術導出
4. **文字規約の適用** — 字数上限・体言止め・禁止記号

この段階のテキストは**プレーン**（強調記法なし）。デザインガイドラインファイルが指定されていれば `meta.theme` に反映する。

---

### Step B — subagent-design（`agents/3scoring.md`）

`subagent-design` サブエージェントを起動。
Step A の SPEC に**デザインだけを上乗せ**する：

| 作業 | 内容 |
|---|---|
| 意味色の割り当て | リスク＝赤 / 成果＝緑 / 注意＝黄マーカー / キーメッセージ＝アクセント |
| 強調マークアップ | `**太字**` `[[アクセント]]` `{c:red\|…}` `{hl:yellow\|…}` を本文に付与 |
| 図形スタイル | パネル・カード・タイムライン状態色・進捗バー色・テーブル罫線 |
| 装飾追加 | 山場スライドのみ最大2件（`deco-` プレフィックス） |
| 統一性点検 | 全ページで同一 role の座標・スタイル・意味色が一致しているか |

**座標は変更しない**（レイアウトは A の確定事項）。強調は1スライド最大3箇所・本文の20%以下。

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

---

### Step C — subagent-pptxgen（`agents/4pptxgen.md`）

`subagent-pptxgen` サブエージェントを起動。
Step B の SPEC をレンダラーテンプレートに埋め込んだ `generate.js` を書き出し、`npm install pptxgenjs && node generate.js` を実行して `presentation.pptx` を出力する。
実行前に preflight 検証（境界・必須キー・マークアップ開閉）を行い、結果を報告する。

---

### 既存PPTX更新時の追加ステップ

既存PPTXを更新する場合（Step 0 でOCRを実行した場合）、Step A の前に **`refactoring-slides`** スキル（`skills/refactoring-slides/SKILL.md`）を呼び出し、before/after スライドのハンガリアンアルゴリズムによる最適マッピングを行う。対応関係は Step A 以降に引き継がれ、既存スライドのデザイン要素を可能な限り維持する。

---

## 出力

`presentation.pptx` を生成して完了。
保存先パスをユーザーに伝える。
