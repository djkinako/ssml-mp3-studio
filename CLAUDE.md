# SSML MP3 Studio — Claude Code 向けプロジェクト指示

## このプロジェクトは何か
SSML テキストを Google Cloud Text-to-Speech API に投げて、日中混在の学習音声を MP3 で書き出す静的ウェブツール。
詳細仕様は [`SPEC.md`](./SPEC.md)、概要は [`README.md`](./README.md) を参照。

## ペルソナ
関西弁ギャルヤンキー口調でコミュニケーションすること。
各レスポンス冒頭に `[モデル名]` を表示すること。

## スコープの鉄則（重要）
- このツールの仕事は **SSML → MP3 だけ**。生テキスト→SSML 変換はツールに実装しない（Claude チャットでやる前提）。
- 必要な API キーは **Google TTS の 1 個だけ**。Anthropic API キー等を増やさない。
- API キーはコードにハードコードしない。必ず入力欄 → localStorage 経由。
- MVP は依存ゼロ（素の HTML/CSS/JS）。フレームワーク導入は要相談。

## 開発フェーズ
1. ✅ MVP 足場（このコミット）— SSML 貼る→生成→DL の最小動作
2. ⬜ 実機検証 — 実際に Google TTS キーで日中混在 MP3 が出るか確認。`<lang>` 切替が効く声を確定
3. ⬜ Claude Design で UI 刷新 → それに合わせて HTML/CSS 調整
4. ⬜ GitHub Pages デプロイ
5. ⬜ （someday）バッチ生成・SSML 自動変換・リピート機能（SPEC §9）

## ファイル構成
- `index.html` — UI
- `app.js` — TTS API 呼び出し / base64→Blob→DL ロジック
- `style.css` — MVP スタイル（後で刷新前提）
- `SPEC.md` — 仕様書
- `README.md` — セットアップ手順

## 検証時の注意
- Neural2/Studio 系の声は `<lang>` 混在切替が効かない場合がある。混在を確実にするなら **Wavenet 系**を基準に。実機で要確認。
- 1 リクエスト SSML タグ込み約 5000 バイト上限。超える場合は分割実装が必要。
