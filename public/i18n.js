// SSML MP3 Studio — i18n モジュール
// 日本語(関西弁ギャルヤンキー) / 繁体字台湾華語の2言語切替
// グローバル window.I18N に dict / 言語切替 / DOM 反映ユーティリティを束ねる

(function () {
  // --- 辞書本体 ---
  // key 命名規則: <section>.<purpose>(_template の付くやつは {placeholder} 置換あり)
  const dict = {
    ja: {
      // ヘッダー
      "header.title": "SSML MP3 Studio",
      "header.subtitle": "SSML を貼って、日中混在の学習音声を MP3 で書き出す（試験公開版）",
      "header.beta": "β",
      "lang.ja_label": "🇯🇵 JA",
      "lang.tw_label": "🇹🇼 繁",

      // 利用案内カード
      "notice.body":
        "✨ 無料で使える試験公開版です。台湾華語学習者向け(初級者〜上級者)に、日本語＋台湾華語(繁体字)の段階的中国語化 SSML から MP3 を生成します。",
      "notice.limit": "🐛 上限: 1 ユーザーあたり 1 日 4 回まで(運用コスト抑制のため)",

      // 声の設定
      "voice.section_title": "1. 声の設定",
      "voice.ja_label": "日本語の声",
      "voice.zh_label": "中国語の声",
      "voice.ja_speed_label": "日本語の速度",
      "voice.zh_speed_label": "中国語の速度",
      "voice.hint":
        "※ SSML 内の <lang xml:lang=\"zh-…\"> で囲まれた中国語部分が、自動で「中国語の声」＋「中国語の速度」に切り替わるで。",

      // SSML 入力
      "ssml.section_title": "2. SSML を貼る",
      "ssml.intro":
        "<speak>...</speak> で囲まれた SSML を 1 個貼り付けてください。5000 バイト上限です。",
      "ssml.placeholder": "<speak>...</speak> をここに貼って",
      "ssml.sample_btn": "サンプル投入",
      "ssml.byte_count_template": "{bytes} バイト / 約5000バイト上限",

      // 生成ボタン・ステータス
      "generate.btn": "🔊 MP3 生成",
      "status.no_ssml": "⚠️ SSML を貼ってや",
      "status.no_speak": "⚠️ SSML は <speak>...</speak> で囲んでな",
      "status.over_size": "⚠️ SSML が 5000 バイトを超えとる。短くしてな",
      "status.generating": "⏳ 生成中…",
      "status.success_template":
        "✅ 生成できたで! ({size_kb} KB) 下で再生 / DL してな",
      "status.error_template": "❌ エラー: {message}",
      "status.limit_reached_template":
        "❌ 今日の利用上限に達したで。明日また使ってな (上限 {dailyLimit} 回/日)",
      "status.network_error_template": "❌ 通信エラー: {message}",
      "rate.info_template": "今日の残り利用回数: {remaining} / {dailyLimit} 回",
      "result.download_btn": "⬇ ダウンロード",

      // フッター
      "footer.copy": "© SSML MP3 Studio β",
    },

    tw: {
      // ヘッダー
      "header.title": "SSML MP3 Studio",
      "header.subtitle": "貼上 SSML，將中日混合的學習音檔輸出為 MP3（試用公開版）",
      "header.beta": "β",
      "lang.ja_label": "🇯🇵 日",
      "lang.tw_label": "🇹🇼 繁",

      // 利用案内カード
      "notice.body":
        "✨ 這是免費的試用公開版。為台灣華語學習者(初級〜進階)，從日語＋台灣華語(繁體字)漸進中文化的 SSML 生成 MP3。",
      "notice.limit": "🐛 上限：每位使用者每日 4 次（為控制運作成本）",

      // 声の設定
      "voice.section_title": "1. 語音設定",
      "voice.ja_label": "日語語音",
      "voice.zh_label": "華語語音",
      "voice.ja_speed_label": "日語速度",
      "voice.zh_speed_label": "華語速度",
      "voice.hint":
        "※ SSML 中以 <lang xml:lang=\"zh-…\"> 包起來的華語部分，會自動切換為「華語語音」＋「華語速度」。",

      // SSML 入力
      "ssml.section_title": "2. 貼上 SSML",
      "ssml.intro":
        "請貼上一段以 <speak>...</speak> 包覆的 SSML。上限為 5000 位元組。",
      "ssml.placeholder": "請貼上 <speak>...</speak>",
      "ssml.sample_btn": "載入範例",
      "ssml.byte_count_template": "{bytes} 位元組 / 約 5000 位元組上限",

      // 生成ボタン・ステータス
      "generate.btn": "🔊 生成 MP3",
      "status.no_ssml": "⚠️ 請貼上 SSML",
      "status.no_speak": "⚠️ SSML 需要用 <speak>...</speak> 包起來",
      "status.over_size": "⚠️ SSML 超過 5000 位元組，請縮短",
      "status.generating": "⏳ 生成中…",
      "status.success_template":
        "✅ 生成完成！({size_kb} KB) 下方可播放 / 下載",
      "status.error_template": "❌ 錯誤: {message}",
      "status.limit_reached_template":
        "❌ 已達今日使用上限，請明天再試 (上限每日 {dailyLimit} 次)",
      "status.network_error_template": "❌ 連線錯誤: {message}",
      "rate.info_template": "今日剩餘使用次數: {remaining} / {dailyLimit} 次",
      "result.download_btn": "⬇ 下載",

      // フッター
      "footer.copy": "© SSML MP3 Studio β",
    },
  };

  // --- {name} プレースホルダ置換ヘルパ ---
  function interpolate(template, replacements) {
    if (!template) return "";
    if (!replacements) return template;
    return template.replace(/\{(\w+)\}/g, (m, k) =>
      Object.prototype.hasOwnProperty.call(replacements, k) ? String(replacements[k]) : m
    );
  }

  // --- 本体 ---
  const I18N = {
    dict: dict,
    currentLang: "ja",

    // 指定キーの文言を返す。replacements で {name} を埋める
    t(key, replacements = {}) {
      const lang = this.currentLang in this.dict ? this.currentLang : "ja";
      const val = (this.dict[lang] && this.dict[lang][key]) || this.dict.ja[key] || key;
      return interpolate(val, replacements);
    },

    // data-i18n 属性付き要素を全部洗ってテキスト or 指定属性を上書き
    applyI18n() {
      const nodes = document.querySelectorAll("[data-i18n]");
      nodes.forEach((el) => {
        const key = el.getAttribute("data-i18n");
        if (!key) return;
        const text = this.t(key);
        const attrName = el.getAttribute("data-i18n-attr");
        if (attrName) {
          el.setAttribute(attrName, text);
        } else {
          el.textContent = text;
        }
      });
    },

    // 言語切替本体: state / localStorage / <html lang> / DOM / トグル aria-pressed を全部同期
    setLang(lang) {
      const next = lang === "tw" ? "tw" : "ja";
      this.currentLang = next;
      try {
        localStorage.setItem("ssml_mp3_studio_lang", next);
      } catch (e) {
        // localStorage 不可環境(プライベートブラウズ等)は無視
      }
      document.documentElement.lang = next === "tw" ? "zh-TW" : "ja";
      this.applyI18n();

      // 国旗トグルの押下状態
      const jaBtn = document.getElementById("langJa");
      const twBtn = document.getElementById("langTw");
      if (jaBtn) jaBtn.setAttribute("aria-pressed", next === "ja" ? "true" : "false");
      if (twBtn) twBtn.setAttribute("aria-pressed", next === "tw" ? "true" : "false");

      // 動的に組み立てるテキスト(app.js の byteCount/rateInfo 等)に再描画機会を提供
      window.dispatchEvent(new CustomEvent("langchange", { detail: { lang: next } }));
    },

    // 初回起動時の言語推定: localStorage → navigator.language → デフォ ja
    detectInitialLang() {
      try {
        const saved = localStorage.getItem("ssml_mp3_studio_lang");
        if (saved === "ja" || saved === "tw") return saved;
      } catch (e) {
        // 無視
      }
      const navLang = (navigator.language || "").toString();
      if (/^zh|^tw/i.test(navLang)) return "tw";
      return "ja";
    },
  };

  // グローバル公開
  window.I18N = I18N;

  // --- 初期化: DOM 構築後に言語決定 → トグルにイベント登録 ---
  window.addEventListener("DOMContentLoaded", () => {
    const initial = I18N.detectInitialLang();
    I18N.setLang(initial);

    const jaBtn = document.getElementById("langJa");
    const twBtn = document.getElementById("langTw");
    if (jaBtn) jaBtn.addEventListener("click", () => I18N.setLang("ja"));
    if (twBtn) twBtn.addEventListener("click", () => I18N.setLang("tw"));
  });
})();
