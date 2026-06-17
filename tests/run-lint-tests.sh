#!/usr/bin/env bash
# tests/run-lint-tests.sh
#
# bats が無い環境で lint-pattern-13.bats と同じテストケースを手動実行する
# フォールバックランナー。CI / 開発ローカルで bats を入れる前に動作確認したい
# 場合に使う。
#
# 終了コード: 0=全 PASS / 1=1 個以上 FAIL

set -uo pipefail

STAGING_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LINT_SH="$STAGING_DIR/scripts/v5-modular-lint.sh"
NG_THESAURUS="$STAGING_DIR/scripts/ng-thesaurus.yaml"

export NO_COLOR=1

PASS=0
FAIL=0
FAILED_TESTS=()

run_test() {
    local name="$1"
    local result="$2"
    if [[ "$result" == "PASS" ]]; then
        printf "  \033[32m✅ PASS\033[0m  %s\n" "$name"
        PASS=$((PASS + 1))
    else
        printf "  \033[31m❌ FAIL\033[0m  %s\n" "$name"
        FAIL=$((FAIL + 1))
        FAILED_TESTS+=("$name")
    fi
}

make_ssml() {
    local file="$1"
    local phrase="$2"
    cat > "$file" <<EOF
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

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "PATTERN_13 / PATTERN_14 / allowlist テストランナー"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# ───── テスト 1: 在班上 ヒット ─────
SSML=$(mktemp -t t1.XXXXXX.xml)
make_ssml "$SSML" "我們在班上一起學習"
OUT=$(bash "$LINT_SH" "$SSML" 2>&1)
RC=$?
if [[ $RC -eq 1 ]] && [[ "$OUT" == *"PATTERN_13"* ]] && [[ "$OUT" == *"在班上"* ]]; then
    run_test "在班上 が NG 辞書ヒット(allowlist 注入なし)" PASS
else
    run_test "在班上 が NG 辞書ヒット(allowlist 注入なし) [rc=$RC]" FAIL
fi
rm -f "$SSML"

# ───── テスト 2: 公車 スルー ─────
SSML=$(mktemp -t t2.XXXXXX.xml)
make_ssml "$SSML" "我們搭公車去學校"
OUT=$(bash "$LINT_SH" "$SSML" 2>&1)
RC=$?
if [[ $RC -eq 0 ]] && [[ "$OUT" == *"[11/12] PATTERN_13"* ]] && [[ "$OUT" != *"1 hits"* ]]; then
    run_test "公車 はスルー(辞書外、台湾華語の正しい用語)" PASS
else
    run_test "公車 はスルー [rc=$RC]" FAIL
fi
rm -f "$SSML"

# ───── テスト 3a: 衆議院 注入なしで NG ─────
TEST_DICT=$(mktemp -t d.XXXXXX.yaml)
cat > "$TEST_DICT" <<'EOF'
ng_thesaurus:
  - word: "衆議院"
    category: "japanese-only"
    added_by: "test"
    added_at: "2026-06-17"
    evidence: "テスト用"
    replacement_examples:
      - "立法院"
EOF
SSML=$(mktemp -t t3a.XXXXXX.xml)
make_ssml "$SSML" "他在衆議院演講"
OUT=$(bash "$LINT_SH" --ng-thesaurus "$TEST_DICT" "$SSML" 2>&1)
RC=$?
if [[ $RC -eq 1 ]] && [[ "$OUT" == *"衆議院"* ]] && [[ "$OUT" == *"1 hits"* ]]; then
    run_test "衆議院 が(テスト辞書)ヒット → allowlist 注入なしで NG" PASS
else
    run_test "衆議院 注入なし NG [rc=$RC]" FAIL
fi
rm -f "$SSML"

# ───── テスト 3b: 衆議院 allowlist 注入時スルー ─────
SSML=$(mktemp -t t3b.XXXXXX.xml)
ALLOW=$(mktemp -t allow.XXXXXX.txt)
echo "衆議院" > "$ALLOW"
make_ssml "$SSML" "他在衆議院演講"
OUT=$(bash "$LINT_SH" --ng-thesaurus "$TEST_DICT" --allowlist "$ALLOW" "$SSML" 2>&1)
RC=$?
if [[ $RC -eq 0 ]] && [[ "$OUT" == *"allowlist 1 語"* ]] && [[ "$OUT" != *"1 hits"* ]]; then
    run_test "衆議院 allowlist 注入時スルー" PASS
else
    run_test "衆議院 allowlist 注入時スルー [rc=$RC]" FAIL
fi
rm -f "$SSML" "$ALLOW" "$TEST_DICT"

# ───── テスト 4: メタ文字混入辞書 → exit 2 ─────
TEST_DICT=$(mktemp -t d.XXXXXX.yaml)
cat > "$TEST_DICT" <<'EOF'
ng_thesaurus:
  - word: "在班.上"
    category: "taiwanese-unnatural"
EOF
SSML=$(mktemp -t t4.XXXXXX.xml)
make_ssml "$SSML" "我們搭公車去學校"
OUT=$(bash "$LINT_SH" --ng-thesaurus "$TEST_DICT" "$SSML" 2>&1)
RC=$?
if [[ $RC -eq 2 ]] && [[ "$OUT" == *"メタ文字検出"* ]]; then
    run_test "辞書メタ文字混入(\".\")→ exit 2(起動拒否)" PASS
else
    run_test "辞書メタ文字混入 → exit 2 [rc=$RC]" FAIL
fi
rm -f "$SSML" "$TEST_DICT"

# ───── テスト 5: PATTERN_14 リピート 2 回 → OK ─────
SSML=$(mktemp -t t5.XXXXXX.xml)
make_ssml "$SSML" "我們搭公車去學校"
OUT=$(bash "$LINT_SH" "$SSML" 2>&1)
RC=$?
if [[ $RC -eq 0 ]] && [[ "$OUT" == *"PATTERN_14 Phase 1 リピート 2 回検証"* ]] && [[ "$OUT" == *"OK"* ]]; then
    run_test "PATTERN_14: リピート 2 回ジャスト → OK" PASS
else
    run_test "PATTERN_14: リピート 2 回ジャスト → OK [rc=$RC]" FAIL
fi
rm -f "$SSML"

# ───── テスト 6: PATTERN_14 リピート 1 回 → NG ─────
SSML=$(mktemp -t t6.XXXXXX.xml)
cat > "$SSML" <<'EOF'
<speak>
<lang xml:lang="cmn-TW">我們搭公車去學校</lang>。
ほな、もう一度聞いてみよか。<break time="800ms"/>
<lang xml:lang="cmn-TW">我們搭公車去學校</lang>。
</speak>
EOF
OUT=$(bash "$LINT_SH" "$SSML" 2>&1)
RC=$?
if [[ $RC -eq 1 ]] && [[ "$OUT" == *"PATTERN_14"* ]] && [[ "$OUT" == *"1 回(2 回必須)"* ]]; then
    run_test "PATTERN_14: リピート 1 回(v1.5.x 仕様)→ NG" PASS
else
    run_test "PATTERN_14: リピート 1 回 → NG [rc=$RC]" FAIL
fi
rm -f "$SSML"

# ───── テスト 7: --llm-unavailable 注記 ─────
SSML=$(mktemp -t t7.XXXXXX.xml)
make_ssml "$SSML" "我們搭公車去學校"
OUT=$(bash "$LINT_SH" --llm-unavailable "$SSML" 2>&1)
RC=$?
if [[ $RC -eq 0 ]] && [[ "$OUT" == *"--llm-unavailable"* ]] && [[ "$OUT" == *"林老師チェック未実施"* ]]; then
    run_test "--llm-unavailable で末尾に未実施旨を明示" PASS
else
    run_test "--llm-unavailable 注記 [rc=$RC]" FAIL
fi
rm -f "$SSML"

# ───── サマリ ─────
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
TOTAL=$((PASS + FAIL))
printf "結果: \033[32m%d PASS\033[0m / \033[31m%d FAIL\033[0m / %d TOTAL\n" "$PASS" "$FAIL" "$TOTAL"

if [[ $FAIL -gt 0 ]]; then
    echo ""
    echo "FAIL したテスト:"
    for t in "${FAILED_TESTS[@]}"; do
        echo "  - $t"
    done
    exit 1
fi
exit 0
