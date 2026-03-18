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
> 以降の全フェーズ（特にフェーズ2の design-conductor、フェーズ3の subagent-slidecode）で、ガイドラインに定義されたカラーパレット・フォント・余白・レイアウトルールを厳守する。Content.theme の初期値としてガイドラインの内容を読み込み、各サブエージェントにもガイドラインファイルのパスを渡すこと。

### Step 0-3 — 確認と開始

収集した情報をまとめてユーザーに確認し、OKが出たらフェーズ1以降を実行する。

---

## 入力

- mdファイル単体
- または PPTX + mdメモのセット
- またはユーザーが直接貼り付けたテキスト

---

## Content オブジェクト

全フェーズを通じてデータを保持する中央オブジェクト。

```json
{
  "meta": {
    "title": "",
    "date": "",
    "audience": "",
    "style": ""
  },
  "sections": [
    {
      "type": "title | section | content | compare | process | timeline | diagram | cards | table | progress | closing",
      "title": "",
      "subhead": "",
      "points": [],
      "notes": ""
    }
  ],
  "theme": {
    "colors": {},
    "fonts": {}
  }
}
```

---

## エージェントワークフロー（agents/ の番号順に実行）

### Step 0 — slide-ocr（`agents/0ocr.md`）※PPTX入力のときのみ

`slide-ocr` サブエージェントを起動。
既存PPTXのテキスト・レイアウトを読み取り、slideData 配列の雛形を生成する。
出力は `const slideData = [...]` の JavaScript 配列リテラルのみ。

---

### Step 1 — subagent-instruct（`agents/1instruct.md`）

`subagent-instruct` サブエージェントを起動。
入力テキスト（md / 貼り付けテキスト / Step 0 の OCR 結果）を受け取り、以下を実行する：

1. **コンテキスト分解・正規化** — 目的・意図・聞き手を把握し、章→節→要点の階層にマッピング。表記を統一
2. **パターン選定・ストーリー再構築** — 章・節ごとに最適なスライドタイプを選定し、説得ラインへ再配列
3. **構成指示書生成** — 各スライド1枚ごとの全体構成指示書（レイアウト計画・要素配置・座標計算）をJSON配列で生成

座標は LAYOUT_WIDE（13.33" × 7.5"）上で算術的に導出し、境界検証・間隔検証済みの精密な値を出力する。

---

### Step 2 — subagent-precisecode（`agents/2coding.md`）

`subagent-precisecode` サブエージェントを起動。
Step 1 の構成指示書JSONを受け取り、座標値をそのまま忠実にハードコードした精密な PptxGenJS `generate.js` を生成する。

---

### Step 3 — subagent-scoring（`agents/3scoring.md`）＋品質改善ループ

`subagent-scoring` サブエージェントを起動。
Step 1 の構成指示書JSONを**5軸**でデザイン品質スコアリングする。

| 軸 | 配点 | 観点 |
|---|---|---|
| Cross-Slide Consistency（統一性） | 40点 | 複数ページ間でヘッダー・フッター・マージン・フォントが揃っているか |
| Layout Balance（バランス） | 20点 | 左右対称性・余白の均等性・コンテンツの偏り |
| Readability（可読性） | 20点 | フォントサイズ下限・テキスト量・コントラスト |
| Visual Hierarchy（視覚階層） | 10点 | タイトル > サブヘッド > 本文のサイズ順序 |
| Bounds Integrity（境界整合） | 10点 | はみ出し・重なり・最低間隔 |

#### スコアリング結果のユーザー提示

スコアリング完了後、**必ずユーザーにスコアリング結果を提示**する。以下の形式で表示：

```
📊 デザイン品質スコアリング結果
━━━━━━━━━━━━━━━━━━━━━━━━━
総合スコア: XX / 100 点
判定: pass / fix / reject

  統一性:    XX/40
  バランス:  XX/20
  可読性:    XX/20
  視覚階層:  XX/10
  境界整合:  XX/10

違反事項: （あれば列挙）
━━━━━━━━━━━━━━━━━━━━━━━━━
```

#### recommendation による分岐（品質改善ループ）

| recommendation | 条件 | アクション |
|---|---|---|
| `"pass"` | totalScore ≥ 80 かつ error 0件 | ユーザーに「合格」を通知し、Step 4 へ進む |
| `"fix"` | totalScore ≥ 70 または error 1件以上 | ユーザーに violations を提示し、**Step 1（instruct）→ Step 2（coding）→ Step 3（scoring）** を再実行する。violations の内容を instruct に渡して座標修正を指示する |
| `"reject"` | totalScore < 70 | ユーザーに不合格を通知し、**Step 1（instruct）からやり直し**。構成指示書を根本的に再生成し、Step 2→Step 3 を再実行する |

**ループの上限**: 最大3回まで再試行する。3回再試行しても pass にならない場合、現時点のスコアと violations をユーザーに提示し、「このまま続行するか、手動で修正するか」を確認する。

---

### Step 4 — subagent-pptxgen（`agents/4pptxgen.md`）

`subagent-pptxgen` サブエージェントを起動。
Step 2 で生成された `generate.js` を `npm install pptxgenjs && node generate.js` で実行し `presentation.pptx` を出力する。

---

### 既存PPTX更新時の追加ステップ

既存PPTXを更新する場合（Step 0 でOCRを実行した場合）、Step 1 の前に **`refactoring-slides`** スキル（`skills/refactoring-slides/SKILL.md`）を呼び出し、before/after スライドのハンガリアンアルゴリズムによる最適マッピングを行う。対応関係は Step 1 以降に引き継がれ、既存スライドのデザイン要素を可能な限り維持する。

---

## 出力

`presentation.pptx` を生成して完了。
保存先パスをユーザーに伝える。
