#!/usr/bin/env bats
# tests/lint-pattern-13.bats
#
# v1.6.0 設計書 ④ 4.5 で要件化された最低 3 ケースの bats テスト。
# PATTERN_13(既知 NG 熟語辞書)+ allowlist 機構の動作検証。
#
# 実行方法:
#   bats tmp/v1.6.0-staging/tests/lint-pattern-13.bats
#
# 必要環境:
#   - bash (BSD/GNU)
#   - awk / sed / grep / perl
#   - bats >= 1.0 (npm i -g bats / brew install bats-core)
#
# 注: bats が未インストールでも、テストファイル末尾の「フォールバック直接実行」
# セクションは `bash tmp/v1.6.0-staging/tests/lint-pattern-13.bats` で実行可能。

# ─────────── setup / teardown ───────────

setup() {
    # スクリプト & 辞書のパス解決(リポジトリルートから相対)
    STAGING_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
    LINT_SH="$STAGING_DIR/scripts/v5-modular-lint.sh"
    NG_THESAURUS="$STAGING_DIR/scripts/ng-thesaurus.yaml"

    # テスト出力色なし
    export NO_COLOR=1

    # 一時 SSML ファイル
    TMP_SSML=$(mktemp -t pattern13.XXXXXX.xml)
    TMP_ALLOWLIST=$(mktemp -t allowlist.XXXXXX.txt)
}

teardown() {
    rm -f "$TMP_SSML" "$TMP_ALLOWLIST" 2>/dev/null
}

# ─────────── ヘルパー: 標準 2 回リピート付き SSML を生成 ───────────
# Phase 1 ブロックを含む(PATTERN_14 で NG にならないため)
make_ssml_with_phrase() {
    local phrase="$1"
    cat > "$TMP_SSML" <<EOF
<speak>
<lang xml:lang="cmn-TW">${phrase}</lang>。
解説や。
ほな、もう一度聞いてみよか。<break time="800ms"/>
<lang xml:lang="cmn-TW">${phrase}</lang>。<break time="1.5s"/>
はい、もういっぺん。<break time="500ms"/>
<lang xml:lang="cmn-TW">${phrase}</lang>。
</speak>
EOF
}

# ─────────── テストケース 1: 在班上 が NG 辞書ヒット ───────────
# 設計書 ④ 4.5 要件: 「在班上 ヒット」
@test "PATTERN_13: 在班上 が NG 辞書ヒットする(allowlist 注入なし)" {
    make_ssml_with_phrase "我們在班上一起學習"

    run bash "$LINT_SH" "$TMP_SSML"

    # exit 1(NG)
    [ "$status" -eq 1 ]

    # PATTERN_13 ヒット文言が出る
    [[ "$output" == *"PATTERN_13"* ]]
    [[ "$output" == *"在班上"* ]]
    [[ "$output" == *"1 hits"* ]]
}

# ─────────── テストケース 2: 公車 はスルー(辞書外) ───────────
# 設計書 ④ 4.5 要件: 「公車 スルー」
# 公車 は台湾華語の正しい用語(大陸の 公交車 に対して)、辞書には乗ってない
@test "PATTERN_13: 公車 はスルー(辞書外、台湾華語の正しい用語)" {
    make_ssml_with_phrase "我們搭公車去學校"

    run bash "$LINT_SH" "$TMP_SSML"

    # exit 0(OK)
    [ "$status" -eq 0 ]

    # PATTERN_13 は OK 判定
    [[ "$output" == *"[11/12] PATTERN_13"* ]]
    [[ "$output" == *"PATTERN_13 既知 NG 熟語辞書(v1.6.0"*"OK"* ]]
}

# ─────────── テストケース 3a: 衆議院 allowlist 注入なしで挙動確認 ───────────
# 設計書 ④ 4.5 要件: 「衆議院 allowlist 注入時スルー / 注入なし時ヒット」
#
# 注: 衆議院 は 現行辞書には未登録。「ヒット」条件成立のため、
# テスト専用辞書を一時生成して 衆議院 を NG 辞書に含めた状態で検証する。
# これにより「学習対象として正当な固有名詞は allowlist で構造的に逃がせる」
# という機構そのものを検証できる。

@test "PATTERN_13: 衆議院 が(テスト用)辞書ヒット → allowlist 注入なしで NG" {
    # テスト用 NG 辞書(衆議院 1 語のみ)
    TEST_DICT=$(mktemp -t test-dict.XXXXXX.yaml)
    cat > "$TEST_DICT" <<'EOF'
ng_thesaurus:
  - word: "衆議院"
    category: "japanese-only"
    added_by: "test"
    added_at: "2026-06-17"
    evidence: "テスト用、本番辞書には登録しない"
    replacement_examples:
      - "立法院"
EOF

    make_ssml_with_phrase "他在衆議院演講"

    run bash "$LINT_SH" --ng-thesaurus "$TEST_DICT" "$TMP_SSML"

    [ "$status" -eq 1 ]
    [[ "$output" == *"衆議院"* ]]
    [[ "$output" == *"1 hits"* ]]

    rm -f "$TEST_DICT"
}

@test "PATTERN_13: 衆議院 を allowlist に入れると注入時スルー" {
    TEST_DICT=$(mktemp -t test-dict.XXXXXX.yaml)
    cat > "$TEST_DICT" <<'EOF'
ng_thesaurus:
  - word: "衆議院"
    category: "japanese-only"
    added_by: "test"
    added_at: "2026-06-17"
    evidence: "テスト用、本番辞書には登録しない"
    replacement_examples:
      - "立法院"
EOF

    # 衆議院 を allowlist に追加(Issue 本文 / Phase 0 サマリ表に登場するシナリオ)
    echo "衆議院" > "$TMP_ALLOWLIST"

    make_ssml_with_phrase "他在衆議院演講"

    run bash "$LINT_SH" --ng-thesaurus "$TEST_DICT" --allowlist "$TMP_ALLOWLIST" "$TMP_SSML"

    [ "$status" -eq 0 ]
    [[ "$output" == *"[11/12] PATTERN_13"* ]]
    # allowlist にカウントが入ってる旨表示
    [[ "$output" == *"allowlist 1 語"* ]]
    # ヒットしてない
    [[ "$output" != *"1 hits"* ]]

    rm -f "$TEST_DICT"
}

# ─────────── 追加: メタ文字混入辞書は exit 2(起動拒否) ───────────
@test "PATTERN_13: 辞書にメタ文字混入(\".\" 含む)→ exit 2(起動拒否)" {
    TEST_DICT=$(mktemp -t test-dict.XXXXXX.yaml)
    cat > "$TEST_DICT" <<'EOF'
ng_thesaurus:
  - word: "在班.上"
    category: "taiwanese-unnatural"
EOF
    make_ssml_with_phrase "我們搭公車去學校"

    run bash "$LINT_SH" --ng-thesaurus "$TEST_DICT" "$TMP_SSML"

    [ "$status" -eq 2 ]
    [[ "$output" == *"メタ文字検出"* ]]

    rm -f "$TEST_DICT"
}

# ─────────── 追加: PATTERN_14 リピート 2 回ジャストの正常系 ───────────
@test "PATTERN_14: Phase 1 リピート 2 回ジャスト → OK" {
    make_ssml_with_phrase "我們搭公車去學校"

    run bash "$LINT_SH" "$TMP_SSML"

    [ "$status" -eq 0 ]
    [[ "$output" == *"[12/12] PATTERN_14"* ]]
    [[ "$output" == *"PATTERN_14 Phase 1 リピート 2 回検証(v1.6.0"*"OK"* ]]
}

# ─────────── 追加: PATTERN_14 リピート 1 回しかない → NG ───────────
@test "PATTERN_14: リピート 1 回(v1.5.x 仕様)→ NG" {
    cat > "$TMP_SSML" <<'EOF'
<speak>
<lang xml:lang="cmn-TW">我們搭公車去學校</lang>。
ほな、もう一度聞いてみよか。<break time="800ms"/>
<lang xml:lang="cmn-TW">我們搭公車去學校</lang>。
</speak>
EOF

    run bash "$LINT_SH" "$TMP_SSML"

    [ "$status" -eq 1 ]
    [[ "$output" == *"PATTERN_14"* ]]
    [[ "$output" == *"1 回(2 回必須)"* ]]
}

# ─────────── 追加: --llm-unavailable モードで注記出力 ───────────
@test "v1.6.0: --llm-unavailable で末尾に未実施旨を明示" {
    make_ssml_with_phrase "我們搭公車去學校"

    run bash "$LINT_SH" --llm-unavailable "$TMP_SSML"

    [ "$status" -eq 0 ]
    [[ "$output" == *"--llm-unavailable"* ]]
    [[ "$output" == *"林老師チェック未実施"* ]]
}
