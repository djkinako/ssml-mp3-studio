# v1.7.0 動的フィルタ仕様(SKILL.md 追記候補)

**作成日**: 2026-06-18
**Phase**: v1.7.0 仕様策定(本実装は別 PR、本ファイルは明文化のみ)
**位置づけ**: v1.6.4 引き算リリースで予告した「`ng-thesaurus.yaml` 等固定辞書の動的判定移行」の本体仕様
**設計原則**: 「3 軸 OR トリガで WebSearch 最小発火」「結果を辞書化しない(自己権威化の連鎖を切る)」

---

## 🎯 設計思想

### 何を解決するか

v1.6.3 までの固定辞書(`ng-thesaurus.yaml`, `linlaoshi-prompt.md` 例示)は **N=1 林老師判定をリテラル化** したため、誤判定(例: 「在班上」を NG 扱い)が **構造的に再生産される連鎖** を生んでいた。

v1.7.0 動的フィルタは **「都度裏取り」と「結果の非永続化」** で連鎖を断つ:

- **辞書化しない**: WebSearch 結果は脚注 1 行で透明化、`ng-thesaurus.yaml` 等に追記しない
- **3 軸 OR トリガ**: AND だと発火しない設計欠陥を回避(機能不全防止)
- **対比軸自動マーキング**: 大陸 vs 台湾 / 日本 vs 台湾 / 類義差分は強制裏取り
- **発火頻度の上限**: 1 教材想定 WebSearch 2-5 回(対比軸の語が全体の 15-25% という頻度モデル)

### v1.6.4 との接続

| v1.6.4(引き算) | v1.7.0(動的判定本体) |
|---|---|
| `ng-thesaurus.yaml` 「在班上」エントリ削除 | WebSearch で都度裏取り |
| `linlaoshi-prompt.md` L11-12 NG 例示削除 | judgment_logic セクションで confidence/register 申告義務 |
| Bash wrapper false sense of security 解体 | PATTERN_15 物理ログ拡張(confidence/register/裏取り結果フィールド必須化) |
| SKILL.md +6 行予告 blockquote | 本仕様書を SKILL.md に統合(v1.7.0 リリース時) |

---

## ① 3 軸 OR トリガ仕様

### 軸 1: confidence(Sonnet self-confidence)

**定義**: native-checker-v1 が各派生語 / 地の文に対して付与する自己確信度(1-5 整数)。

| confidence | 意味 | 発火条件 |
|---|---|---|
| 5 | 確信あり、間違いなく OK / NG | 発火なし |
| 4 | 強く OK / NG、辞書照合済 | 発火なし |
| 3 | 中程度、文脈次第 | **発火**(WebSearch 実施) |
| 2 | 弱い、議論余地あり | **発火**(WebSearch 実施) |
| 1 | 不明、人間レビュー希望 | **発火**(WebSearch 実施 + 結果に注釈) |

**閾値**: `confidence ≤ 3` で発火。

**実装位置**:
- `native-checker-v1/SKILL.md` の出力 JSON に `confidence` フィールド必須化(既存仕様の継承)
- native-checker-v1 内部で confidence ≤ 3 を検出時、自動 WebSearch 実行
- 結果を `prose_issues` または `issues` の各エントリに `webcheck_result` フィールドで添付

### 軸 2: register(書面語 / 口語 / 微妙 / 跨ぐ / 不明)

**定義**: native-checker-v1 が各派生語 / 地の文に対して付与するレジスター分類。

| register 値 | 意味 | 発火条件 |
|---|---|---|
| `spoken` | 純口語 | 発火なし |
| `written` | 純書面語 | 発火なし |
| `subtle` | 微妙(口語 / 書面語の境界が曖昧) | **発火** |
| `straddle` | 両方跨ぐ(コンテキスト次第) | **発火** |
| `unknown` | 不明 | **発火** + 結果に注釈 |

**実装位置**:
- `native-checker-v1/SKILL.md` の出力 JSON に `register` フィールド必須化(新規)
- `linlaoshi-prompt.md` に register 分類タスクを追加(judgment_logic セクション)
- subtle / straddle / unknown を検出時、自動 WebSearch 実行

**意義**: confidence が 4-5 でも register が subtle / straddle のときは、林老師の主観確信が高いだけで実態が割れている可能性があるため、強制的に裏取り。

### 軸 3: 対比軸(大陸 vs 台湾 / 日本 vs 台湾 / 類義差分)

**定義**: プロンプト(`zhtw-v5-modular.md` および `linlaoshi-prompt.md`)内で、以下のいずれかに該当する語を自動マーキング → 強制裏取り。

| 対比カテゴリ | 例 | マーキング条件 |
|---|---|---|
| 大陸 vs 台湾 | 公車 / 公交車、影片 / 視頻、橘子 / 橙子 | プロンプト内で「大陸用語」「台湾華語」のいずれかの語と共起 |
| 日本 vs 台湾 | 衆議院、聯合艦隊、博多 | プロンプト内で「日本固有」「日本由来」「日本側」のいずれかの語と共起 |
| 類義差分 | 在班上 / 在班裡 / 在班級裡 | 派生語列挙で 2 つ以上の類義語が並ぶ場合(同義語クラスタ) |

**実装位置**:
- `linlaoshi-prompt.md` の judgment_logic セクションに「対比軸タグ付け義務」を追加
- native-checker-v1 内部で出力 JSON の `contrast_axis` フィールドに `["mainland_vs_taiwan", "japan_vs_taiwan", "synonym_cluster"]` のいずれかを格納
- 1 つでもタグ付与時、強制 WebSearch(confidence/register と無関係に発火)

**意義**: 対比軸は **「ユーザーが間違えやすい判定」** が集中する領域なので、confidence が高くても林老師の主観だけで決めさせない。

---

## ② OR トリガ判定論理(機能不全防止)

### 発火条件式

```
WebSearch 発火 := (confidence ≤ 3) OR (register ∈ {subtle, straddle, unknown}) OR (contrast_axis ≠ null)
```

### なぜ OR か(AND 禁止理由)

- AND にすると **3 軸すべて引っかかる語のみ裏取り** = 実質発火しない(高 confidence かつ contrast_axis ありの語は素通り)
- OR にすることで **対比軸の語が必ず裏取り対象になる**(自己権威化の連鎖を切る最重要経路)

### 発火頻度モデル(設計時想定)

| 語タイプ | 1 教材あたり想定数 | 発火率 |
|---|---|---|
| 通常派生語(confidence 4-5、register 確定、対比軸なし) | 12-18 個 | 0% |
| confidence 3 のみ | 1-2 個 | 100% |
| register subtle/straddle のみ | 1-2 個 | 100% |
| 対比軸のみ | 2-4 個(15-25%) | 100% |
| 軸重複(confidence 低 + 対比軸) | 0-1 個 | 100%(重複は 1 回として数える) |
| **想定発火回数** | — | **2-5 回 / 教材** |

**コスト試算**:
- WebSearch 1 回 = 約 5-10 秒、ツール側コスト無料(Claude Code 内蔵)
- 月 100 教材 × 平均 3.5 回 = 月 350 WebSearch 発火
- 体感影響: 1 教材あたり追加 10-50 秒(2-5 回 × 5-10 秒)

---

## ③ WebSearch クエリ仕様

### 固定テンプレ

```
"<語>" 台灣 教育部 OR ptt OR dcard
```

**テンプレ要素の意味**:
- `"<語>"`: ダブルクォートで完全一致検索(部分マッチ排除)
- `台灣`: 繁体字「灣」で台湾サイトに寄せる(簡体字「湾」は大陸サイトを呼ぶ)
- `教育部`: 教育部國語辭典の権威付け
- `OR ptt`: PTT(台湾掲示板)で実用頻度確認
- `OR dcard`: Dcard(台湾若年層 SNS)で口語実態確認

### ドメイン制限

WebSearch ツールに対するドメイン制限(オプション、ツール側仕様に従う):

```
.tw / .edu.tw / moe.gov.tw
```

**意義**:
- `.tw`: 台湾ドメイン全般
- `.edu.tw`: 台湾教育機関(裏取り権威)
- `moe.gov.tw`: 教育部公式

**フォールバック**: ツール側で domain 制限が効かない場合、結果リストから手動フィルタリング(URL に `.tw` / `.edu.tw` / `moe.gov.tw` を含むもののみ採用、結果が 0 件なら confidence: unknown で投稿)。

### クエリの動的拡張(オプション、v1.7.0 で実装可否判断)

対比軸が `mainland_vs_taiwan` の場合のみ、追加クエリ:

```
"<語>" 大陸 vs 台灣 用法差異
```

→ 大陸用語との境界判定に特化。

---

## ④ 結果の取り扱い(辞書化禁止 + 脚注 1 行透明化)

### 取り扱い原則

1. **辞書化禁止**: WebSearch 結果を `ng-thesaurus.yaml` や `disputed-words.yaml` に追記しない
2. **脚注 1 行透明化**: native-checker-v1 出力 JSON に `webcheck_result` フィールド追加、コメント末尾に「※ X 件の語で裏取り実施」と明示
3. **物理ログには記録**: `tmp/native-check/<issue>-pair<i>.json` に裏取り結果を保存(再現性確保)、ただし永続辞書には反映しない

### なぜ辞書化しないか

- 辞書化 = N=1 判定のリテラル固定化 = メタ盲点 8 本の再生産経路
- 「都度裏取り」が原則なので、結果を覚えさせると次回以降の裏取りがスキップされる
- 辞書の鮮度劣化(教育部辭典更新、台湾若年層の語彙変化)に追従できない

### 例外: 「明確に大陸固有」の判定のみ ng-thesaurus.yaml 提案 Issue 化

WebSearch で全結果が「大陸用法のみ」「台湾サイトにヒットゼロ」のときに限り、メインエージェント(Opus)が `ng-thesaurus.yaml` 追加提案 Issue を自動起票(自動追記禁止、人間レビュー必須)。

**提案 Issue のフォーマット**:
```markdown
[v1.7.0 自動提案] ng-thesaurus.yaml に「<語>」を追加してええか?

WebSearch 結果: <3-5 件の URL>
判定: 大陸固有(台湾ドメイン 0 件)
出典(教育部辭典 URL): <URL or "未収録">
提案レベル: needs_human_review
```

きなこ承認時のみ追記。これにより N=1 連鎖を構造的に阻止しつつ、明確な大陸固有語は辞書化メリットを享受できる。

---

## ⑤ 実装位置マトリクス

| ファイル | 追記内容 | 行数増減見込み |
|---|---|---|
| `SKILL.md` Step 5.5 | native-checker-v1 起動時の入力 JSON に confidence/register 申告義務追加 | +20 行 |
| `linlaoshi-prompt.md` | judgment_logic セクション新設(confidence/register/contrast_axis 申告必須) | +40 行 |
| `v5-modular-lint.sh` PATTERN_15 拡張 | 物理ログ JSON に confidence/register/裏取り結果フィールド必須化(grep 検証) | +30 行 |
| `native-checker-v1/SKILL.md` | WebSearch 発火論理を Step 内に明文化(3 軸 OR + クエリテンプレ + 辞書化禁止) | +50 行 |
| **合計** | | **+140 行**(v1.7.0 引き算リリース +200 行以内に収まる) |

### SKILL.md Step 5.5 への追記(具体例)

```markdown
### Step 5.5: native-checker-v1 起動【v1.7.0 動的フィルタ統合】

入力 JSON に以下フィールドを必須追加:

```json
{
  "request_dynamic_filter": true,
  "confidence_threshold": 3,
  "register_trigger": ["subtle", "straddle", "unknown"],
  "contrast_axis_auto_mark": true,
  "websearch_query_template": "\"<語>\" 台灣 教育部 OR ptt OR dcard",
  "websearch_domain_filter": [".tw", ".edu.tw", "moe.gov.tw"]
}
```

出力 JSON の各 issue / prose_issue エントリに以下フィールド必須:
- `confidence`: 1-5 整数
- `register`: `spoken | written | subtle | straddle | unknown`
- `contrast_axis`: `null | mainland_vs_taiwan | japan_vs_taiwan | synonym_cluster`
- `webcheck_result`: `{queried: bool, hits: [URL], conclusion: string}` (発火時のみ)
```

### linlaoshi-prompt.md への追記(具体例)

```markdown
## judgment_logic セクション(v1.7.0 新設)

### confidence 申告ルール

各 issue / prose_issue について、以下基準で confidence(1-5)を申告:

- 5: 教育部辭典収録 + 台湾コーパス頻度高 + 大陸固有判定明確
- 4: 上記 2 つ以上満たす + 自己経験で確信
- 3: 1 つのみ満たす、または経験のみ
- 2: 経験も曖昧、議論余地あり
- 1: 不明、人間レビュー希望

**重要**: confidence 5 でも register が subtle / straddle のときは WebSearch 発火対象(自己権威化禁止)。

### register 申告ルール

各派生語に以下のいずれかを付与:
- `spoken`: 口語のみ(例: 「啦」「囉」)
- `written`: 書面語のみ(例: 「然而」「茲」)
- `subtle`: 微妙(口語 / 書面語境界、例: 「在班上」)
- `straddle`: 両方跨ぐ(コンテキスト次第、例: 「不過」)
- `unknown`: 不明

### contrast_axis 自動マーキング

派生語列挙時、以下に該当すれば必ずタグ付与:
- 大陸用語と比較される派生語(例: 「公車」←→「公交車」) → `mainland_vs_taiwan`
- 日本固有表現と比較される派生語(例: 「議會」←→「衆議院」) → `japan_vs_taiwan`
- 同義語クラスタ内の派生語(2 つ以上類義語が並ぶ) → `synonym_cluster`

タグ付与時、confidence / register に関わらず WebSearch 発火対象。
```

### v5-modular-lint.sh PATTERN_15 拡張(具体例)

```bash
# v1.7.0 — PATTERN_15 物理ログ拡張
# tmp/native-check/<issue>-pair<i>.json の必須フィールド検証

PATTERN_15_REQUIRED_FIELDS='confidence register contrast_axis'

for log_file in tmp/native-check/${ISSUE}-pair*.json; do
    [[ ! -f "$log_file" ]] && continue
    for field in $PATTERN_15_REQUIRED_FIELDS; do
        if ! jq -e ".issues[].${field}" "$log_file" > /dev/null 2>&1; then
            print_ng 15 "PATTERN_15 物理ログに ${field} フィールド欠落: ${log_file}" 1
        fi
    done

    # WebSearch 発火条件チェック(confidence ≤ 3 or register ∈ {subtle, straddle, unknown} or contrast_axis 非 null)
    FIRE_EXPECTED=$(jq '[.issues[] | select(.confidence <= 3 or (.register | IN("subtle", "straddle", "unknown")) or (.contrast_axis != null))] | length' "$log_file")
    FIRE_ACTUAL=$(jq '[.issues[] | select(.webcheck_result.queried == true)] | length' "$log_file")
    if [[ "$FIRE_EXPECTED" != "$FIRE_ACTUAL" ]]; then
        print_ng 15 "PATTERN_15 WebSearch 発火数不一致: expected=${FIRE_EXPECTED} actual=${FIRE_ACTUAL}" 1
    fi
done
```

---

## ⑥ 機能不全防止チェックリスト(v1.7.0 実装時必須)

実装エージェントが以下をすべて満たしていることを確認:

- [ ] OR トリガが AND になっていない(コード review で確認)
- [ ] 対比軸の語が無条件発火(confidence 5 でも発火する)
- [ ] WebSearch 結果が `ng-thesaurus.yaml` に追記されていない(grep で確認)
- [ ] 脚注 1 行透明化が Step 7 投稿コメントに反映されている
- [ ] 「明確に大陸固有」のみ Issue 提案、自動追記されていない
- [ ] PATTERN_15 が confidence/register/contrast_axis を物理検証している
- [ ] ドメインフィルタ未対応時のフォールバック(URL 手動フィルタ)が機能している
- [ ] 月次 WebSearch 発火数が想定範囲(200-500 回 / 月)に収まっている

---

## ⑦ 自己権威化の連鎖を切る構造的根拠

| メカニズム | どう連鎖を切るか |
|---|---|
| **辞書化禁止** | 次回も同じ語が裏取り対象になる(N=1 判定がリテラル化されない) |
| **OR トリガ** | confidence 5 でも対比軸ありなら裏取り(自己確信の素通り防止) |
| **対比軸自動マーキング** | プロンプト編集時に対比語を入れた瞬間に強制裏取り(エージェント判断不要) |
| **WebSearch ドメイン制限** | 大陸サイトの結果で台湾華語判定しない(構造的に台湾実態に寄せる) |
| **自動 Issue 提案(辞書追加)** | 人間レビュー必須(N=1 自動追記禁止) |
| **物理ログに confidence/register 必須化** | エージェントが「裏取りした風」だけで済ませられない(PATTERN_15 で機械検証) |

---

## 自己評価(設計準拠チェック)

| 観点 | 評価 |
|---|---|
| 仕様策定のみ(コード追加最小限) | ✅ 本仕様書 +500 行は v1.7.0 リリース時に SKILL.md +140 行に圧縮、tmp/ 配下は実装後削除 |
| OR トリガ(AND 禁止) | ✅ 発火条件式と機能不全防止理由を明文化 |
| 対比軸自動マーキング | ✅ 大陸 vs 台湾 / 日本 vs 台湾 / 類義差分の 3 カテゴリ定義 |
| WebSearch クエリテンプレ | ✅ `"<語>" 台灣 教育部 OR ptt OR dcard` 固定 + ドメイン制限 |
| 結果の辞書化禁止 | ✅ 脚注 1 行透明化 + 「明確に大陸固有」のみ Issue 提案経路 |
| 1 教材 WebSearch 2-5 回想定 | ✅ 発火頻度モデル明示(対比軸の語が 15-25%) |
| 実装位置マトリクス +140 行 | ✅ v1.7.0 引き算リリース +200 行以内に収まる |
| 自己権威化解消の構造的根拠 | ✅ 6 メカニズムで連鎖を切る経路明示 |
| メタ盲点 8 本対応(辞書化禁止 = メタ盲点 #3 解体) | ✅ 辞書化禁止 + 都度裏取りで N=1 連鎖を構造的に阻止 |
