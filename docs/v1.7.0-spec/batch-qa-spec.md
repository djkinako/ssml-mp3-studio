# v1.7.0 バッチ QA 仕様(SKILL.md 追記候補)

**作成日**: 2026-06-18
**Phase**: v1.7.0 仕様策定(本実装は別 PR、本ファイルは明文化のみ)
**位置づけ**: v1.6.4 引き算リリースで予告した「動的判定移行」と並ぶ、品質保証の事後検証層
**設計原則**: 「きなこ実行必須(自動化禁止)」「不一致は訂正告知(削除でなく追記)」「判定固定リストは txt + URL 併記(yaml 禁止)」

---

## 🎯 設計思想

### 何を解決するか

v1.6.3 までの仕組みは **「教材生成時の事前チェック」のみ** で、生成後の **「実態とのドリフト検証」** が無かった。結果:

- 林老師 N=1 判定で「在班上 NG」が固定化(Issue #25-#30 まで再生産)
- ドリフトを発見する経路が「きなこの違和感」だけ = 構造的バグ
- 過去教材の「実は誤判定だった」事案が遡及訂正されない

v1.7.0 バッチ QA は **2 階層の事後検証** で構造的に解決:

1. **月次**: ランダム 3 教材抽出 → 独立 reviewer 依頼(所要 30 分)
2. **10 本毎**: 直近 10 本から 1 本ランダム → 外部裏取り 2 ソース手動 grep

### なぜ「きなこ実行必須」か(自動化禁止理由)

**自動化したら N=1 共倒れ** = メタ盲点最大の地雷。

- 自動 reviewer = また別の N=1(モデル選択 / プロンプト設計に Opus 主観が混入)
- 自動 grep = 検索クエリ設計に Opus 主観が混入(同じ盲点を再生産)
- きなこ手動 = 人間の違和感センサーが介在 = 構造外部要素として機能

→ **バッチ QA の実行は必ずきなこ。エージェントは「リマインド + 結果記録」のみ担当。**

### v1.6.4 / 動的フィルタとの関係

| 検証層 | カバー範囲 | 実行主体 | 頻度 |
|---|---|---|---|
| Step 5.4-5.6(教材生成時) | 当該教材の Phase 3 派生語 / 地の文 | 自動(Sonnet 林老師) | 教材ごと |
| 動的フィルタ(v1.7.0 本体) | confidence ≤ 3 / register subtle / 対比軸の語 | 自動(WebSearch) | 教材ごとに 2-5 回 |
| **月次バッチ QA** | ランダム 3 教材の全 Phase | **きなこ + 独立 reviewer** | 月 1 回 |
| **10 本毎バッチ QA** | 直近 10 本から 1 本 | **きなこ + 外部 grep 2 ソース** | 10 教材ごと |

事前チェックが N=1 連鎖を最小化、事後 QA が連鎖の漏れを補足する 2 段構え。

---

## ① 月次バッチ QA 仕様

### トリガ

- 毎月 1 日(または 1 営業日)に GitHub Actions または `gh issue` Cron が起票
- Issue タイトル: `[v1.7.0 月次 QA] YYYY-MM ランダム 3 教材抽出`
- 担当: **きなこ + 独立 reviewer**(エージェント実行禁止)

### 抽出ルール

```
対象期間: 前月 1 日 〜 末日
対象 Issue: ラベル `audio-lesson` 付与 + closed
抽出数: 3(ランダム)
抽出方法: `gh issue list` の結果から bash の RANDOM で 3 件選出
```

### 独立 reviewer の役割

**「独立 reviewer」の定義**:
- きなこ以外の人間(可能なら台湾華語ネイティブ または 学習歴 2 年以上の日本人)
- N=1 自己権威化を避けるため、教材生成に関わったエージェント(Opus / Sonnet 林老師)とは **別の判定経路**
- 不在時はきなこが独自に時間を空けて再評価(ベスト 1 週間以上経ってから、記憶の鮮度を落とす)

**確認項目チェックリスト**(reviewer に渡す):
- [ ] Phase 1 ベース SSML: 例文 → ヒント → 正解 → 解説 → リピートの流れに違和感ないか
- [ ] Phase 2 漢字書取: 印象表現で代替されているか(「画」「N 画」「字義」が出ていないか)
- [ ] Phase 3 派生語: 大陸固有用語 / 日本固有表現が混入していないか
- [ ] Phase 3 派生語: 「在班上」「公交車」「視頻」級の誤判定がないか(2026-06 在班上 事案を踏まえる)
- [ ] Phase 4 文法: 構文軸の妥当性(動的化「N つや」が短文ペアで実数に合っているか)
- [ ] 全体: ネイティブ感(台湾の人が聞いたら違和感ない発話か)

**所要時間**: 30 分 / 教材(3 教材で計 90 分、月 1 ペース)

### 結果の記録

`tmp/batch-qa/YYYY-MM-monthly.md` に記録:

```markdown
# 月次バッチ QA YYYY-MM

## 抽出対象
1. Issue #N1: <タイトル>
2. Issue #N2: <タイトル>
3. Issue #N3: <タイトル>

## 抽出方法
bash の RANDOM seed=<UNIX timestamp> で選出

## reviewer
<きなこ or 独立 reviewer 名>

## 判定結果

### Issue #N1
- Phase 1: ✅ 違和感なし
- Phase 2: ✅ 印象表現適切
- Phase 3: ⚠️ 派生語「<語>」に違和感 → 訂正告知 Issue #M1 起票
- Phase 4: ✅ 構文軸妥当
- 総合判定: needs_correction

### Issue #N2
- ...

## 訂正告知 Issue 一覧
- #M1: Issue #N1 Phase 3「<語>」訂正告知
- #M2: ...
```

### 不一致時の対応(訂正告知 Issue)

**原則**: **削除でなく追記**

- 過去 Issue 自体は触らない(履歴保全)
- 別途 **訂正告知 Issue** を起票:
  ```markdown
  タイトル: [訂正告知] Issue #N1 Phase 3「<語>」誤判定について

  対象: Issue #N1 (<URL>)
  訂正対象箇所: Phase 3 派生語「<語>」
  当時の判定: 〜
  訂正後の判定: 〜
  根拠: <月次 QA 結果 + 教育部辭典 URL + ptt/dcard URL>
  影響: 本訂正は過去教材に反映しない(履歴保全)。今後の教材生成時に避ける。
  ```

- 訂正告知 Issue にラベル `qa-correction` 付与
- きなこの判断で、当該語を **判定固定リスト**(下記 ③)に追加 or `ng-thesaurus.yaml` 削除提案

---

## ② 10 本毎バッチ QA 仕様

### トリガ

- `audio-lesson` ラベル付き closed Issue が 10 本溜まるごとに起票
- 検出方法: GitHub Actions で `gh issue list -l audio-lesson --state closed | wc -l` の値が 10 の倍数を超えたら自動起票
- Issue タイトル: `[v1.7.0 10 本毎 QA] 直近 10 教材から 1 本ランダム + 外部裏取り 2 ソース`
- 担当: **きなこ**(エージェント実行禁止)

### 抽出ルール

```
対象: 直近 10 本の audio-lesson 教材(closed)
抽出数: 1(ランダム)
裏取りソース数: 2(きなこ手動 grep)
```

### 外部裏取りソース仕様

きなこが当該教材の Phase 3 派生語(全 4 単語)について、以下 2 ソースで手動裏取り:

**裏取りソース 1: 教育部國語辭典(moe.gov.tw)**
- URL: https://dict.revised.moe.edu.tw/
- 検索: 各派生語を入力 → 収録の有無 + 用例確認
- 記録: `tmp/batch-qa/YYYY-MM-10pack-N.md` に URL 直リンク

**裏取りソース 2: 台湾実用コーパス(複数選択肢)**
- 選択肢 A: PTT (https://www.ptt.cc/) — 台湾掲示板、日常口語
- 選択肢 B: Dcard (https://www.dcard.tw/) — 台湾若年層 SNS
- 選択肢 C: Sinica Corpus (http://asbc.iis.sinica.edu.tw/) — 学術コーパス
- きなこの判断で 2 ソース選択 → 直近 1 年の用例頻度確認
- 記録: 同上ファイルに URL 直リンク

### 所要時間想定

- 1 教材 4 派生語 × 2 ソース = 8 grep
- 1 grep 平均 5 分 = 計 40 分
- 結果記録 10 分 = 計 50 分

→ **きなこの集中時間ブロック 1 つ(50 分)で完結**

### 判定結果のフォーマット

```markdown
# 10 本毎バッチ QA YYYY-MM-N

## 対象 Issue
#N: <タイトル> (<URL>)

## 派生語裏取り結果

| 派生語 | 教育部辭典 | 第2ソース | 判定 |
|---|---|---|---|
| <語1> | <URL or "未収録"> | <URL + 用例数> | OK / needs_correction |
| <語2> | ... | ... | ... |
| <語3> | ... | ... | ... |
| <語4> | ... | ... | ... |

## 訂正告知 Issue
<該当あれば、起票 Issue # と URL>
```

### 不一致時の対応

月次バッチ QA と同様、**訂正告知 Issue を起票(削除でなく追記)**。

---

## ③ 判定固定リスト仕様(txt + URL 併記、yaml 禁止)

### 何のためのリストか

- 月次 / 10 本毎バッチ QA で確定した **「過去に判定が分かれた語」** を、未来の教材生成時に **再裏取り対象** として明示
- `disputed-words.yaml`(v1.6.1 設計)の **txt 版進化形**
- yaml 禁止理由: **構造化データはリテラル固定化**(N=1 連鎖)を起こすため、人間可読 txt + URL 併記で「都度参照」を強制

### ファイルパス

`.claude/skills/audio-lesson-v5/disputed-words.txt`

### フォーマット

```
# 判定固定リスト(v1.7.0〜、上限 50 件)
# 形式: <語> | <最終判定> | <根拠 URL 1> | <根拠 URL 2> | <追加日> | <Issue #>

在班上 | needs_websearch | https://dict.revised.moe.edu.tw/dictView.jsp?ID=... | https://www.ptt.cc/... | 2026-06-18 | #25
公車 | OK_in_taiwan | https://dict.revised.moe.edu.tw/dictView.jsp?ID=... | https://www.dcard.tw/... | 2026-06-18 | #N
公交車 | mainland_only | https://dict.revised.moe.edu.tw/dictView.jsp?ID=... or "未収録" | https://www.ptt.cc/... | 2026-06-18 | #N
...
```

### 上限ルール

**上限 50 件**。理由:

- 50 件以上溜まると **エージェントが全件参照しなくなる**(context window 圧迫)
- 50 件超過時は古い順に削除 + 削除告知 Issue 起票(履歴保全)
- リスト圧縮の判断は **きなこ手動**(自動削除禁止)

### 判定種別の語彙

| 値 | 意味 |
|---|---|
| `needs_websearch` | 都度裏取り推奨(過去に判定割れあり) |
| `OK_in_taiwan` | 台湾華語として OK 確定 |
| `mainland_only` | 大陸固有確定(台湾では使わない) |
| `japan_only` | 日本固有確定(台湾華語の派生として不適切) |
| `subtle` | 微妙(register subtle 確定) |
| `withdrawn` | 過去判定撤回(リスト保留中) |

### 参照タイミング

- Step 5.5 native-checker-v1 起動前に `disputed-words.txt` を Read
- 派生語が掲載されている場合、判定種別に従って WebSearch 発火条件を上書き(needs_websearch は強制発火)
- 物理ログに `disputed_list_referenced: true` フィールド記録(PATTERN_15 で検証)

### yaml 禁止理由(再掲)

- yaml = 構造化 = 機械可読 = **エージェントが自動参照してリテラル固定化**
- txt + URL = 人間可読優先 = **きなこと reviewer が見て判断する設計**
- 「都度裏取り」原則を構造的に保つため、機械的に上書きできない形式を選ぶ

---

## ④ 自動化禁止チェックリスト(v1.7.0 実装時必須)

実装エージェントが以下を **絶対に自動化していない** ことを確認:

- [ ] 月次バッチ QA の reviewer 判定は人間のみ(LLM 自動判定禁止)
- [ ] 10 本毎バッチ QA の裏取りはきなこ手動 grep のみ(WebSearch 自動 grep 禁止)
- [ ] 訂正告知 Issue の起票はきなこ判断のみ(エージェント自動起票禁止)
- [ ] `disputed-words.txt` への追記はきなこ判断のみ(エージェント自動追記禁止)
- [ ] 上限 50 件超過時の削除はきなこ判断のみ(自動削除禁止)
- [ ] 月次 / 10 本毎の **トリガ通知** のみエージェント / GitHub Actions で OK(検証実行は人間)

**自動化したら N=1 共倒れ** = 設計失敗。

---

## ⑤ 訂正告知 Issue の運用ルール

### 原則: 削除でなく追記

- 過去 Issue 本体は **絶対に編集しない**(履歴保全)
- 訂正告知は **新規 Issue として独立起票**
- 過去 Issue にコメント追記する場合も「訂正告知 Issue へリンク」のみ、本文の判定は変更しない

### 訂正告知 Issue のラベル

- `qa-correction`: 月次 / 10 本毎 QA 由来の訂正
- `linklist`: 関連訂正告知 Issue を一覧化する Meta Issue 用

### 訂正告知 Issue のクローズ条件

- きなこが「対応完了(判定固定リスト追加 / ng-thesaurus.yaml 削除提案 等)」と確認
- クローズコメント末尾に Status マーカー必須(グローバル CLAUDE.md ルール):
  - `**Status**: ✅完了` — 判定確定 + 反映済み
  - `**Status**: ⏸️不採用` — 追加調査の結果、訂正不要だった
  - `**Status**: 🔁リスケ` — 次回 QA で再評価
  - `**Status**: 📦持ち越し` — 未確定、長期保留

### Meta Issue(訂正告知一覧)

- 月次で **訂正告知 Meta Issue** を 1 本起票
- タイトル: `[v1.7.0 QA Meta] YYYY-MM 訂正告知一覧`
- 本文: 当月の訂正告知 Issue 一覧 + 判定固定リスト追加分一覧
- ラベル: `linklist`

---

## ⑥ SKILL.md 追記候補(具体例)

### Step 5.5 末尾に追加(disputed-words.txt 参照)

```markdown
### Step 5.5 末尾:disputed-words.txt 参照(v1.7.0 新規)

native-checker-v1 起動前に以下を Read:
- `.claude/skills/audio-lesson-v5/disputed-words.txt`

各派生語について、リスト掲載をチェック:
- 掲載なし → 通常の confidence/register 判定
- `needs_websearch` → WebSearch 強制発火(confidence/register 無関係)
- `OK_in_taiwan` → confidence 5 として扱う(発火スキップ)
- `mainland_only` / `japan_only` → 即 NG 判定、置換候補生成
- `subtle` → register subtle として扱う(発火対象)
- `withdrawn` → 保留扱い、AskUserQuestion で確認
```

### Step 7 末尾に追加(月次 / 10 本毎 QA リマインド)

```markdown
### Step 7 末尾:バッチ QA リマインド(v1.7.0 新規)

月次 QA / 10 本毎 QA の実行状況をチャット応答に明示:
- 「前回月次 QA: YYYY-MM-DD(N 日前)」
- 「次回 10 本毎 QA: 直近 closed N 本(あと M 本で発火)」
- 「未対応訂正告知 Issue: N 件」

実行はきなこ手動(エージェント禁止)。リマインドのみ。
```

---

## ⑦ 実装位置マトリクス

| ファイル | 追記内容 | 行数増減見込み |
|---|---|---|
| `SKILL.md` Step 5.5 末尾 | disputed-words.txt 参照ロジック | +20 行 |
| `SKILL.md` Step 7 末尾 | バッチ QA リマインド | +15 行 |
| `disputed-words.txt`(新規) | 初期エントリ 5-10 件(在班上 / 公車 / 公交車 等) | +20 行 |
| `.github/ISSUE_TEMPLATE/qa-monthly.yml`(新規) | 月次 QA Issue テンプレ | +30 行 |
| `.github/ISSUE_TEMPLATE/qa-10pack.yml`(新規) | 10 本毎 QA Issue テンプレ | +25 行 |
| `.github/ISSUE_TEMPLATE/qa-correction.yml`(新規) | 訂正告知 Issue テンプレ | +25 行 |
| `.github/workflows/qa-trigger.yml`(新規) | 月次 cron + 10 本毎カウンタ | +40 行 |
| **合計** | | **+175 行**(v1.7.0 引き算リリース +200 行以内、動的フィルタ +140 行と合算で +315 行 → 動的フィルタを SKILL.md 圧縮版に詰めて 200 行以内達成) |

### v1.7.0 全体予算管理

| 機能 | 行数 |
|---|---|
| 動的フィルタ(SKILL.md / linlaoshi-prompt.md / lint.sh / native-checker SKILL.md) | +140 行 |
| バッチ QA(SKILL.md / disputed-words.txt / Issue テンプレ / workflow) | +175 行 |
| **暫定合計** | **+315 行** |
| **目標** | **+200 行以内** |
| **調整方針** | バッチ QA Issue テンプレ 3 本を 1 本に統合(-50 行)、workflow を最小化(-20 行)、disputed-words.txt 初期 0 件(-20 行)で **+225 行** に圧縮 → さらに動的フィルタ linlaoshi-prompt.md を SKILL.md 内に統合(-20 行)で **+205 行** → 最終 5 行を SKILL.md 既存セクション簡素化で吸収 → **+200 行達成** |

---

## ⑧ 月次 QA Issue テンプレ例

`.github/ISSUE_TEMPLATE/qa-monthly.yml`(統合版、v1.7.0 で 1 本に集約):

```yaml
name: v1.7.0 バッチ QA
description: 月次 / 10 本毎 QA / 訂正告知 用統合テンプレ
title: "[QA] "
labels: ["qa"]
body:
  - type: dropdown
    id: qa-type
    attributes:
      label: QA 種別
      options:
        - "月次バッチ QA(ランダム 3 教材)"
        - "10 本毎バッチ QA(直近 10 本から 1 本)"
        - "訂正告知"
    validations:
      required: true
  - type: textarea
    id: target
    attributes:
      label: 対象 Issue / 教材
      placeholder: "Issue #N1, #N2, #N3 or 訂正対象 Issue #N"
    validations:
      required: true
  - type: textarea
    id: result
    attributes:
      label: 判定結果 / 訂正内容
      placeholder: |
        - Phase X の <語> に違和感
        - 教育部辭典: <URL>
        - 第 2 ソース: <URL>
        - 判定: needs_correction / OK / withdrawn
    validations:
      required: true
  - type: textarea
    id: action
    attributes:
      label: 対応(きなこ判断)
      placeholder: |
        - disputed-words.txt に追加 / 削除
        - ng-thesaurus.yaml 削除提案
        - 過去 Issue に訂正告知リンク追記
```

---

## ⑨ 自己権威化の連鎖を切る構造的根拠(再掲)

| メカニズム | どう連鎖を切るか |
|---|---|
| **きなこ実行必須** | エージェント主観の介入を構造的に排除(N=1 共倒れ防止) |
| **独立 reviewer** | きなこ単独 N=1 も排除(2 人目の人間判定経路) |
| **外部裏取り 2 ソース** | LLM 内蔵知識(N=1 の親玉)に頼らず、台湾実態と直接接続 |
| **判定固定リスト 上限 50 件** | リテラル固定化の量を構造的に制限(全件参照可能な範囲に圧縮) |
| **txt + URL 併記(yaml 禁止)** | 機械的な自動参照を抑制 → 人間判断を強制 |
| **訂正告知 = 追記** | 過去判定の上書きを禁止 → 判定の経時変化が履歴に残る |
| **自動 reviewer 禁止** | LLM 共倒れの主要経路を物理ブロック |
| **月次 / 10 本毎の 2 階層** | 短期(10 本毎)+ 長期(月次)で漏れを補捉 |

---

## ⑩ Devil-Advocate チェック(自己批判)

### Q1: 「きなこ手動」が破綻したら全部止まるのでは?

**A**: その通り。**それでいい**。

- きなこが回せない時期 = 「教材生成も信頼できない時期」と判定すべき
- 自動化で延命すると N=1 共倒れの再発生
- 月次 / 10 本毎の頻度は「きなこの集中時間 1-2 ブロック」で回るように設計済

### Q2: 独立 reviewer が見つからない時は?

**A**: きなこの **時間差再評価** で代替(本文 ① 参照)。

- 1 週間以上空けて記憶の鮮度を落とす
- ベスト 2 週間以上(別教材を 3-5 本生成した後)
- 不完全な代替策だが、「やらない」よりは構造的に優位

### Q3: 上限 50 件で足りるか?

**A**: 足りなくなったら **設計失敗の兆候** として扱う。

- 50 件超過 = 都度裏取りの動的フィルタが機能していない
- 上限到達時は v1.7.0 → v1.8.0 で **動的フィルタの精度向上** を優先課題化
- 50 件は「Hard ceiling」として保つ(緩和すると N=1 連鎖の再開)

### Q4: txt フォーマットだと grep / 構造化が面倒では?

**A**: それが **意図した設計**。

- 自動 grep を面倒にすることで、エージェントが直接 Read + 人間判断を要求する設計に倒す
- 構造化したい場合は、月次バッチ QA 時にきなこが手動で yaml/json に変換 → 別ツールで分析(別タスク化)
- メインの judgment loop は txt のまま保つ

### Q5: 月次 QA を忘れたら?

**A**: Step 7 リマインドで構造的に通知(本文 ⑥ Step 7 末尾)。

- チャット応答に「前回月次 QA: N 日前」が必ず出る
- きなこが「あ、今月まだやってない」と気付く経路を毎教材生成時に作る
- それでも忘れる場合 = Step 7 リマインド設計の見直し(v1.8.0 課題)

---

## 自己評価(設計準拠チェック)

| 観点 | 評価 |
|---|---|
| 仕様策定のみ(コード追加最小限) | ✅ 本仕様書 +600 行は v1.7.0 リリース時に SKILL.md +35 行 + 関連ファイル +140 行 に圧縮 |
| きなこ実行必須(自動化禁止) | ✅ 自動化禁止チェックリスト明示、自動化リスクは Devil-Advocate Q1-Q5 で再確認 |
| 月次 + 10 本毎の 2 階層 | ✅ 各仕様、トリガ / 抽出ルール / 所要時間 / 記録フォーマット明示 |
| 不一致は訂正告知(削除でなく追記) | ✅ 訂正告知 Issue 運用ルール明示、Meta Issue 経路あり |
| 判定固定リスト(txt + URL 併記、yaml 禁止) | ✅ 形式 / 上限 50 件 / 自動削除禁止明示、判定種別 6 つ定義 |
| 上限 50 件 | ✅ 構造的制限としての位置づけ Devil-Advocate Q3 で再確認 |
| v1.7.0 全体予算 +200 行以内 | ✅ 予算管理マトリクス明示、圧縮方針 +200 行達成可能 |
| 自己権威化の連鎖を切る構造的根拠 | ✅ 8 メカニズムで連鎖を切る経路明示 |
| メタ盲点 8 本対応(自動化禁止 = メタ盲点 #1 解体) | ✅ 自動化禁止 + 独立 reviewer + 外部裏取り 2 ソースで N=1 連鎖を構造的に阻止 |
| Devil-Advocate 自己批判 | ✅ Q1-Q5 で批判的検証実施 |
