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
6. ⬜ Claude Design で UI 刷新 → それに合わせて HTML/CSS 調整
7. ⬜ （someday）バッチ生成・複数SSML一括ZIP DL・リピート機能 (SPEC §9)

## ファイル構成
- `index.html` — UI
- `app.js` — TTS API 呼び出し / SSML 変換 (`buildSsml()`) / base64→Blob→DL ロジック
- `style.css` — MVP スタイル（後で刷新前提）
- `SPEC.md` — 仕様書
- `README.md` — セットアップ手順
- `CHANGELOG.md` — 更新履歴
- `prompts/zhtw-v4.md` — 台湾華語学習教材 SSML 生成プロンプト v4
- `.github/ISSUE_TEMPLATE/audio-lesson.yml` — 学習教材生成依頼 Issue テンプレ

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

### Issue 対応コメントのフォーマット例 (v0.5.0〜: 全ペア統合版)

```markdown
[Opus 4.7] djkinako/ssml-mp3-studio番頭

**🔄 きなこ発言の要点:**
- 例文ペア N 組 (構文: 把/被/成語/...)
- 特別な指示: ...

SSML 生成したで👇 全ペアを 1 つの SSML に統合してあるから、これ 1 個コピーして貼ったら 1 MP3 になる。

\`\`\`xml
<speak>
[ペア1: 例文 → ヒント1 → ヒント2 → ヒント3 → 正解 → 解説]
<break time="3s"/>
次いくで。<break time="2s"/>
[ペア2: 例文 → ...]
<break time="3s"/>
お次や。<break time="2s"/>
[ペアN: ...]
</speak>
\`\`\`

(N ペアの合計バイト数: XXXX バイト / 5000 上限)

---

👉 https://djkinako.github.io/ssml-mp3-studio/ に貼って 🔊 MP3 生成。
```

**5000 バイト超の場合**: 上記を複数 SSML に分割し、グループごとに ```xml ブロックを並べる。各ブロックの先頭に「**グループ1/3 (1850バイト)**」のような見出しを付ける。
