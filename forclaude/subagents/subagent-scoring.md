# subagent-scoring

ハンガリーアルゴリズムでスコアリング

新しいスライドオブジェクトが来ても、既存スライドと最適にマッピングし、統一されたデザインになるよう類似性を点数化する。

```js
// ── 類似性スコア計算 ──────────────────────────────────────────

function getSimilarity(before, after) {
  let score = 0;

  const layoutMatch = before.layout === after.layout;
  const titleMatch  = before.title === after.title;
  const subMatch    = before.subtitle === after.subtitle;
  const bodyMatch   = before.body === after.body;
  const imageMatch  = before.image === after.image;

  const isFullMatch = layoutMatch && titleMatch && subMatch && bodyMatch && imageMatch;
  if (isFullMatch) return 500;

  if (layoutMatch) score += 50;
  if (titleMatch)  score += 80;
  if (subMatch)    score += 20;
  if (bodyMatch)   score += 160;
  if (imageMatch)  score += 40;

  return score;
}

// 位置ボーナスを含めたマッピング用スコア
function getSimilarityForMapping(before, after, beforeIndex, afterIndex) {
  const base = getSimilarity(before, after);
  const layoutMatch = before.layout === after.layout;

  if (layoutMatch) {
    if (beforeIndex === afterIndex)   return base + 8;
    if (afterIndex < beforeIndex)     return base + 6; // より前の位置へ
    return base + 4;                                   // 自然な順序
  } else {
    if (beforeIndex === afterIndex)   return base + 4;
    if (afterIndex > beforeIndex)     return base + 2; // 自然な順序
    return base;
  }
}

// ── ハンガリアンアルゴリズム ─────────────────────────────────

// コスト行列から最適な1:1マッピングを返す（最大化版）
function hungarian(costMatrix) {
  const n = costMatrix.length;
  const maxVal = costMatrix.flat().reduce((a, b) => Math.max(a, b), 0);

  // 最大化 → 最小化に変換
  const cost = costMatrix.map(row => row.map(v => maxVal - v));

  const u = new Array(n + 1).fill(0);
  const v = new Array(n + 1).fill(0);
  const p = new Array(n + 1).fill(0); // p[j] = row assigned to col j
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

  // result[beforeIndex] = afterIndex
  const result = new Array(n);
  for (let j = 1; j <= n; j++) {
    if (p[j] !== 0) result[p[j] - 1] = j - 1;
  }
  return result;
}

// ── メイン：最適マッピング生成 ───────────────────────────────

/**
 * @param {Array} beforeSlides - 既存スライド配列
 * @param {Array} afterSlides  - 新スライド配列
 * @returns {Array} mapping - mapping[i] = j : before[i] → after[j]
 */
function computeOptimalMapping(beforeSlides, afterSlides) {
  const n = beforeSlides.length;
  const m = afterSlides.length;
  const size = Math.max(n, m);

  // 正方行列にパディング（足りない分は0）
  const matrix = Array.from({ length: size }, (_, i) =>
    Array.from({ length: size }, (_, j) => {
      if (i < n && j < m) return getSimilarityForMapping(beforeSlides[i], afterSlides[j], i, j);
      return 0;
    })
  );

  return hungarian(matrix);
}

// ── 使用例 ───────────────────────────────────────────────────

const before = [
  { layout: "title", title: "Introduction", subtitle: "", body: "Hello", image: "" },
  { layout: "content", title: "Main",        subtitle: "sub", body: "Content here", image: "img1.png" },
  { layout: "end",    title: "Thank you",    subtitle: "", body: "", image: "" },
];

const after = [
  { layout: "title",   title: "Introduction", subtitle: "", body: "Hello", image: "" },
  { layout: "content", title: "Main",         subtitle: "sub", body: "Updated content", image: "img1.png" },
  { layout: "end",     title: "See you",      subtitle: "", body: "", image: "" },
];

const mapping = computeOptimalMapping(before, after);
// mapping[i] = j → before[i] は after[j] にマップされる
console.log(mapping); // e.g. [0, 1, 2]
```
