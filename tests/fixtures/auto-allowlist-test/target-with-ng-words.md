# テスト対象: 在班上 と 視頻 を含む生成結果

学習対象として正当な「在班上」「視頻」を含む例文を解説する。

## ペア1: クラスで目立たない

### Phase 1: ベース SSML
```xml
<speak>
<voice name="ja-JP-Wavenet-B"><prosody rate="0.95">
ほな例文聴いていくで。
</prosody></voice>
<lang xml:lang="cmn-TW">我在班上並不特別出眾</lang>
<voice name="ja-JP-Wavenet-B"><prosody rate="0.95">
ほな、もう一度聞いてみよか。
</prosody></voice>
<lang xml:lang="cmn-TW">我在班上並不特別出眾</lang>
<break time="1.5s"/>
<lang xml:lang="cmn-TW">我在班上並不特別出眾</lang>
</speak>
```

## ペア2: 動画を見る

### Phase 1: ベース SSML
```xml
<speak>
<voice name="ja-JP-Wavenet-B"><prosody rate="0.95">
今日のフレーズは「視頻を見る」。
</prosody></voice>
<lang xml:lang="cmn-TW">他喜歡看視頻</lang>
<voice name="ja-JP-Wavenet-B"><prosody rate="0.95">
ほな、もう一度聞いてみよか。
</prosody></voice>
<lang xml:lang="cmn-TW">他喜歡看視頻</lang>
<break time="1.5s"/>
<lang xml:lang="cmn-TW">他喜歡看視頻</lang>
</speak>
```
