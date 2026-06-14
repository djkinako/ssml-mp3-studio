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

---

## 🎧 学習教材を作る(Issue 起点ワークフロー、v0.4.0〜)

「日本語+中国語のペア」から、**段階的に中国語化していく学習音声**を作りたい場合の流れ:

### 1. GitHub Issue を起票
- **テンプレート**: 「🎧 中国語学習音声 SSML 生成依頼」を選ぶ
- 日本語文と台湾華語(繁体字)のペアを `---` 区切りで複数入力可
- Issue URL: https://github.com/djkinako/ssml-mp3-studio/issues/new/choose

例:
```
日本語: 彼はいつも口先だけで実行しない
中国語: 他總是光說不練
---
日本語: 急ぐと逆にうまくいかないものだ
中国語: 欲速則不達
```

### 2. Claude Code に「対応して」
Issue に「対応して」とコメント、または Claude Code で `gh issue view <番号>` から起動。
Claude Code は内部で `prompts/zhtw-v4.md`（プロンプト v4・4ループ検証済み）を読んで、
段階的中国語化 SSML を各ペア分まとめて生成し、Issue にコードブロックでコメント返信する。

### 3. SSML をコピーしてブラウザで MP3 化
Issue コメントから SSML をコピー → このアプリ（https://djkinako.github.io/ssml-mp3-studio/）
に貼って「🔊 MP3 生成」→ ダウンロード。

> 💡 **MP3 生成を自動化していない理由**: vibe coding 流儀(依存ゼロ・ブラウザだけで完結)と、ペアごとに音声を耳で確認してから次へ進めるワークフローを優先したため。

### SSML プロンプトの中身
`prompts/zhtw-v4.md` を参照。主要ルール:
- 学習者プロファイル: 台湾語学学校2年修了・N1〜N2 相当
- 段階化: 代名詞 → 名詞 → 動詞句 → 完全中国語
- ヒント間ポーズ: 4秒(考える時間)
- 解説: 成語宣言 + 類似表現 2〜3 個 + 構文/文語/口語の特徴
- トーン: 関西弁(やで・ねん・やな)

---

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
