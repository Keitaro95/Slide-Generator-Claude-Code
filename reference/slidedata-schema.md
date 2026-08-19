# SPEC / slideData 契約仕様

> **このファイルがパイプライン A / B / C 共通の唯一の正典（single source of truth）です。**
> プラグインとしてインストールされた場合、実体は
> `${CLAUDE_PLUGIN_ROOT}/reference/slidedata-schema.md` に置かれます。
> リポジトリを直接使う場合は `reference/slidedata-schema.md` を参照してください。
>
> エージェント（`agents/*.md`）およびスキル（`skills/*/SKILL.md`）は、
> スキーマの詳細が必要になったときにこのファイルを読み込みます。
> **利用者のプロジェクトにある `CLAUDE.md` ではありません。**

## エージェントパイプライン

```
[0ocr]  → A: subagent-structure → B: subagent-design → C: subagent-pptxgen
既存PPTX   agents/2coding.md      agents/3scoring.md    agents/4pptxgen.md
→slideData 構造化・レイアウト・座標  色・強調マークアップ   generate.js 生成＋実行
           → SPEC(JSON)          → SPEC(マークアップ付き) → presentation.pptx
```

| 段 | 責務 | やってはいけないこと |
|---|---|---|
| A | 内容の構造化、テンプレート選択、**全要素の座標算出**、文字規約 | 色・強調の付与（Bの責務） |
| B | 意味色・強調マークアップ・図形スタイル・装飾 | **座標の変更**、テキストの意味変更（Aの責務） |
| C | SPEC をテンプレートに埋め込み描画・実行 | レイアウト補正・デザイン判断 |

---

## SPEC（デザイン構造化JSON）— A/B/C 共通の契約

```json
{
  "meta": {
    "title": "…", "date": "YYYY.MM.DD", "output": "presentation.pptx",
    "theme": { "accent": "4285F4", "font": "Meiryo", "logo": "…", "footerText": "…",
               "colors": { "blue": "4285F4", "red": "EA4335", "…": "…" } }
  },
  "slides": [{
    "slideIndex": 0, "type": "content", "page": 1, "background": "white",
    "layout": { "template": "A", "description": "…", "regions": { "body": { "x": 0, "y": 0, "w": 0, "h": 0 } } },
    "elements": [{
      "id": "body-bullets", "role": "body",
      "method": "addText",              // addText | addShape | addImage | addTable
      "shape": "rect",                  // addShape 時のみ
      "content": ["…"],                 // 文字列 / 配列 / {headers,rows}
      "format": "bullets",              // plain | runs | bullets
      "props": { "x": 0.5, "y": 2.16, "w": 12.33, "h": 4.42, "fontSize": 16, "color": "text" }
    }],
    "arrows": [], "notes": "…",
    "calculations": {}, "boundsCheck": { "allWithinBounds": true, "violations": [] }
  }],
  "designReport": { "…": "Bのみ付与。描画には使わない" }
}
```

- 色は **パレットキー**（`accent` / `text` / `red` / `green` / `neutral` …）か **`#`なし6桁hex**
- `props.fill` は文字列指定可（C側で `{ color }` に変換）／枠線不要は `"line": "none"`
- 座標はインチ実寸。スライドは **13.33" × 7.5"**（LAYOUT_WIDE）

---

## インラインマークアップ仕様

B が付与し、C の `parseRuns()` が解釈する。

| 記法 | 効果 |
|---|---|
| `**テキスト**` | 太字 |
| `[[テキスト]]` | 太字＋アクセント色 |
| `{c:NAME\|テキスト}` | 文字色（NAME = パレットキー or 6桁hex） |
| `{hl:NAME\|テキスト}` | 蛍光マーカー |

- `[[ ]]` `{ }` は1段ネスト可（`{hl:yellow|{c:red|要決裁}}`）。`**` はネスト不可
- 閉じ記号が無いトークンはプレーン文字として描画される
- 黄色は文字色に使わない（白背景でコントラスト不足）。`{hl:yellow|…}` を使う

---

## slideData オブジェクト スキーマ（0ocr の出力形式）

既存PPTXを読み取る `0ocr` が出力し、A が SPEC へ変換する中間表現。

### 共通ルール

- `notes` は全タイプで任意（スライドノートに入る）
- `subhead` は `title` / `section` / `closing` 以外で使用可
- インライン装飾は 0ocr / A では付けない（B の責務）

---

### type: `title`

```json
{
  "type": "title",
  "title": "プレゼンタイトル",
  "date": "YYYY.MM.DD",
  "notes": "..."
}
```

---

### type: `section`

```json
{
  "type": "section",
  "title": "1. セクション名",
  "notes": "..."
}
```

---

### type: `content`

単列：
```json
{
  "type": "content",
  "title": "...",
  "subhead": "...",
  "points": ["bullet1", "bullet2"],
  "notes": "..."
}
```

2列（`twoColumn`で自動分割）：
```json
{
  "type": "content",
  "title": "...",
  "twoColumn": true,
  "points": ["左1", "左2", "右1", "右2"],
  "notes": "..."
}
```

2列（`columns`で明示分割）：
```json
{
  "type": "content",
  "title": "...",
  "columns": [["左1", "左2"], ["右1", "右2"]],
  "notes": "..."
}
```

---

### type: `compare`

```json
{
  "type": "compare",
  "title": "...",
  "subhead": "...",
  "leftTitle": "A案",
  "rightTitle": "B案",
  "leftItems": ["メリット1", "メリット2"],
  "rightItems": ["メリット1", "メリット2"],
  "notes": "..."
}
```

---

### type: `process`

```json
{
  "type": "process",
  "title": "...",
  "subhead": "...",
  "steps": ["ステップ1", "ステップ2", "ステップ3"],
  "notes": "..."
}
```

---

### type: `timeline`

`state` は `"done"` / `"next"` / `"todo"` のいずれか。

```json
{
  "type": "timeline",
  "title": "...",
  "subhead": "...",
  "milestones": [
    { "label": "開始", "date": "2025.01", "state": "done" },
    { "label": "リリース", "date": "2025.06", "state": "next" },
    { "label": "完了", "date": "2025.12", "state": "todo" }
  ],
  "notes": "..."
}
```

---

### type: `diagram`

レーン間のカードは横方向に矢印で自動接続される。

```json
{
  "type": "diagram",
  "title": "...",
  "subhead": "...",
  "lanes": [
    { "title": "レーン1", "items": ["カードA", "カードB"] },
    { "title": "レーン2", "items": ["カードC", "カードD"] }
  ],
  "notes": "..."
}
```

---

### type: `cards`

`items` は文字列でもオブジェクトでも可。`columns` は 2〜3（省略時は件数で自動）。

```json
{
  "type": "cards",
  "title": "...",
  "subhead": "...",
  "columns": 3,
  "items": [
    { "title": "カードタイトル", "desc": "説明文 [[強調]] **太字**" },
    "文字列カードも可"
  ],
  "notes": "..."
}
```

---

### type: `table`

```json
{
  "type": "table",
  "title": "...",
  "subhead": "...",
  "headers": ["列1", "列2", "列3"],
  "rows": [
    ["値A", "値B", "値C"],
    ["値D", "値E", "値F"]
  ],
  "notes": "..."
}
```

---

### type: `progress`

`percent` は 0〜100 の数値。

```json
{
  "type": "progress",
  "title": "...",
  "subhead": "...",
  "items": [
    { "label": "項目A", "percent": 80 },
    { "label": "項目B", "percent": 45 }
  ],
  "notes": "..."
}
```

---

### type: `closing`

```json
{
  "type": "closing",
  "notes": "..."
}
```

---

## スライドタイプ一覧

| type | 必須フィールド | 任意フィールド |
|------|--------------|--------------|
| `title` | `title` | `date`, `notes` |
| `section` | `title` | `sectionNo`, `notes` |
| `content` | `title`, `points[]` | `subhead`, `twoColumn`, `columns[2][]`, `notes` |
| `compare` | `title` | `subhead`, `leftTitle`, `rightTitle`, `leftItems[]`, `rightItems[]`, `notes` |
| `process` | `title`, `steps[]` | `subhead`, `notes` |
| `timeline` | `title`, `milestones[{label,date,state}]` | `subhead`, `notes` |
| `diagram` | `title`, `lanes[{title,items[]}]` | `subhead`, `notes` |
| `cards` | `title`, `items[{title,desc}]` | `subhead`, `columns`, `notes` |
| `table` | `title`, `headers[]`, `rows[][]` | `subhead`, `notes` |
| `progress` | `title`, `items[{label,percent}]` | `subhead`, `notes` |
| `closing` | — | `notes` |

---

## PptxGenJS プロジェクトルール

- layout: `"LAYOUT_WIDE"`（13.33 x 7.5 インチ）を標準とする。**座標は必ず 13.33 x 7.5 を基準に算出する**（960px=10インチ相当のグリッドを流用しない）
- 日本語テキストは必ず `fontFace: "Meiryo"`, `lang: "ja-JP"` を指定
- カラーは `"#"` なし 6 桁 hex。fill は `{ color: "hex" }` オブジェクト形式
- `ShapeType` は **インスタンス経由**で参照する（`pptx.ShapeType.rect`）。pptxgenjs v4 では `PptxGenJS.ShapeType` は存在しない。文字列 `'rect'` の直接指定も可
- 図形に枠線が不要なときは `line: { type: 'none' }` を明示（未指定だと黒枠が出る）
- shadow オブジェクトは呼び出しごとにファクトリ関数で新規生成
- 画像パスは `generate.js` からの相対パスを使用
- `roundRect` にアクセントボーダーを重ねない（角丸で隙間が生じる）
