---
name: native-checker-v1
description: |
  台湾華語(繁体字)の派生語・解説文のネイティブ感をチェックする Skill。
  3観点で判定:
    1. 台湾ネイティブに伝わる言い方か
    2. 大陸固有の言い回しじゃないか
    3. 日本固有表現じゃないか
  audio-lesson-v5 Skill の Step 5.5 から呼び出される、または他のチェック用途で直接起動可。
when_to_use: |
  audio-lesson-v5 Skill 内部から Step 5.5 で起動。
  または、ユーザーが「ネイティブチェック」「派生語チェック」を依頼した時。
tools_needed: [Read, Agent, Bash, Write]
---

# native-checker-v1 — 台湾華語ネイティブチェック Skill

## 概要

audio-lesson-v5 Skill が生成した Phase 3 派生語列挙 + Phase 3 解説テキストに対して、台湾華語ネイティブ視点でチェックします。

## 決定論的 6 ステップフロー(v1.6.1〜:物理ログ書出義務 + 完了マーカー追加)

### Step 0: ping エンドポイント(軽量可用性チェック)

呼出元 audio-lesson-v5 Step 5.4 から呼ばれる **超軽量** な疎通確認。
本体パイプライン(Step 1〜6)とは分離されており、判定や置換は行わない。

```
Skill({
  skill: "native-checker-v1",
  args: JSON.stringify({ "mode": "ping" })
})
```

仕様:
- **タイムアウト**: **5 秒**(超過したら即 NG 返却)
- **出力**: **1 token のみ**(`"OK"`)
- **副作用なし**: ログファイル書出さない、置換しない、Sonnet 本体呼ばない
- **動作**: Agent ツール(Sonnet)に最短プロンプトで ping を投げて応答を返す
  - 内部実装例: `Agent({ model: "sonnet", prompt: "Reply with exactly: OK", max_tokens: 5 })`
- **失敗時**: タイムアウト or エラーなら `{ "ping": "NG", "reason": "<timeout|error>" }` を返却

呼出元はこの戻り値を見て **DEPLOYED + ping OK** 確認後に Step 5.5 突入確定する(SKILL.md Step 5.4 ハードルール参照)。

---

### Step 1: 入力受信

呼び出し元(audio-lesson-v5)から以下を受け取る:

```json
{
  "mode": "check",
  "issue_number": 27,
  "pair_n": 1,
  "pair_chinese": "我們勇者一行人凱旋而歸",
  "pair_japanese": "私たち、勇者一行の凱旋です",
  "source_type": "Netflix字幕|学術書|会話文|大陸ドラマ字幕|オリジナル",
  "phase1_ssml": "<speak>...</speak>",
  "phase0_focus_words": [
    { "word": "我們", "pinyin_kana": "ウォーメン", "translation": "私たち" }
  ],
  "phase3_derived_words": [
    {
      "word": "在班上",
      "pinyin_kana": "ザイバンシャン",
      "translation": "クラスで",
      "ssml_segment": "<lang xml:lang=\"cmn-TW\">在班上</lang>(ザイバンシャン、クラスで)",
      "register": "spoken|written|neutral"
    }
  ],
  "phase3_prose": "Phase 3 解説テキスト本文(地の文)"
}
```

**必須フィールド**: `issue_number`, `pair_n`(物理ログのファイル名に使う)

### Step 2: 林老師 Sonnet サブエージェント呼び出し

Agent ツールを使用:

```
Agent({
  subagent_type: "general-purpose",
  model: "sonnet",
  description: "台湾華語ネイティブチェック",
  prompt: [林老師システムプロンプト(prompts/linlaoshi-prompt.md 全文)
           + 入力JSON文字列化したもの
           + "Output as JSON only, no prose."]
})
```

Sonnet 接続パラメータ(v1.6.1 最適化):

| パラメータ | 旧(v1.6.0) | 新(v1.6.1) |
|---|---|---|
| タイムアウト | 60秒 | **30秒** |
| リトライ間隔 | 1秒→4秒 | **0.5秒→2秒** |
| Circuit Breaker 閾値 | 連続3ペア | **連続2ペア** |

- 失敗時は Step 3 のリトライ機構に流れる
- **経過時間(elapsed_ms)を Step 2 開始時から計測開始**(Step 6 で物理ログに記録)

### Step 3: JSON パース + 構造化(失敗時の決定論的復旧)

```
パース成功:
  → Step 4 へ進む

パース失敗:
  リトライ N=2(0.5秒バックオフ → 2秒バックオフ)
  なお失敗:
    needs_changes=unknown でフォールバック
    内部メモに「林老師判定: 取得失敗」記録
    呼び出し元に「人間レビュー希望」フラグ立てて返却
    **物理ログには verdict="error" or "unknown" で書き出し義務**(Step 6 参照)

連続 2 ペア失敗(v1.6.1 で 3→2 に厳格化):
  Circuit Breaker 発動
  AskUserQuestion でユーザーに確認:
    「林老師チェック連続失敗。どうする?」
    選択肢: ① 投稿中止(問題報告のみ) ② スキップで投稿(理由を本文に明示)
  ※「リトライ」「翌日再実行」は動作未定義のため選択肢から削除

50% 以上のペアで失敗:
  投稿中止
  チャット応答で「林老師チェック軒並み失敗、ネット/API 確認して」と申告
```

### Step 4: Opus 側 sanity check

呼び出し元(Opus メイン)が以下を確認:

| チェック項目 | NG なら |
|---|---|
| 置換語 = 元単語 | 削除のみ(無理な置換しない) |
| 置換語 = 空文字 | 削除のみ |
| 置換語 = Phase 0 4語と衝突 | 削除のみ |
| 置換語 = Phase 3 他派生と重複 | 削除のみ |
| 置換語 が lint PATTERN_13 NG リストに該当 | 削除のみ |

sanity OK のものだけ置換。

### Step 5: 置換結果返却

JSON 形式で audio-lesson-v5 Skill に戻す:

```json
{
  "verdict": "approved" | "needs_changes" | "unknown",
  "applied_replacements": [
    {
      "original_word": "在班上",
      "replacement_word": "在班裡",
      "replaced_ssml": "<lang xml:lang=\"cmn-TW\">在班裡</lang>(ザイバンリ、クラスで)"
    }
  ],
  "removed_words": [],
  "prose_fixes_applied": [],
  "circuit_breaker_triggered": false,
  "fallback_mode": false,
  "internal_log": "..."
}
```

内部メモに記録:
- 林老師判定結果(approved / needs_changes / unknown)
- 修正した派生語数 / 置換例
- リトライ回数
- 失敗パターン(あれば)

### Step 6: 物理ログファイル書出(★v1.6.1 で新規追加・必須★)

#### 6.1 書出規約

**呼出ごとに必ず書き出す**(成功時も失敗時も):

| 項目 | 値 |
|---|---|
| パス | `tmp/native-check/<issue_number>-pair<pair_n>.json` |
| 例 | `tmp/native-check/27-pair1.json`、`tmp/native-check/27-pair3.json` |
| 親ディレクトリ | 存在しなければ `mkdir -p tmp/native-check/` で作成 |
| 文字エンコーディング | UTF-8 |
| 改行 | LF |

#### 6.2 JSON スキーマ

```json
{
  "uuid": "abc-123-...(呼出ごとにユニーク、UUID v4)",
  "timestamp": "2026-06-18T00:00:00Z(ISO 8601 UTC)",
  "verdict": "approved | needs_changes | unknown | error",
  "pair_n": 1,
  "elapsed_ms": 1234
}
```

各フィールドの説明:

| フィールド | 型 | 説明 |
|---|---|---|
| `uuid` | string | UUID v4(呼出ごとにユニーク。同一ペアの再実行で別 UUID 発行) |
| `timestamp` | string | ISO 8601 UTC(Z 終端、書出時点のタイムスタンプ) |
| `verdict` | enum | `approved`/`needs_changes`/`unknown`/`error` の 4 値のみ |
| `pair_n` | integer | 1 以上の整数(Issue 内のペア番号) |
| `elapsed_ms` | integer | Step 2 開始〜Step 5 完了までの経過ミリ秒 |

#### 6.3 失敗時の書出義務

**Sonnet タイムアウト / Agent ツール例外 / JSON パース失敗 等の異常終了でも必ず書き出す**:

```json
{
  "uuid": "...",
  "timestamp": "2026-06-18T00:00:00Z",
  "verdict": "error",
  "pair_n": 1,
  "elapsed_ms": 30000
}
```

理由: lint PATTERN_15 が物理ログ突合で「Step 5.5 走ったか」を判定するため、書出ゼロ = スキップとみなされる。失敗ケースでも「走った痕跡」を残す。

#### 6.4 完了マーカー(コメント本文書込)

呼出元(audio-lesson-v5)が Step 7 投稿前に **コメント本文** に書き込む HTML コメント。
本 Skill は **戻り値の `marker` フィールド** として返却(呼出元に書込位置を任せる):

```json
{
  "verdict": "approved",
  "marker": "<!-- NATIVE_CHECK_STATUS: done -->",
  ...
}
```

**マーカー仕様**:

| 状況 | マーカー文字列 |
|---|---|
| 全ペア verdict=`approved` | `<!-- NATIVE_CHECK_STATUS: done -->` |
| 全ペア verdict=`needs_changes`(置換適用済み) | `<!-- NATIVE_CHECK_STATUS: done -->` |
| 一部ペア成功 + 一部失敗(X/Y 形式) | `<!-- NATIVE_CHECK_STATUS: partial:<X>/<Y> -->` (例: `partial:5/7`) |
| Dropdown「スキップ」選択 | `<!-- NATIVE_CHECK_STATUS: skipped:user_dropdown_choice -->` |
| Step 5.4 物理可用性 NG(MISSING/ping NG) | `<!-- NATIVE_CHECK_STATUS: skipped:tool_unavailable -->` |
| Circuit Breaker → スキップで投稿選択 | `<!-- NATIVE_CHECK_STATUS: skipped:circuit_breaker -->` |

**偽陰性防止ルール(★重要★)**:

- **`verdict=approved` または `verdict=needs_changes`(置換適用済み)時のみマーカー書き込み**
- `verdict=unknown` / `verdict=error` のペアが残った状態で `done` マーカー書き込むのは禁止
  - そういう場合は `partial:<X>/<Y>` でX=成功ペア数, Y=総ペア数を明示
- マーカー書き込みは **呼出元(audio-lesson-v5 Step 7)が一括判断** する
  - 本 Skill は各ペアの戻り値に `marker_eligible: true/false` を入れて呼出元に伝える

#### 6.5 物理ログ保持期間

- `tmp/native-check/` 配下は **教材投稿完了後に手動削除可**
- ただし lint PATTERN_15 が突合する間は保持必須
- 推奨: 投稿完了 + Issue クローズ後に削除(Issue 別フォルダ運用も可)

---

## 失敗時フォールバック表(v1.6.1 改訂)

| 状況 | 対応 | 物理ログ verdict |
|---|---|---|
| Sonnet タイムアウト(30秒超) | リトライ N=2(0.5秒→2秒バックオフ) | `error`(リトライ全失敗時) |
| HTTP 5xx エラー | 同上 | `error` |
| レート制限 | 同上(さらに長めのバックオフ) | `error` |
| JSON パース失敗 | リトライ N=2、なお失敗なら `unknown` | `unknown` |
| 連続 2 ペア失敗 | Circuit Breaker + AskUserQuestion(投稿中止 or スキップ投稿) | 該当ペアまで個別書出 |
| 50% 以上失敗 | 投稿中止 + チャット応答で申告 | 該当ペアまで個別書出 |
| Agent ツール利用不可 | Skill 全体スキップ + `fallback_mode: true` 返却 | ログ書出スキップ(Step 5.4 で事前検出済み想定) |

## オフライン/ツール不可フォールバック

audio-lesson-v5 SKILL.md Step 5.4 で「Agent ツール利用可能性チェック + ping エンドポイント呼出」を実施し、利用不可なら Skill 全体スキップする想定。
ping NG なら本 Skill 呼出に進まないため、ログ書出不要。

## 林老師システムプロンプト

`prompts/linlaoshi-prompt.md` を参照。

## 境界判定例(ベンチマーク用)

`examples/boundary-cases.md` を参照。

## ベンチマーク手順

Phase 2 着手時に実施:
1. boundary-cases.md の 25 ペアを Sonnet にぶん投げ
2. ワシ(Opus)の判定と diff
3. **一致率 80% 以上**で本番投入合格
4. 不一致 20% 超なら linlaoshi-prompt.md に観点別判定例ペア集を追加して再ベンチマーク

## モデル選定

| モデル | 一致率予想 | コスト/ペア | レイテンシ |
|---|---|---|---|
| Haiku | 60-70% | ~$0.001 | <1s |
| **Sonnet**(本命) | **80-90%** | ~$0.005-0.04(実測) | 2-5s |
| Opus | 90-95% | ~$0.02 | 5-10s |

Phase 2 で 3モデル盲検比較 → 最適確定。

## コスト試算(v1.6.1 実トークンベース改訂)

旧楽観値(`~$0.005/ペア`)を撤回 → 実トークン数ベース:

| 項目 | 値 |
|---|---|
| Sonnet input | $3/M tokens |
| Sonnet output | $15/M tokens |
| 1ペア input | 約 3,500-5,500 tokens |
| 1ペア output | 100(approved) or 500-900(needs_changes) |
| **1ペアコスト** | **$0.02-0.04**(approved or needs_changes 込み) |
| 7ペア教材 | 約 $0.14-0.28 |
| 月100教材 | 約 $14-28 |

→ 許容上限 月 $10 と乖離する可能性 → **早期 return 強制適用**(PATTERN_13 ヒットゼロのペアは Sonnet 呼出スキップ、native-checker-v1 側で完結)

## Claude Max 契約整合

- Skill / Agent / Bash すべて Claude Code 環境内で動作
- 別 API キー不要
- CLAUDE.md「API キーは Google TTS 1個だけ」鉄則 OK

## 呼び出し方法

### audio-lesson-v5 Skill 内部から(本番チェック)

```
Skill({
  skill: "native-checker-v1",
  args: JSON.stringify({
    mode: "check",
    issue_number: 27,
    pair_n: 1,
    pair_chinese: "...",
    pair_japanese: "...",
    source_type: "Netflix字幕",
    phase1_ssml: "...",
    phase0_focus_words: [...],
    phase3_derived_words: [...],
    phase3_prose: "..."
  })
})
```

### audio-lesson-v5 Skill 内部から(ping のみ、Step 5.4)

```
Skill({
  skill: "native-checker-v1",
  args: JSON.stringify({ mode: "ping" })
})
```

戻り値: `{ "ping": "OK" }` or `{ "ping": "NG", "reason": "<timeout|error>" }`

### 直接起動(ユーザーが「ネイティブチェック」依頼時)

```
/native-checker-v1
```

引数なしで起動するとデモモード(boundary-cases.md の 25 ペアでベンチマーク実行)。

## 関連

- 親 Skill: audio-lesson-v5
- 設計書: tmp/v1.6.1-design/DESIGN.md
- 呼び出し元: audio-lesson-v5 SKILL.md Step 5.4(ping) / Step 5.5(check)
- 物理ログ突合先: v5-modular-lint.sh `--pre-post` モード PATTERN_15
