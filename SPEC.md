# SSML MP3 Studio — 仕様書

**作成日:** 2026-06-14
**最終更新:** 2026-06-14
**ステータス:** MVP（検証フェーズ）

---

## 1. 目的（なぜ作るか）

筋トレ中に「耳で聴く」中国語学習音声コンテンツを自作するためのツール。

学習テキストは「日本語の解説 ＋ 中国語のフレーズ」が混在する。
- 日本語パートは日本語の声で読み上げ
- 中国語パートは中国語の声で読み上げ

これを **1つのMP3** に書き出して、スマホに入れて筋トレ中に聴く。

## 2. スコープ（MVP で作るもの / 作らないもの）

### ✅ MVP で作る
1. **SSML テキストをペースト**するテキストエリア
2. **Google Cloud Text-to-Speech API** を叩いて音声合成
3. 返ってきた音声を **MP3 としてダウンロード**
4. **API キー入力欄**（localStorage 保存・コードに埋め込まない）
5. 声・速度などの基本パラメータ選択（任意）

### ❌ MVP では作らない（後回し or 別ステップ）
- **生テキスト → SSML 自動変換**：これは Claude（チャット）にやらせる前提。ツール内には実装しない（Anthropic API キーが増えて複雑化するため）
- 教材テキストそのものの生成
- バッチ処理（複数フレーズ一括）：必要になったら後で追加
- 凝った UI：まず動かす → 後で Claude Design で整える

### 設計の割り切り（重要）
> **「SSML 変換はチャットで AI にやらせる、ツールの仕事は SSML → MP3 だけ」**
> これにより必要な API キーは **Google TTS の 1 個だけ** で済む。

## 3. 全体の流れ（ユーザー体験）

```
[Claude チャット]                    [このツール]
 中国語学習テキスト生成   ──SSML──▶   SSMLをペースト
 ＋ SSML 形式で出力                     ↓ APIキー入力（初回のみ）
                                       ↓ 「生成」ボタン
                                       ↓ Google TTS API
                                       ↓
                                     MP3 ダウンロード ──▶ スマホで聴く
```

## 4. 技術スタック

| 項目 | 採用 | 理由 |
|------|------|------|
| 形態 | 静的サイト（GitHub Pages 公開可） | サーバー不要・無料・既存の vibe coding 流儀に合う |
| フロント | 素の HTML / CSS / JS（ビルドなし） | MVP は依存ゼロが最速。フレームワークは過剰 |
| TTS | Google Cloud Text-to-Speech REST API | SSML で日中混在の言語切替が一番スムーズ |
| API 呼び出し | ブラウザから直接 `fetch()`（APIキー方式） | CORS 問題なし。サーバー不要 |
| キー保管 | localStorage（ユーザーが自分で入力） | コードに埋めない＝Public リポでも安全 |

## 5. Google Cloud TTS API 仕様メモ

- **エンドポイント:** `POST https://texttospeech.googleapis.com/v1/text:synthesize?key=API_KEY`
- **リクエスト body:**
  ```json
  {
    "input": { "ssml": "<speak>...</speak>" },
    "voice": { "languageCode": "ja-JP", "name": "ja-JP-Neural2-B" },
    "audioConfig": { "audioEncoding": "MP3", "speakingRate": 1.0 }
  }
  ```
- **レスポンス:** `{ "audioContent": "<base64>" }` → デコードして Blob → ダウンロード
- **言語切替:** SSML 内で `<lang xml:lang="zh-CN">咖啡</lang>` のように囲むと、その部分だけ中国語音声になる
- **制限:** 1 リクエストあたり SSML タグ込みで **約 5000 バイト**。長文は分割が必要
- **料金:** Standard 音声は月 400 万文字無料、Neural2/WaveNet は月 100 万文字無料。個人学習用途なら実質無料

### voice の `name` で「ベース言語の声」を決める
SSML 全体のデフォルト言語は `voice.languageCode` / `voice.name` で決まる。
日本語ベースの解説なら `ja-JP-Neural2-B`（女性）等を指定し、中国語部分だけ `<lang>` で切り替える。

#### 主な声の候補
| 言語 | name の例 | 備考 |
|------|-----------|------|
| 日本語 | `ja-JP-Neural2-B`（女性）/ `ja-JP-Neural2-C`（男性）/ `ja-JP-Neural2-D`（男性） | |
| 中国語(簡体) | `cmn-CN-Wavenet-A`（女性）/ `cmn-CN-Wavenet-B`（男性） | languageCode は `cmn-CN` |
| 中国語(繁体) | `cmn-TW-Wavenet-A` 等 | 台湾向けは `cmn-TW` |

> ※ `<lang xml:lang="zh-CN">` の切替が効くのは Standard/WaveNet 系。Neural2/Studio は `<lang>` 非対応な場合があるので、混在切替を確実にするなら **WaveNet 系を基準にする**のが無難。MVP で実機検証する。

## 6. SSML サンプル（学習テキスト1セット）

```xml
<speak>
  今日の表現です。<break time="500ms"/>
  毎日コーヒーを飲むのが習慣です。<break time="700ms"/>
  中国語では、<lang xml:lang="zh-CN">我每天喝咖啡是习惯</lang>。<break time="700ms"/>
  ポイントは <lang xml:lang="zh-CN">习惯</lang> という単語です。<break time="500ms"/>
  もう一度。<lang xml:lang="zh-CN">我每天喝咖啡是习惯</lang>。
</speak>
```

## 7. UI 要素（MVP）

- API キー入力欄（password 型・localStorage 保存・「保存」「クリア」ボタン）
- ベース言語 / 声の選択（プルダウン）
- 読み上げ速度スライダー（0.5〜1.5）
- SSML 入力テキストエリア（大きめ・サンプル投入ボタン付き）
- 「🔊 MP3 生成」ボタン
- ステータス表示（生成中… / エラー内容）
- 生成後：再生プレビュー（`<audio>`）＋「⬇ ダウンロード」ボタン

## 8. セキュリティ注意

- API キーはコードにハードコードしない（必ず入力欄経由）
- GCP コンソールで該当キーを **「Text-to-Speech API のみ」＋「公開ドメイン（GitHub Pages の URL）からのみ」** に制限することを README で案内
- localStorage はそのブラウザ内のみ。共有 PC では「クリア」推奨

## 9. 今後の拡張候補（someday）

- 生テキスト → SSML 自動変換（ルールベース or Claude API）
- 複数セット一括生成（バッチ）＋ ZIP ダウンロード
- フレーズ履歴の保存
- 無音 `<break>` の自動挿入調整 UI
- 繰り返し回数指定（中国語フレーズを N 回リピート）

## 更新ログ
- 2026-06-14: 初版作成（番頭・人生PMチャットからスピンアウト）
