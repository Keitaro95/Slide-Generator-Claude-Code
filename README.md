# Slide Generator

**A Claude Code plugin that turns Markdown, an existing PPTX, or pasted text into a finished PowerPoint deck.**

A three-stage subagent pipeline — **structure → design → render** — decides the layout and computes every coordinate, applies semantic colour and inline emphasis markup, then renders a real `.pptx` with [pptxgenjs](https://gitbrent.github.io/PptxGenJS/). 11 slide layouts, optional design-guideline files for consistent theming.

```
/plugin marketplace add Keitaro95/Slide-Generator-Claude-Code
/plugin install slide-generator@slide-generator
```

Then just ask Claude: *"スライドを作って"* / *"turn this markdown into slides"*.

> Requires [Claude Code](https://claude.com/claude-code) and **Node.js 18+**.
> Prompts and generated slide copy are optimised for Japanese, but the pipeline works with any language.

---

以下、日本語ドキュメント。

## 概要

mdファイル、既存PPTX＋mdメモ、または貼り付けテキストを受け取り、エージェントワークフローで PowerPoint（`.pptx`）を自動生成する Claude Code プラグインです。

- **構造（A）→ デザイン（B）→ 描画（C）** の3段サブエージェントパイプライン
- 11種類のスライドレイアウト（title / section / content / compare / process / timeline / diagram / cards / table / progress / closing）
- 意味色＋インラインマークアップ（`[[アクセント]]` / `**太字**` / `{c:red|文字色}` / `{hl:yellow|マーカー}`）で本文を装飾
- デザインガイドラインファイルを指定すると、カラー・フォント・レイアウトを全スライドに統一適用
- 既存PPTXの更新時は、before/after スライドをハンガリアンアルゴリズムで最適マッピングし、既存デザインを可能な限り維持

## 動作要件

| 要件 | 備考 |
|---|---|
| [Claude Code](https://claude.com/claude-code) | プラグイン機能に対応したバージョン |
| Node.js 18 以上 + npm | `generate.js` の実行に必要（[nodejs.org](https://nodejs.org/)） |

依存パッケージ `pptxgenjs` は生成時に自動インストールされます。

## インストール

Claude Code のセッション内で、以下を順に実行してください。

```
/plugin marketplace add Keitaro95/Slide-Generator-Claude-Code
/plugin install slide-generator@slide-generator
```

インストール後、Claude Code を再起動すると有効になります。

### 更新・アンインストール

```
/plugin update slide-generator
/plugin uninstall slide-generator
```

## 使い方

インストール後は、**普通に話しかけるだけ**でスキルが起動します。

```
議事録.md からスライドを作って
この提案書のPPTXを、下のメモの内容で更新して
```

明示的に呼び出す場合はスラッシュコマンドを使います。

```
/slide-generator:slide-generator
```

起動すると、対話形式で以下を確認します。

1. **入力タイプ** — mdファイル / 既存PPTX+mdメモ / テキスト貼り付け
2. **補足情報** — タイトル・対象オーディエンス・枚数目安・デザイン方向性・デザインガイドライン・保存先
3. **確認** — 内容に合意したらエージェントワークフローを実行

最後に `presentation.pptx` が生成され、保存先パスが表示されます。

### デザインガイドラインを効かせる

`design-guidelines.md` のようなファイルのパスを渡すと、そこに書かれたカラーパレット・フォント・余白・レイアウトルールが全スライドに優先適用されます。

## エージェントワークフロー

```
[Step 0] slide-ocr  →  A: subagent-structure  →  B: subagent-design  →  C: subagent-pptxgen
既存PPTX読取           構造化・座標算出          色・マークアップ         generate.js 生成＋実行
→ slideData            → SPEC(JSON)            → SPEC(装飾付き)        → presentation.pptx
```

各段の責務は明確に分離されています。**A は色を塗らず、B は座標を動かさず、C は判断をしません。**

| 段 | エージェント | 役割 | やらないこと |
|---|---|---|---|
| 0 | `slide-ocr`<br>（`agents/0ocr.md`） | 既存PPTX・PDF・画像のテキストとレイアウトを読み取り、`slideData` 配列の雛形を生成 | — |
| A | `subagent-structure`<br>（`agents/2coding.md`） | コンテキスト分解 → パターン選定 → ストーリー再構築 → レイアウトテンプレート選択 → **全要素の座標算出** → 文字規約適用 | 色・強調の付与 |
| B | `subagent-design`<br>（`agents/3scoring.md`） | 意味色の割り当て → インラインマークアップ付与 → 図形スタイル調整 → 装飾追加 → 全ページ統一性の点検 → `designReport` 出力 | **座標の変更**、テキストの意味変更 |
| C | `subagent-pptxgen`<br>（`agents/4pptxgen.md`） | SPEC をレンダラーテンプレートに埋め込み `generate.js` を生成 → preflight検証 → 実行 → `.pptx` 出力 | レイアウト補正、デザイン判断 |

Step 0 は PPTX 入力のときのみ実行されます。
Step B の完了時にはデザイン調整レポートが提示され、構造的な問題（`error`）が見つかった場合は Step A に差し戻して再計算します（最大2回）。

## ディレクトリ構成

```
Slide-Generator-Claude-Code/
├── .claude-plugin/
│   ├── plugin.json          # プラグインマニフェスト
│   └── marketplace.json     # マーケットプレイス定義
├── agents/                  # サブエージェント群
│   ├── 0ocr.md              # slide-ocr
│   ├── 2coding.md           # A: subagent-structure
│   ├── 3scoring.md          # B: subagent-design
│   └── 4pptxgen.md          # C: subagent-pptxgen
├── skills/
│   ├── slide-generator/SKILL.md      # メインスキル定義
│   └── refactoring-slides/SKILL.md   # 既存PPTX更新時のスライド対応付け
├── reference/
│   └── slidedata-schema.md  # SPEC・マークアップ・slideDataスキーマ定義（正典）
├── scripts/
│   └── validate.sh          # マニフェスト・コンポーネント検証
└── LICENSE
```

## 開発

ローカルのチェックアウトを読み込んで動作確認する場合：

```sh
git clone https://github.com/Keitaro95/Slide-Generator-Claude-Code.git
claude --plugin-dir ./Slide-Generator-Claude-Code
```

変更後は検証を実行してください（CI と同じチェックが走ります）。

```sh
./scripts/validate.sh
```

仕様（SPEC / `slideData` スキーマ / インラインマークアップ）を変更するときは、正典である [`reference/slidedata-schema.md`](reference/slidedata-schema.md) を編集します。開発上の詳しい規約は [`.claude/CLAUDE.md`](.claude/CLAUDE.md) にあります。

## トラブルシューティング

**`/plugin marketplace add` で SSH 認証エラーが出る**

git が GitHub への SSH 接続を試みて失敗している場合があります。HTTPS を使うよう設定してください。

```sh
git config --global url."https://github.com/".insteadOf "git@github.com:"
```

> この設定は **すべてのリポジトリ** の `git@github.com:` 形式のURLに影響します。
> 影響範囲を限定したい場合は `--global` を外して該当リポジトリ内で実行するか、後で
> `git config --global --unset url."https://github.com/".insteadOf` で解除してください。

**スライド生成が Step C で止まる**

Node.js がインストールされているか確認してください（`node --version`）。18 以上が必要です。

**スキルが呼び出されない**

`/plugin` でプラグインが有効になっているか確認し、Claude Code を再起動してください。

## ライセンス

[MIT](LICENSE) © Keitaro Sasaki
