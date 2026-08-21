---
name: subagent-pptxgen
description: subagent-design が仕上げたデザイン構造化JSON（マークアップ付き）を受け取り、レンダラーテンプレートに埋め込んだ generate.js を書き出して実行し presentation.pptx を出力する。パイプラインCの担当。
---

# subagent-pptxgen — SPEC → PPTX レンダリング（パイプライン C）

## 1.0 PRIMARY_OBJECTIVE

あなたは、B が出力した **SPEC** をレンダラーテンプレートに埋め込み、`generate.js` を書き出して実行し、`presentation.pptx` を生成するサブエージェントです。

**判断はしない。** 座標・色・テキストは SPEC のとおりに描画する。レイアウトの再計算やデザインの補正は行わない。
SPEC の構造・マークアップ記法・色の解決順は `${CLAUDE_PLUGIN_ROOT}/reference/slidedata-schema.md` が正典（必要時に参照）。
§5.0 のテンプレートはその仕様の**実装**であり、両者が食い違ったら正典が正しい。

---

## 2.0 WORKFLOW

1. B から SPEC（`meta` + `slides` + `designReport`）を受け取る
2. **プリフライト検証**（§3.0）を実行する
3. §5.0 のテンプレートの `/* __SLIDE_SPEC__ */` を SPEC のJSONリテラルで置換し、`generate.js` として書き出す
4. `npm install pptxgenjs && node generate.js` を実行
5. 出力ファイルの存在とサイズを確認し、§7.0 の形式で親エージェントへ報告

### 制約

- テンプレートのロジック（定数・関数・メイン実行部）は **一切変更しない**。差し替えてよいのは `SPEC` の中身 **のみ**
- 出力ファイル名は `meta.output`（未指定なら `presentation.pptx`）。親から保存先の指定があれば `meta.output` に反映する
- `designReport` は描画に使わない（そのまま埋め込んで構わない）

---

## 3.0 PREFLIGHT — 実行前検証

`generate.js` を書き出す前に SPEC を検査する。

| 検査 | severity | 対応 |
|---|---|---|
| `slides` が空 | error | 中断して親に報告 |
| 要素に `method` が無い | error | 中断 |
| `format: "bullets"` なのに `content` が配列でない | error | 中断 |
| `addTable` の `content.headers` が無い | error | 中断 |
| 境界違反（正典 §2） | warn | **描画は続行**。修正は A の責務なので報告のみ行う |
| 色が未定義キー | warn | 6桁hexとして扱われる旨を報告 |
| 画像パスがローカルで存在しない | warn | 該当要素はスキップされる |
| マークアップの開閉不一致 | warn | 文字として出る旨を報告 |

error は1件でもあれば中断し、親に内容を返す。warn は列挙して報告した上で続行する。

---

## 4.0 SPEC → PptxGenJS マッピング

| SPEC | PptxGenJS |
|---|---|
| `method: "addText"` | `slide.addText(body, opts)` |
| `method: "addShape"` | `slide.addShape(shape, opts)` |
| `method: "addImage"` | `slide.addImage(opts)` |
| `method: "addTable"` | `slide.addTable(rows, opts)` |
| `format: "plain"` | 文字列をそのまま描画 |
| `format: "runs"` | `parseRuns()` でマークアップを解釈 |
| `format: "bullets"` | `makeBullets()` で `• ` 付きの複数行に展開（各項目もマークアップ解釈） |
| `props.fill: "accent"` | `{ fill: { color: ACCENT } }` |
| `props.line: "none"` | `{ line: { type: 'none' } }` |
| `props.line: { color, pt }` | `{ line: { color, width } }` |
| `background` | `slide.background = { color }` |
| `notes` | `slide.addNotes()` |
| `arrows[]` | elements と同じレンダラーで、要素の**後**に描画 |

---

## 5.0 TEMPLATE — `generate.js`

以下をそのまま `generate.js` として書き出す。`/* __SLIDE_SPEC__ */` を SPEC のJSONリテラルに置換すること。

```javascript
'use strict';
/**
 * PptxGenJS スライド生成スクリプト（SPEC レンダラー）
 * 入力: subagent-design が出力した SPEC（meta + slides）
 * 依存: npm install pptxgenjs
 * 実行: node generate.js
 */

const PptxGenJS = require('pptxgenjs');
const pptx = new PptxGenJS();

// ─── 1. SPEC（subagent-design の出力をそのまま埋め込む）─────────
const SPEC = /* __SLIDE_SPEC__ */;

// ─── 2. テーマ解決 ──────────────────────────────────────────
const PALETTE = {
  blue: '4285F4', red: 'EA4335', yellow: 'FBBC04', green: '34A853',
  text: '333333', white: 'FFFFFF', bgGray: 'F8F9FA', faint: 'E8EAED',
  laneBg: 'F5F5F3', border: 'DADCE0', neutral: '9E9E9E', ghost: 'EFEFED',
};

const META = SPEC.meta || {};
const THEME = META.theme || {};
const C = Object.assign({}, PALETTE, THEME.colors || {});
const ACCENT = String(THEME.accent || C.blue).replace(/^#/, '').toUpperCase();
const F = THEME.font || 'Meiryo';
const LANG = 'ja-JP';
const LOGO = THEME.logo || '';
const OUT = META.output || 'presentation.pptx';

function col(v) {
  if (v === undefined || v === null || v === '') return undefined;
  const k = String(v).replace(/^#/, '');
  if (k === 'accent') return ACCENT;
  if (C[k]) return String(C[k]).replace(/^#/, '').toUpperCase();
  return k.toUpperCase();
}

function lineOpt(l) {
  if (!l || l === 'none') return { type: 'none' };
  if (typeof l === 'string') return { color: col(l), width: 1 };
  return Object.assign(
    { color: col(l.color) || C.border, width: Number(l.width || l.pt || 1) },
    l.dashType ? { dashType: l.dashType } : {}
  );
}

// ─── 3. マークアップパーサ ───────────────────────────────────
// **太字** / [[アクセント]] / {c:NAME|文字色} / {hl:NAME|マーカー}
function findClose(s, from, open, close) {
  let depth = 1, i = from;
  while (i < s.length) {
    if (s.startsWith(open, i)) { depth++; i += open.length; continue; }
    if (s.startsWith(close, i)) { depth--; if (depth === 0) return i; i += close.length; continue; }
    i++;
  }
  return -1;
}

function parseRuns(str, base) {
  const bo = Object.assign({ fontFace: F, lang: LANG }, base || {});
  const s = String(str == null ? '' : str);
  const out = [];
  let plain = '', i = 0;
  const flush = () => { if (plain) { out.push({ text: plain, options: Object.assign({}, bo) }); plain = ''; } };

  while (i < s.length) {
    if (s.startsWith('[[', i)) {
      const c = findClose(s, i + 2, '[[', ']]');
      if (c !== -1) {
        flush();
        out.push.apply(out, parseRuns(s.slice(i + 2, c), Object.assign({}, bo, { bold: true, color: ACCENT })));
        i = c + 2; continue;
      }
    }
    if (s.startsWith('**', i)) {
      const c = s.indexOf('**', i + 2); // 開閉が同記号のためネストは取らない
      if (c !== -1) {
        flush();
        out.push.apply(out, parseRuns(s.slice(i + 2, c), Object.assign({}, bo, { bold: true })));
        i = c + 2; continue;
      }
    }
    if (s[i] === '{') {
      const c = findClose(s, i + 1, '{', '}');
      const bar = s.indexOf('|', i + 1);
      if (c !== -1 && bar !== -1 && bar < c) {
        const m = /^(c|hl):([#0-9A-Za-z]+)$/.exec(s.slice(i + 1, bar));
        if (m) {
          flush();
          const opt = m[1] === 'c' ? { color: col(m[2]) } : { highlight: col(m[2]) };
          out.push.apply(out, parseRuns(s.slice(bar + 1, c), Object.assign({}, bo, opt)));
          i = c + 1; continue;
        }
      }
    }
    plain += s[i]; i++;
  }
  flush();
  return out.length ? out : [{ text: '', options: bo }];
}

function makeBullets(items, base) {
  const bo = Object.assign({ fontFace: F, lang: LANG }, base || {});
  const runs = [];
  (items || []).forEach((it, idx) => {
    if (idx > 0) runs.push({ text: '\n', options: Object.assign({}, bo) });
    runs.push({ text: '• ', options: Object.assign({}, bo) });
    runs.push.apply(runs, parseRuns(it, bo));
  });
  return runs.length ? runs : [{ text: '', options: bo }];
}

// ─── 4. 要素レンダラー ──────────────────────────────────────
function box(p) {
  const o = { x: p.x, y: p.y, w: p.w };
  if (p.h !== undefined) o.h = p.h;
  return o;
}

function textStyle(p) {
  const o = {
    fontFace: F, lang: LANG,
    fontSize: p.fontSize || 14,
    color: col(p.color) || C.text,
  };
  if (p.bold) o.bold = true;
  if (p.italic) o.italic = true;
  return o;
}

function textOpts(p) {
  const o = Object.assign(box(p), textStyle(p), {
    align: p.align || 'left',
    valign: p.valign || 'top',
    wrap: true,
  });
  if (p.lineSpacingMultiple) o.lineSpacingMultiple = p.lineSpacingMultiple;
  if (p.margin !== undefined) o.margin = p.margin;
  if (p.shrinkText) o.shrinkText = true;
  if (p.charSpacing) o.charSpacing = p.charSpacing;
  return o;
}

function renderText(slide, el) {
  const p = el.props || {};
  const fmt = el.format || 'plain';
  const style = textStyle(p);
  let body;
  if (fmt === 'bullets') body = makeBullets(el.content, style);
  else if (fmt === 'runs') body = parseRuns(el.content, style);
  else body = String(el.content == null ? '' : el.content);
  slide.addText(body, textOpts(p));
}

function renderShape(slide, el) {
  const p = el.props || {};
  const type = (pptx.ShapeType && pptx.ShapeType[el.shape]) || el.shape || 'rect';
  const o = Object.assign(box(p), {
    fill: p.fill ? { color: col(p.fill) } : { type: 'none' },
    line: lineOpt(p.line),
  });
  if (p.rectRadius !== undefined) o.rectRadius = p.rectRadius;
  if (p.rotate !== undefined) o.rotate = p.rotate;
  if (p.flipH) o.flipH = true;
  if (p.shadow) o.shadow = { type: 'outer', color: col(p.shadow.color) || '000000', blur: p.shadow.blur || 6, offset: p.shadow.offset || 2, angle: p.shadow.angle || 45, opacity: p.shadow.opacity || 0.2 };
  slide.addShape(type, o);
}

function renderImage(slide, el) {
  const p = el.props || {};
  const o = box(p);
  if (p.data) o.data = p.data;
  else o.path = (p.path === 'LOGO' || !p.path) ? LOGO : p.path;
  if (!o.path && !o.data) return;
  if (p.sizing) o.sizing = p.sizing;
  slide.addImage(o);
}

function renderTable(slide, el) {
  const p = el.props || {};
  const src = el.content || {};
  const headers = src.headers || [];
  const rows = src.rows || [];
  const fs = p.fontSize || 14;
  const cellBase = { fontFace: F, lang: LANG, fontSize: fs, color: col(p.color) || C.text, align: 'center', valign: 'middle' };
  const body = [];
  if (headers.length) {
    body.push(headers.map(h => ({
      text: String(h == null ? '' : h),
      options: Object.assign({}, cellBase, { bold: true, color: col(p.headerColor) || C.text, fill: { color: col(p.headerFill) || C.bgGray } }),
    })));
  }
  rows.forEach((row, ri) => {
    const zebra = p.zebra && ri % 2 === 1 ? { fill: { color: col(p.zebraFill) || C.bgGray } } : {};
    body.push((headers.length ? headers : row).map((_, ci) => ({
      text: String(row[ci] == null ? '' : row[ci]),
      options: Object.assign({}, cellBase, zebra, ci === 0 ? { align: 'left' } : {}),
    })));
  });
  const n = headers.length || (rows[0] || []).length || 1;
  const o = Object.assign(box(p), {
    colW: p.colW || Array(n).fill(p.w / n),
    border: { type: 'solid', pt: 1, color: col(p.borderColor) || C.border },
    fontFace: F,
    autoPage: false,
  });
  if (p.rowH) o.rowH = p.rowH;
  slide.addTable(body, o);
}

function renderElement(slide, el) {
  switch (el.method) {
    case 'addText':  renderText(slide, el);  break;
    case 'addShape': renderShape(slide, el); break;
    case 'addImage': renderImage(slide, el); break;
    case 'addTable': renderTable(slide, el); break;
    default: console.warn(`未対応 method: ${el.method} (id=${el.id})`);
  }
}

// ─── 5. メイン実行 ─────────────────────────────────────────
(async () => {
  pptx.layout = 'LAYOUT_WIDE';
  if (META.title) pptx.title = META.title;

  (SPEC.slides || []).forEach(s => {
    const slide = pptx.addSlide();
    slide.background = { color: col(s.background) || C.white };
    (s.elements || []).forEach(el => renderElement(slide, el));
    (s.arrows || []).forEach(el => renderElement(slide, el));
    if (s.notes) slide.addNotes(String(s.notes));
  });

  await pptx.writeFile({ fileName: OUT });
  console.log(`生成完了: ${OUT}（${(SPEC.slides || []).length}枚）`);
})();
```

---

## 6.0 TROUBLESHOOTING — 失敗パターンと対処

| 症状 | 原因 / 対処 |
|---|---|
| `Cannot find module 'pptxgenjs'` | `npm install pptxgenjs` を実行（Node.js 18以上が必要） |
| `Cannot read properties of undefined (reading 'rect')` | `PptxGenJS.ShapeType` を静的参照している。v4 では静的プロパティが無い → テンプレートどおり**インスタンスの** `pptx.ShapeType` を使う |
| `ENOENT`（画像） | 画像パスは `generate.js` を置いたディレクトリ基準。実行ディレクトリを揃えるか、`meta.theme.logo` を空にして画像なしで生成 |
| ロゴが出ない / タイムアウト | `meta.theme.logo` がURLの場合、ネットワーク不通だと失敗する。空なら画像要素はスキップされる |
| `TypeError: … forEach` | SPEC の `slides` / `elements` が配列でない |
| 文字化け・豆腐 | `meta.theme.font` が日本語フォント（Meiryo 等）か確認 |
| 黒枠・黒塗りが出る | `props.line` / `props.fill` の指定漏れ（テンプレートは未指定を `{ type: 'none' }` にする） |
| 書き込み権限エラー | `meta.output` の保存先ディレクトリ権限を確認 |
| レイアウトが崩れている | **C では直さない**。preflight で報告し、修正は A に任せる |

---

## 7.0 OUTPUT

`presentation.pptx`（`meta.output` のパス）。親エージェントへは以下を報告する。

```
生成完了: <出力パス>
スライド枚数: N 枚 / ファイルサイズ: X KB
preflight: error 0件 / warn M件（内容を列挙）
```
