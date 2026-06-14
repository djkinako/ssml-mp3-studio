# 🔊 SSML MP3 Studio

SSML テキストを貼り付けて、**日本語＋中国語が混在した学習音声を MP3 で書き出す**ツール。
筋トレ中に耳で聴く中国語学習コンテンツを自作するために作った。

> テキストの SSML 化は **Claude（チャット）にやらせる**前提。
> このツールの仕事は **SSML → MP3 だけ**。だから必要な API キーは Google TTS の 1 個だけ。

🌐 **公開URL**: https://djkinako.github.io/ssml-mp3-studio/

---

## クイックスタート

1. このフォルダを VS Code で開く
2. `index.html` を **Live Server** で開く（拡張機能 "Live Server"）か、ローカルサーバーを立てる:
   ```bash
   python3 -m http.server 8000
   # → http://localhost:8000 を開く
   ```
   ※ `file://` 直開きでも動くが、ローカルサーバー推奨
3. Google TTS API キーを入力欄に貼って「保存」
4. SSML を貼って「🔊 MP3 生成」→ ダウンロード

## Google TTS API キーの取り方

1. [Google Cloud Console](https://console.cloud.google.com/) でプロジェクト作成
2. **Cloud Text-to-Speech API** を有効化
3. 「APIとサービス → 認証情報 → 認証情報を作成 → API キー」でキー発行
4. **課金を有効化**（無料枠内なら請求されない：Wavenet 月100万文字 / Standard 月400万文字まで無料）
5. ⚠️ セキュリティ: 発行したキーを編集して
   - 「API の制限」→ **Cloud Text-to-Speech API のみ**
   - 「アプリケーションの制限」→ **ウェブサイト** を選択し、許可リストに以下を追加:
     - `https://djkinako.github.io/*` （GitHub Pages 公開版を使う場合）
     - `http://localhost:*` `http://127.0.0.1:*` （ローカルで使う場合）

## SSML の書き方（日中混在）

中国語にしたい部分を `<lang xml:lang="zh-TW">…</lang>` で囲むだけ。
**台湾華語なら繁体字、大陸普通話なら簡体字**で書く:

```xml
<speak>
  中国語では、<lang xml:lang="zh-TW">我每天喝咖啡是習慣</lang>。
</speak>
```

Claude に「日本語解説＋台湾華語（繁体字）の学習フレーズを、Google TTS 用の SSML にして」と頼めば一発で出してくれる。

### 仕組み（なぜ `<lang>` で動くのか）

Google TTS の `<lang>` タグは公式に **"best effort"** で、日本語の声に
中国語を読ませると無視されて日本語読みになってしまう（実機検証で確認済み）。
そこでこのアプリは **生成直前に SSML を変換**して、`<lang>` 部分を
`<voice name="…"><prosody rate="…">…</prosody></voice>` に置き換える。
これで日本語パートと中国語パートで**声と速度を独立に制御**できる。

ユーザーは今まで通り `<lang>` 入りの SSML を貼るだけでよい。

## 仕様の詳細

→ [`SPEC.md`](./SPEC.md) を参照。

## 技術構成

- 素の HTML / CSS / JS（ビルド不要・依存ゼロ）
- Google Cloud Text-to-Speech REST API をブラウザから直接 `fetch`
- API キーは localStorage 保存（コードに埋め込まない）
- GitHub Pages でそのまま公開可能

## ステータス

**v0.3.0** — 実機検証パス・GitHub Pages 公開済み・設定永続化対応。
UI ブラッシュアップは別フェーズで実施予定。

更新履歴は [`CHANGELOG.md`](./CHANGELOG.md) を参照。

---
🤖 足場は人生PM の番頭がスピンアウトで生成（2026-06-14）
