# 更新履歴

このファイルは SSML MP3 Studio の更新履歴。
バージョン番号は [Semantic Versioning](https://semver.org/lang/ja/) に準拠（`MAJOR.MINOR.PATCH`）:
- **PATCH** (0.0.x): バグ修正・微調整
- **MINOR** (0.x.0): 新機能・UI 変更
- **MAJOR** (x.0.0): 互換性のない破壊的変更

---

## [0.4.0] - 2026-06-14

### 追加
- 🎧 **Issue 起点 SSML 生成ワークフロー** を導入。日本語+台湾華語(繁体字)ペアを GitHub Issue で投げると、Claude Code が `prompts/zhtw-v4.md` を使って段階的中国語化 SSML を生成し Issue にコメント返信する
- 📋 `prompts/zhtw-v4.md` — Web 版 Claude セッションで 4 ループ検証した台湾華語学習教材 SSML 生成プロンプト v4 を配置。N1〜N2 学習者向け・関西弁トーン・成語解説・5項目セルフレビュー指示込み
- 📋 `.github/ISSUE_TEMPLATE/audio-lesson.yml` — 「🎧 中国語学習音声 SSML 生成依頼」Issue テンプレ
- 📋 `CLAUDE.md` に Issue 起点ワークフローの手順を明文化(Claude Code の責務範囲・コメント形式・守るべきこと)
- 📋 README に「学習教材を作る(Issue 起点ワークフロー)」セクション追加

### 背景
Web 版 Claude セッションで「Multi-Agent + GitHub Issue + ffmpeg + Drive 統合」のフル仕様 (zhtw-audio-lab) 構想を立てたが、4視点 (architect/critic/engineer/UX) でレビューした結果、「ssml-mp3-studio v0.3.0 が既にコア論点を解決済みのため申し送り書の大部分は過剰」と全員一致。プロンプト v4 を ssml-mp3-studio に同居させ、Issue 起票 → SSML 生成 → ブラウザで MP3 化 のシンプルワークフローに集約。

---

## [0.3.0] - 2026-06-14

### 追加
- 🎯 **設定の永続化**: API キーに加えて、声 2 つ・速度 2 つも localStorage に保存。ブラウザを閉じても次回開いた時に前回の設定が復元される
- 🏷️ **バージョン表示**: ヘッダーの見出し脇に現在のバージョン(`v0.3.0`)を表示
- 📝 **CHANGELOG.md** を新規作成。過去バージョンの履歴も遡及して記録
- 🌐 **GitHub Pages デプロイ**: 公開可能な状態に整備

---

## [0.2.0] - 2026-06-14

### 追加
- 🇯🇵🇹🇼 **日本語の声と中国語の声をそれぞれ独立して選択可能**に（プルダウン 2 つに分離）
- 🐢🐇 **日本語の速度と中国語の速度を独立スライダー化**（各 0.5〜1.5）
- 🥟 中国語の声のデフォルトを **台湾華語 (`cmn-TW-Wavenet-A`)** に変更（大陸普通話も選択肢として残置）

### 変更（内部）
- 🪄 **`<lang>` → `<voice>+<prosody>` 自動変換ロジック** (`buildSsml()`) を導入。Google TTS の `<lang>` タグが "best effort" で日本語声に中国語を読ませると無視される問題を、アプリ側で吸収。ユーザーは今まで通り Claude が出す `<lang>` 入り SSML を貼るだけで OK
- 📊 速度は入れ子 `<prosody>` で外側=ja・内側=zh/ja の相対値とし、ユーザー指定値がそのまま絶対速度として実音に反映されるよう調整

### ドキュメント
- README に「仕組み（なぜ `<lang>` で動くのか）」の節を追加
- SPEC §5 注釈を実機検証結論で更新、§6 サンプルを繁体字に統一、§7 UI 要素を 4 項目構成に更新

---

## [0.1.2] - 2026-06-14

### 修正
- 🧹 `.gstack/` を `.gitignore` に追加（ローカル状態ディレクトリをリポに含めない）

---

## [0.1.1] - 2026-06-14

### 修正
- 🐛 **生成前に再生プレビュー / DL ボタンが表示されるバグを修正**。CSS 詳細度で `#result`(ID) の `display: flex` が `.hidden`(class) の `display: none` に勝っており、生成前から空の `<audio>` と無効 DL ボタンが見えていた。`.hidden` に `!important` を付与して確実に隠す

---

## [0.1.0] - 2026-06-14

### 初版
- ✨ MVP 足場: SSML テキストを貼って、Google Cloud Text-to-Speech API で MP3 を生成・ダウンロード
- 🔑 API キー入力欄 + localStorage 保存
- 🗣️ 声の選択（日本語 Wavenet/Neural2、中国語 cmn-CN/cmn-TW）
- 🎚️ 読み上げ速度スライダー（0.5〜1.5）
- 📋 SSML サンプル投入ボタン + バイト数カウンタ（5000 バイト上限警告）
- 🎵 生成後の再生プレビュー + ダウンロードボタン
- 📄 SPEC.md / README.md 同梱
