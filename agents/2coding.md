---
name: subagent-slidecode
description: slideData配列をもとにPptxGenJSのNode.jsスクリプトを生成し、presentation.pptxを出力する。
---


# subagent-slidecode

受け取った `slideData` 配列をもとに PptxGenJS の Node.js スクリプトを生成する。

## 入力

`slideData` 配列（JSON）。スライドタイプ一覧：
`title` / `section` / `content` / `compare` / `process` / `timeline` / `diagram` / `cards` / `table` / `progress` / `closing`

## 出力

以下のテンプレートの `slideData` 部分のみを書き換えた `generate.js` を出力する。
実行方法: `npm install pptxgenjs && node generate.js`

## テンプレート

```javascript
'use strict';
/**
 * PptxGenJS スライド自動生成スクリプト
 * Version: 1.0 (Google Design Template — PptxGenJS Port)
 * 依存: npm install pptxgenjs
 * 実行: node generate.js
 */

const PptxGenJS = require('pptxgenjs');

// ─── 1. 定数 ────────────────────────────────────────────
// 960×540px ベース → 10×5.625インチ (16:9)。1px = 1/96インチ
const PX = n => +(n / 96).toFixed(4);

const C = {
  blue:    '4285F4',
  red:     'EA4335',
  yellow:  'FBBC04',
  green:   '34A853',
  text:    '333333',
  white:   'FFFFFF',
  bgGray:  'F8F9FA',
  faint:   'E8EAED',
  laneBg:  'F5F5F3',
  border:  'DADCE0',
  neutral: '9E9E9E',
  ghost:   'EFEFED',
};

const F = 'Arial';
const FS = {
  title: 45, date: 16, secTitle: 38, cTitle: 28,
  subhead: 18, body: 14, footer: 9,
  lane: 13, small: 10, step: 14, ghost: 180,
};

const LOGO = 'https://upload.wikimedia.org/wikipedia/commons/thumb/2/2f/Google_2015_logo.svg/1024px-Google_2015_logo.svg.png';
const FOOTER_TEXT = `© ${new Date().getFullYear()} Your Organization`;

// ─── 2. 位置定義 (px) ────────────────────────────────────
const POS = {
  title:   { logo: { l:55, t:105, w:135, h:45 }, text: { l:50, t:230, w:800, h:90 }, date: { l:50, t:340, w:250, h:40 } },
  header:  { logo: { r:20, t:20, w:75, h:25 }, titleText: { l:25, t:60, w:830, h:65 }, underline: { l:25, t:128, w:260, h:4 }, subhead: { l:25, t:140, w:830, h:30 } },
  content: { body: { l:25, t:172, w:910, h:303 }, colL: { l:25, t:172, w:440, h:303 }, colR: { l:495, t:172, w:440, h:303 } },
  compare: { leftBox: { l:25, t:172, w:430, h:303 }, rightBox: { l:505, t:172, w:430, h:303 } },
  section: { ghost: { l:35, t:120, w:300, h:200 }, text: { l:55, t:230, w:840, h:80 } },
  footer:  { left: { l:15, t:505, w:250, h:20 }, right: { r:15, t:505, w:50, h:20 } },
  bar:     { l:0, t:534, w:960, h:6 },
};

function px2rect(pos, dy = 0) {
  const l = pos.r !== undefined ? 960 - pos.r - pos.w : pos.l;
  return { x: PX(l), y: PX(pos.t + dy), w: PX(pos.w), h: pos.h ? PX(pos.h) : undefined };
}

const noLine = () => ({ type: 'none' });

// ─── 3. ユーティリティ ────────────────────────────────────
function addBar(slide) {
  const r = px2rect(POS.bar);
  slide.addShape(PptxGenJS.ShapeType.rect, { ...r, fill: { color: C.blue }, line: noLine() });
}

function addFooter(slide, pg) {
  const l = px2rect(POS.footer.left);
  slide.addText(FOOTER_TEXT, { ...l, fontFace: F, fontSize: FS.footer, color: C.text });
  if (pg > 0) {
    const r = px2rect(POS.footer.right);
    slide.addText(String(pg), { ...r, fontFace: F, fontSize: FS.footer, color: C.blue, align: 'right' });
  }
}

function addBarFooter(slide, pg) { addBar(slide); addFooter(slide, pg); }

function addHeader(slide, title) {
  const logo = px2rect(POS.header.logo);
  slide.addImage({ path: LOGO, x: logo.x, y: logo.y, w: logo.w, h: logo.h });

  const t = px2rect(POS.header.titleText);
  slide.addText(title || '', { ...t, fontFace: F, fontSize: FS.cTitle, bold: true, color: C.text, wrap: true });

  const u = px2rect(POS.header.underline);
  slide.addShape(PptxGenJS.ShapeType.rect, { ...u, fill: { color: C.blue }, line: noLine() });
}

// subhead がある場合は描画して dy=36px を返す。ない場合は 0
function addSubhead(slide, subhead) {
  if (!subhead) return 0;
  const r = px2rect(POS.header.subhead);
  slide.addText(subhead, { ...r, fontFace: F, fontSize: FS.subhead, color: C.text });
  return 36;
}

// インライン記法 [[青太字]] / **太字** → PptxGenJS text runs
function parseRuns(s, base = {}) {
  const bo = { fontFace: F, ...base };
  const runs = [];
  let plain = '', i = 0;
  const flush = () => { if (plain) { runs.push({ text: plain, options: { ...bo } }); plain = ''; } };
  while (i < s.length) {
    if (s[i] === '[' && s[i + 1] === '[') {
      const c = s.indexOf(']]', i + 2);
      if (c !== -1) { flush(); runs.push({ text: s.substring(i + 2, c), options: { ...bo, bold: true, color: C.blue } }); i = c + 2; continue; }
    }
    if (s[i] === '*' && s[i + 1] === '*') {
      const c = s.indexOf('**', i + 2);
      if (c !== -1) { flush(); runs.push({ text: s.substring(i + 2, c), options: { ...bo, bold: true } }); i = c + 2; continue; }
    }
    plain += s[i]; i++;
  }
  flush();
  return runs.length ? runs : [{ text: '', options: bo }];
}

// 箇条書き配列 → PptxGenJS text runs（• プレフィックス付き）
function makeBullets(points) {
  const base = { fontFace: F, fontSize: FS.body, color: C.text };
  const runs = [];
  (points || []).forEach((pt, idx) => {
    if (idx > 0) runs.push({ text: '\n\n', options: base });
    runs.push({ text: '• ', options: base });
    runs.push(...parseRuns(String(pt || ''), base));
  });
  return runs.length ? runs : [{ text: '• —', options: base }];
}

// ─── 4. slideData（ここを書き換える） ────────────────────
const slideData = [
  { type: 'title', title: 'サンプルプレゼンテーション', date: '2025.08.12', notes: '本日はお集まりいただきありがとうございます。' },
  { type: 'section', title: '1. はじめに', notes: '最初のセクションです。' },
  { type: 'cards', title: 'Google風デザインのテスト', subhead: 'モダンなデザインパターン', columns: 3, items: [
    { title: 'パターン1', desc: '現状：[[重要機能]]実装済み\n課題：パフォーマンス**最適化**が必要' },
    { title: 'パターン2', desc: '現状：デザイン更新完了\n課題：[[ユーザビリティ改善]]を検討' },
    { title: 'パターン3', desc: '現状：テスト環境構築\n課題：**本番環境への移行準備**' },
  ], notes: 'カード形式のスライドです。' },
  { type: 'closing', notes: '以上で説明を終わります。' },
];

// ─── 5. スライド生成関数群 ────────────────────────────────
function createTitleSlide(slide, data) {
  slide.background = { color: C.white };
  const logo = px2rect(POS.title.logo);
  slide.addImage({ path: LOGO, x: logo.x, y: logo.y, w: logo.w, h: logo.h });
  const t = px2rect(POS.title.text);
  slide.addText(data.title || '', { ...t, fontFace: F, fontSize: FS.title, bold: true, color: C.text, wrap: true, valign: 'top' });
  const d = px2rect(POS.title.date);
  slide.addText(data.date || '', { ...d, fontFace: F, fontSize: FS.date, color: C.text });
  addBar(slide);
}

function createSectionSlide(slide, data, secNum, pg) {
  slide.background = { color: C.bgGray };
  const num = String(secNum).padStart(2, '0');
  const gr = px2rect(POS.section.ghost);
  slide.addText(num, { ...gr, fontFace: F, fontSize: FS.ghost, bold: true, color: C.ghost, valign: 'middle' });
  const t = px2rect(POS.section.text);
  slide.addText(data.title || '', { ...t, fontFace: F, fontSize: FS.secTitle, bold: true, color: C.text, align: 'center', valign: 'middle' });
  addFooter(slide, pg);
}

function createContentSlide(slide, data, pg) {
  slide.background = { color: C.white };
  addHeader(slide, data.title);
  const dy = addSubhead(slide, data.subhead);
  const points = Array.isArray(data.points) ? data.points : [];
  const isTwo = !!(data.twoColumn || (Array.isArray(data.columns) && data.columns.length === 2));

  if (isTwo) {
    let L = [], R = [];
    if (Array.isArray(data.columns) && data.columns.length === 2) {
      L = data.columns[0] || []; R = data.columns[1] || [];
    } else {
      const mid = Math.ceil(points.length / 2);
      L = points.slice(0, mid); R = points.slice(mid);
    }
    const lr = px2rect(POS.content.colL, dy);
    const rr = px2rect(POS.content.colR, dy);
    slide.addText(makeBullets(L), { ...lr, wrap: true });
    slide.addText(makeBullets(R), { ...rr, wrap: true });
  } else if (points.length > 0) {
    const br = px2rect(POS.content.body, dy);
    slide.addText(makeBullets(points), { ...br, wrap: true });
  }
  addBarFooter(slide, pg);
}

function createCompareSlide(slide, data, pg) {
  slide.background = { color: C.white };
  addHeader(slide, data.title);
  const dy = addSubhead(slide, data.subhead);

  [
    { pos: POS.compare.leftBox,  title: data.leftTitle  || '選択肢A', items: data.leftItems  || [] },
    { pos: POS.compare.rightBox, title: data.rightTitle || '選択肢B', items: data.rightItems || [] },
  ].forEach(({ pos, title, items }) => {
    const r = px2rect(pos, dy);
    const barH = PX(30), pad = PX(12);
    slide.addShape(PptxGenJS.ShapeType.rect, { x: r.x, y: r.y, w: r.w, h: r.h, fill: { color: C.laneBg }, line: { color: C.border, pt: 1 } });
    slide.addShape(PptxGenJS.ShapeType.rect, { x: r.x, y: r.y, w: r.w, h: barH, fill: { color: C.blue }, line: noLine() });
    slide.addText(title, { x: r.x, y: r.y, w: r.w, h: barH, fontFace: F, fontSize: FS.lane, bold: true, color: C.white, align: 'center', valign: 'middle' });
    slide.addText(makeBullets(items), { x: r.x + pad, y: r.y + barH + pad, w: r.w - pad * 2, h: r.h - barH - pad * 2, wrap: true });
  });
  addBarFooter(slide, pg);
}

function createProcessSlide(slide, data, pg) {
  slide.background = { color: C.white };
  addHeader(slide, data.title);
  const dy = addSubhead(slide, data.subhead);
  const area = px2rect({ l: 25, t: 172, w: 910, h: 303 }, dy);
  const steps = Array.isArray(data.steps) ? data.steps : [];
  const n = Math.max(1, steps.length);
  const gapY = (area.h - PX(40)) / Math.max(1, n - 1);
  const cx = area.x + PX(44);
  const top0 = area.y + PX(10);

  if (n > 1) {
    slide.addShape(PptxGenJS.ShapeType.rect, { x: cx - PX(1), y: top0 + PX(6), w: PX(2), h: gapY * (n - 1), fill: { color: C.faint }, line: noLine() });
  }
  for (let i = 0; i < n; i++) {
    const cy = top0 + gapY * i;
    const sz = PX(28);
    slide.addShape(PptxGenJS.ShapeType.rect, { x: cx - sz / 2, y: cy - sz / 2, w: sz, h: sz, fill: { color: C.white }, line: { color: C.blue, pt: 1 } });
    slide.addText(String(i + 1), { x: cx - sz / 2, y: cy - sz / 2, w: sz, h: sz, fontFace: F, fontSize: 12, bold: true, color: C.blue, align: 'center', valign: 'middle' });
    slide.addText(steps[i] || '', { x: cx + PX(28), y: cy - PX(16), w: area.w - PX(70), h: PX(32), fontFace: F, fontSize: FS.step, color: C.text, valign: 'middle' });
  }
  addBarFooter(slide, pg);
}

function createTimelineSlide(slide, data, pg) {
  slide.background = { color: C.white };
  addHeader(slide, data.title);
  const dy = addSubhead(slide, data.subhead);
  const area = px2rect({ l: 25, t: 172, w: 910, h: 303 }, dy);
  const milestones = Array.isArray(data.milestones) ? data.milestones : [];
  if (!milestones.length) { addBarFooter(slide, pg); return; }

  const inner = PX(60);
  const baseY = area.y + area.h * 0.55;
  const leftX = area.x + inner;
  const rightX = area.x + area.w - inner;
  const dotR = PX(8);
  const gap = (rightX - leftX) / Math.max(1, milestones.length - 1);

  slide.addShape(PptxGenJS.ShapeType.rect, { x: leftX, y: baseY - PX(1), w: rightX - leftX, h: PX(2), fill: { color: C.faint }, line: noLine() });

  milestones.forEach((m, i) => {
    const x = leftX + gap * i;
    const state = (m.state || 'todo').toLowerCase();
    const dotFill = state === 'done' ? C.green : C.white;
    const dotLine = state === 'done' ? noLine() : state === 'next' ? { color: C.yellow, pt: 2 } : { color: C.neutral, pt: 1 };
    slide.addShape(PptxGenJS.ShapeType.ellipse, { x: x - dotR / 2, y: baseY - dotR / 2, w: dotR, h: dotR, fill: { color: dotFill }, line: dotLine });
    slide.addText(String(m.label || ''), { x: x - PX(45), y: baseY - PX(40), w: PX(90), h: PX(20), fontFace: F, fontSize: FS.small, bold: true, align: 'center', color: C.text });
    slide.addText(String(m.date || ''), { x: x - PX(45), y: baseY + PX(8), w: PX(90), h: PX(18), fontFace: F, fontSize: FS.small, color: C.neutral, align: 'center' });
  });
  addBarFooter(slide, pg);
}

function createDiagramSlide(slide, data, pg) {
  slide.background = { color: C.white };
  addHeader(slide, data.title);
  const dy = addSubhead(slide, data.subhead);
  const area = px2rect({ l: 25, t: 172, w: 910, h: 303 }, dy);
  const lanes = Array.isArray(data.lanes) ? data.lanes : [];
  const n = Math.max(1, lanes.length);
  const laneGap = PX(24), lanePad = PX(10), laneTitleH = PX(30);
  const cardGap = PX(12), cardMinH = PX(48), cardMaxH = PX(70);
  const arrowH = PX(10), arrowGap = PX(8);
  const laneW = (area.w - laneGap * (n - 1)) / n;
  const cardBoxes = [];

  for (let j = 0; j < n; j++) {
    const lane = lanes[j] || { title: '', items: [] };
    const left = area.x + j * (laneW + laneGap);
    const top = area.y;

    slide.addShape(PptxGenJS.ShapeType.rect, { x: left, y: top, w: laneW, h: laneTitleH, fill: { color: C.laneBg }, line: { color: C.border, pt: 1 } });
    slide.addText(lane.title || '', { x: left, y: top, w: laneW, h: laneTitleH, fontFace: F, fontSize: FS.lane, bold: true, align: 'center', valign: 'middle', color: C.text });

    const items = Array.isArray(lane.items) ? lane.items : [];
    const rows = Math.max(1, items.length);
    const availH = area.h - laneTitleH - lanePad * 2;
    const cardH = Math.max(cardMinH, Math.min(cardMaxH, (availH - cardGap * (rows - 1)) / rows));
    const totalH = cardH * rows + cardGap * (rows - 1);
    const firstTop = top + laneTitleH + lanePad + Math.max(0, (availH - totalH) / 2);

    cardBoxes[j] = [];
    for (let i = 0; i < rows; i++) {
      const cardTop = firstTop + i * (cardH + cardGap);
      const cardLeft = left + lanePad;
      const cardW = laneW - lanePad * 2;
      slide.addShape(PptxGenJS.ShapeType.roundRect, { x: cardLeft, y: cardTop, w: cardW, h: cardH, fill: { color: C.white }, line: { color: C.border, pt: 1 }, rectRadius: 0.05 });
      slide.addText(items[i] || '', { x: cardLeft, y: cardTop, w: cardW, h: cardH, fontFace: F, fontSize: FS.body, color: C.text, align: 'center', valign: 'middle', wrap: true });
      cardBoxes[j][i] = { x: cardLeft, y: cardTop, w: cardW, h: cardH };
    }
  }

  for (let j = 0; j < n - 1; j++) {
    const L = cardBoxes[j], R = cardBoxes[j + 1];
    for (let i = 0; i < Math.max(L.length, R.length); i++) {
      const a = L[i], b = R[i];
      if (a && b) {
        const w = Math.max(0, b.x - (a.x + a.w) - arrowGap * 2);
        if (w >= PX(8)) {
          const yMid = ((a.y + a.h / 2) + (b.y + b.h / 2)) / 2;
          slide.addShape(PptxGenJS.ShapeType.rightArrow, { x: a.x + a.w + arrowGap, y: yMid - arrowH / 2, w, h: arrowH, fill: { color: C.blue }, line: noLine() });
        }
      }
    }
  }
  addBarFooter(slide, pg);
}

function createCardsSlide(slide, data, pg) {
  slide.background = { color: C.white };
  addHeader(slide, data.title);
  const dy = addSubhead(slide, data.subhead);
  const area = px2rect({ l: 25, t: 172, w: 910, h: 303 }, dy);
  const items = Array.isArray(data.items) ? data.items : [];
  const cols = Math.min(3, Math.max(2, Number(data.columns) || (items.length <= 4 ? 2 : 3)));
  const gap = PX(16);
  const rows = Math.ceil(items.length / cols);
  const cardW = (area.w - gap * (cols - 1)) / cols;
  const cardH = Math.max(PX(92), (area.h - gap * (rows - 1)) / rows);

  for (let idx = 0; idx < items.length; idx++) {
    const r = Math.floor(idx / cols), col = idx % cols;
    const left = area.x + col * (cardW + gap);
    const top = area.y + r * (cardH + gap);
    slide.addShape(PptxGenJS.ShapeType.roundRect, { x: left, y: top, w: cardW, h: cardH, fill: { color: C.white }, line: { color: C.border, pt: 1 }, rectRadius: 0.05 });

    const obj = items[idx];
    let textRuns;
    if (typeof obj === 'string') {
      textRuns = parseRuns(obj, { fontFace: F, fontSize: FS.body, color: C.text });
    } else {
      const title = String(obj.title || '');
      const desc = String(obj.desc || '');
      textRuns = [];
      if (title) textRuns.push({ text: title, options: { fontFace: F, fontSize: FS.body, color: C.text, bold: true } });
      if (desc) {
        textRuns.push({ text: '\n', options: { fontFace: F, fontSize: FS.body } });
        textRuns.push(...parseRuns(desc, { fontFace: F, fontSize: FS.body, color: C.text }));
      }
    }
    slide.addText(textRuns, { x: left, y: top, w: cardW, h: cardH, valign: 'middle', wrap: true });
  }
  addBarFooter(slide, pg);
}

function createTableSlide(slide, data, pg) {
  slide.background = { color: C.white };
  addHeader(slide, data.title);
  const dy = addSubhead(slide, data.subhead);
  const area = px2rect({ l: 25, t: 172, w: 910, h: 303 }, dy);
  const headers = Array.isArray(data.headers) ? data.headers : [];
  const rows = Array.isArray(data.rows) ? data.rows : [];

  if (headers.length > 0) {
    const tableRows = [];
    tableRows.push(headers.map(h => ({ text: String(h || ''), options: { bold: true, fontFace: F, fontSize: FS.body, color: C.text, fill: C.bgGray, align: 'center', valign: 'middle' } })));
    rows.forEach(row => {
      tableRows.push(headers.map((_, c) => ({ text: String(row[c] || ''), options: { fontFace: F, fontSize: FS.body, color: C.text, align: 'center', valign: 'middle' } })));
    });
    slide.addTable(tableRows, { x: area.x, y: area.y, w: area.w, border: { type: 'solid', pt: 1, color: C.border }, fontFace: F });
  }
  addBarFooter(slide, pg);
}

function createProgressSlide(slide, data, pg) {
  slide.background = { color: C.white };
  addHeader(slide, data.title);
  const dy = addSubhead(slide, data.subhead);
  const area = px2rect({ l: 25, t: 172, w: 910, h: 303 }, dy);
  const items = Array.isArray(data.items) ? data.items : [];
  const n = Math.max(1, items.length);
  const rowH = area.h / n;

  for (let i = 0; i < n; i++) {
    const y = area.y + i * rowH + PX(6);
    slide.addText(String(items[i].label || ''), { x: area.x, y, w: PX(150), h: PX(18), fontFace: F, fontSize: FS.body, color: C.text });
    const barLeft = area.x + PX(160);
    const barW = area.w - PX(210);
    slide.addShape(PptxGenJS.ShapeType.rect, { x: barLeft, y, w: barW, h: PX(14), fill: { color: C.faint }, line: noLine() });
    const p = Math.max(0, Math.min(100, Number(items[i].percent || 0)));
    if (p > 0) slide.addShape(PptxGenJS.ShapeType.rect, { x: barLeft, y, w: barW * (p / 100), h: PX(14), fill: { color: C.green }, line: noLine() });
    slide.addText(String(p) + '%', { x: barLeft + barW + PX(6), y: y - PX(1), w: PX(40), h: PX(16), fontFace: F, fontSize: FS.small, color: C.neutral });
  }
  addBarFooter(slide, pg);
}

function createClosingSlide(slide) {
  slide.background = { color: C.white };
  const imgW = PX(450);
  const imgH = imgW * (120 / 361); // Google logo aspect ratio
  slide.addImage({ path: LOGO, x: (10 - imgW) / 2, y: (5.625 - imgH) / 2, w: imgW, h: imgH });
}

// ─── 6. メイン実行 ────────────────────────────────────────
(async () => {
  const pptx = new PptxGenJS();
  pptx.layout = 'LAYOUT_WIDE';
  let pg = 0, secNum = 0;

  for (const data of slideData) {
    const slide = pptx.addSlide();
    if (data.type !== 'title' && data.type !== 'closing') pg++;

    switch (data.type) {
      case 'title':    createTitleSlide(slide, data);            break;
      case 'section':  createSectionSlide(slide, data, ++secNum, pg); break;
      case 'content':  createContentSlide(slide, data, pg);      break;
      case 'compare':  createCompareSlide(slide, data, pg);      break;
      case 'process':  createProcessSlide(slide, data, pg);      break;
      case 'timeline': createTimelineSlide(slide, data, pg);     break;
      case 'diagram':  createDiagramSlide(slide, data, pg);      break;
      case 'cards':    createCardsSlide(slide, data, pg);        break;
      case 'table':    createTableSlide(slide, data, pg);        break;
      case 'progress': createProgressSlide(slide, data, pg);     break;
      case 'closing':  createClosingSlide(slide);                break;
    }

    if (data.notes) slide.addNotes(data.notes);
  }

  await pptx.writeFile({ fileName: 'presentation.pptx' });
  console.log('生成完了: presentation.pptx');
})();
```

## slideData スキーマ早見表

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

インライン装飾: `[[青太字]]` / `**太字**`
