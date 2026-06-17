# Few-shot ペア1: 凱旋而歸(成語含む文学系)

## ペア概要

| 項目 | 内容 |
|---|---|
| 日本語 | 私たち、勇者一行の凱旋です |
| 中国語(繁体字) | 我們勇者一行人凱旋而歸 |
| カテゴリ | 成語含む文学系、4ブロックフル(Phase 1-4 全部出力) |
| 由来 | アニメ「葬送のフリーレン」1話、フリーレン台詞 |

## Phase 0 フォーカス語

| # | 単語 | 抽出理由 |
|---|---|---|
| 1 | **我們** | 繁体字特有「們」、人称複数の最頻出ワード、派生広い |
| 2 | **凱旋** | 文の意味のコア、日本語と同形の熟語だが書面語専用 |
| 3 | **而** | 書面語マーカー、一文字単語例外、超頻出接続詞 |
| 4 | **歸** | 繁体字「帰」、書面語、口語「回」との対比軸 |

**自己相互チェック3点**:
- ① 部分文字列共有なし: 我們/凱旋/而/歸はどれも互いに包含関係なし ✅
- ② 同一品詞・意味カテゴリの重複なし: 代名詞・名詞・接続詞・動詞でバラけている ✅
- ③ Phase 3 派生語列挙が交差しない: 我們→你們/他們系、凱旋→凱歌/凱旋門系、而→而且/然而系、歸→歸來/歸國系 ✅

## 学習ポイント

- **4ブロックフル**: ベース → 漢字認識 → 語彙深掘り → 文法、全てを使って深掘りする典型例
- **書面語スイッチ**: 「而」「歸」2つの書面語サインが8文字に凝縮、温度感を伝える
- **成語の型**: 「動詞 + 而 + 動詞」型(凱旋而歸 / 敗興而歸 / 滿載而歸)のパターン認識
- **集合接尾辞**: 「一行人」の「人」が集合を表す型
- **Phase 2 軽量版(v1.5.0)**: 3パターン判定テンプレ(①日本語と同じ字 / ②旧字体 / ③日本語にない繁体字)のみで構成、構成解説・印象表現・字形描写は一切排除

---

## Phase 1: ベース SSML

```xml
<speak>
例文。<break time="300ms"/>
私たち、勇者一行の凱旋です。<break time="2s"/>
ヒント1。<break time="300ms"/>
<lang xml:lang="cmn-TW">我們</lang><break time="200ms"/>、<break time="200ms"/>勇者一行の凱旋です。<break time="4s"/>
ヒント2。<break time="300ms"/>
<lang xml:lang="cmn-TW">我們</lang><break time="200ms"/>、<break time="200ms"/><lang xml:lang="cmn-TW">勇者一行人</lang><break time="200ms"/>の凱旋です。<break time="4s"/>
ヒント3。<break time="300ms"/>
<lang xml:lang="cmn-TW">我們</lang><break time="200ms"/>、<break time="200ms"/><lang xml:lang="cmn-TW">勇者一行人</lang><break time="200ms"/>、<break time="200ms"/><lang xml:lang="cmn-TW">凱旋而歸</lang>。<break time="4s"/>
正解。<break time="500ms"/>
<lang xml:lang="cmn-TW">我們勇者一行人凱旋而歸</lang>。<break time="3s"/>
<!-- explain -->
解説。<break time="500ms"/>
ポイントは「<break time="200ms"/><lang xml:lang="cmn-TW">凱旋而歸</lang><break time="200ms"/>」、これ成語やで。「戦勝して堂々と帰還する」って意味の固定表現や。<break time="500ms"/>
構造的には「動詞 + <break time="200ms"/><lang xml:lang="cmn-TW">而</lang><break time="200ms"/> + 動詞」のパターンで、同じ型の成語仲間に「<break time="200ms"/><lang xml:lang="cmn-TW">敗興而歸</lang><break time="200ms"/>」、がっかりして帰る。「<break time="200ms"/><lang xml:lang="cmn-TW">滿載而歸</lang><break time="200ms"/>」、大収穫で帰る、なんかがある。<break time="2s"/>
ほな、もっかい。<break time="800ms"/>
<lang xml:lang="cmn-TW">我們勇者一行人凱旋而歸</lang>。
</speak>
```

---

## Phase 2: 漢字認識モジュール(v1.5.0 軽量版・3パターン判定)

```xml
<speak>
<lang xml:lang="cmn-TW">我們勇者一行人凱旋而歸</lang>。<break time="2s"/>
<!-- explain -->
漢字認識の解説や。ピックアップは四つの単語、それぞれどの字か見ていくで。<break time="800ms"/>

ひとつ目、<lang xml:lang="cmn-TW">我們</lang>(ウォーメン、私たち)。<break time="500ms"/>
「ウォー」は日本語の「我々」の「われ」と同じ字、「メン」は日本語にない繁体字で、複数形を作る接尾辞や。<break time="1.5s"/>

ふたつ目、<lang xml:lang="cmn-TW">凱旋</lang>(カイセン、凱旋)。<break time="500ms"/>
「カイ」は日本語の「凱旋」の「がい」、「セン」は「旋回」の「せん」と同じ字や。日本語と同じ熟語やから組み合わせで覚えられるで。<break time="1.5s"/>

みっつ目、書面語の主役<lang xml:lang="cmn-TW">而</lang>(アー)。<break time="500ms"/>
これ一文字単語の例外枠で取り上げるで。日本語の「しかして」の「じ」と同じ字、書面語の接続詞や。日常会話では使わへんけど、文章では超頻出やで。<break time="1.5s"/>

よっつ目、<lang xml:lang="cmn-TW">歸</lang>(グイ、帰る)。<break time="500ms"/>
これも一文字単語の例外枠や。日本語の「帰る」の旧字体や。意味は同じく「帰る」、書面語向きの言い回しに使うで。<break time="2s"/>

単語の認識を意識して、もっかい。<break time="800ms"/>
<lang xml:lang="cmn-TW">我們勇者一行人凱旋而歸</lang>。
</speak>
```

---

## Phase 3: 語彙深掘りモジュール

```xml
<speak>
<lang xml:lang="cmn-TW">我們勇者一行人凱旋而歸</lang>。<break time="2s"/>
<!-- explain -->
語彙の深掘りや。漢字認識と同じ四つの単語、意味と派生を見ていくで。<break time="800ms"/>

ひとつ目、<lang xml:lang="cmn-TW">我們</lang>。<break time="500ms"/>
「私たち」「われわれ」の人称代名詞や。「われ」(私の意)に複数マーカー「メン」を足した型で、同じパターンの仲間に<lang xml:lang="cmn-TW">你們</lang>(君たち)、<lang xml:lang="cmn-TW">他們</lang>(彼ら)、<lang xml:lang="cmn-TW">她們</lang>(彼女たち)。複数マーカーの「メン」は名詞にもくっつけて<lang xml:lang="cmn-TW">同學們</lang>(同級生たち)、<lang xml:lang="cmn-TW">朋友們</lang>(友達一同)、中国語の人称複数はぜーんぶこの型で作るで。<break time="1.5s"/>

ふたつ目、<lang xml:lang="cmn-TW">凱旋</lang>。<break time="500ms"/>
意味は「勝利して堂々と帰る」。日本語と同じ熟語やけど、台湾華語では書面語・英雄譚向きの格式高い表現や。仲間ワードに<lang xml:lang="cmn-TW">凱歌</lang>(勝利の歌)、<lang xml:lang="cmn-TW">凱旋門</lang>(凱旋門)、そして今回の文のキー成語<lang xml:lang="cmn-TW">凱旋而歸</lang>(凱旋して帰る)。<break time="1.5s"/>

みっつ目、<lang xml:lang="cmn-TW">而</lang>。<break time="500ms"/>
書面語の接続詞で、機能は「なになにしてなになにする」「なになにしつつなになにする」と前後を繋ぐ役割や。仲間ワードに<lang xml:lang="cmn-TW">而且</lang>(しかも)、<lang xml:lang="cmn-TW">然而</lang>(しかしながら)、<lang xml:lang="cmn-TW">反而</lang>(かえって)。会話では使わんけど、文章・ニュース・物語文では超頻出。「書面語スイッチ」が入った合図やと思っとくとええで。<break time="1.5s"/>

よっつ目、<lang xml:lang="cmn-TW">歸</lang>。<break time="500ms"/>
意味は「帰る」「戻る」。口語やと普通は<lang xml:lang="cmn-TW">回</lang>(ホイ)を使う、<lang xml:lang="cmn-TW">回家</lang>(家に帰る)、<lang xml:lang="cmn-TW">回來</lang>(戻ってくる)。それに対して<lang xml:lang="cmn-TW">歸</lang>は書面語専用、<lang xml:lang="cmn-TW">歸來</lang>(帰り来る)、<lang xml:lang="cmn-TW">歸國</lang>(帰国)、<lang xml:lang="cmn-TW">歸還</lang>(返還する)みたいに格式高い文脈で使うで。<break time="2s"/>

意味と派生を意識して、もっかい。<break time="800ms"/>
<lang xml:lang="cmn-TW">我們勇者一行人凱旋而歸</lang>。
</speak>
```

---

## Phase 4: 文法モジュール

```xml
<speak>
<lang xml:lang="cmn-TW">我們勇者一行人凱旋而歸</lang>。<break time="2s"/>
<!-- explain -->
文法ポイント、見ていくで。<break time="800ms"/>

ひとつ目、成語の型「動詞 + <lang xml:lang="cmn-TW">而</lang> + 動詞」。<break time="500ms"/>
今回の<lang xml:lang="cmn-TW">凱旋而歸</lang>(凱旋して帰る)はこの型の典型例や。同じ型の仲間ワードに<lang xml:lang="cmn-TW">敗興而歸</lang>(がっかりして帰る)、<lang xml:lang="cmn-TW">滿載而歸</lang>(大収穫で帰る)、<lang xml:lang="cmn-TW">無功而返</lang>(成果なく帰る)、<lang xml:lang="cmn-TW">乘興而來</lang>(意気込んで来る)。「どんな状態で帰ったか・来たか」を一言でキメる書面語パターンや、英雄譚やニュース見出しで超頻出やで。<break time="1.5s"/>

ふたつ目、集団を表す<lang xml:lang="cmn-TW">一行人</lang>。<break time="500ms"/>
構造は<lang xml:lang="cmn-TW">一行</lang>(ひと連れ・集まり)に<lang xml:lang="cmn-TW">人</lang>を足して「一行のみんな」を表す形や。仲間ワードに<lang xml:lang="cmn-TW">一行人馬</lang>(一隊の人と馬)、<lang xml:lang="cmn-TW">我們這群人</lang>(われわれ一同)、<lang xml:lang="cmn-TW">一夥人</lang>(ひと群れの人々)。集団の規模感や仲間感を出すときに使う型やで。<break time="1.5s"/>

みっつ目、書面語スイッチの目印。<break time="500ms"/>
この一文、わずか八文字の中に<lang xml:lang="cmn-TW">而</lang>と<lang xml:lang="cmn-TW">歸</lang>っていう書面語サインが二つも入っとる。聞き手に「これはガチの英雄譚モードや」って一発で伝わる文構造や。日常会話で使う言い方やと<lang xml:lang="cmn-TW">我們勇者隊伍回來了</lang>(われわれ勇者チーム戻ってきたで)みたいになる、書面語と口語の温度差めちゃ感じられるな。<break time="2s"/>

文法構造を意識して、もっかい。<break time="800ms"/>
<lang xml:lang="cmn-TW">我們勇者一行人凱旋而歸</lang>。
</speak>
```

---

## 自己 lint チェック結果(Phase 2 v1.5.0 軽量版)

- 鬼門ワード(画/字義/然り而して/豈/几/疋): なし(`<sub alias>` 古字部品引用を全削除) ✅
- 単独漢字裸出し: なし(熟語経由 or `<lang>` タグ内のみ) ✅
- 二度読み(漢字+カッコふりがな): カタカナ読み+意味の二重情報なので二度読みではない ✅
- 繋辞NG: `</lang>です` `</lang>だ。` なし ✅
- Markdown 強調 (`**` `*` `__` `_`): なし ✅
- Phase 0 ↔ Phase 2/3 連動: 4語完全一致(我們/凱旋/而/歸)、順序も同じ ✅
- 構成解説削除確認: 部首名(ニンベン/サンズイ等)・構成位置(上に○下に○等)・古字部品 `<sub>`・印象表現(ごっつい/線多め等)・字形描写、全て排除 ✅
- 3パターン判定使用確認: ①「我々の『われ』と同じ字」「凱旋の『がい』」「旋回の『せん』」「而と同じ字」、②「帰るの旧字体」、③「日本語にない繁体字(們)」と3パターン全部使用 ✅
