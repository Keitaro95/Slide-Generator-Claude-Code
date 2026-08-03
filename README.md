# Slide Generator — Claude Code Plugin

mdファイル、またはPPTX+mdメモを受け取り、エージェントワークフローでPowerPoint（.pptx）を自動生成するClaude Codeプラグイン。

## install：以下のものをclaude codeにお投げください

```sh
# 0. SSH認証エラーが出る場合は先にこちらを実行（初回のみ）
git config --global url."https://github.com/".insteadOf "git@github.com:"

# 1. マーケットプレイスとして追加
/plugin marketplace add Keitaro95/Slide-Generator-Claude-Code

# 2. プラグインをインストール
/plugin install slide-generator@slide-generator
```

### ローカルで使う場合

```bash
# --plugin-dir フラグでローカルロード
claude --plugin-dir ./path/to/slide-generator

# Claude Code内で再ロード
/reload-plugins
```

インストール後、`/slide-generator` スキルが使えるようになります。

## 機能

- mdファイル・既存PPTX・テキスト貼り付けの3種類の入力に対応
- **構造（A）→ デザイン（B）→ 描画（C）** の3段エージェントパイプライン
- 11種類のスライドレイアウト（title / section / content / compare / process / timeline / diagram / cards / table / progress / closing）
- 意味色＋インラインマークアップ（`[[アクセント]]` / `**太字**` / `{c:red|文字色}` / `{hl:yellow|マーカー}`）で本文を装飾
- デザインガイドラインファイル指定でカラー・フォント・レイアウトを統一適用

## 使い方

```
/slide-generator
```

起動後、対話形式で以下を確認します：

1. 入力タイプ（mdファイル / 既存PPTX+mdメモ / テキスト貼り付け）
2. 補足情報（タイトル・対象オーディエンス・枚数目安・デザイン方向性・デザインガイドライン・保存先）
3. 確認後、エージェントワークフローを実行

## エージェントワークフロー

```
[Step 0] 0ocr  →  A: 2coding  →  B: 3scoring  →  C: 4pptxgen
既存PPTX読取      構造化・座標     色・マークアップ    generate.js 実行
→ slideData      → SPEC(JSON)   → SPEC(装飾付き)   → presentation.pptx
```

### Step 0：スライド理解（PPTX入力時のみ）

| エージェント | 役割 |
|------------|------|
| `slide-ocr`（`0ocr.md`） | 既存PPTXのテキスト・レイアウトを読み取り、slideData配列の雛形を生成 |

### A：デザイン構造化

| エージェント | 役割 |
|------------|------|
| `subagent-structure`（`2coding.md`） | コンテキスト分解→パターン選定→ストーリー再構築→レイアウトテンプレート選択→**全要素の座標算出**→文字規約適用→SPEC（JSON）出力 |

この段階のテキストはプレーン。色・強調は付けない。

### B：デザイン調整

| エージェント | 役割 |
|------------|------|
| `subagent-design`（`3scoring.md`） | 意味色の割り当て→インラインマークアップ付与→図形スタイル調整→装飾追加→全ページ統一性の点検→`designReport` 出力 |

座標は変更しない。強調は1スライド最大3箇所・本文の20%以下。

### C：PPTX出力

| エージェント | 役割 |
|------------|------|
| `subagent-pptxgen`（`4pptxgen.md`） | SPECをレンダラーテンプレートに埋め込み`generate.js`を生成→preflight検証→実行→`presentation.pptx`を出力 |

## ディレクトリ構成

```
slide-generator/
├── .claude-plugin/
│   ├── plugin.json          # プラグインマニフェスト
│   └── marketplace.json     # マーケットプレイス定義
├── skills/
│   ├── slide-generator/
│   │   └── SKILL.md         # メインスキル定義
│   └── refactoring-slides/
│       └── SKILL.md         # 既存PPTX更新時のスライド対応付け
├── agents/                  # サブエージェント群
│   ├── 0ocr.md              # slide-ocr
│   ├── 2coding.md           # A: subagent-structure
│   ├── 3scoring.md          # B: subagent-design
│   └── 4pptxgen.md          # C: subagent-pptxgen
└── CLAUDE.md                # SPEC・マークアップ・slideDataスキーマ定義
```

## 依存関係

スライド生成時に自動インストール：

```bash
npm install pptxgenjs
```
