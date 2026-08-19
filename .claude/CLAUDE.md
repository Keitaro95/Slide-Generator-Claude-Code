# Slide Generator — 開発者向けガイド

このファイルは **このリポジトリで開発作業をするとき** に読み込まれる指示書です。
プラグインとしてインストールされた場合、利用者のセッションには読み込まれません。

> プラグインルートに `CLAUDE.md` を置くと `claude plugin validate --strict` が警告を出すため、
> 意図的に `.claude/CLAUDE.md` に配置しています（プロジェクトコンテキストとしては同様に読み込まれます）。

> **重要**: スライドの仕様（SPEC / slideData スキーマ / インラインマークアップ / PptxGenJS ルール）は
> このファイルではなく **[`reference/slidedata-schema.md`](../reference/slidedata-schema.md)** が正典です。
> エージェントもスキルもそちらを参照します。仕様を変更するときは必ずそちらを編集してください。

---

## リポジトリ構成

```
.
├── .claude-plugin/
│   ├── plugin.json          # プラグインマニフェスト
│   └── marketplace.json     # マーケットプレイス定義（このリポジトリ自身を配信）
├── .claude/
│   └── CLAUDE.md            # このファイル（開発者向け・利用者には配られない）
├── agents/                  # サブエージェント定義（自動検出）
│   ├── 0ocr.md              # slide-ocr
│   ├── 2coding.md           # A: subagent-structure
│   ├── 3scoring.md          # B: subagent-design
│   └── 4pptxgen.md          # C: subagent-pptxgen
├── skills/                  # スキル定義（自動検出）
│   ├── slide-generator/SKILL.md
│   └── refactoring-slides/SKILL.md
├── reference/
│   └── slidedata-schema.md  # ★ SPEC / slideData 契約仕様（正典）
├── scripts/
│   └── validate.sh          # マニフェスト＋コンポーネント検証
├── LICENSE
└── README.md
```

---

## 編集時のルール

### パス参照は必ずプラグインルート基準にする

エージェント・スキルの本文からリポジトリ内のファイルを参照するときは、
**必ず `${CLAUDE_PLUGIN_ROOT}` を使う**。

```markdown
✅ `${CLAUDE_PLUGIN_ROOT}/reference/slidedata-schema.md`
❌ `CLAUDE.md`            … 利用者プロジェクトの CLAUDE.md に解決されてしまう
❌ `reference/...`        … 利用者のカレントディレクトリ基準になってしまう
❌ `/Users/.../reference` … 絶対パスは可搬性がない
```

`${CLAUDE_PLUGIN_ROOT}` はプラグインのインストール先を指す環境変数で、
commands / agents / skills の本文で展開されます。

### 仕様の二重管理をしない

SPEC・slideData スキーマ・マークアップ記法は `reference/slidedata-schema.md` にのみ書く。
エージェント側には「どう使うか」だけを書き、スキーマ本体をコピーしない。

### サブエージェント名は frontmatter の `name` が正

| ファイル | `name` |
|---|---|
| `agents/0ocr.md` | `slide-ocr` |
| `agents/2coding.md` | `subagent-structure` |
| `agents/3scoring.md` | `subagent-design` |
| `agents/4pptxgen.md` | `subagent-pptxgen` |

ファイル名ではなくこの `name` で Agent ツールから起動する。

---

## 検証

変更後は必ずマニフェストとコンポーネントを検証する。

```sh
./scripts/validate.sh     # 下記4つをまとめて実行（CI と同じ）

# 個別に実行する場合
claude plugin validate . --strict                            # marketplace.json
claude plugin validate .claude-plugin/plugin.json --strict   # plugin.json
claude plugin validate ./skills --strict                     # skills/*/SKILL.md
claude plugin validate ./agents --strict                     # agents/*.md
```

ローカル読み込みで動作確認する場合：

```sh
claude --plugin-dir .
```

---

## リリース

1. `.claude-plugin/plugin.json` の `version` を semver で更新
2. `claude plugin validate . --strict` が通ることを確認
3. `claude plugin tag .` でリリースタグ（`slide-generator--vX.Y.Z`）を作成
4. push
