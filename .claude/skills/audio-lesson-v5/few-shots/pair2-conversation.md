# Few-shot ペア2: 帶把傘出門吧(会話文 + 語気助詞)

## ペア概要

| 項目 | 内容 |
|---|---|
| 日本語 | 今日は雨が降りそうだから傘を持っていこう |
| 中国語(繁体字) | 今天好像會下雨,帶把傘出門吧 |
| カテゴリ | 会話文 + 語気助詞「吧」(機能語トラック分離例) |
| 文字数 | 14字(短文 → Phase 4 は 2 ポイント) |
| 由来 | v4 入力2(日常会話、代名詞なし)を v5-modular 4ブロック化 |

## Phase 0 フォーカス語

| # | 単語 | 抽出理由 |
|---|---|---|
| 1 | **今天** | 時間語、文の意味のコア、口語の定番 |
| 2 | **好像會** | 推量マーカーの定番複合、N1-N2 学習者がモヤるポイント |
| 3 | **帶把傘** | 量詞「把」の特殊用法、把字構文ではない型の例 |
| 4 | **吧** | 機能語(語気助詞)、Phase 4 で扱う特例枠 |

**自己相互チェック3点**:
- ① 部分文字列共有なし: 今天/好像會/帶把傘/吧、互いに包含関係なし ✅
- ② 同一品詞・意味カテゴリの重複なし: 時間名詞・助動詞・動詞句・語気助詞でバラけている ✅
- ③ Phase 3 派生語列挙が交差しない: 今天→明天/昨天系、好像→似乎/大概系、帶→帶走/帶來系、吧→Phase 4 で機能語として扱うので Phase 3 では深掘りしない ✅

**機能語の特例運用**:
- 「吧」は機能語(語気助詞)なので **Phase 0 の通常4枠基準では対象外**やけど、ここではあえてピックアップして **Phase 4 で文末詞として扱う見本**として残す。
- Phase 2(漢字認識)では「吧」を **言及のみ**に留め、Phase 3(語彙)では深掘りせず、Phase 4 で「語気助詞」軸でガッツリ扱う。
- → これが「機能語トラック分離」の実例。

## 学習ポイント

- **会話文の温度感**: 書面語スイッチが入らない、日常の口語表現
- **機能語の扱い**: 「吧」を 4枠の特例枠として、Phase 4 で文末詞軸で扱う模範例
- **Phase 4 「2ポイント」動的化**: 短文(14字)で文法的に淡白なので、3ポイント固定ではなく **2ポイントで止める** 模範例
- **量詞「把」の特殊用法**: 把字構文ではなく「一把傘」の量詞残り
- **Phase 2 軽量版(v1.5.0)**: 3パターン判定テンプレ(①日本語と同じ字 / ②旧字体 / ③日本語にない繁体字)のみで構成、構成解説・印象表現・字形描写は一切排除

---

## Phase 1: ベース SSML

```xml
<speak>
例文。<break time="300ms"/>
今日は雨が降りそうだから傘を持っていこう。<break time="2s"/>
ヒント1。<break time="300ms"/>
<lang xml:lang="cmn-TW">今天</lang><break time="200ms"/>は雨が降りそうだから傘を持っていこう。<break time="4s"/>
ヒント2。<break time="300ms"/>
<lang xml:lang="cmn-TW">今天</lang><break time="200ms"/>は<break time="200ms"/><lang xml:lang="cmn-TW">雨</lang><break time="200ms"/>が降りそうだから<break time="200ms"/><lang xml:lang="cmn-TW">傘</lang><break time="200ms"/>を持っていこう。<break time="4s"/>
ヒント3。<break time="300ms"/>
<lang xml:lang="cmn-TW">今天</lang><break time="200ms"/>は<break time="200ms"/><lang xml:lang="cmn-TW">好像會下雨</lang><break time="200ms"/>やから、<break time="200ms"/><lang xml:lang="cmn-TW">帶把傘出門</lang><break time="200ms"/>しよか。<break time="4s"/>
正解。<break time="500ms"/>
<lang xml:lang="cmn-TW">今天好像會下雨,帶把傘出門吧</lang>。<break time="3s"/>
<!-- explain -->
解説。<break time="500ms"/>
ポイントは「<break time="200ms"/><lang xml:lang="cmn-TW">好像會下雨</lang><break time="200ms"/>」と文末の「<break time="200ms"/><lang xml:lang="cmn-TW">吧</lang><break time="200ms"/>」やで。<break time="200ms"/><lang xml:lang="cmn-TW">好像會</lang><break time="200ms"/>は根拠ゆるめの推量で、「降りそう」の感じに近いねん。<break time="500ms"/>
「<break time="200ms"/><lang xml:lang="cmn-TW">把</lang><break time="200ms"/>」はここでは処置文やなくて、<break time="200ms"/><lang xml:lang="cmn-TW">一把傘</lang><break time="200ms"/>の量詞だけ残った形やな。文末の「<break time="200ms"/><lang xml:lang="cmn-TW">吧</lang><break time="200ms"/>」で、自分にも相手にも軽く促す口語感が出るで。<break time="2s"/>
ほな、もっかい。<break time="800ms"/>
<lang xml:lang="cmn-TW">今天好像會下雨,帶把傘出門吧</lang>。
</speak>
```

---

## Phase 2: 漢字認識モジュール(v1.5.0 軽量版・3パターン判定)

```xml
<speak>
<lang xml:lang="cmn-TW">今天好像會下雨,帶把傘出門吧</lang>。<break time="2s"/>
<!-- explain -->
漢字認識の解説や。ピックアップは四つの単語、それぞれどの字か見ていくで。<break time="800ms"/>

ひとつ目、<lang xml:lang="cmn-TW">今天</lang>(ジンティエン、今日)。<break time="500ms"/>
「ジン」は日本語の「今日」の「こん」と同じ字、「ティエン」は「天気」の「てん」と同じ字や。<break time="1.5s"/>

ふたつ目、<lang xml:lang="cmn-TW">好像會</lang>(ハオシャンホイ、なになにしそう)。<break time="500ms"/>
「ハオ」は日本語の「好き」の「すき」、「シャン」は「想像」の「ぞう」、「ホイ」は日本語の「会う」の旧字体<lang xml:lang="cmn-TW">會</lang>や。<break time="1.5s"/>

みっつ目、<lang xml:lang="cmn-TW">帶把傘</lang>(ダイバーサン、傘を持っていく)。<break time="500ms"/>
「ダイ」は日本語の「携帯」の「たい」の旧字体、「バ」は日本語にない繁体字で量詞専用、「サン」は日本語の「日傘」の「かさ」と同じ字や。<break time="1.5s"/>

よっつ目、文末の口語マーカー<lang xml:lang="cmn-TW">吧</lang>(バ、語気助詞)。<break time="500ms"/>
これ一文字単語の例外枠で取り上げるで、ただし機能語やからここでは言及だけや。意味と使い方は文法モジュールで文末詞として詳しく扱うで。<break time="2s"/>

単語の認識を意識して、もっかい。<break time="800ms"/>
<lang xml:lang="cmn-TW">今天好像會下雨,帶把傘出門吧</lang>。
</speak>
```

---

## Phase 3: 語彙深掘りモジュール

```xml
<speak>
<lang xml:lang="cmn-TW">今天好像會下雨,帶把傘出門吧</lang>。<break time="2s"/>
<!-- explain -->
語彙の深掘りや。漢字認識と同じ四つの単語、意味と派生を見ていくで。ただし四つ目の<lang xml:lang="cmn-TW">吧</lang>は機能語やから、語彙としての深掘りは省略して文法モジュールで扱うで。<break time="800ms"/>

ひとつ目、<lang xml:lang="cmn-TW">今天</lang>。<break time="500ms"/>
「今日」を表す日常会話の最頻出ワードや。仲間ワードに<lang xml:lang="cmn-TW">明天</lang>(明日)、<lang xml:lang="cmn-TW">昨天</lang>(昨日)、<lang xml:lang="cmn-TW">後天</lang>(あさって)、<lang xml:lang="cmn-TW">前天</lang>(おととい)。全部「数字感覚の前後 + 天」の型で、台湾華語の日付表現はぜんぶこのパターンや。書面語やと<lang xml:lang="cmn-TW">本日</lang>に化けるけど、会話では絶対<lang xml:lang="cmn-TW">今天</lang>やで。<break time="1.5s"/>

ふたつ目、<lang xml:lang="cmn-TW">好像會</lang>。<break time="500ms"/>
推量の複合マーカーや。<lang xml:lang="cmn-TW">好像</lang>(なになにみたいだ)と<lang xml:lang="cmn-TW">會</lang>(なになにするだろう)を組み合わせて、「根拠ゆるめの予測」のニュアンスを出す。仲間ワードに<lang xml:lang="cmn-TW">似乎</lang>(書面語の推量、なになにのようだ)、<lang xml:lang="cmn-TW">大概</lang>(おおよそ、たぶん)、<lang xml:lang="cmn-TW">可能會</lang>(なになにする可能性がある)。確信度の弱→強の順に並べると、<lang xml:lang="cmn-TW">好像會 → 大概會 → 應該會 → 一定會</lang>って感じや。<break time="1.5s"/>

みっつ目、<lang xml:lang="cmn-TW">帶把傘</lang>。<break time="500ms"/>
動詞<lang xml:lang="cmn-TW">帶</lang>は「持っていく・連れていく」の口語動詞や。仲間ワードに<lang xml:lang="cmn-TW">帶走</lang>(持ち去る)、<lang xml:lang="cmn-TW">帶來</lang>(持ってくる)、<lang xml:lang="cmn-TW">帶上</lang>(身に着けていく)、<lang xml:lang="cmn-TW">攜帶</lang>(携帯する、書面語)。書面語の<lang xml:lang="cmn-TW">攜帶</lang>と口語の<lang xml:lang="cmn-TW">帶</lang>のペアで温度差が分かるで。<break time="1.5s"/>

よっつ目、<lang xml:lang="cmn-TW">吧</lang>。<break time="500ms"/>
これは機能語(文末の語気助詞)やから、語彙としての深掘りは無し。意味より使い方が主役の単語やから、文法モジュールで文末詞の軸でガッツリ扱うで。<break time="2s"/>

意味と派生を意識して、もっかい。<break time="800ms"/>
<lang xml:lang="cmn-TW">今天好像會下雨,帶把傘出門吧</lang>。
</speak>
```

---

## Phase 4: 文法モジュール(短文で2ポイント、3点固定の打破例)

```xml
<speak>
<lang xml:lang="cmn-TW">今天好像會下雨,帶把傘出門吧</lang>。<break time="2s"/>
<!-- explain -->
文法ポイントは二つや。短い文やから、無理に詰めるんやのうて、二つに絞ってじっくり見ていくで。<break time="800ms"/>

ひとつ目、量詞だけ残った<lang xml:lang="cmn-TW">把</lang>の特殊用法。<break time="500ms"/>
普通<lang xml:lang="cmn-TW">把</lang>っていうと「<lang xml:lang="cmn-TW">把</lang>字構文」、つまり処置文の<lang xml:lang="cmn-TW">把</lang>を思い浮かべるけど、ここの<lang xml:lang="cmn-TW">帶把傘</lang>は違うで。これは<lang xml:lang="cmn-TW">一把傘</lang>(一本の傘)の量詞<lang xml:lang="cmn-TW">一</lang>が省略されて、量詞<lang xml:lang="cmn-TW">把</lang>だけが残った形や。同じパターンに<lang xml:lang="cmn-TW">給我一杯水</lang>が<lang xml:lang="cmn-TW">給我杯水</lang>に縮む、<lang xml:lang="cmn-TW">買一本書</lang>が<lang xml:lang="cmn-TW">買本書</lang>に縮む、っていう口語の省略パターンがあるで。「数詞が省略されて量詞だけ残る」って覚えとくと、聞き取りでハマらんで済むで。<break time="1.5s"/>

ふたつ目、文末の語気助詞<lang xml:lang="cmn-TW">吧</lang>。<break time="500ms"/>
これ Phase 0 では機能語の特例枠で扱ったやつや。文末の<lang xml:lang="cmn-TW">吧</lang>には主に三つの使い方があって、ひとつは「促し・提案」、<lang xml:lang="cmn-TW">走吧</lang>(行こうや)、<lang xml:lang="cmn-TW">吃飯吧</lang>(ご飯食べよ)。ふたつ目は「軽い推量」、<lang xml:lang="cmn-TW">是這樣吧</lang>(こうちゃうかな)。みっつ目は「不確かな同意」、<lang xml:lang="cmn-TW">好吧</lang>(まあええわ)。今回の<lang xml:lang="cmn-TW">帶把傘出門吧</lang>は一つ目の「自分にも相手にも軽く促す」用法やな。仲間の語気助詞に<lang xml:lang="cmn-TW">啊</lang>(感嘆)、<lang xml:lang="cmn-TW">啦</lang>(主張柔らかめ)、<lang xml:lang="cmn-TW">喔</lang>(注意喚起)があるけど、<lang xml:lang="cmn-TW">吧</lang>は「ふんわり提案」の専門担当やで。<break time="2s"/>

文法構造を意識して、もっかい。<break time="800ms"/>
<lang xml:lang="cmn-TW">今天好像會下雨,帶把傘出門吧</lang>。
</speak>
```

---

## 自己 lint チェック結果(Phase 2 v1.5.0 軽量版)

- 鬼門ワード(画/字義/然り而して/豈/几/疋): なし(`<sub alias="テヘン">扌</sub>` 等の古字部品引用を全削除) ✅
- 単独漢字裸出し: なし(熟語経由 or `<lang>` タグ内のみ) ✅
- 二度読み(漢字+カッコふりがな): カタカナ読み+意味の二重情報なので二度読みではない ✅
- 繋辞NG: `</lang>です` `</lang>だ。` なし(関西弁「やから」「やで」「やな」で対応) ✅
- Markdown 強調 (`**` `*` `__` `_`): なし ✅
- Phase 0 ↔ Phase 2/3 連動: 4語完全一致(今天/好像會/帶把傘/吧)、順序も同じ ✅
- Phase 4 動的「2ポイント」: 短文(14字)で文法的に淡白なので 2ポイントに絞った ✅
- 機能語特例: 「吧」は Phase 2 で言及のみ・Phase 3 で語彙深掘り省略 → Phase 4 で機能語軸で深掘り、と明示的にトラック分離 ✅
- 構成解説削除確認: 部首名(クチヘン等)・構成位置(上に○下に○等)・古字部品 `<sub>`・印象表現(ごっつい等)・字形描写、全て排除 ✅
- 3パターン判定使用確認: ①「今と同じ字」「天気のてんと同じ字」「好きのすき」「想像のぞう」「傘と同じ字」、②「会うの旧字体」「帯の旧字体」、③「日本語にない繁体字(把)」と3パターン全部使用 ✅
