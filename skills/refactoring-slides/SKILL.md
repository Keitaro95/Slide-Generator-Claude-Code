---
name: refactoring-slides
description: 既存PPTXを更新する際に、before/afterスライドをハンガリアンアルゴリズムで最適マッピングし、類似性スコアで対応付けを行うスキル。
---

# refactoring-slides — 既存PPTXスライド対応付けスキル

## 1.0 PRIMARY_OBJECTIVE

あなたは、既存PPTXから抽出した**beforeスライド配列**と、conductorが生成した**afterスライド配列**を受け取り、変更前後のスライドを**ハンガリアンアルゴリズムによる最適マッピング**で対応付けするAIです。

特に重要なのは**既存スライドのデザイン要素（位置・色・フォント）を最大限維持しながら、追加・削除・並べ替えに対応する**ことです。

---

## 2.0 INPUT

| パラメータ | 型 | 説明 |
|---|---|---|
| `beforeSlides` | `Array<Slide>` | 既存PPTXから抽出したスライド配列（OCR結果） |
| `afterSlides` | `Array<Slide>` | conductor が生成した新しいslideData配列 |

### Slide オブジェクトの構造

```
{
  layout:   string  // スライドタイプ（title, content, compare, ...）
  title:    string  // タイトルテキスト
  subtitle: string  // サブタイトル・サブヘッドテキスト
  body:     string  // 本文テキスト（箇条書き結合）
  image:    string  // 画像パス or null
}
```

---

## 3.0 SIMILARITY_SCORING — 類似性スコア計算

### 3.1 基本類似性スコア（`getSimilarity`）

各フィールドの一致度を重み付き加算で算出する。

| フィールド | 配点 | 重要度 |
|---|---|---|
| `body`（本文） | 160点 | 最重要 — コンテンツの本体 |
| `title`（タイトル） | 80点 | 高 — スライドの識別子 |
| `layout`（レイアウト） | 50点 | 中 — 構造の一致 |
| `image`（画像） | 40点 | 中 — ビジュアル要素 |
| `subtitle`（サブタイトル） | 20点 | 低 — 補足情報 |
| **合計** | **350点** | |
| **完全一致ボーナス** | **500点** | 全フィールド一致時に即返却 |

#### 算出方法

```
function getSimilarity(before, after):
  全フィールドが完全一致 → return 500（早期リターン）

  score = 0
  if layout 一致: score += 50
  if title  一致: score += 80
  if subtitle 一致: score += 20
  if body   一致: score += 160
  if image  一致: score += 40

  return score
```

---

### 3.2 位置ボーナス付きスコア（`getSimilarityForMapping`）

基本スコアに**スライド位置の近接度**を加算し、自然な順序を維持する。

#### 位置ボーナスルール

| 条件 | layout一致時 | layout不一致時 |
|---|---|---|
| 同じインデックス（`beforeIndex === afterIndex`） | +8 | +4 |
| afterが前方（`afterIndex < beforeIndex`） | +6 | +0 |
| afterが後方（`afterIndex > beforeIndex`）— 自然な順序 | +4 | +2 |

#### 設計意図

- **layout一致時はボーナスが大きい**: 同じレイアウトタイプ同士の対応を優先
- **同一インデックスに最大ボーナス**: 位置が変わらないマッピングを優先
- **自然な順序（後方移動）にもボーナス**: スライド追加による後方シフトは一般的

---

## 4.0 HUNGARIAN_ALGORITHM — ハンガリアンアルゴリズム

### 4.1 概要

N×Nのコスト行列に対して**O(N³)**で最適割当を求める。類似性スコア（利益最大化）を最小化問題に変換して適用する。

### 4.2 前処理

```
1. size = max(beforeSlides.length, afterSlides.length)
2. size × size の類似性行列を構築
   - i < n かつ j < m → getSimilarityForMapping(before[i], after[j], i, j)
   - それ以外 → 0（ダミースロット：追加・削除に対応）
3. 利益行列 → コスト行列に変換: cost[i][j] = maxVal - similarity[i][j]
```

### 4.3 ダミースロットの役割

| before数 vs after数 | ダミーの意味 |
|---|---|
| `n < m`（afterが多い） | beforeのダミー行 → **新規追加スライド**（対応する既存スライドなし） |
| `n > m`（beforeが多い） | afterのダミー列 → **削除スライド**（対応する新スライドなし） |
| `n === m` | ダミーなし — 全スライドが1:1対応 |

### 4.4 実装

```js
function hungarian(costMatrix) {
  const n = costMatrix.length;
  const maxVal = costMatrix.flat().reduce((a, b) => Math.max(a, b), 0);
  const cost = costMatrix.map(row => row.map(v => maxVal - v));

  const u = new Array(n + 1).fill(0);
  const v = new Array(n + 1).fill(0);
  const p = new Array(n + 1).fill(0);
  const way = new Array(n + 1).fill(0);

  for (let i = 1; i <= n; i++) {
    p[0] = i;
    let j0 = 0;
    const minDist = new Array(n + 1).fill(Infinity);
    const used = new Array(n + 1).fill(false);

    do {
      used[j0] = true;
      let i0 = p[j0], delta = Infinity, j1;

      for (let j = 1; j <= n; j++) {
        if (!used[j]) {
          const cur = cost[i0 - 1][j - 1] - u[i0] - v[j];
          if (cur < minDist[j]) {
            minDist[j] = cur;
            way[j] = j0;
          }
          if (minDist[j] < delta) {
            delta = minDist[j];
            j1 = j;
          }
        }
      }

      for (let j = 0; j <= n; j++) {
        if (used[j]) {
          u[p[j]] += delta;
          v[j] -= delta;
        } else {
          minDist[j] -= delta;
        }
      }
      j0 = j1;
    } while (p[j0] !== 0);

    do {
      p[j0] = p[way[j0]];
      j0 = way[j0];
    } while (j0);
  }

  const result = new Array(n);
  for (let j = 1; j <= n; j++) {
    if (p[j] !== 0) result[p[j] - 1] = j - 1;
  }
  return result;
}
```

---

## 5.0 OUTPUT_FORMAT — 出力形式

```json
{
  "mapping": [0, 2, 1, 3, -1],
  "pairs": [
    {
      "beforeIndex": 0,
      "afterIndex": 0,
      "similarity": 500,
      "type": "unchanged",
      "detail": "完全一致（layout=content, title=概要）"
    },
    {
      "beforeIndex": 1,
      "afterIndex": 2,
      "similarity": 290,
      "type": "modified",
      "detail": "layout+title+body一致、位置変更(1→2)"
    },
    {
      "beforeIndex": 2,
      "afterIndex": 1,
      "similarity": 130,
      "type": "modified",
      "detail": "title+layout一致、body変更"
    },
    {
      "beforeIndex": 3,
      "afterIndex": 3,
      "similarity": 80,
      "type": "modified",
      "detail": "titleのみ一致、layout変更(content→compare)"
    },
    {
      "beforeIndex": 4,
      "afterIndex": -1,
      "similarity": 0,
      "type": "deleted",
      "detail": "対応する新スライドなし"
    }
  ],
  "additions": [
    {
      "afterIndex": 4,
      "detail": "新規追加スライド（対応する既存スライドなし）"
    }
  ],
  "summary": {
    "totalBefore": 5,
    "totalAfter": 5,
    "unchanged": 1,
    "modified": 3,
    "deleted": 1,
    "added": 1
  }
}
```

### mapping 配列の読み方

- `mapping[i] = j` — before[i] は after[j] に対応
- `mapping[i] = -1` — before[i] は削除（対応する新スライドなし）

### pairs の type 値

| type | 条件 | 意味 |
|---|---|---|
| `"unchanged"` | similarity === 500 | 完全一致 — デザイン要素をそのまま維持 |
| `"modified"` | 0 < similarity < 500 | 部分一致 — 既存デザインをベースに差分のみ更新 |
| `"deleted"` | similarity === 0 or ダミー対応 | 削除 — 既存スライドを除去 |

---

## 6.0 MAPPING_WORKFLOW — マッピング手順

### Step 1: スライド正規化

before/after 両配列の各スライドから `layout`, `title`, `subtitle`, `body`, `image` を抽出・正規化する。

### Step 2: 類似性行列の構築

`size × size`（`size = max(n, m)`）の行列を構築。各セルに `getSimilarityForMapping` の結果を格納する。

### Step 3: ハンガリアンアルゴリズムの実行

コスト行列に変換後、最適割当を算出する。

### Step 4: マッピング結果の分類

各ペアを `unchanged` / `modified` / `deleted` に分類し、ダミースロットに対応した afterスライドを `additions` として記録する。

### Step 5: 結果出力

mapping配列・pairs・additions・summaryを含むJSON を出力する。

---

## 7.0 COMMON_MISTAKES — 回避すべきミス

- **beforeとafterのスライド数が異なる場合にエラーとする**: ダミースロットで吸収するため、数の不一致は正常
- **文字列の部分一致を類似性に含める**: 現在の設計は完全一致のみ。部分一致を導入すると計算が不安定になる
- **位置ボーナスを過大にする**: ボーナスは最大8点。基本スコア（最大350点）を逆転させない程度に抑える
- **title/closingスライドを特別扱いしない**: title/closingは通常1枚ずつ存在し、layout一致で自然に対応するため特別処理は不要
- **削除・追加の判定を類似性閾値で行う**: ハンガリアンアルゴリズムがダミースロットへの割当として自動判定するため、閾値は不要

---

## 8.0 OUTPUT_RULES

- 出力は **上記JSON形式のみ**。前置き・解説・補足テキストは一切禁止
- pairs は type=`deleted` を末尾にソートする
- detail は各ペアの対応理由を1行で要約する（デバッグ用）
- additions は afterIndex の昇順でソートする
