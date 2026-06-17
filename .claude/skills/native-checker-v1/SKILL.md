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
tools_needed: [Read, Agent, Bash]
---

# native-checker-v1 — 台湾華語ネイティブチェック Skill

## 概要

audio-lesson-v5 Skill が生成した Phase 3 派生語列挙 + Phase 3 解説テキストに対して、台湾華語ネイティブ視点でチェックします。

## 決定論的 5 ステップフロー

### Step 1: 入力受信

呼び出し元(audio-lesson-v5)から以下を受け取る:

```json
{
  "pair_chinese": "我們勇者一行人凱旋而歸",
  "pair_japanese": "私たち、勇者一行の凱旋です",
  "source_type": "Netflix字幕|学術書|会話文|大陸ドラマ字幕|オリジナル",
  "phase1_ssml": "<speak>...</speak>",
  "phase0_focus_words": [
    { "word": "我們", "pinyin_kana": "ウォーメン", "translation": "私たち" },
    ...
  ],
  "phase3_derived_words": [
    {
      "word": "在班上",
      "pinyin_kana": "ザイバンシャン",
      "translation": "クラスで",
      "ssml_segment": "<lang xml:lang=\"cmn-TW\">在班上</lang>(ザイバンシャン、クラスで)",
      "register": "spoken|written|neutral"
    },
    ...
  ],
  "phase3_prose": "Phase 3 解説テキスト本文(地の文)"
}
```

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

- 失敗時は Step 3 のリトライ機構に流れる

### Step 3: JSON パース + 構造化(失敗時の決定論的復旧)

```
パース成功:
  → Step 4 へ進む

パース失敗:
  リトライ N=2(1秒バックオフ → 4秒バックオフ)
  なお失敗:
    needs_changes=unknown でフォールバック
    内部メモに「林老師判定: 取得失敗」記録
    呼び出し元に「人間レビュー希望」フラグ立てて返却

連続 3 ペア失敗:
  Circuit Breaker 発動
  AskUserQuestion でユーザーに確認:
    「林老師チェック連続失敗。どうする?」
    選択肢: ① リトライ ② lint のみで投稿 ③ 翌日再実行

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

## 失敗時フォールバック表

| 状況 | 対応 |
|---|---|
| Sonnet タイムアウト(60秒超) | リトライ N=2(1秒→4秒バックオフ) |
| HTTP 5xx エラー | 同上 |
| レート制限 | 同上(さらに長めのバックオフ) |
| JSON パース失敗 | リトライ N=2、なお失敗なら needs_changes=unknown |
| 連続 3 ペア失敗 | Circuit Breaker + AskUserQuestion |
| 50% 以上失敗 | 投稿中止 + チャット応答で申告 |
| Agent ツール利用不可 | Skill 全体スキップ + 呼び出し元に "fallback_mode": true 返却 |

## オフライン/ツール不可フォールバック

audio-lesson-v5 SKILL.md Step 5.4 で「Agent ツール利用可能性チェック」を実施し、利用不可なら Skill 全体スキップする想定。

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
| **Sonnet**(本命) | **80-90%** | ~$0.005 | 2-5s |
| Opus | 90-95% | ~$0.02 | 5-10s |

Phase 2 で 3モデル盲検比較 → 最適確定。

## コスト試算

| 月教材数 | Sonnet コスト |
|---|---|
| 10教材 | ~$0.5 |
| 30教材 | ~$1.5 |
| 100教材 | ~$5 |

許容上限: **月 $10**(超えたら警告)

## Claude Max 契約整合

- Skill / Agent / Bash すべて Claude Code 環境内で動作
- 別 API キー不要
- CLAUDE.md「API キーは Google TTS 1個だけ」鉄則 OK

## 呼び出し方法

### audio-lesson-v5 Skill 内部から

```
Skill({
  skill: "native-checker-v1",
  args: JSON.stringify({
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

### 直接起動(ユーザーが「ネイティブチェック」依頼時)

```
/native-checker-v1
```

引数なしで起動するとデモモード(boundary-cases.md の 25 ペアでベンチマーク実行)。

## 関連

- 親 Skill: audio-lesson-v5
- 設計書: tmp/v1.6.0-design/DESIGN.md
- 呼び出し元: audio-lesson-v5 SKILL.md Step 5.5
