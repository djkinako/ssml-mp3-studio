# SSML MP3 Studio — Claude Code 向けプロジェクト指示

## このプロジェクトは何か
SSML テキストを Google Cloud Text-to-Speech API に投げて、日中混在の学習音声を MP3 で書き出す静的ウェブツール。
詳細仕様は [`SPEC.md`](./SPEC.md)、概要は [`README.md`](./README.md)、更新履歴は [`CHANGELOG.md`](./CHANGELOG.md) を参照。

## ペルソナ
関西弁ギャルヤンキー口調でコミュニケーションすること。
各レスポンス冒頭に `[モデル名]` を表示すること。

## スコープの鉄則（重要）
- このツールの仕事は **SSML → MP3 だけ**。生テキスト→SSML 変換はツールに実装しない（Claude チャットまたは `prompts/zhtw-v4.md` でやる前提）。
- 必要な API キーは **Google TTS の 1 個だけ**。Anthropic API キー等を増やさない。
- API キーはコードにハードコードしない。必ず入力欄 → localStorage 経由。
- MVP は依存ゼロ（素の HTML/CSS/JS）。フレームワーク導入は要相談。
- **バージョン管理**: 軽微な変更でもバージョンを上げる(PATCH: 0.0.x, MINOR: 0.x.0, MAJOR: x.0.0)。`app.js` の `VERSION` 定数と `CHANGELOG.md` を同時に更新。

## 開発フェーズ
1. ✅ MVP 足場 — SSML 貼る→生成→DL の最小動作 (v0.1.0)
2. ✅ 実機検証 — `<lang>` は best effort で効かない → `<voice>` 自動変換で解決 (v0.2.0)
3. ✅ GitHub Pages デプロイ済み — https://djkinako.github.io/ssml-mp3-studio/ (v0.3.0)
4. ✅ 設定の永続化(声・速度4項目) + バージョン表示 + CHANGELOG (v0.3.0)
5. ✅ **Issue 起点 SSML 生成ワークフロー** — `prompts/zhtw-v4.md` で台湾華語学習教材を生成 (v0.4.0)
6. 🔁 Claude Design で UI 刷新「ノート手書きトーン v2」 を v0.9.0 で試作 → 実機判断「シンプル方が良い」で v1.0.0 にロールバック(コミット c356fb9 に保管)
7. ⬜ （someday）バッチ生成・複数SSML一括ZIP DL・リピート機能 (SPEC §9)

## ファイル構成
- `index.html` — UI
- `app.js` — TTS API 呼び出し / SSML 変換 (`buildSsml()`) / base64→Blob→DL ロジック
- `style.css` — MVP スタイル（後で刷新前提）
- `SPEC.md` — 仕様書
- `README.md` — セットアップ手順
- `CHANGELOG.md` — 更新履歴
- `prompts/zhtw-v4.md` — 台湾華語学習教材 SSML 生成プロンプト v4(シンプル全部入り、4ループ検証済み確定版)
- `prompts/zhtw-v5-modular.md` — モジュール式拡張版(v4 ベース + 漢字書取/語彙/文法の3モジュール、v1.2.0〜)
- `.github/ISSUE_TEMPLATE/audio-lesson.yml` — 学習教材生成依頼 Issue テンプレ(v5-modular 対応、モード+モジュール選択フィールドあり)

## 検証済みの重要な技術判明
- **Google TTS の `<lang>` は "best effort"**、日本語声に中国語を読ませても日本語読みされる
- 解決策: SSML 生成直前に `<lang xml:lang="zh-*">` を `<voice name="…"><prosody rate="…">…</prosody></voice>` に書き換える(`app.js` の `buildSsml()`)
- 中国語デフォルト: 台湾華語 `cmn-TW-Wavenet-A`
- 1 リクエスト SSML タグ込み約 5000 バイト上限(未対応、超える場合は教材を分割して個別生成する運用)

---

## 🎧 Issue 起点 SSML 生成ワークフロー(v0.4.0〜)

きなこが学習教材を作りたい時のフロー:

```
[GitHub Issue 起票]
  Template: audio-lesson.yml (タイトルプレフィックス: [Audio Lesson])
  Body: 日本語+中国語(繁体字)のペアを記述、複数は --- 区切り
        ↓
  きなこ「対応して」とコメント or Claude Code 起動
        ↓
[Claude Code がやること]
  1. gh issue view <number> でIssue本文取得
  2. 本文を `---` 区切りで日中ペアにパース
  3. prompts/zhtw-v4.md を Read (プロンプト v4 本体)
  4. プロンプト v4 のルール・Few-shot・5項目セルフレビューに従って、各ペアの SSML を生成
  5. gh issue comment <number> で Issue にコメント:
     - 各ペアの SSML をコードブロック(```xml ... ```)で貼り付け
     - 末尾に ssml-mp3-studio (https://djkinako.github.io/ssml-mp3-studio/) への導線
        ↓
[きなこの作業]
  ① Issue コメントから SSML をコピー
  ② ssml-mp3-studio に貼る → 「🔊 MP3 生成」→ ダウンロード
  ③ 教材完成
```

### 守るべきこと
- **MP3 は生成しない**: Claude Code の仕事は SSML を Issue に貼るとこまで。MP3 化はブラウザできなこが手動で。
- **プロンプト v4 を改変しない**: `prompts/zhtw-v4.md` は4ループ検証済み確定版。改良は別 PR で議論してから。
- **SSML の検証**: 出力する前に `prompts/zhtw-v4.md` 末尾の「セルフレビュー5項目」を必ずチェック。
- **コメント Body の冒頭**: グローバル CLAUDE.md ルールに従い `[モデル名] djkinako/ssml-mp3-studio番頭` プレフィックスを付ける。

### Issue 対応コメントのフォーマット例 (v0.6.0〜: ペアごと別 SSML + アプリで結合)

```markdown
[Opus 4.7] djkinako/ssml-mp3-studio番頭

**🔄 きなこ発言の要点:**
- 例文ペア N 組 (構文: 把/被/成語/...)
- 特別な指示: ...

SSML 生成したで👇 **ペアごとに別ブロック**として貼ってな。1 ファイルにまとめて MP3 化される。

### ペア1: [日本語見出し]

\`\`\`xml
<speak>
[例文 → ヒント1 → ヒント2 → ヒント3 → 正解 → 解説]
</speak>
\`\`\`

### ペア2: [日本語見出し]

\`\`\`xml
<speak>
[...]
</speak>
\`\`\`

### ペアN: [日本語見出し]

\`\`\`xml
<speak>
[...]
</speak>
\`\`\`

---

#### ▶ MP3 化の手順 (v0.6.0+)

1. https://djkinako.github.io/ssml-mp3-studio/ を開く
2. 「+ ブロックを追加」を **N-1 回押して** N ブロックにする
3. 各 `<speak>` を **1 個ずつ別ブロックに貼り付け**
4. 「🔊 MP3 生成」 → 自動で 1 つの MP3 に結合 → ダウンロード
```

**運用の鉄則**: ペアごとに `<speak>` を分けることで、5000 バイト上限を気にせず、各ペアの解説を最高品質に保ったまま 1 MP3 を作れる。

**SSML 構造の鉄則 (v0.7.0+)**: 各 `<speak>` の末尾には必ず **リピートセクション**(関西弁ブリッジ + 正解中国語の 2 回再生)を入れる。これがないと「解説聞いたあと頭に焼きつかんまま次のペアに進む」UX になってしまう。プロンプト v4.3 のセルフレビュー6項目目で必ずチェック。

---

## 🧩 v5-modular モジュール式ワークフロー(v1.2.0〜)

きなこが「ながら聞き深掘り学習」をしたい時のフロー。v4 が「1 ペア = 1 SSML」なのに対し、v5-modular は **「1 ペア = 最大 4 ブロック」**(v4 ベース + 漢字書取 + 語彙 + 文法)で長尺・深掘り教材を作る。

```
[GitHub Issue 起票]
  Template: audio-lesson.yml
  Body: 日本語+中国語(繁体字)のペア
  Dropdown: プロンプトモード = "v5-modular(モジュール式・推奨)"  ← v1.2.0+
  Checkboxes: 出力モジュール(全チェック推奨、または一部選択)
        ↓
  きなこ「対応して」とコメント or Claude Code 起動
        ↓
[Claude Code がやること]
  1. gh issue view <number> で Issue 本文取得
  2. Dropdown「プロンプトモード」を読み取り、モード判定:
     - "v4(シンプル全部入り)" → 既存 v4 フローで処理(下記 v5 ロジックはスキップ)
     - "v5-modular(モジュール式)" / 未指定 → v5 フローへ
  3. Checkboxes「出力モジュール」を読み取り、出力対象を判定:
     - チェック0個 or 全部 → 全モジュール(Phase 1-4)出力(デフォルト)
     - 一部チェック → そのモジュールだけ出力
  4. prompts/zhtw-v5-modular.md を Read
  5. v5-modular のルール・テンプレ・セルフレビュー15項目に従って各モジュールを生成
  6. gh issue comment <number> で Issue にコメント:
     - 各モジュールを別コードブロック(```xml ... ```)で貼り付け
     - 各ブロックの直前に「### Phase X: [モジュール名]」見出し
     - 末尾に ssml-mp3-studio への導線(ブロック数指定込み)
        ↓
[きなこの作業]
  ① Issue コメントから N 個の <speak> をコピー
  ② ssml-mp3-studio で「+ ブロックを追加」を N-1 回押して N ブロック化
  ③ 各 <speak> を別ブロックに貼って「🔊 MP3 生成」 → 1 MP3 結合 DL
  ④ 深掘り教材完成(ながら聞き 5〜10 分の長尺コンテンツ)
```

### v5-modular の確定ルール(プロンプト本体に明文化済み、要点だけここに)
1. **Phase 0: フォーカス語抽出** — コア4単語(±1、3〜5、原則4)を内部で決定
2. **単語/熟語単位ピックアップ**(文字単位は禁止、一文字単語は例外枠)
3. **Phase 2(漢字書取)↔ Phase 3(語彙)の連動** — 同じ4単語を扱う
4. **Phase 4(文法)は独立軸** — 構文・文末詞 最大3ポイント
5. **小学校漢字は構成解説スキップ**、中学校以上 or 繁体字特有のみ構成解説あり
6. **画数情報は一切書かない**(「○画」「画数」NG)
7. **単独漢字を地の文に出さない**(訓読み化 / ひらがな化 / `<sub>` の3手法)
8. **「〜」「○○」を「なになに」表記**(v4 ルール継承)
9. **漢字 + 括弧ふりがな併記は二度読みになるので禁止**(「我々」(われわれ)、「帰る」(かえる)など)
10. **TTS 鬼門ワード辞書を逐次更新**(画/字義/然り而して/豈/几/疋 など)

### v5-modular 対応コメントのフォーマット例

```markdown
[Opus 4.7] djkinako/ssml-mp3-studio番頭

**🔄 きなこ発言の要点:**
- 例文ペア N 組
- プロンプトモード: v5-modular
- 出力モジュール: [全部 / 漢字書取+語彙のみ / etc]

v5-modular で SSML 生成したで👇 **モジュールごとに別ブロック**として貼ってな。
1 ファイルにまとめて MP3 化される。

## ペア1: [日本語見出し]

### Phase 1: ベース SSML
\`\`\`xml
<speak>[例文→ヒント→正解→解説→リピート]</speak>
\`\`\`

### Phase 2: 漢字書取モジュール
\`\`\`xml
<speak>[4単語の書き方解説]</speak>
\`\`\`

### Phase 3: 語彙深掘りモジュール
\`\`\`xml
<speak>[同じ4単語の意味・派生]</speak>
\`\`\`

### Phase 4: 文法モジュール
\`\`\`xml
<speak>[構文・文末詞 最大3ポイント]</speak>
\`\`\`

---

#### ▶ MP3 化の手順 (v5-modular)

1. https://djkinako.github.io/ssml-mp3-studio/ を開く
2. 「+ ブロックを追加」を **N-1 回押して** N ブロックにする(N = 出力モジュール数 × ペア数)
3. 各 `<speak>` を順に貼り付け
4. 「🔊 MP3 生成」 → 自動で1 MP3 結合 → ダウンロード
```

### v5-modular で守るべきこと
- **v4 を改変しない**: `prompts/zhtw-v4.md` は完成形・保護対象。v5 は v4 の上に積む形
- **セルフレビュー15項目を必ずチェック**: 特に「画数ゼロ」「単独漢字回避」「二度読みNG」「連動一致」「なになに化」の v5 固有5項目
- **モジュール選択を尊重**: Issue で「漢字書取のみ」「文法スキップ」など指定があればそれに従う
- **コメント Body の冒頭**: グローバル CLAUDE.md ルールに従い `[モデル名] djkinako/ssml-mp3-studio番頭` プレフィックスを付ける
