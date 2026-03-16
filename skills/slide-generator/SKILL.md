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
| 保存先パス | 「出力ファイルの保存先はどこにしますか？（デフォルト: カレントディレクトリ）」 |

全部まとめて一度に聞いてもよい。ユーザーが既に答えている項目は聞き直さない。

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

## エージェントワークフロー（順番に実行）

### フェーズ1：スライド理解（PPTX入力のときのみ実行）

**Step 1 — slide-design-ocr**
`slide-design-ocr` サブエージェントを起動。
既存PPTXのレイアウト・デザイン構造を読み取り、Content.theme に反映する。

**Step 2 — slide-ocr**
`slide-ocr` サブエージェントを起動。
既存PPTXのテキストを文字起こしし、Content.sections の雛形を作る。

---

### フェーズ2：スライド戦略

**Step 3 — design-conductor**
`design-conductor` サブエージェントを起動。
Content.theme のカラー・フォント・レイアウト方針を決定する。

**Step 4 — text-conductor**
`text-conductor` サブエージェントを起動。
mdファイルを以下の順で処理し、Content.sections を構築する。

1. **Markdownパース** — フロントマター抽出・ページ分割・AST走査
2. **構造化** — 大テーマ → 中テーマ → 要点の階層ツリーに整理
3. **パターン選定** — 魔神プロンプトの思考フローに従い、各セクションに最適なスライドタイプを選ぶ
   - 比較 → compare、時系列 → timeline、手順 → process など
4. **言語化** — 各スライドのテキストを体言止め・90文字以内に圧縮
5. **スピーカーノート生成** — 各スライドの notes を作成

---

### フェーズ3：スライド生成とスコアループ

**Step 5 — subagent-converter**
`subagent-converter` サブエージェントを起動。
Content.sections → slideData 配列に変換する。
コードブロックは画像プレースホルダー（imgサンプル）に変換する。

**Step 6 — subagent-slidecode**
`subagent-slidecode` サブエージェントを起動。
slideData を受け取り、pptxgenjs の `generate.js` を生成・実行する。
`npm install pptxgenjs && node generate.js` で `presentation.pptx` を出力。

**Step 7 — subagent-scoring**
`subagent-scoring` サブエージェントを起動。
ハンガリアンアルゴリズムで before/after のスライドをスコアリングする。

スコア基準：
- 完全一致: 500点
- レイアウト一致: +50点
- タイトル一致: +80点
- 本文一致: +160点
- 位置ボーナス（同位置・自然順序）: +2〜+8点

**Step 8 — subagent-refactoring**
`subagent-refactoring` サブエージェントを起動。
スコアが閾値（目安: 全スライド平均400点以上）を下回っていれば、
Step 5〜7 をループして再生成・再スコアリングする。
閾値を超えたら終了。

---

## 出力

`presentation.pptx` を生成して完了。
保存先パスをユーザーに伝える。
