# Slide Generator — 開発者向けガイド

このファイルは **このリポジトリで開発作業をするとき** に読み込まれる指示書です。
プラグインとしてインストールされた場合、利用者のセッションには読み込まれません。

> プラグインルートに `CLAUDE.md` を置くと `claude plugin validate --strict` が警告を出すため、
> 意図的に `.claude/CLAUDE.md` に配置しています（プロジェクトコンテキストとしては同様に読み込まれます）。

リポジトリ構成とパイプラインの概要は [`README.md`](../README.md) を参照してください。
仕様の正典は [`reference/slidedata-schema.md`](../reference/slidedata-schema.md) です。

---

## 編集時の3原則

### 1. 仕様は正典にだけ書く

SPEC・`slideData` スキーマ・マークアップ記法・`role` 一覧・座標基準・パレットは
**`reference/slidedata-schema.md` にのみ**書く。エージェント／スキル側には「どう使うか」だけを書き、
スキーマ本体をコピーしない。パイプライン図と責務表も正典 §1 が唯一の定義で、
各エージェントは自分の前後関係を1行触れるだけに留める。

`agents/c-pptxgen.md` の `generate.js` テンプレートは正典の**実装**です。
両者が食い違ったら正典が正しい。仕様を変えたら必ずテンプレートも追従させること。

### 2. パス参照は必ずプラグインルート基準にする

```markdown
✅ `${CLAUDE_PLUGIN_ROOT}/reference/slidedata-schema.md`
❌ `CLAUDE.md`            … 利用者プロジェクトの CLAUDE.md に解決されてしまう
❌ `reference/...`        … 利用者のカレントディレクトリ基準になってしまう
❌ `/Users/.../reference` … 絶対パスは可搬性がない
```

`${CLAUDE_PLUGIN_ROOT}` はプラグインのインストール先を指す環境変数で、
commands / agents / skills の本文で展開されます。

### 3. サブエージェントは frontmatter の `name` で起動する

`agents/` のファイル名はパイプラインの段（`0-ocr` / `a-structure` / `b-design` / `c-pptxgen`）に
対応させていますが、Agent ツールから呼ぶときのキーは frontmatter の `name`
（`slide-ocr` / `subagent-structure` / `subagent-design` / `subagent-pptxgen`）です。

---

## 検証

変更後は必ずマニフェストとコンポーネントを検証する。

```sh
./scripts/validate.sh     # 4つのターゲットをまとめて検証（CI と同じ）
```

`skills/refactoring-slides/SKILL.md` の JS を変更した場合は、実際に走らせて確認する。

```sh
sed -n '/^```javascript$/,/^```$/p' skills/refactoring-slides/SKILL.md | sed '1d;$d' > /tmp/slide-diff.js
# /* __BEFORE__ */ /* __AFTER__ */ を配列リテラルに置換してから
node /tmp/slide-diff.js
```

ローカル読み込みで動作確認する場合：

```sh
claude --plugin-dir .
```

---

## リリース

1. `.claude-plugin/plugin.json` の `version` を semver で更新
2. `./scripts/validate.sh` が通ることを確認
3. `claude plugin tag .` でリリースタグ（`slide-generator--vX.Y.Z`）を作成
4. push
