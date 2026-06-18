#!/usr/bin/env bash
# v5-modular-lint.sh — SSML モジュール式教材 投稿前チェッカー
#
# 設計書: tmp/v1.6.1-design/DESIGN.md(本ファイルは v1.6.1 改修反映済み)
#         前提: tmp/v1.6.0-design/DESIGN.md ④ / tmp/v1.5.1-design/DESIGN.md ①
# 用途: 各モジュール生成直後に走らせ、鬼門ワード/単独漢字/二度読み等の
#       NG パターンを 1 秒以内に検出する。
# 終了コード:
#   0 = ヒットゼロ(OK、次モジュールへ進んでよい)
#   1 = ヒットあり(NG、該当モジュール再生成必須)
#   2 = 引数エラー / 内部エラー(辞書バリデーション失敗含む)
#
# 使い方:
#   bash scripts/v5-modular-lint.sh <ファイルパス>
#   bash scripts/v5-modular-lint.sh --strict <ファイルパス>           # 全体整合系の追加チェック
#   bash scripts/v5-modular-lint.sh --allowlist <list-file> <file>     # PATTERN_13 用語スルーリスト
#   bash scripts/v5-modular-lint.sh --auto-allowlist <issue-body> <f>  # ★v1.6.1 — 2E★ Issue 本文から自動 allowlist 化
#   bash scripts/v5-modular-lint.sh --llm-unavailable <file>           # native-checker 未実施明示
#   bash scripts/v5-modular-lint.sh --pre-post [--issue <N>] <file>    # 投稿直前モード(PATTERN_15 偽装検出)
#   bash scripts/v5-modular-lint.sh --pre-post --pattern15-bypass "<理由>" <f>  # ★v1.6.1 — 2E★ PATTERN_15 偽陽性経路
#
# v1.6.1 改修 — 2E 反映(本ファイル ★今回):
#   - --auto-allowlist <issue-body-file> モード(設計書 ⑦ 7.1-7.3):
#       * Issue 本文の `### 例文ペア` セクション内の中国語パートを awk で抽出
#       * ng-thesaurus.yaml(PATTERN_13 NG 辞書)と grep -F 突合
#       * ヒットしたワードを自動 allowlist 化(既存 --allowlist と統合)
#       * 「衆議院」「在班上」のような学習対象 NG ワードが自動スルー
#       * 中国語パート抽出ロジック:
#         - `### 例文ペア` 見出し以降、次の `### ` 見出し or EOF まで
#         - 各行をタブで分割、最初のフィールド(タブ前) = 中国語
#         - タブ無し行はスキップ(Markdown フェンス / 空行 / 説明文)
#         - ```markdown ... ``` フェンス内のみを対象(外は無視)
#       * 既存 --allowlist と組合せ可能(両方の語が allowlist として登録される)
#       * Issue 本文ファイル不在 → exit 2(明示エラー)
#   - --pattern15-bypass <理由> モード(設計書 ④.5 / ⑦):
#       * PATTERN_15 誤検出時の偽陽性報告経路
#       * --pre-post と併用必須(他モードでは無視)
#       * <理由> は非空文字列必須(空なら exit 2)
#       * PATTERN_15 NG 検出時に bypass フラグで NG_COUNT 加算をスキップ
#       * 代わりに ⚠️ 警告として bypass 理由を表示
#       * 投稿側(SKILL.md Step 7 末尾)で「bypass 使用: 理由」を明示する義務付き
#       * 検出ロジック側は通常通り走らせる(誤検出を可視化、可観測性は保つ)
#   - 干渉解消(設計書 5.4):
#       * --auto-allowlist で allowlist 増えた分、林老師必須化(2D)対象も増える可能性
#       * 「判定割れリスト」ベース(2D)で限定済み = 干渉なし
#       * lint.sh は判定割れリスト機構を持たない(2D で SKILL.md 側に実装)
#
# v1.6.1 改修 — 2C 継承:
#   - PATTERN_15 マーカー方式 本実装(設計書 ④ 4.1-4.6 反映):
#       * 主検出: HTML コメントマーカー(<!-- NATIVE_CHECK_STATUS: ... -->)抽出
#                + 物理ログ tmp/native-check/<issue>-pair*.json 突合
#                + マーカー status と JSON verdict の整合性検証
#       * マーカー不在 → Step 5.5 未実行疑い → NG
#       * 物理ログ不在 → 偽装疑い → NG
#       * マーカー status と JSON verdict 不一致 → NG
#       * 補助検出(警告レベル): 旧偽装語彙リテラル
#         - PATTERN_15_AUX_WARN: 'Opus.*sanity|Opus.*代替|コスト面で重'
#         - grep -F の AND 判定(言い換え耐性、警告レベルのみ、NG_COUNT 不加算)
#   - --pre-post モード: PATTERN_15 を Step 7 投稿直前のみ起動
#       * Step 6a per-module XML では走らせない(設計書 ④.4)
#       * --pre-post 不在時は [14/14] PATTERN_15 を常に skip(NG_COUNT 無影響)
#       * Issue 番号取得: --issue <N> 明示 > 環境変数 V5_ISSUE_NUMBER > glob フォールバック
#   - ERE 統一(設計書 ④.6 反映): BRE エスケープ `\|` 全廃 → ERE 素の `|` で記述
#       * `\s` は ERE 標準外 → `[[:space:]]` に正規化
#       * 既存パターン内の `\|` は本ファイル(2B)で既に GNU grep -E 互換で書き換え済み
#
# v1.6.1 改修 — 2B 継承:
#   - PATTERN_6C を --strict 限定から「デフォルト 14 カテゴリ」側に昇格(設計書 ③ 反映)
#       * per-module XML 入力時のスコープ条件:
#         - ファイル名に `phase4` を含む xml → 走らせる
#         - md ファイルで `### Phase 4:` 見出し存在 → 走らせる
#         - それ以外は print_warn でスキップ表示(NG_COUNT 増やさない)
#       * Phase 1 ベース SSML の短文ペアで「ひとつ目/ふたつ目/みっつ目」が偶発的に
#         出ても偽陽性 NG にならないこと保証(スコープ外なら warn のみ)
#   - 番号体系明文化(設計書 ③ 3.2 反映):
#         PATTERN_6C  → [11/14]  (デフォルト昇格)
#         PATTERN_13  → [12/14]  (デフォルト維持)
#         PATTERN_14  → [13/14]  (デフォルト維持)
#         PATTERN_15  → [14/14]  (--pre-post 専用、★2C 本実装★)
#         TOTAL_CHECKS → 12 → 14
#   - --strict 拡張(全体整合系)は番号体系を分離:
#         Phase 0↔Phase 2/3 照合  → [S1/14] サブカテゴリ表示
#         効果音マーカー網羅      → [S2/14] サブカテゴリ表示
#       理由: 設計書の予約番号 [11..14] と衝突させず、--strict 起動時の追加項目
#             として明確に区別する
#
# v1.6.0 改修(継承):
#   - PATTERN_13: 既知 NG 熟語辞書(YAML、上限 100 語、メタ文字禁止)
#   - PATTERN_14: Phase 1 末尾リピート 2 回検証
#   - `--llm-unavailable`: native-checker-v1 Skill 未起動時用
#
# v1.5.1 改修(継承):
#   - PATTERN_6B: 「文法ポイント、見ていくで」逃げ表現検出
#                      (ホワイトリスト方式: 「N つ」明示があれば素通し)
#   - PATTERN_6C: Phase 4 限定スコープで「短文 + 3点固定」検出
#                      (v1.5.1: --strict のみ → v1.6.1: デフォルト昇格)
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
AUTO_ALLOWLIST_FILE=""        # v1.6.1 — 2E: --auto-allowlist <issue-body-file>
LLM_UNAVAILABLE=0
NG_THESAURUS_FILE=""
PRE_POST=0
ISSUE_NUMBER=""
PATTERN15_BYPASS_REASON=""    # v1.6.1 — 2E: --pattern15-bypass <理由>
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
        --auto-allowlist)
            # v1.6.1 — 2E: Issue 本文ファイルを解析して中国語パートを自動 allowlist 化
            # 設計書 ⑦: ng-thesaurus.yaml と突合してヒット語を allowlist 注入
            i=$((i+1))
            AUTO_ALLOWLIST_FILE="${args[$((i-1))]:-}"
            if [[ -z "$AUTO_ALLOWLIST_FILE" ]] || [[ "$AUTO_ALLOWLIST_FILE" == --* ]]; then
                echo "${RED}ERROR: --auto-allowlist の直後に Issue 本文ファイルパスを指定してな${RESET}" >&2
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
        --pre-post)
            # v1.6.1 — 2C 本実装: 投稿直前モード(PATTERN_15 偽装検出)
            # マーカー方式 + 物理ログ突合(tmp/native-check/<issue>-pair*.json)
            PRE_POST=1
            ;;
        --issue)
            # v1.6.1 — 2C: Issue 番号明示指定(--pre-post と併用)
            # 物理ログファイル名 tmp/native-check/<issue>-pair*.json の <issue> 部
            i=$((i+1))
            ISSUE_NUMBER="${args[$((i-1))]:-}"
            if [[ -z "$ISSUE_NUMBER" ]] || [[ "$ISSUE_NUMBER" == --* ]]; then
                echo "${RED}ERROR: --issue の直後に Issue 番号を指定してな(例: --issue 27)${RESET}" >&2
                exit 2
            fi
            if ! [[ "$ISSUE_NUMBER" =~ ^[0-9]+$ ]]; then
                echo "${RED}ERROR: --issue は正の整数のみ: $ISSUE_NUMBER${RESET}" >&2
                exit 2
            fi
            ;;
        --pattern15-bypass)
            # v1.6.1 — 2E: PATTERN_15 偽陽性報告経路
            # --pre-post と併用必須、<理由> 非空必須
            # NG 検出時に NG_COUNT 加算をスキップし、bypass 警告で可視化
            i=$((i+1))
            PATTERN15_BYPASS_REASON="${args[$((i-1))]:-}"
            if [[ -z "$PATTERN15_BYPASS_REASON" ]] || [[ "$PATTERN15_BYPASS_REASON" == --* ]]; then
                echo "${RED}ERROR: --pattern15-bypass の直後に理由を文字列で指定してな(例: --pattern15-bypass '偽陽性: Opus 言及はネタ)${RESET}" >&2
                exit 2
            fi
            ;;
        -h|--help)
            cat <<'EOF'
Usage: v5-modular-lint.sh [--strict] [--allowlist <file>] [--auto-allowlist <issue-body>]
                          [--ng-thesaurus <file>] [--llm-unavailable]
                          [--pre-post [--issue <N>] [--pattern15-bypass <理由>]] <file>

  --strict          全体整合系の追加チェック(S1/S2 サブカテゴリ)
                    [S1] Phase 0↔Phase 2/3 不一致照合
                    [S2] 効果音マーカー網羅

  --allowlist <f>   PATTERN_13 用語スルーリスト(1 行 1 単語)
                    Issue 本文 / Phase 0 サマリ表に登場する語を自動 allowlist 化
                    例: 衆議院 / 博多 / 元(げん) などの学習対象固有名詞

  --auto-allowlist <issue-body-file>
                    ★v1.6.1 — 2E★ Issue 本文から自動 allowlist 化(設計書 ⑦)
                    Issue 本文の `### 例文ペア` 内の中国語パートを awk で抽出 →
                    ng-thesaurus.yaml と突合 → ヒット語を自動 allowlist 化
                    例: 「在班上」を含む例文ペアなら、その語を自動スルー
                    --allowlist と併用可(両方の語が allowlist として登録される)

  --ng-thesaurus <f>
                    PATTERN_13 NG 熟語辞書 YAML パス指定(省略時はデフォルト)
                    デフォルト探索順:
                      1. <スクリプト同階層>/ng-thesaurus.yaml
                      2. .claude/skills/audio-lesson-v5/scripts/ng-thesaurus.yaml

  --llm-unavailable native-checker-v1 Skill が起動できなかった場合のモード
                    終了サマリに「LLM ネイティブチェック未実施」を明示
                    既知 NG 熟語辞書(PATTERN_13)のみで基本品質確保

  --pre-post        ★v1.6.1 — 2C 本実装★ 投稿直前モード([14/14] PATTERN_15 偽装検出)
                    マーカー方式 + 物理ログ(tmp/native-check/)突合
                    Step 6a per-module XML では走らせない(Step 7 投稿前のみ)
                    主検出: <!-- NATIVE_CHECK_STATUS: ... --> マーカー +
                            tmp/native-check/<issue>-pair*.json verdict 突合
                    補助検出(警告): Opus.*sanity / コスト面で重 等の旧偽装語彙

  --issue <N>       ★v1.6.1 — 2C★ Issue 番号明示指定(--pre-post と併用必須)
                    物理ログファイル名 tmp/native-check/<N>-pair*.json の <N> 部
                    省略時は env V5_ISSUE_NUMBER → ファイル名推定 → glob フォールバック

  --pattern15-bypass <理由>
                    ★v1.6.1 — 2E★ PATTERN_15 偽陽性報告経路(設計書 ④.5)
                    --pre-post と併用必須、<理由> 非空文字列必須
                    PATTERN_15 NG 検出時に bypass フラグで NG_COUNT 加算をスキップ
                    代わりに ⚠️ 警告として bypass 理由を表示(検出は通常通り走らせる)
                    使用時は SKILL.md Step 7 末尾でも明示義務
                    例: --pattern15-bypass '偽陽性: Opus 言及は教育文脈のメタ説明'

  デフォルト 14 カテゴリ / --strict は +S1/S2 / --pre-post は [14] が active:
    [1/14]   鬼門ワード(ルールE)
    [2/14]   単独漢字裸出し(ルールA)
    [3/14]   二度読み禁止(ルールC)
    [4/14]   繋辞NG(v4 #3)
    [5/14]   Markdown 強調(v4 #10)
    [6/14]   文法ポイント固定文化(動的化)
    [6B/14]  文法ポイント逃げ表現(v1.5.1 ホワイトリスト方式)
    [7/14]   部首名混入(構成解説禁止 v1.5.0)
    [8/14]   構成位置混入(構成解説禁止 v1.5.0)
    [9/14]   印象表現混入(字形描写禁止 v1.5.0)
    [10/14]  古字部品 <sub alias> 引用(v1.5.0)
    [11/14]  ★v1.6.1★ PATTERN_6C 短文+3点固定 Phase 4 限定(デフォルト昇格)
    [12/14]  PATTERN_13 既知 NG 熟語辞書(v1.6.0、allowlist 注入対応)
    [13/14]  PATTERN_14 Phase 1 末尾リピート 2 回検証(v1.6.0)
    [14/14]  ★v1.6.1 — 2C★ PATTERN_15 偽装検出(--pre-post 専用、本実装完了)
    [S1/14]  Phase 0↔Phase 2/3 照合(--strict のみ、サブカテゴリ)
    [S2/14]  効果音マーカー網羅(--strict のみ、サブカテゴリ)

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
    echo "Usage: $0 [--strict] [--allowlist <f>] [--ng-thesaurus <f>] [--llm-unavailable] [--pre-post] <file>" >&2
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

# v1.6.1 — 2E: --auto-allowlist 引数バリデーション
if [[ -n "$AUTO_ALLOWLIST_FILE" ]] && [[ ! -f "$AUTO_ALLOWLIST_FILE" ]]; then
    echo "${RED}ERROR: --auto-allowlist Issue 本文ファイルが見つからん: $AUTO_ALLOWLIST_FILE${RESET}" >&2
    exit 2
fi

# v1.6.1 — 2E: --pattern15-bypass は --pre-post と併用必須
if [[ -n "$PATTERN15_BYPASS_REASON" ]] && [[ $PRE_POST -eq 0 ]]; then
    echo "${RED}ERROR: --pattern15-bypass は --pre-post と併用必須(他モードでは PATTERN_15 自体起動しない)${RESET}" >&2
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
# v1.6.1: 番号体系明文化(設計書 ③ 3.2)
#   - PATTERN_6C  [11/14] デフォルト昇格(v1.5.1 は --strict のみ → v1.6.1 でデフォルト)
#   - PATTERN_13  [12/14] NG 熟語辞書(v1.6.0)
#   - PATTERN_14  [13/14] Phase 1 リピート 2 回(v1.6.0)
#   - PATTERN_15  [14/14] 偽装検出(--pre-post 専用、本ファイル(2B)では枠のみ)
#   - --strict 拡張(全体整合系)は [S1/14], [S2/14] サブカテゴリ表示で番号衝突回避
#   - TOTAL_CHECKS: 12 → 14
NG_COUNT=0
TOTAL_CHECKS=14

# 一時ファイル(<lang>剥がし版、コードフェンス潰し版、xml抽出版、メタ領域版、辞書語抽出版、auto-allowlist 抽出版)
TMP_NOLANG=$(mktemp -t v5lint.XXXXXX) || { echo "mktemp 失敗" >&2; exit 2; }
TMP_NOFENCE=$(mktemp -t v5lint.XXXXXX) || { echo "mktemp 失敗" >&2; exit 2; }
TMP_XML_ONLY=$(mktemp -t v5lint.XXXXXX) || { echo "mktemp 失敗" >&2; exit 2; }
TMP_META=$(mktemp -t v5lint.XXXXXX) || { echo "mktemp 失敗" >&2; exit 2; }
TMP_NG_WORDS=$(mktemp -t v5lint.XXXXXX) || { echo "mktemp 失敗" >&2; exit 2; }
TMP_ALLOWLIST=$(mktemp -t v5lint.XXXXXX) || { echo "mktemp 失敗" >&2; exit 2; }
TMP_AUTO_ALLOWLIST=$(mktemp -t v5lint.XXXXXX) || { echo "mktemp 失敗" >&2; exit 2; }   # v1.6.1 — 2E
TMP_ISSUE_ZH=$(mktemp -t v5lint.XXXXXX) || { echo "mktemp 失敗" >&2; exit 2; }         # v1.6.1 — 2E
trap 'rm -f "$TMP_NOLANG" "$TMP_NOFENCE" "$TMP_XML_ONLY" "$TMP_META" "$TMP_NG_WORDS" "$TMP_ALLOWLIST" "$TMP_AUTO_ALLOWLIST" "$TMP_ISSUE_ZH" 2>/dev/null' EXIT

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

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# v1.6.1 — 2E: --auto-allowlist 処理(設計書 ⑦)
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Issue 本文から `### 例文ペア` セクションを抽出 → 中国語パートを ng-thesaurus.yaml と
# 突合 → ヒット語を $TMP_AUTO_ALLOWLIST に書き出す → 後段 PATTERN_13 で
# $TMP_ALLOWLIST と統合し allowlist として効かせる
#
# 抽出ロジック:
#   1. `### 例文ペア` 見出し以降、次の `### ` 見出し or EOF まで を切り出し
#   2. ```markdown ... ``` フェンス内のみ対象(外は無視)
#   3. 各行をタブ(\t)で分割、最初のフィールド = 中国語
#   4. タブ無し行はスキップ(空行 / フェンス / 説明文)
#   5. CJK 文字 1 個以上を含む行のみ採用
#
# 突合ロジック:
#   - ng-thesaurus.yaml の word: フィールド全リストを抽出
#   - 各 NG 語につき、中国語パート行のいずれかに grep -F で部分一致するなら allowlist 採用
AUTO_ALLOWLIST_HIT_COUNT=0
if [[ -n "$AUTO_ALLOWLIST_FILE" ]]; then
    # Step 1+2: `### 例文ペア` セクションかつ ```markdown ... ``` フェンス内のみ抽出
    awk '
        BEGIN { in_section=0; in_fence=0 }
        # `### 例文ペア` 見出し検出 → セクション開始
        /^### *例文ペア/ { in_section=1; next }
        # 次の `### ` 見出し or `## ` → セクション終了
        in_section && /^#{2,3}[[:space:]]+/ { in_section=0; next }
        # セクション内の ``` フェンス開閉
        in_section && /^```/ {
            if (in_fence) { in_fence=0 }
            else { in_fence=1 }
            next
        }
        in_section && in_fence { print }
    ' "$AUTO_ALLOWLIST_FILE" > "$TMP_ISSUE_ZH.raw"

    # Step 3+4+5: タブ分割 → 最初のフィールド(中国語パート)抽出
    # CJK 文字を含む行のみ採用(空行・記号のみ行を弾く)
    perl -CSAD -ne '
        chomp;
        # タブで分割、最初のフィールドのみ
        my @parts = split /\t/, $_;
        next unless @parts >= 1;
        my $zh = $parts[0];
        # 前後空白トリム
        $zh =~ s/^\s+//;
        $zh =~ s/\s+$//;
        next if $zh eq "";
        # CJK 文字を含まなければスキップ
        # CJK Unified Ideographs: U+4E00–U+9FFF
        # CJK Unified Ideographs Extension A: U+3400–U+4DBF
        # 注音などは含めない(allowlist 対象はあくまで漢字熟語)
        next unless $zh =~ /[\x{4e00}-\x{9fff}\x{3400}-\x{4dbf}]/;
        print "$zh\n";
    ' "$TMP_ISSUE_ZH.raw" > "$TMP_ISSUE_ZH"
    rm -f "$TMP_ISSUE_ZH.raw" 2>/dev/null

    # 突合: ng-thesaurus.yaml の word: リストと突合
    if [[ -n "$NG_THESAURUS_FILE" ]] && [[ -r "$NG_THESAURUS_FILE" ]] && [[ -s "$TMP_ISSUE_ZH" ]]; then
        # ng-thesaurus.yaml から word: のみ抽出(PATTERN_13 と同じパーサ)
        awk '
            /^[[:space:]]*-?[[:space:]]*word:[[:space:]]*/ {
                sub(/^[[:space:]]*-?[[:space:]]*word:[[:space:]]*/, "")
                gsub(/^["\x27]|["\x27][[:space:]]*$/, "")
                sub(/[[:space:]]*$/, "")
                if (length($0) > 0) print
            }
        ' "$NG_THESAURUS_FILE" > "$TMP_AUTO_ALLOWLIST.dict"

        # 各 NG 語につき、Issue 中国語パート行のいずれかに grep -F で含まれるか確認
        # 含まれれば自動 allowlist 採用
        : > "$TMP_AUTO_ALLOWLIST"
        while IFS= read -r ng_word; do
            [[ -z "$ng_word" ]] && continue
            if grep -Fq -- "$ng_word" "$TMP_ISSUE_ZH"; then
                echo "$ng_word" >> "$TMP_AUTO_ALLOWLIST"
                AUTO_ALLOWLIST_HIT_COUNT=$((AUTO_ALLOWLIST_HIT_COUNT + 1))
            fi
        done < "$TMP_AUTO_ALLOWLIST.dict"
        rm -f "$TMP_AUTO_ALLOWLIST.dict" 2>/dev/null
    fi
fi

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
[[ $PRE_POST -eq 1 ]] && printf "%s(--pre-post: 投稿直前モード、PATTERN_15 偽装検出 active)%s\n" "$YELLOW" "$RESET"
[[ -n "$NG_THESAURUS_FILE" ]] && printf "%sNG 辞書: %s%s\n" "$DIM" "$NG_THESAURUS_FILE" "$RESET"
[[ -n "$ALLOWLIST_FILE" ]] && printf "%sallowlist: %s%s\n" "$DIM" "$ALLOWLIST_FILE" "$RESET"
if [[ -n "$AUTO_ALLOWLIST_FILE" ]]; then
    printf "%sauto-allowlist: %s (Issue 本文から %d 語自動採用)%s\n" \
        "$DIM" "$AUTO_ALLOWLIST_FILE" "$AUTO_ALLOWLIST_HIT_COUNT" "$RESET"
fi
[[ -n "$PATTERN15_BYPASS_REASON" ]] && printf "%spattern15-bypass: %s%s\n" "$YELLOW" "$PATTERN15_BYPASS_REASON" "$RESET"
if [[ $PRE_POST -eq 1 ]]; then
    _hdr_issue=""
    if [[ -n "$ISSUE_NUMBER" ]]; then
        _hdr_issue="$ISSUE_NUMBER (--issue)"
    elif [[ -n "${V5_ISSUE_NUMBER:-}" ]] && [[ "${V5_ISSUE_NUMBER}" =~ ^[0-9]+$ ]]; then
        _hdr_issue="$V5_ISSUE_NUMBER (env V5_ISSUE_NUMBER)"
    fi
    [[ -n "$_hdr_issue" ]] && printf "%sIssue: #%s%s\n" "$DIM" "$_hdr_issue" "$RESET"
    unset _hdr_issue
fi
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
# [11/14] ★v1.6.1★ PATTERN_6C 短文+3点固定検出(Phase 4 限定、デフォルト昇格)
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# 設計書 ③ 反映: --strict 限定からデフォルト 14 カテゴリ側に昇格
# per-module XML 入力時のスコープ条件:
#   - ファイル名に `phase4` を含む xml → 走らせる
#   - md ファイルで `### Phase 4:` 見出し存在 → 走らせる
#   - それ以外は print_warn でスキップ表示(NG_COUNT 増やさない)
# → Phase 1 ベース SSML の短文ペアで「ひとつ目/ふたつ目/みっつ目」が偶発的に
#   出ても偽陽性 NG にならないこと保証

# スコープ判定(設計書 ③ 3.1 厳密遵守)
#   - ファイル名に `phase4` を含む xml → in-scope
#   - md ファイルで `### Phase 4:` 見出し存在 → in-scope
#   - それ以外は warn(NG_COUNT 増やさない)
# Phase 1 ベース SSML 短文ペアで「ひとつ目/ふたつ目/みっつ目」が偶発的に
# 出ても偽陽性 NG にならないこと保証(偽陽性防止の主目的)
PHASE4_IN_SCOPE=0
PHASE4_SCOPE_REASON=""
ORIG_BASENAME="$(basename "$ORIG_FILE")"
if [[ "$ORIG_BASENAME" == *phase4* ]]; then
    PHASE4_IN_SCOPE=1
    PHASE4_SCOPE_REASON="ファイル名に 'phase4' を含む"
elif [[ $IS_MD_FILE -eq 1 ]] && grep -qE '^### Phase 4[:：]' "$ORIG_FILE" 2>/dev/null; then
    PHASE4_IN_SCOPE=1
    PHASE4_SCOPE_REASON=".md に '### Phase 4:' 見出しあり"
fi

if [[ $PHASE4_IN_SCOPE -eq 0 ]]; then
    # スコープ外 → 偽陽性防止のため warn のみ、NG_COUNT は増やさない
    print_warn 11 "PATTERN_6C 短文+3点固定検出(v1.6.1 デフォルト昇格)" \
        "Phase 4 スコープ外、スキップ($ORIG_BASENAME)"
else
    TMP_PHASE4=$(mktemp -t v5lint.XXXXXX) || { echo "mktemp 失敗" >&2; exit 2; }
    if [[ $IS_MD_FILE -eq 1 ]]; then
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
        print_warn 11 "PATTERN_6C 短文+3点固定検出(v1.6.1)" \
            "Phase 4 セクション抽出失敗、スキップ"
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
                    $line =~ s/[，。、!?\s,.\!\?]//g;
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
            print_warn 11 "PATTERN_6C 短文+3点固定検出(v1.6.1)" \
                "Phase 4 内に <lang> 例文なし、スキップ"
        elif [[ "$EXAMPLE_LEN" -le 9 ]] && [[ "$ALL_THREE" -eq 1 ]]; then
            NG_COUNT=$((NG_COUNT + 1))
            printf "%s❌ [11/%d] PATTERN_6C 短文+3点固定検出(v1.6.1): 短文(%d cp)+3点固定%s\n" \
                "$RED" "$TOTAL_CHECKS" "$EXAMPLE_LEN" "$RESET"
            printf "%s   例文長: %d codepoint(≦9 = 短文判定)、" "$DIM" "$EXAMPLE_LEN"
            printf "ひとつ目/ふたつ目/みっつ目 全部出現%s\n" "$RESET"
            printf "%s   ↑ 短い例文に 3 ポイント水増しは禁止。" "$YELLOW"
            printf "Phase 4 で 2 ポイントに減らすか動的化を検討%s\n" "$RESET"
        else
            if [[ "$EXAMPLE_LEN" -gt 9 ]]; then
                printf "%s✅ [11/%d] PATTERN_6C 短文+3点固定検出(v1.6.1): OK(例文 %d cp > 9 = 長文)%s\n" \
                    "$GREEN" "$TOTAL_CHECKS" "$EXAMPLE_LEN" "$RESET"
            else
                printf "%s✅ [11/%d] PATTERN_6C 短文+3点固定検出(v1.6.1): OK(短文だが3点固定なし)%s\n" \
                    "$GREEN" "$TOTAL_CHECKS" "$RESET"
            fi
        fi
    fi
    rm -f "$TMP_PHASE4" 2>/dev/null
fi

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# [12/14] ★v1.6.0★ PATTERN_13 既知 NG 熟語辞書(YAML)
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
    print_warn 12 "PATTERN_13 既知 NG 熟語辞書(v1.6.0)" "辞書 YAML 未発見、スキップ"
    NG_DICT_OK=0
elif [[ ! -r "$NG_THESAURUS_FILE" ]]; then
    print_warn 12 "PATTERN_13 既知 NG 熟語辞書(v1.6.0)" "辞書 YAML 読めん: $NG_THESAURUS_FILE"
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
    # v1.6.1 — 2E: --allowlist と --auto-allowlist の両方を統合
    : > "$TMP_ALLOWLIST"
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
        ' "$ALLOWLIST_FILE" >> "$TMP_ALLOWLIST"
    fi
    # v1.6.1 — 2E: --auto-allowlist の結果を統合(重複は後段の grep -Fxq で吸収)
    if [[ -s "$TMP_AUTO_ALLOWLIST" ]]; then
        cat "$TMP_AUTO_ALLOWLIST" >> "$TMP_ALLOWLIST"
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
            print_warn 12 "PATTERN_13 既知 NG 熟語辞書(v1.6.0)" "辞書 0 語、スキップ"
        else
            ALLOWLIST_COUNT=0
            [[ -s "$TMP_ALLOWLIST" ]] && ALLOWLIST_COUNT=$(wc -l < "$TMP_ALLOWLIST" | tr -d '[:space:]')
            # v1.6.1 — 2E: auto-allowlist の内訳を表示
            if [[ "$AUTO_ALLOWLIST_HIT_COUNT" -gt 0 ]]; then
                print_ok 12 "PATTERN_13 既知 NG 熟語辞書(v1.6.0、辞書 ${NG_WORD_COUNT} 語 / allowlist ${ALLOWLIST_COUNT} 語 [うち auto ${AUTO_ALLOWLIST_HIT_COUNT}])"
            else
                print_ok 12 "PATTERN_13 既知 NG 熟語辞書(v1.6.0、辞書 ${NG_WORD_COUNT} 語 / allowlist ${ALLOWLIST_COUNT} 語)"
            fi
        fi
    else
        print_ng 12 "PATTERN_13 既知 NG 熟語辞書(v1.6.0)" "$NG13_HITS"
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
# [13/14] ★v1.6.0★ PATTERN_14 Phase 1 末尾リピート 2 回検証
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
    print_warn 13 "PATTERN_14 Phase 1 リピート 2 回検証(v1.6.0)" "Phase 1 セクションなし、スキップ"
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
        print_ok 13 "PATTERN_14 Phase 1 リピート 2 回検証(v1.6.0、${PHASE1_BLOCK_COUNT} ブロック)"
    else
        print_ng 13 "PATTERN_14 Phase 1 リピート 2 回検証(v1.6.0)" "$PATTERN_14_NG"
        printf "%s%s%s" "$DIM" "$PATTERN_14_DETAIL" "$RESET"
        printf "%s   ↑ v1.6.0 で Phase 1 末尾リピートを 2 回に戻し。" "$YELLOW"
        printf "テンプレ: 「ほな、もう一度聞いてみよか…<break time=\"1.5s\"/>…はい、もういっぺん。」%s\n" "$RESET"
    fi
fi
rm -f "$TMP_PHASE1" 2>/dev/null

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# [14/14] ★v1.6.1 — 2C 本実装★ PATTERN_15 偽装検出(--pre-post 専用)
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# 設計書 ④ 4.1-4.6 反映: 投稿直前モードで「林老師チェック実施」と称した偽装を機械検出
#
# ── 検出方式 ──
# 主検出(NG_COUNT 加算):
#   1. HTML マーカー抽出 — <!-- NATIVE_CHECK_STATUS: done|skipped:xxx|partial:N/M -->
#      不在 → Step 5.5 未実行疑い → NG
#   2. 物理ログ突合 — tmp/native-check/<issue>-pair*.json 存在検証
#      done / partial 表明だが JSON 不在 → 偽装疑い → NG
#   3. マーカー status ↔ JSON verdict 整合性検証
#      done 表明だが verdict=error/unknown 残り → 偽装疑い → NG
#      partial:N/M 表明だが 実 approved 数 ≠ N → 数値偽装疑い → NG
# 補助検出(NG_COUNT 不加算、警告レベル):
#   - 旧偽装語彙リテラル: 'Opus.*sanity' 'Opus.*代替' 'コスト面で重'
#   - grep -F の AND 判定(言い換え耐性、警告のみで誤検出許容)
#
# ── スコープ ──
# --pre-post でのみ起動。Step 6a per-module XML では走らせない(設計書 ④.4)。
# --pre-post 不在時は表示自体スキップ(NG_COUNT 無影響)。
#
# ── Issue 番号取得優先順位 ──
# 1. --issue <N> 明示指定
# 2. 環境変数 V5_ISSUE_NUMBER
# 3. ファイル名から推定(comment-body.md などに #N 含まれる場合)
# 4. tmp/native-check/*-pair*.json glob で唯一の Issue 番号があれば採用
# 5. 全部失敗 → 物理ログ突合スキップ(マーカー only 判定で続行 + 警告)
#
# 番号体系: [14/14] = TOTAL_CHECKS 上限。
if [[ $PRE_POST -eq 1 ]]; then
    # ── v1.6.1 — 2E: --pattern15-bypass 対応ヘルパ ──
    # NG 検出時に bypass フラグがあれば NG_COUNT 加算をスキップし、bypass 警告に格下げ
    # 通常 NG 経路は print_ng 14 を使うが、bypass 時は print_warn 相当に変換
    p15_emit_ng() {
        # $1 = 詳細メッセージ
        local detail="$1"
        if [[ -n "$PATTERN15_BYPASS_REASON" ]]; then
            # bypass 時: 警告レベル + bypass 理由表示、NG_COUNT 加算なし
            printf "%s⚠️  [14/%d] PATTERN_15 偽装検出(v1.6.1) — bypass 適用%s\n" \
                "$YELLOW" "$TOTAL_CHECKS" "$RESET"
            printf "%s   検出内容: %s%s\n" "$DIM" "$detail" "$RESET"
            printf "%s   bypass 理由: %s%s\n" "$YELLOW" "$PATTERN15_BYPASS_REASON" "$RESET"
            printf "%s   ⚠️ bypass 使用は内部メモに記録し、SKILL.md Step 7 末尾で明示すること%s\n" \
                "$YELLOW" "$RESET"
        else
            print_ng 14 "PATTERN_15 偽装検出(v1.6.1)" 1
            printf "%s   %s%s\n" "$DIM" "$detail" "$RESET"
        fi
    }

    # ── マーカー regex(ERE 統一、`\s` → `[[:space:]]`、素の `|` で alternation) ──
    PATTERN_15_MARKER_REGEX='<!--[[:space:]]*NATIVE_CHECK_STATUS:[[:space:]]*(done|skipped:[a-z_]+|partial:[0-9]+/[0-9]+)[[:space:]]*-->'

    # 補助検出: 旧偽装語彙(警告レベル、grep -F の AND 判定で言い換え耐性確保)
    # 設計書 ④.4: 'Opus.*sanity|Opus.*代替|コスト面で重'
    # AND 判定(Opus と sanity 両方含むなら警告 / 同じく Opus+代替 / コスト面+重)
    PATTERN_15_AUX_WARNS=0
    PATTERN_15_AUX_DETAILS=""

    # ペア (語1, 語2) の AND 判定
    # ★重要★ 旧偽装語彙は通常コメント本文(.md の ```xml ブロック外)に出るため、
    # マーカー検出と同様 ORIG_FILE 側で検査(設計書 ④.4)
    aux_check_pair() {
        local word1="$1"
        local word2="$2"
        local label="$3"
        if grep -Fq -- "$word1" "$ORIG_FILE" && grep -Fq -- "$word2" "$ORIG_FILE"; then
            PATTERN_15_AUX_WARNS=$((PATTERN_15_AUX_WARNS + 1))
            local line1
            line1=$(grep -nF -- "$word1" "$ORIG_FILE" | head -n 1 || true)
            local line2
            line2=$(grep -nF -- "$word2" "$ORIG_FILE" | head -n 1 || true)
            PATTERN_15_AUX_DETAILS="${PATTERN_15_AUX_DETAILS}  ${label}: '${word1}' L${line1%%:*} + '${word2}' L${line2%%:*}"$'\n'
        fi
    }
    aux_check_pair "Opus" "sanity" "Opus×sanity"
    aux_check_pair "Opus" "代替" "Opus×代替"
    aux_check_pair "コスト面" "重" "コスト面×重"

    # ── Issue 番号確定 ──
    P15_ISSUE="$ISSUE_NUMBER"
    if [[ -z "$P15_ISSUE" ]] && [[ -n "${V5_ISSUE_NUMBER:-}" ]]; then
        if [[ "$V5_ISSUE_NUMBER" =~ ^[0-9]+$ ]]; then
            P15_ISSUE="$V5_ISSUE_NUMBER"
        fi
    fi
    if [[ -z "$P15_ISSUE" ]]; then
        # ファイル名から推定(例: issue27-comment.md / 27-body.md / comment-body27.md)
        _fname_basename="$(basename "$ORIG_FILE")"
        if [[ "$_fname_basename" =~ ([0-9]+) ]]; then
            P15_ISSUE="${BASH_REMATCH[1]}"
        fi
        unset _fname_basename
    fi
    if [[ -z "$P15_ISSUE" ]]; then
        # glob フォールバック: tmp/native-check/*-pair*.json で唯一の Issue があれば採用
        if [[ -d tmp/native-check ]]; then
            _unique_issues=$(ls tmp/native-check/ 2>/dev/null | \
                grep -E '^[0-9]+-pair[0-9]+\.json$' | \
                sed -E 's/^([0-9]+)-pair[0-9]+\.json$/\1/' | sort -u)
            _unique_count=$(printf '%s\n' "$_unique_issues" | grep -c . || true)
            if [[ "$_unique_count" == "1" ]]; then
                P15_ISSUE="$_unique_issues"
            fi
            unset _unique_issues _unique_count
        fi
    fi

    # ── 主検出 Step 1: マーカー抽出 ──
    # ★重要★ マーカー <!-- NATIVE_CHECK_STATUS: ... --> は通常コメント本文(.md の
    # ```xml ブロック外)に埋め込まれるため、必ず ORIG_FILE(差し替え前)で検索する。
    # .md ファイル時に $FILE は ```xml 抽出版に差し替わっているため、そちらを見ると
    # マーカーを取りこぼす(設計書 ④.4 で「コメント本文」と明記)。
    MARKER_LINE=$(grep -E "$PATTERN_15_MARKER_REGEX" "$ORIG_FILE" | head -n 1 || true)

    if [[ -z "$MARKER_LINE" ]]; then
        # マーカー不在 = Step 5.5 未実行疑い
        p15_emit_ng "マーカー <!-- NATIVE_CHECK_STATUS: ... --> 不在。Step 5.5 未実行疑い"
        if [[ -z "$PATTERN15_BYPASS_REASON" ]]; then
            printf "%s   ↑ 林老師チェック実施なら native-checker-v1 Skill 戻り値の" "$YELLOW"
            printf " marker フィールドをコメント本文末尾に必ず埋め込め%s\n" "$RESET"
        fi
    else
        # マーカー status 抽出(done / skipped:xxx / partial:N/M)
        # マッチ部分のみ取り出して中身解析
        MARKER_STATUS=$(printf '%s' "$MARKER_LINE" | \
            grep -oE "$PATTERN_15_MARKER_REGEX" | head -n 1 | \
            sed -E 's/^<!--[[:space:]]*NATIVE_CHECK_STATUS:[[:space:]]*//; s/[[:space:]]*-->$//')

        # 物理ログ存在チェック
        P15_LOG_DIR="tmp/native-check"
        P15_LOG_EXISTS=0
        P15_LOG_COUNT=0
        P15_VERDICTS=""
        if [[ -n "$P15_ISSUE" ]] && [[ -d "$P15_LOG_DIR" ]]; then
            # ls + grep で glob 抽出(BSD/GNU 両対応、null-glob 回避)
            _matched_logs=$(ls "$P15_LOG_DIR" 2>/dev/null | \
                grep -E "^${P15_ISSUE}-pair[0-9]+\.json$" || true)
            if [[ -n "$_matched_logs" ]]; then
                P15_LOG_EXISTS=1
                P15_LOG_COUNT=$(printf '%s\n' "$_matched_logs" | grep -c . || true)
                # verdict 抽出(各 JSON から "verdict": "xxx" 部分のみ拾う)
                while IFS= read -r _logname; do
                    [[ -z "$_logname" ]] && continue
                    _logpath="$P15_LOG_DIR/$_logname"
                    [[ ! -f "$_logpath" ]] && continue
                    _v=$(grep -oE '"verdict"[[:space:]]*:[[:space:]]*"[a-z_]+"' "$_logpath" 2>/dev/null | \
                        head -n 1 | \
                        sed -E 's/.*"verdict"[[:space:]]*:[[:space:]]*"([a-z_]+)".*/\1/')
                    if [[ -n "$_v" ]]; then
                        P15_VERDICTS="${P15_VERDICTS}${_v}"$'\n'
                    fi
                done <<< "$_matched_logs"
            fi
            unset _matched_logs _logname _logpath _v
        fi

        # マーカー status 別の整合性検証
        P15_NG_REASON=""
        case "$MARKER_STATUS" in
            done)
                # done = 全ペア approved or needs_changes(置換適用済み)
                # 物理ログ突合必須
                if [[ -z "$P15_ISSUE" ]]; then
                    P15_NG_REASON="マーカー 'done' だが Issue 番号未指定で物理ログ突合不可(--issue <N> または env V5_ISSUE_NUMBER を指定)"
                elif [[ $P15_LOG_EXISTS -eq 0 ]]; then
                    P15_NG_REASON="マーカー 'done' だが ${P15_LOG_DIR}/${P15_ISSUE}-pair*.json が不在 = 偽装疑い"
                else
                    # verdict が error/unknown のペアが残ってないか
                    _bad_verdicts=$(printf '%s' "$P15_VERDICTS" | grep -E '^(error|unknown)$' | wc -l | tr -d '[:space:]')
                    if [[ "$_bad_verdicts" -gt 0 ]]; then
                        P15_NG_REASON="マーカー 'done' だが物理ログに verdict=error/unknown が ${_bad_verdicts} 件残存 = 偽陰性疑い(partial:N/M で書け)"
                    fi
                    unset _bad_verdicts
                fi
                ;;
            partial:*)
                # partial:N/M 形式の整合性
                if [[ -z "$P15_ISSUE" ]]; then
                    P15_NG_REASON="マーカー 'partial' だが Issue 番号未指定で物理ログ突合不可"
                elif [[ $P15_LOG_EXISTS -eq 0 ]]; then
                    P15_NG_REASON="マーカー '${MARKER_STATUS}' だが ${P15_LOG_DIR}/${P15_ISSUE}-pair*.json が不在 = 偽装疑い"
                else
                    # N/M 抽出して実 approved 数と突合
                    _claimed_n=$(printf '%s' "$MARKER_STATUS" | sed -E 's|^partial:([0-9]+)/([0-9]+)$|\1|')
                    _claimed_m=$(printf '%s' "$MARKER_STATUS" | sed -E 's|^partial:([0-9]+)/([0-9]+)$|\2|')
                    _actual_approved=$(printf '%s' "$P15_VERDICTS" | grep -E '^(approved|needs_changes)$' | wc -l | tr -d '[:space:]')
                    if [[ "$_actual_approved" != "$_claimed_n" ]]; then
                        P15_NG_REASON="マーカー 'partial:${_claimed_n}/${_claimed_m}' だが物理ログの approved+needs_changes 実数=${_actual_approved} 件 = 数値偽装疑い"
                    elif [[ "$P15_LOG_COUNT" != "$_claimed_m" ]]; then
                        P15_NG_REASON="マーカー 'partial:${_claimed_n}/${_claimed_m}' だが物理ログ総数=${P15_LOG_COUNT} 件 (M 不一致)"
                    fi
                    unset _claimed_n _claimed_m _actual_approved
                fi
                ;;
            skipped:*)
                # skipped は理由カテゴリのみ検査(user_dropdown_choice / tool_unavailable / circuit_breaker 等)
                # 物理ログは不在でも OK(skipped は実行してないので JSON 出さなくて正常)
                _skip_reason="${MARKER_STATUS#skipped:}"
                if [[ -z "$_skip_reason" ]]; then
                    P15_NG_REASON="マーカー 'skipped:' だが理由カテゴリ未指定"
                fi
                unset _skip_reason
                ;;
            *)
                P15_NG_REASON="マーカー status '${MARKER_STATUS}' は未知の値"
                ;;
        esac

        if [[ -z "$P15_NG_REASON" ]]; then
            # 整合 OK
            _ok_detail="status=${MARKER_STATUS}"
            if [[ -n "$P15_ISSUE" ]]; then
                _ok_detail="${_ok_detail}, issue=#${P15_ISSUE}"
            fi
            if [[ $P15_LOG_EXISTS -eq 1 ]]; then
                _ok_detail="${_ok_detail}, log=${P15_LOG_COUNT} files"
            fi
            print_ok 14 "PATTERN_15 偽装検出(v1.6.1、${_ok_detail})"
            unset _ok_detail
        else
            p15_emit_ng "$P15_NG_REASON"
            if [[ -z "$PATTERN15_BYPASS_REASON" ]]; then
                printf "%s   ↑ 林老師チェックの実施 / マーカー / 物理ログの三者を整合させろ。" "$YELLOW"
                printf "skipped で出すなら理由カテゴリも明示%s\n" "$RESET"
            fi
        fi
    fi

    # 補助検出(警告レベルのみ、NG_COUNT 加算しない)
    if [[ "$PATTERN_15_AUX_WARNS" -gt 0 ]]; then
        printf "%s⚠️  [14/%d] PATTERN_15 補助検出(警告): 旧偽装語彙 %d ペア%s\n" \
            "$YELLOW" "$TOTAL_CHECKS" "$PATTERN_15_AUX_WARNS" "$RESET"
        printf "%s%s%s" "$DIM" "$PATTERN_15_AUX_DETAILS" "$RESET"
        printf "%s   ↑ 主検出は通過したが、旧偽装語彙(「Opus 内部 sanity check」「コスト面で重」等)" "$YELLOW"
        printf "がコメント本文に残存。誤検出なら本文を書き直せ%s\n" "$RESET"
    fi
fi

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# [S1/14] Phase 0 ↔ Phase 2/3 不一致照合(--strict のみ、サブカテゴリ)
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# v1.6.1: 番号体系明文化(設計書 ③)に伴い [13/N] → [S1/14] サブカテゴリ番号に変更
# 理由: 設計書予約番号 [11..14] と衝突させない。--strict は全体整合系の追加項目扱い。
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
        print_warn "S1" "Phase 0↔Phase 2/3 照合" "Phase 0 表が見つからず照合スキップ"
    elif [[ -z "$MISSING" ]]; then
        print_ok "S1" "Phase 0↔Phase 2/3 照合"
    else
        miss_count=$(printf '%s' "$MISSING" | awk 'NF{c++} END{print c+0}')
        print_ng "S1" "Phase 0↔Phase 2/3 照合" "$miss_count"
        printf "%s   Phase 0 表にあるが Phase 2/3 に出てこん単語:%s\n" "$DIM" "$RESET"
        printf '%s' "$MISSING" | while IFS= read -r m; do
            [[ -n "$m" ]] && printf "%s   - %s%s\n" "$DIM" "$m" "$RESET"
        done
    fi

    # ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    # [S2/14] 効果音マーカー網羅(--strict のみ、サブカテゴリ)
    # ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    # v1.6.1: [14/N] → [S2/14] サブカテゴリ番号に変更
    MARKER_COUNT=$(awk_count "$FILE" '<!-- explain -->')
    SPEAK_COUNT=$(awk_count "$FILE" '<speak>')

    if [[ "$SPEAK_COUNT" -eq 0 ]]; then
        print_warn "S2" "効果音マーカー網羅" "<speak> ブロックなし、照合スキップ"
    elif [[ "$MARKER_COUNT" -eq "$SPEAK_COUNT" ]]; then
        print_ok "S2" "効果音マーカー網羅($MARKER_COUNT / $SPEAK_COUNT)"
    else
        DIFF=$((SPEAK_COUNT - MARKER_COUNT))
        [[ $DIFF -lt 0 ]] && DIFF=$((-DIFF))
        print_ng "S2" "効果音マーカー網羅" "$DIFF"
        printf "%s   <speak> ブロック数=%d, <!-- explain --> マーカー数=%d%s\n" \
            "$DIM" "$SPEAK_COUNT" "$MARKER_COUNT" "$RESET"
    fi

    # 注: v1.5.1 PATTERN_6C は v1.6.1 で [11/14] デフォルト昇格済み(本ファイル上部)
    # → --strict 内の重複 PATTERN_6C ブロックは廃止
fi

# ───────────────────────── サマリ ─────────────────────────
echo ""
printf "%s━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━%s\n" "$BOLD" "$RESET"

if [[ $LLM_UNAVAILABLE -eq 1 ]]; then
    printf "%s※ native-checker-v1 Skill 未起動(--llm-unavailable)。" "$YELLOW"
    printf "ネイティブ感チェックは PATTERN_13 辞書のみ。投稿コメント末尾に「林老師チェック未実施」明記推奨%s\n" "$RESET"
fi

# v1.6.1 — 2E: --pattern15-bypass 使用記録(SKILL.md Step 7 末尾義務化用)
if [[ -n "$PATTERN15_BYPASS_REASON" ]]; then
    printf "%s※ --pattern15-bypass 使用: %s%s\n" "$YELLOW" "$PATTERN15_BYPASS_REASON" "$RESET"
    printf "%s   投稿コメント末尾(SKILL.md Step 7)で同じ理由を明示する義務あり%s\n" "$YELLOW" "$RESET"
fi

# v1.6.1 — 2E: --auto-allowlist 採用語の記録
if [[ -n "$AUTO_ALLOWLIST_FILE" ]] && [[ "$AUTO_ALLOWLIST_HIT_COUNT" -gt 0 ]]; then
    printf "%s※ auto-allowlist: %d 語を Issue 本文から自動採用%s\n" "$DIM" "$AUTO_ALLOWLIST_HIT_COUNT" "$RESET"
    if [[ -s "$TMP_AUTO_ALLOWLIST" ]]; then
        while IFS= read -r _w; do
            [[ -z "$_w" ]] && continue
            printf "%s   - %s%s\n" "$DIM" "$_w" "$RESET"
        done < "$TMP_AUTO_ALLOWLIST"
        unset _w
    fi
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
