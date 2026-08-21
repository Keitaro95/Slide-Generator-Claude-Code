# SPEC / slideData 契約仕様

> **このファイルがパイプライン全体の唯一の正典（single source of truth）です。**
> エージェント（`agents/*.md`）とスキル（`skills/*/SKILL.md`）は、仕様が必要になった時点で
> `${CLAUDE_PLUGIN_ROOT}/reference/slidedata-schema.md` を読み込みます。
> **利用者プロジェクトの `CLAUDE.md` ではありません。**

---

## 1. パイプラインと責務

```
[0] slide-ocr → [A] subagent-structure → [B] subagent-design → [C] subagent-pptxgen
  既存PPTX読取    構造・レイアウト・座標    色・強調マークアップ    generate.js 生成＋実行
  → slideData     → SPEC                  → SPEC（装飾付き）      → presentation.pptx
```

| 段 | ファイル | 責務 | やってはいけないこと |
|---|---|---|---|
| 0 | `agents/0-ocr.md` | 既存PPTX・PDF・画像を読み取り `slideData` 配列を生成 | 装飾の付与、内容の創作 |
| A | `agents/a-structure.md` | 内容の構造化、テンプレート選択、**全要素の座標算出**、文字規約 | 色・強調の付与（Bの責務） |
| B | `agents/b-design.md` | 意味色、強調マークアップ、図形スタイル、装飾 | **座標の変更**、テキストの意味変更（Aの責務） |
| C | `agents/c-pptxgen.md` | SPEC をテンプレートに埋め込み描画・実行 | レイアウト補正、デザイン判断 |

既存PPTX更新時のみ、A と B の間に `refactoring-slides` スキルが入り、before/after の差分を算出する。

---

## 2. キャンバス基準

```
スライド:     13.33" × 7.5"（LAYOUT_WIDE / EMU 12192000 × 6858000）
左右マージン: 0.50"      上マージン: 0.35"
コンテンツ幅: CONTENT_W  = 13.33 - 0.50 * 2 = 12.33
右端限界:     RIGHT_EDGE = 13.33 - 0.50     = 12.83

境界条件（A が保証し、B が再検証し、C が preflight で報告する）:
- 全要素   x + w ≤ 13.33 かつ y + h ≤ 7.5
- 本文要素 x ≥ 0.50 かつ x + w ≤ 12.83
- 隣接要素間は最低 0.15" / 座標値は小数点2桁まで
```

座標は**インチ実寸**。960px=10インチ相当のグリッドを流用しないこと。

---

## 3. SPEC — A / B / C 共通の契約

### 3.1 全体構造

```json
{
  "meta": {
    "title": "…", "date": "YYYY.MM.DD", "audience": "…", "slideBudget": 12,
    "output": "presentation.pptx",
    "theme": { "accent": "4285F4", "font": "Meiryo", "logo": "…", "footerText": "…",
               "colors": { "blue": "4285F4", "red": "EA4335", "…": "…" } }
  },
  "slides": [{
    "slideIndex": 0, "type": "content", "page": 1, "background": "white",
    "layout": { "template": "A", "description": "…", "regions": { "body": { "x": 0, "y": 0, "w": 0, "h": 0 } } },
    "elements": [ /* §3.2 */ ],
    "arrows": [ /* §3.5 */ ],
    "notes": "…",
    "calculations": { "BODY_TOP": "1.58 + 0.38 + 0.20 = 2.16" },
    "boundsCheck": { "allWithinBounds": true, "minSpacing": 0.15, "violations": [] }
  }],
  "designReport": { "…": "Bのみ付与。描画には使わない" }
}
```

`meta.audience` と `meta.slideBudget` は A が構成判断（説得ライン・枚数調整）に使う。
`type` は §5 の11種類。`page` は title / closing を除いた通し番号。

### 3.2 element オブジェクト

```json
{ "id": "body-bullets", "role": "body",
  "method": "addText", "shape": "rect",
  "content": ["…"], "format": "bullets",
  "props": { "x": 0.50, "y": 2.16, "w": 12.33, "h": 4.42, "fontSize": 16, "color": "text" } }
```

| フィールド | 型 | 説明 |
|---|---|---|
| `id` | string | スライド内で一意 |
| `role` | string | 役割識別子（B が統一性判定に使う）。§3.3 参照 |
| `method` | string | `addText` / `addShape` / `addImage` / `addTable` |
| `shape` | string | `addShape` 時のみ。`rect` / `roundRect` / `ellipse` / `line` / `rightArrow` / `chevron` |
| `content` | string / string[] / object | テキスト、bullets 配列、table 構造（§3.5） |
| `format` | string | `plain`（そのまま）/ `runs`（マークアップ解釈）/ `bullets`（`• ` 付き複数行＋マークアップ解釈） |
| `props` | object | 座標・スタイル（§3.4） |

### 3.3 role 一覧

`header-logo` / `title-text` / `title-underline` / `subhead-text` / `body` / `panel` / `panel-header` /
`panel-title` / `card` / `card-text` / `lane-header` / `lane-title` / `step-box` / `step-num` / `step-text` /
`milestone-dot` / `milestone-label` / `milestone-date` / `axis` / `table` / `progress-track` / `progress-fill` /
`progress-label` / `footer-bar` / `footer-text` / `footer-page` / `ghost-no` / `decoration`

### 3.4 props で使えるキー

```
共通:     x, y, w, h
addText:  fontSize, bold, italic, color, align(left|center|right),
          valign(top|middle|bottom), lineSpacingMultiple, shrinkText, charSpacing, margin
addShape: fill, line("none" | { color, pt }), rectRadius, rotate, flipH, shadow
addImage: path | data, sizing
addTable: colW, rowH, headerFill, headerColor, borderColor, zebra, zebraFill, fontSize
```

- `fill` は文字列指定可（C 側で `{ color }` に変換）。枠線不要は `"line": "none"`
- `props.path: "LOGO"` は `meta.theme.logo` に解決される

### 3.5 addTable の content / arrows

```json
{ "id": "main-table", "role": "table", "method": "addTable",
  "content": { "headers": ["項目", "現状", "目標"],
               "rows": [["売上", "100億", "130億"]] },
  "props": { "x": 0.50, "y": 2.16, "w": 12.33, "h": 4.42, "fontSize": 14, "headerFill": "bgGray" } }
```

```json
{ "id": "arrow-lane0-to-lane1-row0", "from": "lane0-card0", "to": "lane1-card0",
  "method": "addShape", "shape": "rightArrow",
  "props": { "x": 4.72, "y": 3.05, "w": 0.45, "h": 0.22, "fill": "accent", "line": "none" } }
```

`arrows` は `elements` と同じレンダラーで、要素の**後**に描画される。`from` / `to` は参照先 `id` が存在すること。

### 3.6 色の指定と解決順

色は必ず**パレットキー**か **`#` なし6桁hex**。C が次の順で解決する。

```
"accent"       → meta.theme.accent
パレットキー    → meta.theme.colors[key] → 組み込みパレット
6桁hex / #付き → そのまま（# を除去して大文字化）
```

組み込みパレット:

```
blue 4285F4 / red EA4335 / yellow FBBC04 / green 34A853 / text 333333 / white FFFFFF
bgGray F8F9FA / faint E8EAED / laneBg F5F5F3 / border DADCE0 / neutral 9E9E9E / ghost EFEFED
```

---

## 4. インラインマークアップ仕様

B が付与し、C の `parseRuns()` が解釈する。**この表がマークアップの唯一の定義。**

| 記法 | 効果 | 例 |
|---|---|---|
| `**テキスト**` | 太字 | `前年比**120%**を達成` |
| `[[テキスト]]` | 太字＋アクセント色 | `[[全社DX]]を最優先で推進` |
| `{c:NAME\|テキスト}` | 文字色 | `{c:red\|在庫リスク}が拡大` |
| `{hl:NAME\|テキスト}` | 蛍光マーカー（背景色） | `{hl:yellow\|要決裁}` |

- `NAME` は §3.6 のパレットキーか `#` なし6桁hex
- `[[ ]]` `{ }` は**1段までネスト可**（`{hl:yellow|{c:red|要決裁}}`）。`**` は開閉が同記号のためネスト不可
- 閉じ記号が無いトークンは**プレーン文字として描画される**（クラッシュしない）ので開閉を必ず対にする
- 記号そのものを本文で使う場合は全角（`＊＊` / `［［`）に置き換える
- マークアップを入れた要素は `format` を `plain` → `runs` に変更する（`bullets` はそのまま）
- 黄色は文字色に使わない（白背景でコントラスト不足）。`{hl:yellow|…}` を使う

---

## 5. slideData スキーマ（0 → A の中間表現）

既存PPTXを読み取る `0` が出力し、A が SPEC へ変換する。**PPTX入力時のみ通る経路**で、
md・貼り付けテキストからの生成では A が直接 SPEC を作るため使われない。

### 共通ルール

- `notes` は全タイプで任意（スライドノートに入る）
- `subhead` は `title` / `section` / `closing` 以外で使用可
- インライン装飾は 0 / A では付けない（B の責務）

### タイプ一覧

| type | 必須フィールド | 任意フィールド |
|------|--------------|--------------|
| `title` | `title` | `date`, `notes` |
| `section` | `title` | `sectionNo`, `notes` |
| `content` | `title`, `points[]` | `subhead`, `twoColumn`, `columns[2][]`, `notes` |
| `compare` | `title` | `subhead`, `leftTitle`, `rightTitle`, `leftItems[]`, `rightItems[]`, `notes` |
| `process` | `title`, `steps[]` | `subhead`, `notes` |
| `timeline` | `title`, `milestones[]` | `subhead`, `notes` |
| `diagram` | `title`, `lanes[]` | `subhead`, `notes` |
| `cards` | `title`, `items[]` | `subhead`, `columns`(2〜3), `notes` |
| `table` | `title`, `headers[]`, `rows[][]` | `subhead`, `notes` |
| `progress` | `title`, `items[]` | `subhead`, `notes` |
| `closing` | — | `notes` |

### 構造が自明でないフィールド

```json
"columns":    [["左1", "左2"], ["右1", "右2"]]        // content: 明示分割。twoColumn: true なら points を自動2分割
"milestones": [{ "label": "開始", "date": "2025.01", "state": "done" }]   // state: done | next | todo
"lanes":      [{ "title": "レーン1", "items": ["カードA", "カードB"] }]     // レーン間は横方向に矢印で自動接続
"items":      [{ "title": "カード名", "desc": "説明文" }, "文字列でも可"]    // cards
"items":      [{ "label": "項目A", "percent": 80 }]                       // progress: percent は 0〜100
```

その他のタイプは `title` / `subhead` / `points[]` / `steps[]` / `headers[]` / `rows[][]` の素直な文字列配列。

---

## 6. PptxGenJS プロジェクトルール

- layout は `"LAYOUT_WIDE"`。座標は §2 の 13.33 × 7.5 を基準に算出する
- 日本語テキストは必ず `fontFace: "Meiryo"`, `lang: "ja-JP"` を指定
- カラーは `"#"` なし6桁hex。fill は `{ color: "hex" }` オブジェクト形式
- `ShapeType` は**インスタンス経由**で参照する（`pptx.ShapeType.rect`）。pptxgenjs v4 では `PptxGenJS.ShapeType` は存在しない。文字列 `'rect'` の直接指定も可
- 枠線が不要なときは `line: { type: 'none' }` を明示（未指定だと黒枠が出る）
- shadow オブジェクトは呼び出しごとにファクトリ関数で新規生成
- 画像パスは `generate.js` からの相対パスを使用
- `roundRect` にアクセントボーダーを重ねない（角丸で隙間が生じる）
