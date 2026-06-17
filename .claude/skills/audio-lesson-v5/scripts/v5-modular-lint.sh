#!/usr/bin/env bash
# v5-modular-lint.sh — SSML モジュール式教材 投稿前チェッカー
#
# 設計書: tmp/v1.6.0-design/DESIGN.md ④(v1.6.0 改修)/ tmp/v1.5.1-design/DESIGN.md ①(v1.5.1)
# 用途: 各モジュール生成直後に走らせ、鬼門ワード/単独漢字/二度読み等の
#       NG パターンを 1 秒以内に検出する。
# 終了コード:
#   0 = ヒットゼロ(OK、次モジュールへ進んでよい)
#   1 = ヒットあり(NG、該当モジュール再生成必須)
#   2 = 引数エラー / 内部エラー(辞書バリデーション失敗含む)
#
# 使い方:
#   bash scripts/v5-modular-lint.sh <ファイルパス>
#   bash scripts/v5-modular-lint.sh --strict <ファイルパス>           # パターン11-12 + PATTERN_6C
#   bash scripts/v5-modular-lint.sh --allowlist <list-file> <file>     # PATTERN_13 用語スルーリスト
#   bash scripts/v5-modular-lint.sh --llm-unavailable <file>           # native-checker 未実施明示
#
# v1.6.0 改修(本ファイル):
#   - PATTERN_13 追加: 既知 NG 熟語辞書(YAML、上限 100 語、メタ文字禁止)
#       * grep -F でリテラルマッチ(正規表現メタ文字を内蔵せず安全)
#       * `--allowlist <file>` で Issue 本文 / Phase 0 サマリ表の語を構造的スルー
#       * 「衆議院」「博多」のような学習対象固有名詞は allowlist で弾く
#   - PATTERN_14 追加: Phase 1 末尾リピート 2 回検証
#       * Phase 1 ブロック末尾の break 以降に <lang xml:lang="cmn-TW"> が
#         ジャスト 2 回出現してるかチェック(v1.5.x 1 回 → v1.6.0 2 回戻し)
#   - `--llm-unavailable` モード: native-checker-v1 Skill 未起動時用
#       * 終了サマリに「LLM ネイティブチェック未実施」を明示
#
# v1.5.1 改修(継承):
#   - PATTERN_6B 追加: 「文法ポイント、見ていくで」逃げ表現検出
#                      (ホワイトリスト方式: 「N つ」明示があれば素通し)
#   - PATTERN_6C 追加(--strict のみ): Phase 4 限定スコープで
#                      「短文(例文 ≦9 codepoint)+ 3点固定(ひと/ふた/みっつ目)」検出
#
# 依存: bash / awk / sed / grep / perl(BSD/GNU 両対応) のみ。
#       UTF-8 範囲表現は BSD grep が対応してないので awk を使う。

set -uo pipefail

# ───────────────────────── ロケール統一 ─────────────────────────
# UTF-8 範囲(`[一-鿿]` 等)を awk が正しくパースするためロケールを固定。
# macOS BSD / Linux GNU 両環境で動作させる。
if [[ -z "${LC_ALL:-}" ]]; then
    # 注: `locale -a | grep -qx` は pipefail 下で grep が早期 exit すると
    # SIGPIPE(141) が拾われて if が常に false になる。一時ファイル経由で回避。
    _locales_tmp=$(mktemp -t v5lint-locales.XXXXXX 2>/dev/null) || _locales_tmp=""
    if [[ -n "$_locales_tmp" ]]; then
        locale -a > "$_locales_tmp" 2>/dev/null || true
        if grep -qx 'ja_JP.UTF-8' "$_locales_tmp" 2>/dev/null; then
            export LC_ALL=ja_JP.UTF-8
        elif grep -qx 'en_US.UTF-8' "$_locales_tmp" 2>/dev/null; then
            export LC_ALL=en_US.UTF-8
        elif grep -qx 'C.UTF-8' "$_locales_tmp" 2>/dev/null; then
            export LC_ALL=C.UTF-8
        else
            export LC_ALL=ja_JP.UTF-8
        fi
        rm -f "$_locales_tmp" 2>/dev/null
    else
        export LC_ALL=ja_JP.UTF-8
    fi
    unset _locales_tmp
fi

# ───────────────────────── カラー定義 ─────────────────────────
if [[ -t 1 ]] && [[ "${NO_COLOR:-}" == "" ]]; then
    GREEN=$'\033[32m'
    RED=$'\033[31m'
    YELLOW=$'\033[33m'
    BOLD=$'\033[1m'
    DIM=$'\033[2m'
    RESET=$'\033[0m'
else
    GREEN=""
    RED=""
    YELLOW=""
    BOLD=""
    DIM=""
    RESET=""
fi

# ───────────────────────── 引数パース ─────────────────────────
STRICT=0
ALLOWLIST_FILE=""
LLM_UNAVAILABLE=0
NG_THESAURUS_FILE=""
FILE=""
i=1
args=("$@")
while [[ $i -le ${#args[@]} ]]; do
    arg="${args[$((i-1))]}"
    case "$arg" in
        --strict)
            STRICT=1
            ;;
        --allowlist)
            i=$((i+1))
            ALLOWLIST_FILE="${args[$((i-1))]:-}"
            if [[ -z "$ALLOWLIST_FILE" ]] || [[ "$ALLOWLIST_FILE" == --* ]]; then
                echo "${RED}ERROR: --allowlist の直後にファイルパスを指定してな${RESET}" >&2
                exit 2
            fi
            ;;
        --ng-thesaurus)
            i=$((i+1))
            NG_THESAURUS_FILE="${args[$((i-1))]:-}"
            if [[ -z "$NG_THESAURUS_FILE" ]] || [[ "$NG_THESAURUS_FILE" == --* ]]; then
                echo "${RED}ERROR: --ng-thesaurus の直後にファイルパスを指定してな${RESET}" >&2
                exit 2
            fi
            ;;
        --llm-unavailable)
            LLM_UNAVAILABLE=1
            ;;
        -h|--help)
            cat <<'EOF'
Usage: v5-modular-lint.sh [--strict] [--allowlist <file>] [--ng-thesaurus <file>] [--llm-unavailable] <file>

  --strict          パターン11(Phase 0↔Phase 2/3 不一致照合)・
                    パターン12(効果音マーカー網羅)・
                    パターン6C(短文+3点固定 Phase 4 限定)を実行

  --allowlist <f>   PATTERN_13 用語スルーリスト(1 行 1 単語)
                    Issue 本文 / Phase 0 サマリ表に登場する語を自動 allowlist 化
                    例: 衆議院 / 博多 / 元(げん) などの学習対象固有名詞

  --ng-thesaurus <f>
                    PATTERN_13 NG 熟語辞書 YAML パス指定(省略時はデフォルト)
                    デフォルト探索順:
                      1. <スクリプト同階層>/ng-thesaurus.yaml
                      2. .claude/skills/audio-lesson-v5/scripts/ng-thesaurus.yaml

  --llm-unavailable native-checker-v1 Skill が起動できなかった場合のモード
                    終了サマリに「LLM ネイティブチェック未実施」を明示
                    既知 NG 熟語辞書(PATTERN_13)のみで基本品質確保

  デフォルト 12 / --strict 15:
    [1]  鬼門ワード(ルールE)
    [2]  単独漢字裸出し(ルールA)
    [3]  二度読み禁止(ルールC)
    [4]  繋辞NG(v4 #3)
    [5]  Markdown 強調(v4 #10)
    [6]  文法ポイント固定文化(動的化)
    [6B] 文法ポイント逃げ表現(v1.5.1 ホワイトリスト方式)
    [7]  部首名混入(構成解説禁止 v1.5.0)
    [8]  構成位置混入(構成解説禁止 v1.5.0)
    [9]  印象表現混入(字形描写禁止 v1.5.0)
    [10] 古字部品 <sub alias> 引用(v1.5.0)
    [11] Phase 0↔Phase 2/3 照合(--strict のみ)
    [12] 効果音マーカー網羅(--strict のみ)
    [13] ★v1.6.0★ 既知 NG 熟語辞書(リテラル YAML、allowlist 注入対応)
    [14] ★v1.6.0★ Phase 1 末尾リピート 2 回検証
    [6C] ★v1.5.1★ 短文+3点固定 Phase 4 限定(--strict のみ)

終了コード: 0=OK, 1=NG, 2=エラー(辞書バリデーション失敗含む)
EOF
            exit 0
            ;;
        --)
            ;;
        *)
            FILE="$arg"
            ;;
    esac
    i=$((i+1))
done

if [[ -z "$FILE" ]]; then
    echo "${RED}ERROR: チェック対象ファイルを指定してな${RESET}" >&2
    echo "Usage: $0 [--strict] [--allowlist <f>] [--ng-thesaurus <f>] [--llm-unavailable] <file>" >&2
    exit 2
fi

if [[ ! -f "$FILE" ]]; then
    echo "${RED}ERROR: ファイルが見つからん: $FILE${RESET}" >&2
    exit 2
fi

if [[ -n "$ALLOWLIST_FILE" ]] && [[ ! -f "$ALLOWLIST_FILE" ]]; then
    echo "${RED}ERROR: allowlist ファイルが見つからん: $ALLOWLIST_FILE${RESET}" >&2
    exit 2
fi

# ───────────────────────── NG 辞書探索 ─────────────────────────
# PATTERN_13 用辞書 YAML を探す
# 1. --ng-thesaurus 明示指定 > 2. スクリプト同階層 > 3. v5-modular skill 配下
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [[ -z "$NG_THESAURUS_FILE" ]]; then
    if [[ -f "$SCRIPT_DIR/ng-thesaurus.yaml" ]]; then
        NG_THESAURUS_FILE="$SCRIPT_DIR/ng-thesaurus.yaml"
    elif [[ -f ".claude/skills/audio-lesson-v5/scripts/ng-thesaurus.yaml" ]]; then
        NG_THESAURUS_FILE=".claude/skills/audio-lesson-v5/scripts/ng-thesaurus.yaml"
    fi
fi

# ───────────────────────── 集計用 ─────────────────────────
# v1.6.0: PATTERN_13(NG 辞書) + PATTERN_14(Phase 1 リピート 2 回) 追加
# → デフォルト 12、--strict 15
NG_COUNT=0
TOTAL_CHECKS=12
[[ $STRICT -eq 1 ]] && TOTAL_CHECKS=15

# 一時ファイル(<lang>剥がし版、コードフェンス潰し版、xml抽出版、メタ領域版、辞書語抽出版)
TMP_NOLANG=$(mktemp -t v5lint.XXXXXX) || { echo "mktemp 失敗" >&2; exit 2; }
TMP_NOFENCE=$(mktemp -t v5lint.XXXXXX) || { echo "mktemp 失敗" >&2; exit 2; }
TMP_XML_ONLY=$(mktemp -t v5lint.XXXXXX) || { echo "mktemp 失敗" >&2; exit 2; }
TMP_META=$(mktemp -t v5lint.XXXXXX) || { echo "mktemp 失敗" >&2; exit 2; }
TMP_NG_WORDS=$(mktemp -t v5lint.XXXXXX) || { echo "mktemp 失敗" >&2; exit 2; }
TMP_ALLOWLIST=$(mktemp -t v5lint.XXXXXX) || { echo "mktemp 失敗" >&2; exit 2; }
trap 'rm -f "$TMP_NOLANG" "$TMP_NOFENCE" "$TMP_XML_ONLY" "$TMP_META" "$TMP_NG_WORDS" "$TMP_ALLOWLIST" 2>/dev/null' EXIT

# .md ファイルなら ```xml ... ``` ブロックだけ抽出して $FILE を差し替え。
IS_MD_FILE=0
ORIG_FILE="$FILE"
EXT="${FILE##*.}"
if [[ "$EXT" == "md" ]]; then
    IS_MD_FILE=1
    awk '/^```xml/{flag=1; next} /^```$/{flag=0; next} flag' "$FILE" > "$TMP_XML_ONLY"
    awk '
        /^```xml/{flag=1; next}
        /^```$/{if(flag){flag=0; next}}
        !flag{print}
    ' "$FILE" > "$TMP_META"
    if [[ -s "$TMP_XML_ONLY" ]]; then
        printf "%s(.md ファイル: \`\`\`xml ブロックのみ検証 + メタ領域は画字追加検査)%s\n" "$DIM" "$RESET"
        FILE="$TMP_XML_ONLY"
    fi
fi

# <lang xml:lang="...">...</lang> と <sub alias="...">...</sub> を空文字に置換した版
sed -E -e 's#<lang[^>]*>[^<]*</lang>##g' -e 's#<sub[^>]*>[^<]*</sub>##g' "$FILE" > "$TMP_NOLANG"
# Markdown コードフェンス(```...```)行を空行化した版
sed -E 's/^```.*$//' "$FILE" > "$TMP_NOFENCE"

# ───────────────────────── ヘルパー ─────────────────────────
print_ok() {
    printf "%s✅ [%s/%d] %s: OK%s\n" "$GREEN" "$1" "$TOTAL_CHECKS" "$2" "$RESET"
}
print_ng() {
    printf "%s❌ [%s/%d] %s: %d hits%s\n" "$RED" "$1" "$TOTAL_CHECKS" "$2" "$3" "$RESET"
    NG_COUNT=$((NG_COUNT + 1))
}
print_warn() {
    printf "%s⚠️  [%s/%d] %s: %s%s\n" "$YELLOW" "$1" "$TOTAL_CHECKS" "$2" "$3" "$RESET"
}
awk_count() {
    local file="$1"
    local pattern="$2"
    awk -v pat="$pattern" 'BEGIN{c=0} $0 ~ pat {c++} END{print c+0}' "$file" 2>/dev/null
}
awk_show() {
    local file="$1"
    local pattern="$2"
    awk -v pat="$pattern" -v dim="$DIM" -v rst="$RESET" '
        $0 ~ pat {
            line = $0
            if (length(line) > 120) {
                line = substr(line, 1, 120) "..."
            }
            printf "%s   L%d: %s%s\n", dim, NR, line, rst
        }
    ' "$file"
}

# ───────────────────────── ヘッダ ─────────────────────────
printf "%s━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━%s\n" "$BOLD" "$RESET"
printf "%sv5-modular-lint%s — %s\n" "$BOLD" "$RESET" "$FILE"
[[ $LLM_UNAVAILABLE -eq 1 ]] && printf "%s(--llm-unavailable: native-checker Skill 未起動モード)%s\n" "$YELLOW" "$RESET"
[[ -n "$NG_THESAURUS_FILE" ]] && printf "%sNG 辞書: %s%s\n" "$DIM" "$NG_THESAURUS_FILE" "$RESET"
[[ -n "$ALLOWLIST_FILE" ]] && printf "%sallowlist: %s%s\n" "$DIM" "$ALLOWLIST_FILE" "$RESET"
printf "%s━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━%s\n" "$BOLD" "$RESET"

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# [1/N] 鬼門ワード(ルールE) — v1.5.x 継承
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
PATTERN_1='画|字義|然り而して|豈|几|疋|画数|画が多い|[0-9]+画|点が[0-9]+個'
HITS_1=$(awk_count "$TMP_NOLANG" "$PATTERN_1")
if [[ "$HITS_1" -eq 0 ]]; then
    print_ok 1 "鬼門ワード(ルールE)"
else
    print_ng 1 "鬼門ワード(ルールE)" "$HITS_1"
    awk_show "$TMP_NOLANG" "$PATTERN_1"
fi

if [[ $IS_MD_FILE -eq 1 ]] && [[ -s "$TMP_META" ]]; then
    PATTERN_1_META='[0-9一二三四五六七八九十百千]+画|画数|画が多い|二画|三画|四画|五画|六画|七画|八画|九画|十画|十一画|十二画|十三画|十四画|十五画|十六画|十七画|十八画|十九画|二十画'
    HITS_1_META=$(awk_count "$TMP_META" "$PATTERN_1_META")
    if [[ "$HITS_1_META" -eq 0 ]]; then
        printf "%s   ✓ .md メタ領域(lint テーブル本文/ドキュメント部分)に画字混入なし%s\n" "$DIM" "$RESET"
    else
        printf "%s❌ [1/%d] 鬼門ワード(ルールE) .md メタ報告領域に画混入: %d hits%s\n" \
            "$RED" "$TOTAL_CHECKS" "$HITS_1_META" "$RESET"
        printf "%s   ↑ lint テーブル本文/ドキュメント部分に画字検出。'メタ報告だから画使ってもいい' は禁止%s\n" \
            "$YELLOW" "$RESET"
        awk_show "$TMP_META" "$PATTERN_1_META"
        if [[ "$HITS_1" -eq 0 ]]; then
            NG_COUNT=$((NG_COUNT + 1))
        fi
    fi
fi

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# [2/N] 単独漢字裸出し(ルールA)
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
perl_check_pattern2() {
    local file="$1"
    local mode="$2"
    LINT_MODE="$mode" LINT_DIM="$DIM" LINT_RESET="$RESET" \
    perl -CSAD -ne '
        BEGIN {
            $count = 0;
            $dim   = $ENV{LINT_DIM}   || "";
            $rst   = $ENV{LINT_RESET} || "";
            $mode  = $ENV{LINT_MODE}  || "count";
        }
        my $hit = 0;
        if (/\x{300c}[\x{4e00}-\x{9fff}\x{3005}]\x{300d}/
            || />[\x{4e00}-\x{9fff}\x{3005}]</) {
            $count++;
            $hit = 1;
        }
        if ($mode eq "show" && $hit) {
            chomp(my $disp = $_);
            if (length($disp) > 120) { $disp = substr($disp, 0, 120) . "..."; }
            printf "%s   L%d: %s%s\n", $dim, $., $disp, $rst;
        }
        END { print $count, "\n" if $mode eq "count"; }
    ' "$file"
}
HITS_2=$(perl_check_pattern2 "$TMP_NOLANG" count)
HITS_2=$(printf '%s' "$HITS_2" | tr -d '[:space:]')
[[ -z "$HITS_2" ]] && HITS_2=0
if [[ "$HITS_2" -eq 0 ]]; then
    print_ok 2 "単独漢字裸出し(ルールA)"
else
    print_ng 2 "単独漢字裸出し(ルールA)" "$HITS_2"
    perl_check_pattern2 "$TMP_NOLANG" show
fi

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# [3/N] 二度読み禁止(ルールC)
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
PATTERN_3='「[一-鿿々]+」（[ぁ-ん]+）|「[一-鿿々]+」\\([ぁ-ん]+\\)'
HITS_3=$(awk_count "$FILE" "$PATTERN_3")
if [[ "$HITS_3" -eq 0 ]]; then
    print_ok 3 "二度読み禁止(ルールC)"
else
    print_ng 3 "二度読み禁止(ルールC)" "$HITS_3"
    awk_show "$FILE" "$PATTERN_3"
fi

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# [4/N] 繋辞NG(v4 #3)
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
PATTERN_4='</lang>です|</lang>だ。'
HITS_4=$(awk_count "$FILE" "$PATTERN_4")
if [[ "$HITS_4" -eq 0 ]]; then
    print_ok 4 "繋辞NG(v4 #3)"
else
    print_ng 4 "繋辞NG(v4 #3)" "$HITS_4"
    awk_show "$FILE" "$PATTERN_4"
fi

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# [5/N] Markdown 強調記号(v4 #10)
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
PATTERN_5='\\*\\*|__|`'
HITS_5=$(awk_count "$TMP_NOFENCE" "$PATTERN_5")
if [[ "$HITS_5" -eq 0 ]]; then
    print_ok 5 "Markdown強調記号(v4 #10)"
else
    print_ng 5 "Markdown強調記号(v4 #10)" "$HITS_5"
    awk_show "$TMP_NOFENCE" "$PATTERN_5"
fi

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# [6/N] 文法ポイント固定文化警告
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
PATTERN_6='文法ポイント.{0,12}(三|３|3|參)つ|ポイント(は|を).{0,5}(三|３|3)つ'
HITS_6=$(awk_count "$FILE" "$PATTERN_6")
if [[ "$HITS_6" -eq 0 ]]; then
    print_ok 6 "文法ポイント固定文化(Phase 4 動的化)"
else
    print_ng 6 "文法ポイント固定文化(Phase 4 動的化)" "$HITS_6"
    awk_show "$FILE" "$PATTERN_6"
    printf "%s   ↑ 本当に 3 ポイントあるか確認。短文ペアなら 2 つに減らす、" "$YELLOW"
    printf "または「ポイントを見ていくで」に動的化を検討%s\n" "$RESET"
fi

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# [6B/N] v1.5.1 文法ポイント逃げ表現(ホワイトリスト方式)
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
PATTERN_6B_WHITELIST='文法ポイント.{0,15}(一|二|三|四|五|1|2|3|4|5|N|ひと|ふた|みっ|よっ|いつ|N|n)つ'
PATTERN_6B='(文法ポイント|文法の(ポイント|見どころ|要点|勘所))(、|,|を)?.{0,5}(見ていく|紹介する|解説する|扱う|取り上げる|確認する|チェックする|押さえる|拾う|追う|探る)(で|わ|な|よ)?'

awk_count_phase4b() {
    awk -v wl="$PATTERN_6B_WHITELIST" -v pat="$PATTERN_6B" '
        BEGIN { c=0 }
        $0 ~ wl { next }
        $0 ~ pat { c++ }
        END { print c+0 }
    ' "$1"
}
awk_show_phase4b() {
    awk -v wl="$PATTERN_6B_WHITELIST" -v pat="$PATTERN_6B" -v dim="$DIM" -v rst="$RESET" '
        $0 ~ wl { next }
        $0 ~ pat {
            line = $0
            if (length(line) > 120) {
                line = substr(line, 1, 120) "..."
            }
            printf "%s   L%d: %s%s\n", dim, NR, line, rst
        }
    ' "$1"
}
HITS_6B=$(awk_count_phase4b "$FILE")
if [[ "$HITS_6B" -eq 0 ]]; then
    printf "%s✅ [6B/%d] 文法ポイント逃げ表現(v1.5.1 PATTERN_6B): OK%s\n" \
        "$GREEN" "$TOTAL_CHECKS" "$RESET"
else
    printf "%s❌ [6B/%d] 文法ポイント逃げ表現(v1.5.1 PATTERN_6B): %d hits%s\n" \
        "$RED" "$TOTAL_CHECKS" "$HITS_6B" "$RESET"
    NG_COUNT=$((NG_COUNT + 1))
    awk_show_phase4b "$FILE"
    printf "%s   ↑ 「文法ポイント、見ていくで」は逃げ表現。" "$YELLOW"
    printf "「文法ポイントはNつや」とNを明示しろ(動的化)%s\n" "$RESET"
fi

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# [7/N] v1.5.0 部首名混入
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
PATTERN_9='ニンベンに|サンズイに|ガンダレに|まだれに|しんにょうに|くさかんむり|うかんむり|きへんに|もんがまえ|しめすへん|やまいだれ|やまいだれに'
HITS_9=$(awk_count "$TMP_NOLANG" "$PATTERN_9")
if [[ "$HITS_9" -eq 0 ]]; then
    print_ok 7 "部首名混入(構成解説禁止 v1.5.0)"
else
    print_ng 7 "部首名混入(構成解説禁止 v1.5.0)" "$HITS_9"
    awk_show "$TMP_NOLANG" "$PATTERN_9"
fi

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# [8/N] v1.5.0 構成位置混入
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
PATTERN_10='上に「[一-龯]+」.{0,15}下に|左[に側]「.{0,5}」.{0,15}右|真ん中に「[一-龯]+」|上下に「[一-龯]+」|中に「[一-龯]+」'
HITS_10=$(awk_count "$TMP_NOLANG" "$PATTERN_10")
if [[ "$HITS_10" -eq 0 ]]; then
    print_ok 8 "構成位置混入(構成解説禁止 v1.5.0)"
else
    print_ng 8 "構成位置混入(構成解説禁止 v1.5.0)" "$HITS_10"
    awk_show "$TMP_NOLANG" "$PATTERN_10"
fi

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# [9/N] v1.5.0 印象表現混入
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
PATTERN_11='ごっつい|線多め|画数モリモリ|ぎゅっと詰まった|がっつり|骨太|縦長|横広|三層構造|格子状|シャープな字|あっさり字'
HITS_11=$(awk_count "$TMP_NOLANG" "$PATTERN_11")
if [[ "$HITS_11" -eq 0 ]]; then
    print_ok 9 "印象表現混入(字形描写禁止 v1.5.0)"
else
    print_ng 9 "印象表現混入(字形描写禁止 v1.5.0)" "$HITS_11"
    awk_show "$TMP_NOLANG" "$PATTERN_11"
fi

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# [10/N] v1.5.0 古字部品 <sub alias> 引用
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
PATTERN_12='<sub alias=["'"'"']?(アニ|キ|ヒキ|ハ|ダ|セツ|ホン|テン)["'"'"']?[^>]*>(豈|几|疋|巴|兌|挖|穴)</sub>'
HITS_12=$(awk_count "$FILE" "$PATTERN_12")
if [[ "$HITS_12" -eq 0 ]]; then
    print_ok 10 "古字部品<sub alias>引用(v1.5.0)"
else
    print_ng 10 "古字部品<sub alias>引用(v1.5.0)" "$HITS_12"
    awk_show "$FILE" "$PATTERN_12"
fi

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# [11/N] ★v1.6.0★ PATTERN_13 既知 NG 熟語辞書(YAML)
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# - 設計書 ④ 4.1-4.5 反映
# - リテラル熟語のみ許可、メタ文字禁止: . ( ) * + ? [ ] { } | \ ^ $
# - 上限 100 語(辞書側で担保)、含めば lint 自体が起動拒否
# - --allowlist で Issue 本文 / Phase 0 サマリ表の語を構造的スルー
# - 検査対象: <lang>/<sub> 中身を温存した元ファイル($FILE)
#   理由: PATTERN_13 は中国語熟語の検出が主目的。<lang xml:lang="cmn-TW">在班上</lang>
#         に登場した語も拾わなければ意味がない
NG_DICT_OK=1
if [[ -z "$NG_THESAURUS_FILE" ]]; then
    print_warn 11 "PATTERN_13 既知 NG 熟語辞書(v1.6.0)" "辞書 YAML 未発見、スキップ"
    NG_DICT_OK=0
elif [[ ! -r "$NG_THESAURUS_FILE" ]]; then
    print_warn 11 "PATTERN_13 既知 NG 熟語辞書(v1.6.0)" "辞書 YAML 読めん: $NG_THESAURUS_FILE"
    NG_DICT_OK=0
fi

if [[ $NG_DICT_OK -eq 1 ]]; then
    # YAML から word: 行のみ抽出(quoted/unquoted 両対応)
    # 例: `  - word: "在班上"` → `在班上`
    # 軽量 awk パーサ(依存ゼロ、yq 不要)
    awk '
        /^[[:space:]]*-?[[:space:]]*word:[[:space:]]*/ {
            sub(/^[[:space:]]*-?[[:space:]]*word:[[:space:]]*/, "")
            # 前後の引用符除去
            gsub(/^["\x27]|["\x27][[:space:]]*$/, "")
            sub(/[[:space:]]*$/, "")
            if (length($0) > 0) print
        }
    ' "$NG_THESAURUS_FILE" > "$TMP_NG_WORDS"

    NG_WORD_COUNT=$(wc -l < "$TMP_NG_WORDS" | tr -d '[:space:]')

    # ── 辞書バリデーション ──
    # 上限 100 語
    if [[ "$NG_WORD_COUNT" -gt 100 ]]; then
        printf "%sERROR: NG 辞書 %d 語 > 上限 100 語。整理してから lint しい%s\n" \
            "$RED" "$NG_WORD_COUNT" "$RESET" >&2
        exit 2
    fi

    # メタ文字検出: . ( ) * + ? [ ] { } | \ ^ $
    # ※「.」は単語末尾でなく必ず NG(意図せず混入したら危険)
    # 注: BSD grep の bracket expression(`[...]`)では `[` `]` のエスケープが
    #     ロケール依存で揺れるので、alternation で確実に書く
    META_HITS=$(grep -nE '\.|\(|\)|\*|\+|\?|\[|\]|\{|\}|\||\\|\^|\$' "$TMP_NG_WORDS" || true)
    if [[ -n "$META_HITS" ]]; then
        printf "%sERROR: NG 辞書にメタ文字検出(リテラル熟語のみ許可)%s\n" "$RED" "$RESET" >&2
        printf "%s%s\n%s%s\n" "$DIM" "$META_HITS" "" "$RESET" >&2
        printf "%s  禁止メタ文字: . ( ) * + ? [ ] { } | \\\\ ^ \$%s\n" "$YELLOW" "$RESET" >&2
        exit 2
    fi

    # ── allowlist 読み込み ──
    if [[ -n "$ALLOWLIST_FILE" ]]; then
        # 空行・コメント行(#始まり)を除外、前後空白トリム
        awk '
            /^[[:space:]]*#/ { next }
            /^[[:space:]]*$/ { next }
            {
                sub(/^[[:space:]]+/, "")
                sub(/[[:space:]]+$/, "")
                if (length($0) > 0) print
            }
        ' "$ALLOWLIST_FILE" > "$TMP_ALLOWLIST"
    else
        : > "$TMP_ALLOWLIST"
    fi

    # ── PATTERN_13 マッチング(grep -F でリテラル部分一致) ──
    # 各 NG 単語につき:
    #   1. allowlist にあれば即スキップ
    #   2. $FILE 中に出現(grep -F)するかチェック
    NG13_HITS=0
    NG13_DETAILS=""
    if [[ "$NG_WORD_COUNT" -gt 0 ]]; then
        while IFS= read -r ng_word; do
            [[ -z "$ng_word" ]] && continue
            # allowlist 注入チェック(部分一致でなく完全一致行で)
            if [[ -s "$TMP_ALLOWLIST" ]] && grep -Fxq -- "$ng_word" "$TMP_ALLOWLIST"; then
                continue
            fi
            # 本体ファイル中に出現?
            if grep -Fq -- "$ng_word" "$FILE"; then
                NG13_HITS=$((NG13_HITS + 1))
                # 行番号付き 1 行抜粋(120字切り詰め)
                hit_line=$(grep -nF -- "$ng_word" "$FILE" | head -n 1)
                NG13_DETAILS="${NG13_DETAILS}${ng_word}|${hit_line}"$'\n'
            fi
        done < "$TMP_NG_WORDS"
    fi

    if [[ "$NG13_HITS" -eq 0 ]]; then
        if [[ "$NG_WORD_COUNT" -eq 0 ]]; then
            print_warn 11 "PATTERN_13 既知 NG 熟語辞書(v1.6.0)" "辞書 0 語、スキップ"
        else
            ALLOWLIST_COUNT=0
            [[ -s "$TMP_ALLOWLIST" ]] && ALLOWLIST_COUNT=$(wc -l < "$TMP_ALLOWLIST" | tr -d '[:space:]')
            print_ok 11 "PATTERN_13 既知 NG 熟語辞書(v1.6.0、辞書 ${NG_WORD_COUNT} 語 / allowlist ${ALLOWLIST_COUNT} 語)"
        fi
    else
        print_ng 11 "PATTERN_13 既知 NG 熟語辞書(v1.6.0)" "$NG13_HITS"
        printf '%s' "$NG13_DETAILS" | while IFS='|' read -r ng_word hit_line; do
            [[ -z "$ng_word" ]] && continue
            # hit_line は "Lnum:本文" 形式
            ln_num="${hit_line%%:*}"
            ln_body="${hit_line#*:}"
            if [[ ${#ln_body} -gt 100 ]]; then
                ln_body="${ln_body:0:100}..."
            fi
            printf "%s   [%s] L%s: %s%s\n" "$DIM" "$ng_word" "$ln_num" "$ln_body" "$RESET"
        done
        printf "%s   ↑ ng-thesaurus.yaml の既知 NG 熟語。replacement_examples を参照して置換、" "$YELLOW"
        printf "または学習対象として正当なら --allowlist で除外%s\n" "$RESET"
    fi
fi

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# [12/N] ★v1.6.0★ PATTERN_14 Phase 1 末尾リピート 2 回検証
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# - 設計書 ③ 3.4
# - v1.5.x は Phase 1 末尾リピート 1 回だったが、v1.6.0 で v4 と統一して 2 回戻し
# - 検出ロジック:
#   1. Phase 1 セクション(.md は `### Phase 1:` 範囲 / .xml は全体)を切り出す
#   2. リピート開始マーカー(「もう一度聞いて」「もういっぺん」「もう一回」「再聴」等)
#      を検出 → そこから </speak> までを「リピート区間」と定義
#   3. リピート区間内の <lang xml:lang="cmn-TW">...</lang> 出現回数
#   4. ジャスト 2 回 → OK / それ以外 → NG
# - .md ファイル時: 複数 Phase 1 ブロックがあれば各々検証
# - リピートマーカー検出失敗 = Phase 1 にリピート構造なし = NG(v1.6.0 仕様)

TMP_PHASE1=$(mktemp -t v5lint.XXXXXX) || { echo "mktemp 失敗" >&2; exit 2; }

# Phase 1 抽出
if [[ "$EXT" == "md" ]] || [[ $IS_MD_FILE -eq 1 ]]; then
    # .md: `### Phase 1:` から次の `###` or `---` or `## ` まで(複数ブロック対応)
    awk '
        BEGIN { flag=0 }
        /^#{2,3}[[:space:]]+Phase[[:space:]]+1[:：]/ {
            if (flag) print "---PHASE1-END---"
            flag=1; print "---PHASE1-START---"; print; next
        }
        flag && /^#{2,3}[[:space:]]+Phase[[:space:]]+[2-4][:：]/ { flag=0; print "---PHASE1-END---"; next }
        flag && /^#{2,3}[[:space:]]+(ペア|Pair)/ { flag=0; print "---PHASE1-END---"; next }
        flag && /^---$/ { flag=0; print "---PHASE1-END---"; next }
        flag { print }
        END { if (flag) print "---PHASE1-END---" }
    ' "$ORIG_FILE" > "$TMP_PHASE1"
else
    # .xml: ファイル全体を Phase 1 とみなす
    echo "---PHASE1-START---" > "$TMP_PHASE1"
    cat "$FILE" >> "$TMP_PHASE1"
    echo "---PHASE1-END---" >> "$TMP_PHASE1"
fi

PHASE1_BLOCK_COUNT=$(awk '/^---PHASE1-START---/{c++} END{print c+0}' "$TMP_PHASE1")

if [[ "$PHASE1_BLOCK_COUNT" -eq 0 ]]; then
    print_warn 12 "PATTERN_14 Phase 1 リピート 2 回検証(v1.6.0)" "Phase 1 セクションなし、スキップ"
else
    # 各 Phase 1 ブロックで「リピート開始マーカー」以降の <lang cmn-TW> 出現回数
    # マーカー(逐語コピペでなくとも誤差吸収するため複数候補):
    #   - もう一度聞いて
    #   - もう一回聞いて
    #   - もういっぺん
    #   - 再聴
    PATTERN_14_RESULT=$(perl -CSAD -Mutf8 -ne '
        BEGIN {
            our @blocks = ();
            our $cur = "";
            our $in = 0;
        }
        if (/^---PHASE1-START---/) { $in = 1; $cur = ""; next; }
        if (/^---PHASE1-END---/)   { push @blocks, $cur; $in = 0; $cur = ""; next; }
        if ($in) { $cur .= $_; }
        END {
            my $i = 0;
            my @results = ();
            for my $block (@blocks) {
                $i++;
                # リピート開始マーカー位置を探す(最初に見つかった位置)
                my $marker_pos = -1;
                if ($block =~ /(もう一度聞いて|もう一回聞いて|もういっぺん|再聴)/) {
                    $marker_pos = $-[0];
                }
                if ($marker_pos < 0) {
                    push @results, "$i:NOMARKER:0";
                    next;
                }
                my $tail = substr($block, $marker_pos);
                # </speak> までを切り詰め
                if ($tail =~ /<\/speak>/) {
                    $tail = substr($tail, 0, $-[0]);
                }
                # <lang xml:lang="cmn-TW">...</lang> の出現回数
                my $count = 0;
                while ($tail =~ /<lang\s+xml:lang="cmn-TW">[^<]+<\/lang>/g) {
                    $count++;
                }
                push @results, "$i:OK:$count";
            }
            print join("\n", @results), "\n";
        }
    ' "$TMP_PHASE1")

    PATTERN_14_NG=0
    PATTERN_14_DETAIL=""
    while IFS= read -r line; do
        [[ -z "$line" ]] && continue
        block_idx=$(echo "$line" | cut -d: -f1)
        status=$(echo "$line" | cut -d: -f2)
        count=$(echo "$line" | cut -d: -f3)
        if [[ "$status" == "NOMARKER" ]]; then
            PATTERN_14_NG=$((PATTERN_14_NG + 1))
            PATTERN_14_DETAIL="${PATTERN_14_DETAIL}  Phase 1 ブロック ${block_idx}: リピート開始マーカー(もう一度聞いて/もういっぺん/再聴)なし"$'\n'
        elif [[ "$count" -ne 2 ]]; then
            PATTERN_14_NG=$((PATTERN_14_NG + 1))
            PATTERN_14_DETAIL="${PATTERN_14_DETAIL}  Phase 1 ブロック ${block_idx}: リピート区間内の <lang cmn-TW> = ${count} 回(2 回必須)"$'\n'
        fi
    done <<< "$PATTERN_14_RESULT"

    if [[ "$PATTERN_14_NG" -eq 0 ]]; then
        print_ok 12 "PATTERN_14 Phase 1 リピート 2 回検証(v1.6.0、${PHASE1_BLOCK_COUNT} ブロック)"
    else
        print_ng 12 "PATTERN_14 Phase 1 リピート 2 回検証(v1.6.0)" "$PATTERN_14_NG"
        printf "%s%s%s" "$DIM" "$PATTERN_14_DETAIL" "$RESET"
        printf "%s   ↑ v1.6.0 で Phase 1 末尾リピートを 2 回に戻し。" "$YELLOW"
        printf "テンプレ: 「ほな、もう一度聞いてみよか…<break time=\"1.5s\"/>…はい、もういっぺん。」%s\n" "$RESET"
    fi
fi
rm -f "$TMP_PHASE1" 2>/dev/null

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# [13/N] Phase 0 ↔ Phase 2/3 不一致照合(--strict のみ)
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
if [[ $STRICT -eq 1 ]]; then
    PHASE0_WORDS=$(awk '
        /\| *ペア *\| *単語1/ { in_table=1; next }
        in_table && /^\|/ {
            n = split($0, cells, "|")
            for (i = 3; i <= n - 1; i++) {
                gsub(/^[ \t]+|[ \t]+$/, "", cells[i])
                if (cells[i] != "" && cells[i] !~ /^---/ && cells[i] !~ /^[0-9]+$/) {
                    print cells[i]
                }
            }
            next
        }
        in_table && !/^\|/ { in_table=0 }
    ' "$FILE" | sort -u)

    PHASE23_WORDS=$(awk '
        {
            s = $0
            while (match(s, /<lang xml:lang="cmn-TW">[^<]+<\/lang>/)) {
                hit = substr(s, RSTART, RLENGTH)
                sub(/^<lang[^>]*>/, "", hit)
                sub(/<\/lang>$/, "", hit)
                print hit
                s = substr(s, RSTART + RLENGTH)
            }
        }
    ' "$FILE" | sort -u)

    MISSING=""
    if [[ -n "$PHASE0_WORDS" ]]; then
        while IFS= read -r word; do
            if [[ -n "$word" ]]; then
                if ! printf '%s\n' "$PHASE23_WORDS" | grep -qF -- "$word"; then
                    MISSING="${MISSING}${word}"$'\n'
                fi
            fi
        done <<< "$PHASE0_WORDS"
    fi

    if [[ -z "$PHASE0_WORDS" ]]; then
        print_warn 13 "Phase 0↔Phase 2/3 照合" "Phase 0 表が見つからず照合スキップ"
    elif [[ -z "$MISSING" ]]; then
        print_ok 13 "Phase 0↔Phase 2/3 照合"
    else
        miss_count=$(printf '%s' "$MISSING" | awk 'NF{c++} END{print c+0}')
        print_ng 13 "Phase 0↔Phase 2/3 照合" "$miss_count"
        printf "%s   Phase 0 表にあるが Phase 2/3 に出てこん単語:%s\n" "$DIM" "$RESET"
        printf '%s' "$MISSING" | while IFS= read -r m; do
            [[ -n "$m" ]] && printf "%s   - %s%s\n" "$DIM" "$m" "$RESET"
        done
    fi

    # ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    # [14/N] 効果音マーカー網羅(--strict のみ)
    # ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    MARKER_COUNT=$(awk_count "$FILE" '<!-- explain -->')
    SPEAK_COUNT=$(awk_count "$FILE" '<speak>')

    if [[ "$SPEAK_COUNT" -eq 0 ]]; then
        print_warn 14 "効果音マーカー網羅" "<speak> ブロックなし、照合スキップ"
    elif [[ "$MARKER_COUNT" -eq "$SPEAK_COUNT" ]]; then
        print_ok 14 "効果音マーカー網羅($MARKER_COUNT / $SPEAK_COUNT)"
    else
        DIFF=$((SPEAK_COUNT - MARKER_COUNT))
        [[ $DIFF -lt 0 ]] && DIFF=$((-DIFF))
        print_ng 14 "効果音マーカー網羅" "$DIFF"
        printf "%s   <speak> ブロック数=%d, <!-- explain --> マーカー数=%d%s\n" \
            "$DIM" "$SPEAK_COUNT" "$MARKER_COUNT" "$RESET"
    fi

    # ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    # [15/N] v1.5.1 PATTERN_6C 短文+3点固定検出(Phase 4 限定・--strict のみ)
    # ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    TMP_PHASE4=$(mktemp -t v5lint.XXXXXX) || { echo "mktemp 失敗" >&2; exit 2; }
    if [[ "${EXT}" == "md" ]] || [[ $IS_MD_FILE -eq 1 ]]; then
        awk '
            /^### Phase 4:/ { flag=1; print; next }
            flag && /^### / { flag=0; next }
            flag && /^## / { flag=0; next }
            flag && /^---/ { flag=0; next }
            flag { print }
        ' "$ORIG_FILE" > "$TMP_PHASE4"
    else
        cp "$FILE" "$TMP_PHASE4"
    fi

    if [[ ! -s "$TMP_PHASE4" ]]; then
        print_warn 15 "PATTERN_6C 短文+3点固定検出(v1.5.1)" "Phase 4 セクション抽出失敗、スキップ"
    else
        LANG_CONTENT=$(perl -CSAD -ne '
            while (/<lang\s+xml:lang="cmn-TW">([^<]+)<\/lang>/g) {
                print "$1\n";
            }
        ' "$TMP_PHASE4")

        EXAMPLE_LEN=0
        if [[ -n "$LANG_CONTENT" ]]; then
            EXAMPLE_LEN=$(printf '%s' "$LANG_CONTENT" | perl -CSAD -e '
                my $max = 0;
                while (my $line = <STDIN>) {
                    chomp $line;
                    $line =~ s/[，。、！？\s,.\!\?]//g;
                    my $len = length($line);
                    $max = $len if $len > $max;
                }
                print $max;
            ')
        fi

        HAS_HITOTSUME=$(awk '/ひとつ目/ {c++} END {print c+0}' "$TMP_PHASE4")
        HAS_FUTATSUME=$(awk '/ふたつ目/ {c++} END {print c+0}' "$TMP_PHASE4")
        HAS_MITTSUME=$(awk '/みっつ目/ {c++} END {print c+0}' "$TMP_PHASE4")

        ALL_THREE=0
        if [[ "$HAS_HITOTSUME" -gt 0 ]] && [[ "$HAS_FUTATSUME" -gt 0 ]] && [[ "$HAS_MITTSUME" -gt 0 ]]; then
            ALL_THREE=1
        fi

        if [[ "$EXAMPLE_LEN" -eq 0 ]]; then
            print_warn 15 "PATTERN_6C 短文+3点固定検出(v1.5.1)" \
                "Phase 4 内に <lang> 例文なし、スキップ"
        elif [[ "$EXAMPLE_LEN" -le 9 ]] && [[ "$ALL_THREE" -eq 1 ]]; then
            NG_COUNT=$((NG_COUNT + 1))
            printf "%s❌ [15/%d] PATTERN_6C 短文+3点固定検出(v1.5.1): 短文(%d cp)+3点固定%s\n" \
                "$RED" "$TOTAL_CHECKS" "$EXAMPLE_LEN" "$RESET"
            printf "%s   例文長: %d codepoint(≦9 = 短文判定)、" "$DIM" "$EXAMPLE_LEN"
            printf "ひとつ目/ふたつ目/みっつ目 全部出現%s\n" "$RESET"
            printf "%s   ↑ 短い例文に 3 ポイント水増しは禁止。" "$YELLOW"
            printf "Phase 4 で 2 ポイントに減らすか動的化を検討%s\n" "$RESET"
        else
            if [[ "$EXAMPLE_LEN" -gt 9 ]]; then
                printf "%s✅ [15/%d] PATTERN_6C 短文+3点固定検出(v1.5.1): OK(例文 %d cp > 9 = 長文)%s\n" \
                    "$GREEN" "$TOTAL_CHECKS" "$EXAMPLE_LEN" "$RESET"
            else
                printf "%s✅ [15/%d] PATTERN_6C 短文+3点固定検出(v1.5.1): OK(短文だが3点固定なし)%s\n" \
                    "$GREEN" "$TOTAL_CHECKS" "$RESET"
            fi
        fi
    fi
    rm -f "$TMP_PHASE4" 2>/dev/null
fi

# ───────────────────────── サマリ ─────────────────────────
echo ""
printf "%s━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━%s\n" "$BOLD" "$RESET"

if [[ $LLM_UNAVAILABLE -eq 1 ]]; then
    printf "%s※ native-checker-v1 Skill 未起動(--llm-unavailable)。" "$YELLOW"
    printf "ネイティブ感チェックは PATTERN_13 辞書のみ。投稿コメント末尾に「林老師チェック未実施」明記推奨%s\n" "$RESET"
fi

if [[ "$NG_COUNT" -eq 0 ]]; then
    printf "%s%sOK: 全 %d カテゴリでヒットゼロや。次のモジュールへ進んでええで✨%s\n" \
        "$GREEN" "$BOLD" "$TOTAL_CHECKS" "$RESET"
    exit 0
else
    printf "%s%sNG: %d カテゴリで検出。該当モジュールを再生成してな🔥%s\n" \
        "$RED" "$BOLD" "$NG_COUNT" "$RESET"
    exit 1
fi
