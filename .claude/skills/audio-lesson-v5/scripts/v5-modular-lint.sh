#!/usr/bin/env bash
# v5-modular-lint.sh — SSML モジュール式教材 投稿前チェッカー
#
# 設計書: tmp/v1.5.1-design/DESIGN.md ①(v1.5.1 改修)
# 用途: 各モジュール生成直後に走らせ、鬼門ワード/単独漢字/二度読み等の
#       NG パターンを 1 秒以内に検出する。
# 終了コード:
#   0 = ヒットゼロ(OK、次モジュールへ進んでよい)
#   1 = ヒットあり(NG、該当モジュール再生成必須)
#   2 = 引数エラー / 内部エラー
#
# 使い方:
#   bash scripts/v5-modular-lint.sh <ファイルパス>
#   bash scripts/v5-modular-lint.sh --strict <ファイルパス>  # パターン11-12 + PATTERN_6C
#
# v1.5.1 改修(本ファイル):
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
    if locale -a 2>/dev/null | grep -qx 'ja_JP.UTF-8'; then
        export LC_ALL=ja_JP.UTF-8
    elif locale -a 2>/dev/null | grep -qx 'en_US.UTF-8'; then
        export LC_ALL=en_US.UTF-8
    elif locale -a 2>/dev/null | grep -qx 'C.UTF-8'; then
        export LC_ALL=C.UTF-8
    else
        export LC_ALL=ja_JP.UTF-8
    fi
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
FILE=""
for arg in "$@"; do
    case "$arg" in
        --strict)
            STRICT=1
            ;;
        -h|--help)
            cat <<'EOF'
Usage: v5-modular-lint.sh [--strict] <file>

  --strict   パターン11(Phase 0↔Phase 2/3 不一致照合)・
             パターン12(効果音マーカー網羅)・
             パターン13(★v1.5.1★ PATTERN_6C 短文+3点固定 Phase 4 限定)を実行
             ※注: v1.4.x までは 7/8 だったが v1.5.0 で 11/12 に繰り下げ、v1.5.1 で 13 追加

  デフォルトは 1-10 + 6B (1秒以内完了)

検出パターン:
  [1]  鬼門ワード(ルールE): 画 / 字義 / 然り而して / 豈 / 几 / 疋 / N画 / 点がN個
       (.md ファイル: ```xml ブロック本文 + メタ報告領域の両方で画字混入を検査)
  [2]  単独漢字裸出し(ルールA): 「我」など、<lang> 外の地の文に単独漢字
  [3]  二度読み禁止(ルールC): 「我々」(われわれ) のような読み付与
  [4]  繋辞NG(v4 #3): </lang>です / </lang>だ。
  [5]  Markdown 強調(v4 #10): ** / __ / バッククォート単独
  [6]  文法ポイント逃げ表現(★v1.5.1 PATTERN_6B 統合★):
       - 「文法ポイントは三つや」リテラル(従来 PATTERN_6)
       - 「文法ポイント、見ていくで」逃げ表現(新 PATTERN_6B、ホワイトリスト方式)
  [7]  ★v1.5.0★ 部首名混入(構成解説禁止): ニンベンに/サンズイに/まだれ/しんにょう/もんがまえ 等
  [8]  ★v1.5.0★ 構成位置混入(構成解説禁止): 上に「X」下に / 左右 / 真ん中に / 上下に / 中に
  [9]  ★v1.5.0★ 印象表現混入(字形描写禁止): ごっつい / 線多め / ぎゅっと詰まった / 骨太 / 縦長
  [10] ★v1.5.0★ 古字部品 <sub alias> 引用: <sub alias="アニ">豈</sub> 等(部品引用そのものを禁止)
  [11] Phase 0↔Phase 2/3 照合(--strict のみ): サマリ表4語と見出しの diff
  [12] 効果音マーカー網羅(--strict のみ): <!-- explain --> 数 = <speak> 数
  [13] ★v1.5.1★ PATTERN_6C 短文+3点固定(--strict のみ):
       Phase 4 セクションで「例文 ≦9 codepoint かつ ひとつ目/ふたつ目/みっつ目 全出現」を検出

終了コード: 0=OK, 1=NG, 2=エラー
EOF
            exit 0
            ;;
        *)
            FILE="$arg"
            ;;
    esac
done

if [[ -z "$FILE" ]]; then
    echo "${RED}ERROR: チェック対象ファイルを指定してな${RESET}" >&2
    echo "Usage: $0 [--strict] <file>" >&2
    exit 2
fi

if [[ ! -f "$FILE" ]]; then
    echo "${RED}ERROR: ファイルが見つからん: $FILE${RESET}" >&2
    exit 2
fi

# ───────────────────────── 集計用 ─────────────────────────
# v1.5.0: パターン9-12 追加(構成解説混入検出系、デフォルト実行)
#   9  部首名混入(ニンベン/サンズイ/ガンダレ etc)
#   10 構成位置混入(上に○下に○、左右、真ん中、上下)
#   11 印象表現混入(ごっつい/線多め/ぎゅっと/がっつり)
#   12 古字部品 <sub alias> 引用(豈/几/疋/巴/兌/挖/穴)
# v1.5.1: PATTERN_6B(default) + PATTERN_6C(strict) 追加
#   6B カウントはチェック [6/N] と同じ枠で実行(NG_COUNT のみ加算、TOTAL は据置)
#   13 PATTERN_6C 短文+3点固定(--strict のみ、Phase 4 限定スコープ)
# → デフォルト 10、--strict 13
NG_COUNT=0
TOTAL_CHECKS=10
[[ $STRICT -eq 1 ]] && TOTAL_CHECKS=13

# 一時ファイル(<lang>剥がし版、コードフェンス潰し版、xml抽出版、メタ領域版)
TMP_NOLANG=$(mktemp -t v5lint.XXXXXX) || { echo "mktemp 失敗" >&2; exit 2; }
TMP_NOFENCE=$(mktemp -t v5lint.XXXXXX) || { echo "mktemp 失敗" >&2; exit 2; }
TMP_XML_ONLY=$(mktemp -t v5lint.XXXXXX) || { echo "mktemp 失敗" >&2; exit 2; }
TMP_META=$(mktemp -t v5lint.XXXXXX) || { echo "mktemp 失敗" >&2; exit 2; }
trap 'rm -f "$TMP_NOLANG" "$TMP_NOFENCE" "$TMP_XML_ONLY" "$TMP_META" 2>/dev/null' EXIT

# .md ファイルなら ```xml ... ``` ブロックだけ抽出して $FILE を差し替え。
# Few-shot や Issue コメント等の Markdown 文書内でも、SSML 部分(```xml）
# だけを lint 対象にする(メタテーブルや解説文の **強調** や単独漢字を誤検出しない)。
#
# v1.4.1 追加: .md ファイル時は「メタ報告領域」(xml ブロック以外)も別途キープして、
# 画字混入チェック(後段の Pattern 1-meta)を実行する。エージェントが
# 「.md は xml ブロックだけ検査と知ってた」 → 「メタ報告だから画使ってもいい」
# と意識的にバイパスする事案(Q7 セーフゾーン化、Issue #18 観測)を構造的に潰す。
IS_MD_FILE=0
ORIG_FILE="$FILE"
EXT="${FILE##*.}"
if [[ "$EXT" == "md" ]]; then
    IS_MD_FILE=1
    awk '/^```xml/{flag=1; next} /^```$/{flag=0; next} flag' "$FILE" > "$TMP_XML_ONLY"
    # メタ領域 = ```xml ... ``` ブロック以外(=ドキュメント本文・テーブル・見出し等)
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
# (両方とも中身は「指定済みで TTS が正しく読む」ので、鬼門ワード・単独漢字検出から除外)
sed -E -e 's#<lang[^>]*>[^<]*</lang>##g' -e 's#<sub[^>]*>[^<]*</sub>##g' "$FILE" > "$TMP_NOLANG"
# Markdown コードフェンス(```...```)行を空行化した版
sed -E 's/^```.*$//' "$FILE" > "$TMP_NOFENCE"

# ───────────────────────── ヘルパー ─────────────────────────
# print_ok <番号> <カテゴリ名>
print_ok() {
    printf "%s✅ [%d/%d] %s: OK%s\n" "$GREEN" "$1" "$TOTAL_CHECKS" "$2" "$RESET"
}

# print_ng <番号> <カテゴリ名> <ヒット数>
print_ng() {
    printf "%s❌ [%d/%d] %s: %d hits%s\n" "$RED" "$1" "$TOTAL_CHECKS" "$2" "$3" "$RESET"
    NG_COUNT=$((NG_COUNT + 1))
}

# print_warn <番号> <カテゴリ名> <メッセージ>
print_warn() {
    printf "%s⚠️  [%d/%d] %s: %s%s\n" "$YELLOW" "$1" "$TOTAL_CHECKS" "$2" "$3" "$RESET"
}

# awk_count <ファイル> <awkパターン(/.../)抜きの正規表現本体>
# UTF-8 多バイト対応のヒット行数を返す(awk 経由)
awk_count() {
    local file="$1"
    local pattern="$2"
    awk -v pat="$pattern" 'BEGIN{c=0} $0 ~ pat {c++} END{print c+0}' "$file" 2>/dev/null
}

# awk_show <ファイル> <パターン>
# ヒット行を「   Lxx: text」形式で表示(120 文字で切り詰め)
awk_show() {
    local file="$1"
    local pattern="$2"
    local dim="$DIM"
    local reset="$RESET"
    awk -v pat="$pattern" -v dim="$dim" -v rst="$reset" '
        $0 ~ pat {
            line = $0
            # 多バイト文字を考慮した「だいたい120文字」切り詰め
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
printf "%s━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━%s\n" "$BOLD" "$RESET"

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# [1/N] 鬼門ワード(ルールE)
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# - 「画」「字義」「然り而して」「豈」「几」「疋」「画数」「画が多い」「N画」「点がN個」
# - 「画」字単独でも検出(画数の話に流れがちなため、地の文出禁)
# - 検出対象: 元ファイル(<lang> 内に出ることはないが、念のため元ファイル全体)
PATTERN_1='画|字義|然り而して|豈|几|疋|画数|画が多い|[0-9]+画|点が[0-9]+個'

# <sub>/<lang> 内は読み指定済みなので除外した版($TMP_NOLANG)で検出
HITS_1=$(awk_count "$TMP_NOLANG" "$PATTERN_1")
if [[ "$HITS_1" -eq 0 ]]; then
    print_ok 1 "鬼門ワード(ルールE)"
else
    print_ng 1 "鬼門ワード(ルールE)" "$HITS_1"
    awk_show "$TMP_NOLANG" "$PATTERN_1"
fi

# v1.4.1 追加: .md ファイルのメタ報告領域(xml ブロック以外)に対する画字追加検査
# - エージェントが「メタ報告だから画使ってもいい」と意識的判断する Q7 セーフゾーン化を潰す
# - 「lint テーブル本文」「ドキュメントの解説」「コメント本文の表」に「二画」「三画」等が
#   混入する事案(Issue #18 観測)を構造的に捕捉
# - 検査対象: 漢数字・アラビア数字いずれの「N画」+ 「画数」 + 「画が多い」+ 単独「画」
# - 走らせるのは .md ファイル時のみ。.xml 直接 lint には影響しない
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
        # 元の HITS_1 が 0 でも、メタ領域ヒットがあれば NG_COUNT を立てる
        if [[ "$HITS_1" -eq 0 ]]; then
            NG_COUNT=$((NG_COUNT + 1))
        fi
    fi
fi

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# [2/N] 単独漢字裸出し(ルールA)
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# - 「我」「歷」「歸」みたいな単独漢字を、地の文の「カギカッコ」内に裸出ししてる
# - <lang xml:lang="..."> タグ内は除外して判定(剥がし版 TMP_NOLANG で検査)
# - パターン:
#     ①  「X」 …カギカッコ内1漢字
#     ②  >X<  …タグ間に1漢字(XML 整合性チェック)
# - 「々」(U+3005)も漢字相当として補足(CJK Iteration Mark)
# - 単独 1 文字のみマッチ(2 文字以上は OK = 「我々」「凱旋」等)
#
# 注: macOS BSD awk は CJK Han Unicode 範囲(U+4E00-U+9FFF)を字クラスで
#     扱うとき、空の `「」` も誤マッチする既知バグがある。perl の
#     明示 codepoint(`\x{4e00}-\x{9fff}`)なら正しく動くので Pattern 2 は
#     perl 利用(macOS/Linux 標準同梱、Claude Code 環境で確実)。
#
# perl ワンライナー(`-CSAD` で stdin/stdout/stderr/@ARGV を UTF-8 扱い)
# 引数: <ファイル> <モード:count|show>
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
        # ① 「<1漢字>」(カギカッコ内1漢字、々(U+3005)含む)
        # ② >X< (タグ間1漢字)
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
# - 「我々」(われわれ) / 「歴」(れき) のような、漢字直後にひらがな読み付与
# - 全角括弧 「X」（よみ） / 半角括弧 「X」(よみ) 両対応
# - ひらがな範囲は U+3041(ぁ) 〜 U+3093(ん)
# - 注: awk -v で渡すとき `\(` は awk の文字列エスケープで `(` になり regex グループ
#       扱いになるため、`\\(` と二重エスケープして「リテラル `(`」を意図する
PATTERN_3='「[一-鿿々]+」（[ぁ-ん]+）|「[一-鿿々]+」\\([ぁ-ん]+\\)'

HITS_3=$(awk_count "$FILE" "$PATTERN_3")
if [[ "$HITS_3" -eq 0 ]]; then
    print_ok 3 "二度読み禁止(ルールC)"
else
    print_ng 3 "二度読み禁止(ルールC)" "$HITS_3"
    awk_show "$FILE" "$PATTERN_3"
fi

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# [4/N] 繋辞NG(v4 セルフレビュー#3)
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# - </lang>直後に「です」「だ。」が来ると、TTS が中国語読みのまま日本語繋辞で
#   不自然な接続になる
# - 推奨: 「やな」「ということやで」のような関西弁ブリッジを介する
PATTERN_4='</lang>です|</lang>だ。'

HITS_4=$(awk_count "$FILE" "$PATTERN_4")
if [[ "$HITS_4" -eq 0 ]]; then
    print_ok 4 "繋辞NG(v4 #3)"
else
    print_ng 4 "繋辞NG(v4 #3)" "$HITS_4"
    awk_show "$FILE" "$PATTERN_4"
fi

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# [5/N] Markdown 強調記号(v4 セルフレビュー#10)
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# - **強調** / __強調__ / `code` は SSML 中に出ると TTS が読み上げる/XML 不整合
# - コードフェンス ```...``` 行は除外して検査(TMP_NOFENCE)
# - 検出対象: ** / __ / シングルバッククォート
# - 注: awk -v 経由なので `\*` は二重エスケープ必須(`\\*` → awk 文字列 `\*` →
#       regex リテラル `*`)
PATTERN_5='\\*\\*|__|`'

HITS_5=$(awk_count "$TMP_NOFENCE" "$PATTERN_5")
if [[ "$HITS_5" -eq 0 ]]; then
    print_ok 5 "Markdown強調記号(v4 #10)"
else
    print_ng 5 "Markdown強調記号(v4 #10)" "$HITS_5"
    awk_show "$TMP_NOFENCE" "$PATTERN_5"
fi

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# [6/N] 文法ポイント固定文化警告(Phase 4 動的化)
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# - v1.4.0: 「文法ポイントは三つや」リテラルのみ検出 → エージェントが半角数字 / 表現
#   バリエーションで容易に回避してくる(Q3 lint 隙間狙い、Issue #17 観測)
# - v1.4.1: 検出範囲を「文法ポイント XX (三|３|3|參)つ」「ポイント(は|を) XX (三|３|3)つ」
#   まで拡張。これで「文法ポイントを3つ見ていくで」「ポイントは三つあるで」等も捕捉
# - 設計書④ Phase 4 改修: 短文ペア(20字以下)で 3 ポイント水増しを防ぐ
# - 本当に 3 ポイントあるなら問題ないが、目視確認を促す
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
# [6B/N] ★v1.5.1★ 文法ポイント逃げ表現検出(ホワイトリスト方式)
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# - 設計書 ① 1.2「★Critical #1 反映:ホワイトリスト方式★」
# - 問題: 単純な「文法ポイント、見ていくで」検出は 1ポイント時の正当表現を殺す
#         偽陽性爆弾(例:「文法ポイントは1つや」「文法ポイントは2つや」)
# - 対策: ホワイトリスト方式 二段階 awk
#   Step 1: ホワイトリスト(「N つ」明示)にヒットしたら素通し
#   Step 2: 上記にヒットしなかった行のみ「逃げ表現」検出
# - 「N つ」表現が無いまま「文法ポイント、見ていくで」「ポイントを紹介する」と
#   する逃げ表現は禁止(数を明示しろ動的化)
# - 動詞バリエ網羅: 見ていく/紹介する/解説する/扱う/取り上げる/確認する/
#                   チェックする/押さえる/拾う/追う/探る
# - ポイント類語: 文法ポイント / 文法のポイント / 文法の見どころ / 文法の要点 / 文法の勘所
#
# 注: awk -v で渡す regex は二重エスケープ不要(直接 awk の `~` 評価に乗る)
PATTERN_6B_WHITELIST='文法ポイント.{0,15}(一|二|三|四|五|1|2|3|4|5|N|ひと|ふた|みっ|よっ|いつ|N|n)つ'
PATTERN_6B='(文法ポイント|文法の(ポイント|見どころ|要点|勘所))(、|,|を)?.{0,5}(見ていく|紹介する|解説する|扱う|取り上げる|確認する|チェックする|押さえる|拾う|追う|探る)(で|わ|な|よ)?'

# awk 二段階関数: ホワイトリストにヒットすれば素通し、ヒットしなければ PATTERN_6B チェック
awk_count_phase4b() {
    awk -v wl="$PATTERN_6B_WHITELIST" -v pat="$PATTERN_6B" '
        BEGIN { c=0 }
        $0 ~ wl { next }
        $0 ~ pat { c++ }
        END { print c+0 }
    ' "$1"
}

# 二段階表示関数(NG 時のヒット行表示用)
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
# [7/N] ★v1.5.0★ 部首名混入(構成解説禁止 — 設計書 ② 削除対象 #1)
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# - 旧 Phase 2(漢字書取モジュール)で「ニンベンに門」「サンズイに青」のような
#   部首名による字解説が頻発 → 構造的に消す
# - v1.5.0 で Phase 2 → 漢字認識モジュール に改名、3パターン分類(同じ/旧字体/繁体字特有)
#   のみで解説する設計に切替えたため、部首名は **完全禁止**
# - 検査対象: <lang>/<sub> 剥がし版($TMP_NOLANG)
# - 注: 「○○へん」のうち、文脈で問題ない用法(例: 「山辺」など)もあるので
#   「○○に[漢字]」「ガンダレ」「もんがまえ」など部首名としての特徴的形のみ拾う
PATTERN_9='ニンベンに|サンズイに|ガンダレに|まだれに|しんにょうに|くさかんむり|うかんむり|きへんに|もんがまえ|しめすへん|やまいだれ|やまいだれに'

HITS_9=$(awk_count "$TMP_NOLANG" "$PATTERN_9")
if [[ "$HITS_9" -eq 0 ]]; then
    print_ok 7 "部首名混入(構成解説禁止 v1.5.0)"
else
    print_ng 7 "部首名混入(構成解説禁止 v1.5.0)" "$HITS_9"
    awk_show "$TMP_NOLANG" "$PATTERN_9"
    printf "%s   ↑ Phase 2 は 3 パターン分類(同じ/旧字体/繁体字特有)のみで解説。" "$YELLOW"
    printf "部首名による構成解説は禁止%s\n" "$RESET"
fi

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# [8/N] ★v1.5.0★ 構成位置混入(構成解説禁止 — 設計書 ② 削除対象 #2)
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# - 「上に血、下に三人」「左に○、右に△」「真ん中に□」のような位置説明も禁止
# - 音声学習では字形位置説明は無意味、3パターン分類で十分
# - 検査対象: <lang>/<sub> 剥がし版($TMP_NOLANG)
# - 「上に「X」.{0,15}下に」のように上下/左右がセットで出るパターンを拾う
PATTERN_10='上に「[一-龯]+」.{0,15}下に|左[に側]「.{0,5}」.{0,15}右|真ん中に「[一-龯]+」|上下に「[一-龯]+」|中に「[一-龯]+」'

HITS_10=$(awk_count "$TMP_NOLANG" "$PATTERN_10")
if [[ "$HITS_10" -eq 0 ]]; then
    print_ok 8 "構成位置混入(構成解説禁止 v1.5.0)"
else
    print_ng 8 "構成位置混入(構成解説禁止 v1.5.0)" "$HITS_10"
    awk_show "$TMP_NOLANG" "$PATTERN_10"
    printf "%s   ↑ 字形位置説明(上に○下に○)は禁止。3パターン分類のみで解説%s\n" "$YELLOW" "$RESET"
fi

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# [9/N] ★v1.5.0★ 印象表現混入(字形描写禁止 — 設計書 ② 削除対象 #4,#5)
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# - 「ごっつい字」「線多めの繁体字」「ぎゅっと詰まった」「骨太」「縦長」のような
#   字の見た目を擬人化/形容する印象表現は禁止
# - これらは「画数禁止ルール E」の代替として使われてきたが(v1.4.0)、
#   v1.5.0 では Phase 2 自体を 3 パターン分類に絞るため、印象表現も全削除
# - 検査対象: <lang>/<sub> 剥がし版($TMP_NOLANG)
PATTERN_11='ごっつい|線多め|画数モリモリ|ぎゅっと詰まった|がっつり|骨太|縦長|横広|三層構造|格子状|シャープな字|あっさり字'

HITS_11=$(awk_count "$TMP_NOLANG" "$PATTERN_11")
if [[ "$HITS_11" -eq 0 ]]; then
    print_ok 9 "印象表現混入(字形描写禁止 v1.5.0)"
else
    print_ng 9 "印象表現混入(字形描写禁止 v1.5.0)" "$HITS_11"
    awk_show "$TMP_NOLANG" "$PATTERN_11"
    printf "%s   ↑ 印象表現(ごっつい/線多め/骨太 etc)は画数禁止の代替として認めない。" "$YELLOW"
    printf "3パターン分類で解説%s\n" "$RESET"
fi

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# [10/N] ★v1.5.0★ 古字部品 <sub alias> 引用(設計書 ② 削除対象 #3)
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# - 字解説で「<sub alias="アニ">豈</sub>」「<sub alias="ヒキ">疋</sub>」のような
#   古字部品引用が頻発 → これも字形構成解説の一種なので禁止
# - 注: 普通の漢字に対する <sub alias> 読み付与(博多→はかた)は正当用法なので、
#   "古字部品" に限定する(豈/几/疋/巴/兌/挖/穴 — 設計書 ② #3 リスト)
# - 検査対象: 元ファイル(<sub> は剥がさない、内容を見たいので)
#   ただし .md 抽出済みの場合は $FILE = TMP_XML_ONLY 状態でも同じ書式で OK
# - PATTERN_12: alias 属性付き <sub> タグで、中身が古字部品集合のいずれか
PATTERN_12='<sub alias=["'"'"']?(アニ|キ|ヒキ|ハ|ダ|セツ|ホン|テン)["'"'"']?[^>]*>(豈|几|疋|巴|兌|挖|穴)</sub>'

HITS_12=$(awk_count "$FILE" "$PATTERN_12")
if [[ "$HITS_12" -eq 0 ]]; then
    print_ok 10 "古字部品<sub alias>引用(v1.5.0)"
else
    print_ng 10 "古字部品<sub alias>引用(v1.5.0)" "$HITS_12"
    awk_show "$FILE" "$PATTERN_12"
    printf "%s   ↑ 古字部品(豈/几/疋/巴/兌/挖/穴)の <sub alias> 引用は v1.5.0 で全廃。" "$YELLOW"
    printf "字形構成解説の一種%s\n" "$RESET"
fi

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# [11/N] Phase 0 ↔ Phase 2/3 不一致照合(--strict のみ)
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# - Phase 0 の「| ペア | 単語1 | 単語2 | 単語3 | 単語4 |」表の単語と、
#   Phase 2/3 の <lang xml:lang="cmn-TW">X</lang> に登場する単語を照合
# - 構造的整合性チェック、誤検出余地があるので --strict 限定
if [[ $STRICT -eq 1 ]]; then
    # Phase 0 表の単語抽出
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

    # Phase 2/3 に登場する <lang xml:lang="cmn-TW">単語</lang> を抽出
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

    # Phase 0 にあるが Phase 2/3 にない単語を抽出
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
        print_warn 11 "Phase 0↔Phase 2/3 照合" "Phase 0 表が見つからず照合スキップ"
    elif [[ -z "$MISSING" ]]; then
        print_ok 11 "Phase 0↔Phase 2/3 照合"
    else
        miss_count=$(printf '%s' "$MISSING" | awk 'NF{c++} END{print c+0}')
        print_ng 11 "Phase 0↔Phase 2/3 照合" "$miss_count"
        printf "%s   Phase 0 表にあるが Phase 2/3 に出てこん単語:%s\n" "$DIM" "$RESET"
        printf '%s' "$MISSING" | while IFS= read -r m; do
            [[ -n "$m" ]] && printf "%s   - %s%s\n" "$DIM" "$m" "$RESET"
        done
    fi

    # ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    # [12/N] 効果音マーカー網羅(--strict のみ)
    # ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    # - <!-- explain --> マーカー数と <speak> ブロック数の一致
    MARKER_COUNT=$(awk_count "$FILE" '<!-- explain -->')
    SPEAK_COUNT=$(awk_count "$FILE" '<speak>')

    if [[ "$SPEAK_COUNT" -eq 0 ]]; then
        print_warn 12 "効果音マーカー網羅" "<speak> ブロックなし、照合スキップ"
    elif [[ "$MARKER_COUNT" -eq "$SPEAK_COUNT" ]]; then
        print_ok 12 "効果音マーカー網羅($MARKER_COUNT / $SPEAK_COUNT)"
    else
        DIFF=$((SPEAK_COUNT - MARKER_COUNT))
        [[ $DIFF -lt 0 ]] && DIFF=$((-DIFF))
        print_ng 12 "効果音マーカー網羅" "$DIFF"
        printf "%s   <speak> ブロック数=%d, <!-- explain --> マーカー数=%d%s\n" \
            "$DIM" "$SPEAK_COUNT" "$MARKER_COUNT" "$RESET"
    fi

    # ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    # [13/N] ★v1.5.1★ PATTERN_6C: 短文+3点固定検出(Phase 4 限定・--strict のみ)
    # ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    # - 設計書 ① 1.3「★Critical #2 反映:Phase 4 限定スコープ★」
    # - 問題: 短い例文(≦9 codepoint)に対して「ひとつ目」「ふたつ目」「みっつ目」を
    #         水増しして 3 ポイント無理矢理出すパターンを検出
    # - スコープ: Phase 4 セクション限定
    #   - .xml ファイル: ファイル全体を Phase 4 として扱う
    #   - .md ファイル: '### Phase 4:' 〜 次の '###' or '---' までを awk range で切り出す
    # - 例文長判定:
    #   - Phase 4 末尾リピート行の <lang xml:lang="cmn-TW">...</lang> 中身を抽出
    #   - perl -CSD で codepoint カウント(句読点・空白除外)
    #   - 9 codepoint 以下を「短文」と定義
    # - 3点固定検出: Phase 4 範囲内で「ひとつ目」「ふたつ目」「みっつ目」全出現
    #
    # 注: Phase 4 範囲が見つからない / 例文が見つからない場合は SKIP(warn)
    TMP_PHASE4=$(mktemp -t v5lint.XXXXXX) || { echo "mktemp 失敗" >&2; exit 2; }

    # Phase 4 セクション抽出
    # - .xml: 既に xml なのでファイル全体を Phase 4 と見なす
    # - .md: '### Phase 4' から次の '###' or '---' or '## ' まで
    if [[ "${EXT}" == "md" ]] || [[ $IS_MD_FILE -eq 1 ]]; then
        # .md 由来時は ORIG_FILE から Phase 4 抽出(TMP_XML_ONLY だと既に xml だけ)
        # ただしホストの ORIG_FILE = .md なので、ORIG_FILE から抽出する
        awk '
            /^### Phase 4:/ { flag=1; print; next }
            flag && /^### / { flag=0; next }
            flag && /^## / { flag=0; next }
            flag && /^---/ { flag=0; next }
            flag { print }
        ' "$ORIG_FILE" > "$TMP_PHASE4"
    else
        # .xml ファイル: 全体を Phase 4 として扱う
        cp "$FILE" "$TMP_PHASE4"
    fi

    if [[ ! -s "$TMP_PHASE4" ]]; then
        print_warn 13 "PATTERN_6C 短文+3点固定検出(v1.5.1)" "Phase 4 セクション抽出失敗、スキップ"
    else
        # 末尾リピート行の <lang xml:lang="cmn-TW">...</lang> 中身を抽出(複数行対応)
        # 一行に複数の <lang> がある場合、全部の中身をまとめる
        LANG_CONTENT=$(perl -CSAD -ne '
            while (/<lang\s+xml:lang="cmn-TW">([^<]+)<\/lang>/g) {
                print "$1\n";
            }
        ' "$TMP_PHASE4")

        # 例文長判定: 最も長い <lang> 内容を「例文」とみなす(リピート行は同じ例文の繰り返し)
        # 句読点・空白除外で codepoint カウント
        EXAMPLE_LEN=0
        if [[ -n "$LANG_CONTENT" ]]; then
            EXAMPLE_LEN=$(printf '%s' "$LANG_CONTENT" | perl -CSAD -e '
                my $max = 0;
                while (my $line = <STDIN>) {
                    chomp $line;
                    # 句読点・空白除去(全角/半角)
                    $line =~ s/[，。、！？\s,.\!\?]//g;
                    my $len = length($line);
                    $max = $len if $len > $max;
                }
                print $max;
            ')
        fi

        # 3点固定検出: Phase 4 範囲内で「ひとつ目」「ふたつ目」「みっつ目」全出現
        HAS_HITOTSUME=$(awk '/ひとつ目/ {c++} END {print c+0}' "$TMP_PHASE4")
        HAS_FUTATSUME=$(awk '/ふたつ目/ {c++} END {print c+0}' "$TMP_PHASE4")
        HAS_MITTSUME=$(awk '/みっつ目/ {c++} END {print c+0}' "$TMP_PHASE4")

        ALL_THREE=0
        if [[ "$HAS_HITOTSUME" -gt 0 ]] && [[ "$HAS_FUTATSUME" -gt 0 ]] && [[ "$HAS_MITTSUME" -gt 0 ]]; then
            ALL_THREE=1
        fi

        # 判定: 短文 (≦9) かつ 3点全出現
        if [[ "$EXAMPLE_LEN" -eq 0 ]]; then
            print_warn 13 "PATTERN_6C 短文+3点固定検出(v1.5.1)" \
                "Phase 4 内に <lang> 例文なし、スキップ"
        elif [[ "$EXAMPLE_LEN" -le 9 ]] && [[ "$ALL_THREE" -eq 1 ]]; then
            NG_COUNT=$((NG_COUNT + 1))
            printf "%s❌ [13/%d] PATTERN_6C 短文+3点固定検出(v1.5.1): 短文(%d cp)+3点固定%s\n" \
                "$RED" "$TOTAL_CHECKS" "$EXAMPLE_LEN" "$RESET"
            printf "%s   例文長: %d codepoint(≦9 = 短文判定)、" "$DIM" "$EXAMPLE_LEN"
            printf "ひとつ目/ふたつ目/みっつ目 全部出現%s\n" "$RESET"
            printf "%s   ↑ 短い例文に 3 ポイント水増しは禁止。" "$YELLOW"
            printf "Phase 4 で 2 ポイントに減らすか動的化を検討%s\n" "$RESET"
        else
            if [[ "$EXAMPLE_LEN" -gt 9 ]]; then
                printf "%s✅ [13/%d] PATTERN_6C 短文+3点固定検出(v1.5.1): OK(例文 %d cp > 9 = 長文)%s\n" \
                    "$GREEN" "$TOTAL_CHECKS" "$EXAMPLE_LEN" "$RESET"
            else
                printf "%s✅ [13/%d] PATTERN_6C 短文+3点固定検出(v1.5.1): OK(短文だが3点固定なし)%s\n" \
                    "$GREEN" "$TOTAL_CHECKS" "$RESET"
            fi
        fi
    fi
    rm -f "$TMP_PHASE4" 2>/dev/null
fi

# ───────────────────────── サマリ ─────────────────────────
echo ""
printf "%s━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━%s\n" "$BOLD" "$RESET"
if [[ "$NG_COUNT" -eq 0 ]]; then
    printf "%s%sOK: 全 %d カテゴリでヒットゼロや。次のモジュールへ進んでええで✨%s\n" \
        "$GREEN" "$BOLD" "$TOTAL_CHECKS" "$RESET"
    exit 0
else
    printf "%s%sNG: %d カテゴリで検出。該当モジュールを再生成してな🔥%s\n" \
        "$RED" "$BOLD" "$NG_COUNT" "$RESET"
    exit 1
fi
