# Slide Generator — Claude Code Plugin

mdファイルまたはPPTX+mdメモを受け取り、マルチエージェントワークフローでPowerPoint（.pptx）を自動生成するClaude Codeプラグイン。

## 機能

- Markdownからスライド構造を自動解析
- Googleスタイルのデザインテンプレート（PptxGenJS）
- 11種類のスライドレイアウト（title / section / content / compare / process / timeline / diagram / cards / table / progress / closing）
- ハンガリアンアルゴリズムによる品質スコアリング＋自動リファインメントループ
- 既存PPTXの読み取り・改善にも対応

## インストール

### プラグインとして使う（推奨）

```bash
# --plugin-dir フラグでローカルロード（インストール不要）
claude --plugin-dir ./path/to/slide-generator

# Claude Code内で再ロード
/reload-plugins
```

インストール後、`/slide-generator` スキルが使えるようになります。

### 手動インストール

`forclaude/` ディレクトリの内容を `.claude/` にコピーする：

```bash
cp -r forclaude/skills/* ~/.claude/commands/
cp -r forclaude/subagents/* ~/.claude/agents/
```

## 使い方

```
/slide-generator
```

起動後、対話形式で入力ファイルとオプションを確認します。

## エージェント構成

| エージェント | 役割 |
|------------|------|
| `design-conductor` | デザイン方針（カラー・フォント・レイアウト）を決定 |
| `slide-design-ocr` | 既存PPTXのデザイン構造を読み取り |
| `slide-ocr` | 既存PPTXのテキストを文字起こし |
| `subagent-converter` | ContentオブジェクトをslideData配列に変換 |
| `subagent-slidecode` | PptxGenJSスクリプトを生成・実行 |
| `subagent-scoring` | ハンガリアンアルゴリズムでスライド品質をスコアリング |
| `subagent-refactoring` | スコアが閾値を超えるまでループ改善 |

## ディレクトリ構成

```
slide-generator/
├── .claude-plugin/
│   └── plugin.json          # プラグインマニフェスト
├── skills/
│   └── slide-generator/
│       └── SKILL.md         # メインスキル定義
├── agents/                  # サブエージェント群
│   ├── design-conductor.md
│   ├── slide-design-ocr.md
│   ├── slide-ocr.md
│   ├── subagent-converter.md
│   ├── subagent-refactoring.md
│   ├── subagent-scoring.md
│   └── subagent-slidecode.md
└── forclaude/               # 手動インストール用（後方互換）
    ├── skills/
    └── subagents/
```

## 依存関係

スライド生成時に自動インストール：

```bash
npm install pptxgenjs
```
