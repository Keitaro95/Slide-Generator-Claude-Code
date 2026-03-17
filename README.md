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
- PptxGenJSによるスライド自動生成
- 11種類のスライドレイアウト（title / section / content / compare / process / timeline / diagram / cards / table / progress / closing）
- ハンガリアンアルゴリズムによる品質スコアリング＋自動リファインメントループ
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

### フェーズ1：スライド理解（PPTX入力時のみ）

| エージェント | 役割 |
|------------|------|
| `slide-ocr`（`0ocr.md`） | 既存PPTXのテキスト・レイアウトを読み取り、slideData配列の雛形を生成 |

### フェーズ2：スライド戦略・slideData生成

| エージェント | 役割 |
|------------|------|
| `conductor`（`1conductor.md`） | 入力テキストをコンテキスト分解→正規化→パターン選定→ストーリー再構築→slideData生成→スピーカーノート生成→自己検証 |

### フェーズ3：コード生成・スコアリング・PPTX出力

| エージェント | 役割 |
|------------|------|
| `subagent-slidecode`（`2coding.md`） | slideDataをPptxGenJSテンプレートに埋め込んだ`generate.js`を生成 |
| `subagent-scoring`（`3scoring.md`） | ハンガリアンアルゴリズムでスライド品質をスコアリング（閾値未満ならフェーズ2〜3をループ） |
| `subagent-pptxgen`（`4pptxgen.md`） | `generate.js`を実行し`presentation.pptx`を出力 |

## ディレクトリ構成

```
slide-generator/
├── .claude-plugin/
│   ├── plugin.json          # プラグインマニフェスト
│   └── marketplace.json     # マーケットプレイス定義
├── skills/
│   └── slide-generator/
│       └── SKILL.md         # メインスキル定義
├── agents/                  # サブエージェント群
│   ├── 0ocr.md              # slide-ocr
│   ├── 1conductor.md        # conductor
│   ├── 2coding.md           # subagent-slidecode
│   ├── 3scoring.md          # subagent-scoring
│   └── 4pptxgen.md          # subagent-pptxgen
└── CLAUDE.md                # slideDataスキーマ定義
```

## 依存関係

スライド生成時に自動インストール：

```bash
npm install pptxgenjs
```
