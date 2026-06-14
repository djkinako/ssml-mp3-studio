# 🔊 SSML MP3 Studio

SSML テキストを貼り付けて、**日本語＋中国語が混在した学習音声を MP3 で書き出す**ツール。
筋トレ中に耳で聴く中国語学習コンテンツを自作するために作った。

> テキストの SSML 化は **Claude（チャット）にやらせる**前提。
> このツールの仕事は **SSML → MP3 だけ**。だから必要な API キーは Google TTS の 1 個だけ。

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
   - （GitHub Pages 公開時は）「ウェブサイトの制限」→ **自分の Pages ドメインのみ**

## SSML の書き方（日中混在）

ベースは日本語の声。中国語にしたい部分だけ `<lang>` で囲む:

```xml
<speak>
  中国語では、<lang xml:lang="zh-CN">我每天喝咖啡是习惯</lang>。
</speak>
```

Claude に「この日本語解説＋中国語フレーズを、Google TTS 用の SSML にして」と頼めば一発で出してくれる。

## 仕様の詳細

→ [`SPEC.md`](./SPEC.md) を参照。

## 技術構成

- 素の HTML / CSS / JS（ビルド不要・依存ゼロ）
- Google Cloud Text-to-Speech REST API をブラウザから直接 `fetch`
- API キーは localStorage 保存（コードに埋め込まない）
- GitHub Pages でそのまま公開可能

## ステータス

MVP（検証フェーズ）。まず SSML→MP3 が動くことを確認 → その後 Claude Design で UI を刷新予定。

---
🤖 足場は人生PM の番頭がスピンアウトで生成（2026-06-14）
