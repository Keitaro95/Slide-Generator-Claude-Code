---
name: refactoring-slides
description: 既存PPTXを更新する際に、更新前スライドと subagent-structure が生成した更新後スライドをハンガリアンアルゴリズムで最適マッピングし、据え置き・変更・削除・追加の差分レポートを生成するスキル。
---

# refactoring-slides — 更新前後スライドの差分算出

## 1.0 PRIMARY_OBJECTIVE

既存PPTXから抽出した **beforeスライド**（`slide-ocr` の `slideData`）と、
**afterスライド**（`subagent-structure` が生成した SPEC）を突き合わせ、
**どのスライドが据え置き・変更・削除・追加されたか**を確定する。

```
[0] slide-ocr → [A] subagent-structure → ★refactoring-slides → [B] subagent-design → [C] subagent-pptxgen
```

**呼び出しタイミングは A の直後・B の直前。** 入力の afterSlides は A の出力なので、A より前には実行できない。
既存PPTX入力（Step 0 を通った場合）のときだけ実行する。

### 出力の使い道

差分レポートは3つの用途に使われる。生成して終わりではない。

| 用途 | 消費者 |
|---|---|
| 更新内容のユーザー提示（「据え置き5枚 / 変更3枚 / 削除1枚 / 追加2枚」） | 親スキル（`slide-generator`） |
| `deleted` の妥当性確認 — **意図しない情報の欠落検知** | 親スキル → ユーザーに確認 |
| `unchanged` / `modified` ペアの意味色・強調の踏襲（`designReport.colorMap` の初期値） | B: `subagent-design` |

> **できないこと**: 既存PPTXの座標・フォントをそのまま引き継ぐことはできない。
> A が全座標を正典 §2 の基準で再算出するため、レイアウトは必ず作り直しになる。
> このスキルが保全するのは**内容の対応関係**であって、描画属性ではない。

---

## 2.0 INPUT

| パラメータ | 型 | 由来 |
|---|---|---|
| `beforeSlides` | `Array<Slide>` | `slide-ocr` が出力した `slideData` 配列 |
| `afterSlides` | `Array<Slide>` | `subagent-structure`（A）が出力した SPEC の `slides` |

### 正規化フォーマット

両者を次の共通形へ正規化してから比較する（比較は完全一致・トリム済み文字列で行う）。

```
{ layout: string,    // スライドタイプ（title, content, compare, ...）
  title: string,     // タイトルテキスト
  subtitle: string,  // サブタイトル・サブヘッド
  body: string,      // 本文テキスト（箇条書きを "\n" で結合）
  image: string }    // 画像パス or ""
```

| 正規化元 | `layout` | `title` | `subtitle` | `body` | `image` |
|---|---|---|---|---|---|
| **before**（slideData） | `type` | `title` | `subhead` | `points` / `steps` / `items` / `rows` 等を結合 | 画像フィールド |
| **after**（SPEC slides） | `type` | role=`title-text` の `content` | role=`subhead-text` の `content` | role=`body`/`card-text`/`step-text`/`lane-title`/`table` 等の `content` を結合 | `method:"addImage"` の `props.path` |

after 側の `content` は A 出力なのでプレーン文字列（マークアップなし）。before 側と同条件で比較できる。

---

## 3.0 SIMILARITY — 類似性スコア

### 3.1 基本スコア（350点満点）

| フィールド | 配点 | 理由 |
|---|---|---|
| `body`（本文） | 160点 | 最重要 — コンテンツの本体 |
| `title` | 80点 | 高 — スライドの識別子 |
| `layout` | 50点 | 中 — 構造の一致 |
| `image` | 40点 | 中 — ビジュアル要素 |
| `subtitle` | 20点 | 低 — 補足情報 |
| **完全一致** | **500点** | 全フィールド一致時に即返却 |

**空フィールド同士は加点しない。** 両方が空の `subtitle` / `image` を「一致」に数えると、
無関係なスライド同士が 60点で結び付き、削除・追加として検知されなくなる。
（全フィールドが空で一致する `closing` 同士などは、先に完全一致 500点で拾われる）

### 3.2 位置ボーナス

基本スコアに**スライド位置の近接度**を加算し、自然な順序を維持する。

| 条件 | layout一致時 | layout不一致時 |
|---|---|---|
| 同じインデックス | +8 | +4 |
| afterが前方（`afterIndex < beforeIndex`） | +6 | +0 |
| afterが後方（自然な順序） | +4 | +2 |

ボーナスは最大8点。基本スコア（最大350点）を逆転させない範囲に抑える。

---

## 4.0 EXECUTION — 実行方法

**ハンガリアンアルゴリズムを頭の中で解かないこと。** 以下を `slide-diff.js` として書き出し、`node slide-diff.js` で実行する。
`/* __BEFORE__ */` / `/* __AFTER__ */` を §2.0 で正規化した配列のJSONリテラルに置換する。

```javascript
'use strict';
// 更新前後スライドの最適マッピング（ハンガリアンアルゴリズム O(N³)）
const before = /* __BEFORE__ */;
const after  = /* __AFTER__ */;

const norm = v => String(v == null ? '' : v).trim();
const FIELDS = [['body', 160], ['title', 80], ['layout', 50], ['image', 40], ['subtitle', 20]];

// 空フィールド同士は「一致」に数えない（空欄の多いスライド同士が誤って対応するのを防ぐ）
const hit = (b, a, f) => norm(b[f]) !== '' && norm(b[f]) === norm(a[f]);

function getSimilarity(b, a) {
  if (FIELDS.every(([f]) => norm(b[f]) === norm(a[f]))) return 500;
  return FIELDS.reduce((s, [f, pt]) => s + (hit(b, a, f) ? pt : 0), 0);
}

function getSimilarityForMapping(b, a, bi, ai) {
  const base = getSimilarity(b, a);
  const sameLayout = norm(b.layout) === norm(a.layout);
  let bonus;
  if (bi === ai)     bonus = sameLayout ? 8 : 4;
  else if (ai < bi)  bonus = sameLayout ? 6 : 0;
  else               bonus = sameLayout ? 4 : 2;
  return base + bonus;
}

// 利益行列を受け取り、最小コスト割当 result[i] = j を返す
function hungarian(profit) {
  const n = profit.length;
  if (n === 0) return [];
  const maxVal = profit.flat().reduce((a, b) => Math.max(a, b), 0);
  const cost = profit.map(row => row.map(v => maxVal - v));

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
          if (cur < minDist[j]) { minDist[j] = cur; way[j] = j0; }
          if (minDist[j] < delta) { delta = minDist[j]; j1 = j; }
        }
      }

      for (let j = 0; j <= n; j++) {
        if (used[j]) { u[p[j]] += delta; v[j] -= delta; }
        else { minDist[j] -= delta; }
      }
      j0 = j1;
    } while (p[j0] !== 0);

    do { p[j0] = p[way[j0]]; j0 = way[j0]; } while (j0);
  }

  const result = new Array(n);
  for (let j = 1; j <= n; j++) if (p[j] !== 0) result[p[j] - 1] = j - 1;
  return result;
}

// ── マッピング実行 ──────────────────────────────────
const n = before.length, m = after.length;
const size = Math.max(n, m);
const matrix = Array.from({ length: size }, (_, i) =>
  Array.from({ length: size }, (_, j) =>
    (i < n && j < m) ? getSimilarityForMapping(before[i], after[j], i, j) : 0));

const assign = hungarian(matrix);

const mapping = [], pairs = [], matchedAfter = new Set();
for (let i = 0; i < n; i++) {
  const j = assign[i];
  const valid = j !== undefined && j < m && getSimilarity(before[i], after[j]) > 0;
  if (valid) {
    matchedAfter.add(j);
    mapping.push(j);
    const sim = getSimilarity(before[i], after[j]);
    const same = FIELDS.filter(([f]) => hit(before[i], after[j], f)).map(([f]) => f);
    pairs.push({
      beforeIndex: i, afterIndex: j, similarity: sim,
      type: sim === 500 ? 'unchanged' : 'modified',
      detail: sim === 500
        ? `完全一致（layout=${before[i].layout}, title=${before[i].title}）`
        : `一致=${same.join('+') || 'なし'}${i !== j ? `、位置変更(${i}→${j})` : ''}`,
    });
  } else {
    mapping.push(-1);
    pairs.push({ beforeIndex: i, afterIndex: -1, similarity: 0, type: 'deleted',
                 detail: `対応する新スライドなし（${before[i].layout}: ${before[i].title}）` });
  }
}

const additions = [];
for (let j = 0; j < m; j++) {
  if (!matchedAfter.has(j)) {
    additions.push({ afterIndex: j, detail: `新規追加スライド（${after[j].layout}: ${after[j].title}）` });
  }
}

pairs.sort((a, b) => (a.type === 'deleted') - (b.type === 'deleted') || a.beforeIndex - b.beforeIndex);

const count = t => pairs.filter(p => p.type === t).length;
console.log(JSON.stringify({
  mapping, pairs, additions,
  summary: { totalBefore: n, totalAfter: m,
             unchanged: count('unchanged'), modified: count('modified'),
             deleted: count('deleted'), added: additions.length },
}, null, 2));
```

### ダミースロットの役割

`size = max(n, m)` の正方行列にし、範囲外セルはスコア0で埋める。
これにより件数の不一致がそのまま追加・削除として解決される（**閾値判定は不要**）。

| before数 vs after数 | ダミーの意味 |
|---|---|
| `n < m`（afterが多い） | beforeのダミー行 → **新規追加スライド** |
| `n > m`（beforeが多い） | afterのダミー列 → **削除スライド** |
| `n === m` | ダミーなし — 全スライドが1:1対応 |

---

## 5.0 OUTPUT_FORMAT

`node slide-diff.js` の標準出力がそのまま結果。

```json
{
  "mapping": [0, 2, 1, 3, -1],
  "pairs": [
    { "beforeIndex": 0, "afterIndex": 0, "similarity": 500, "type": "unchanged",
      "detail": "完全一致（layout=content, title=概要）" },
    { "beforeIndex": 1, "afterIndex": 2, "similarity": 290, "type": "modified",
      "detail": "一致=body+title+layout、位置変更(1→2)" },
    { "beforeIndex": 4, "afterIndex": -1, "similarity": 0, "type": "deleted",
      "detail": "対応する新スライドなし（content: 旧体制図）" }
  ],
  "additions": [
    { "afterIndex": 4, "detail": "新規追加スライド（cards: 新施策3点）" }
  ],
  "summary": { "totalBefore": 5, "totalAfter": 5,
               "unchanged": 1, "modified": 3, "deleted": 1, "added": 1 }
}
```

- `mapping[i] = j` — before[i] は after[j] に対応。`-1` は削除
- `pairs` は `deleted` を末尾にソート、`additions` は `afterIndex` 昇順

---

## 6.0 親スキルへの返却

JSON に加えて、**ユーザー提示用のサマリ**を1ブロックで返す。

```
📑 更新前後の対応
━━━━━━━━━━━━━━━━━━━━━━━━━
据え置き 1枚 / 変更 3枚 / 削除 1枚 / 追加 1枚（更新前5枚 → 更新後5枚）

削除されたスライド（内容が新スライドに引き継がれていません）:
  P5「旧体制図」— 意図した削除か確認してください

追加されたスライド:
  P5「新施策3点」
━━━━━━━━━━━━━━━━━━━━━━━━━
```

`deleted` が1枚以上ある場合は、**必ずユーザーに意図した削除か確認してから B へ進む**。
意図しない欠落であれば A に差し戻す。

---

## 7.0 COMMON_MISTAKES

- **A より前に実行する**: afterSlides は A の出力。順序は 0 → A → 本スキル → B
- **アルゴリズムを暗算する**: ハンガリアン法は必ず §4.0 のスクリプトを実行して解く
- **既存の座標・フォントを引き継ごうとする**: A が全座標を再算出するため不可能（§1.0 の注記）
- **件数の不一致をエラーにする**: ダミースロットで吸収するため正常
- **文字列の部分一致を類似性に含める**: 現在の設計は完全一致のみ。部分一致は計算を不安定にする
- **`deleted` を黙って通す**: 情報欠落の唯一の検知点なので必ずユーザーに提示する
