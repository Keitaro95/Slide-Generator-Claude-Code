# Slide Generator — CLAUDE.md

## slideData オブジェクト スキーマ

`generate.js` の `slideData` 配列に渡す各オブジェクトの形。

### 共通ルール

- `notes` は全タイプで任意（スライドノートに入る）
- `subhead` は `title` / `section` / `closing` 以外で使用可
- インライン装飾：`[[青太字]]` / `**太字**`（`points`, `desc`, `steps`, `leftItems`, `rightItems` 内で有効）

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

- layout: `"LAYOUT_WIDE"`（13.33 x 7.5 インチ）を標準とする
- 日本語テキストは必ず `fontFace: "Meiryo"`, `lang: "ja-JP"` を指定
- カラーは `"#"` なし 6 桁 hex。fill は `{ color: "hex" }` オブジェクト形式
- shadow オブジェクトは呼び出しごとにファクトリ関数で新規生成
- 画像パスはプロジェクトルートからの相対パスを使用
- `ROUNDED_RECTANGLE` にアクセントボーダーを重ねない（角丸で隙間が生じる）
