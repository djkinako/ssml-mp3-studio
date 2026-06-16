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
      "ssml.byte_count_template": "{bytes} バイト / 目標 4000 バイト以内",

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

      // ⓘ 情報モーダル
      "info.button_aria": "情報を開く",
      "modal.close_label": "閉じる",
      "modal.tab_changelog": "更新履歴",
      "modal.tab_privacy": "プライバシー",
      "modal.tab_terms": "利用上の注意",
      "version.label_template": "現在のバージョン: v{version}",

      // 法的文書本文(HTML)
      "about.privacy_body": "<p><strong>プライバシーポリシー</strong></p><p>本サービス(SSML MP3 Studio β、以下「本サービス」)は、利用者のプライバシーを尊重し、必要最小限の情報のみを取り扱います。</p><p><strong>1. 収集する情報</strong><br />本サービスは、レート制限および乱用防止を目的として、利用者の IP アドレス、利用日付、当日の利用回数を Firebase Firestore に記録します。また、UI 設定および表示言語を利用者のブラウザの localStorage に保存します。</p><p><strong>2. 利用目的</strong><br />収集した情報は、1 IP あたりの 1 日の利用回数制限(乱用防止)およびサービス品質の維持にのみ使用します。利用者を個人として特定する目的では使用しません。</p><p><strong>3. 第三者提供</strong><br />入力された SSML テキストは、音声合成のため Google Cloud Text-to-Speech API に送信されます。Google による取り扱いは Google のポリシーに従います。サーバー基盤として Google Firebase を使用しています。</p><p><strong>4. 保存期間</strong><br />レート制限用のデータは当日のみ意味を持ち、クリーンアップポリシーにより自動的に削除されます。</p><p><strong>5. Cookie・トラッキング</strong><br />本サービスは Cookie および外部トラッキングツールを使用しません。localStorage の利用のみです。</p><p><strong>6. 問い合わせ</strong><br />本サービスは個人運営のため、お問い合わせは GitHub Issues に限定させていただきます。</p>",
      "about.terms_body": "<p><strong>利用上の注意・免責事項</strong></p><p>本サービス(SSML MP3 Studio β、以下「本サービス」)をご利用いただく前に、以下の事項に必ず同意ください。</p><p><strong>1. 生成結果の正確性</strong><br />本サービスが生成する音声および SSML の内容について、運営者は正確性・適切性を保証しません。教材その他の用途で使用される場合は、利用者の責任において内容を検証してください。生成結果に起因するいかなる損害についても、運営者は責任を負いません。</p><p><strong>2. 商用利用</strong><br />生成された音声の商用利用については、Google Cloud Text-to-Speech の利用規約に従ってください。運営者側で追加の制限は設けません。</p><p><strong>3. 禁止事項</strong><br />過度に大きな SSML、不正なコンテンツ、第三者の著作権を侵害するテキストの送信および音声化を禁止します。違反が認められた場合、利用を制限することがあります。</p><p><strong>4. サービスの提供</strong><br />本サービスは無料のβ試験運用であり、予告なく一時停止または終了する場合があります。</p><p><strong>5. サポート</strong><br />個人運営のため、サポートおよび問い合わせ対応は最小限となります。あらかじめご了承ください。</p>",
      "about.changelog_body": "<p><strong>更新履歴</strong></p><ul><li><strong>v3.1</strong>: ハカセとケンタくんのアバターをイラスト画像に置換。SSML 解説直前の効果音を公開版でも鳴るよう修正。送信時の SSML サイズを正確に計算して表示(目標 4000 バイト)。</li><li><strong>v3.0</strong>: プロンプトを双方向化(日本人 × 中国語学習 / 台湾人 × 日本語学習 両対応)。最初に母語・学習言語・レベル・入力スタイルを聞いてくる新方式に。</li><li><strong>v2.5</strong>: デザインを Frutiger Aero(Aqua Marine)に刷新。海グラデーション背景・気泡アニメ・ガラス感のあるカードに。文字サイズも全体的に大きく見やすく。</li><li><strong>v2.3 / v2.4</strong>: 冒頭にハカセとケンタくんの会話劇ランディングを追加。「SSML って何?」「このサイトは何を解決するの?」を分かりやすく解説。</li><li><strong>v2.2</strong>: ⓘ 情報モーダルとプロンプトコピーカードを追加。プライバシーポリシー・利用上の注意も整備。</li><li><strong>v2.1</strong>: 日本語と繁体字台湾華語の UI 切り替えに対応しました。お好みの言語で操作できます。</li><li><strong>v2.0</strong>: Firebase を利用したβ試験公開版を開始。API キーの入力が不要になり、ブラウザを開いてすぐ MP3 を生成できるようになりました(1 日あたりの利用回数に上限あり)。</li><li><strong>v1.0</strong>: 機能安定版としてリリース。UI の見直しと操作性の改善を行いました。</li><li><strong>v0.8</strong>: 複数ブロックを連結する際、ブロックの切れ目に効果音(チャイム)を挿入できるようになりました。</li><li><strong>v0.7</strong>: 中国語の解説のあとに、もう一度中国語の正解部分を読み上げる「リピート機能」を追加。学習効率が向上しました。</li><li><strong>v0.6</strong>: 複数の SSML をひとつの MP3 にまとめて書き出す機能を追加。例文集を 1 ファイルで管理できます。</li><li><strong>v0.1</strong>: 初回リリース。SSML を貼り付けて MP3 を生成・ダウンロードできる基本機能を提供。</li></ul>",

      // プロンプトコピーカード
      "prompt.title": "📋 学習音声 SSML を作るためのプロンプト",
      "prompt.intro": "ChatGPT や Claude にこのプロンプトを貼り付けたら、最初に「母語(日本人/台湾人)」「学習したい言語(日本語/中国語)」「レベル(初級/中級/上級)」を聞いてくるで。例文は日中ペアでも、片方の言語だけでもOK(AIが翻訳してくれる)。出てきた SSML を上の欄に貼って MP3 化してな。",
      "prompt.copy_btn": "プロンプトをコピー",
      "prompt.copy_success": "✓ コピーしたで",
      "prompt.copy_failed": "❌ コピー失敗、手動でコピーしてな",

      // ランディング会話劇(ハカセとケンタくん)
      "landing.hook": "中国語の勉強で <strong>「日本語と中国語が混ざった音声教材」</strong> が欲しい〜って思ったこと、ない?<br />このサイト、その悩みを解決するで。",
      "landing.title": "🎙️ このサイト、何ができるん?",
      "landing.subtitle": "ハカセとケンタくんの会話で解説するで",
      "landing.kenta_name": "ケンタ",
      "landing.hakase_name": "ハカセ",
      "landing.sample_title": "🎧 こんな感じの教材が作れるで",
      "landing.sample_desc": "実際に生成した MP3 のサンプルや。再生して雰囲気つかんでみて。",
      "landing.sample_caption": "(サンプル: 台湾華語 N1-N2 学習向け教材・約 1 分)",
      "landing.q1": "ハカセ、日本語と中国語が混ざった文章を AI に読ませると、なんか変な読み方になるんやけど…",
      "landing.a1": "ええとこに気づいたな。普通のAI音声合成は、メインの言語(例えば日本語)で全部読もうとするから、混ざってる中国語まで日本語っぽく読んでまうんや。これが「日中混在読み上げ問題」やな。",
      "landing.q2": "ほな、どうやって直すん?",
      "landing.a2": "<strong>SSML</strong> っていう「音声の指示書」を使うんや。たとえば「ここは日本語の声、ここは中国語の声、ちょっと速めに、ここで2秒の間」みたいに細かく指定できる。Google の TTS(音声合成)が SSML を読み取って、ちゃんと言語ごとに切替えてくれるんよ。",
      "landing.q3": "SSML って、難しいプログラミング言語ちゃうん? ボクが書けるんかな…",
      "landing.a3": "安心して。実は <strong>ChatGPT や Claude に教材作成のプロンプトを渡すと、SSML を全部書いてくれる</strong>んや。下に「学習音声 SSML を作るためのプロンプト」のコピーボタンがあるから、それを AI に貼り付けて、日本語+中国語の例文を渡すだけ。",
      "landing.q4": "おお、ほな AI が SSML 作ってくれて、それをここに貼ったら…",
      "landing.a4": "🎉 そのとおり! MP3 がダウンロードできて、すぐに耳から学習できる。<strong>筋トレ中・移動中の「ながら聴き」教材を自作できる</strong>んが、このサイトの売りやで。",
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
        "請貼上一段以 <speak>...</speak> 包覆的 SSML。上限為 5000 bytes。",
      "ssml.placeholder": "請貼上 <speak>...</speak>",
      "ssml.sample_btn": "載入範例",
      "ssml.byte_count_template": "{bytes} bytes / 目標 4000 bytes 以內",

      // 生成ボタン・ステータス
      "generate.btn": "🔊 生成 MP3",
      "status.no_ssml": "⚠️ 請貼上 SSML",
      "status.no_speak": "⚠️ SSML 需要用 <speak>...</speak> 包起來",
      "status.over_size": "⚠️ SSML 超過 5000 bytes,請縮短",
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

      // ⓘ 情報モーダル
      "info.button_aria": "開啟資訊",
      "modal.close_label": "關閉",
      "modal.tab_changelog": "更新紀錄",
      "modal.tab_privacy": "隱私權",
      "modal.tab_terms": "使用須知",
      "version.label_template": "目前版本: v{version}",

      // 法的文書本文(HTML)
      "about.privacy_body": "<p><strong>隱私權政策</strong></p><p>本服務(SSML MP3 Studio β,以下簡稱「本服務」)尊重使用者隱私,僅蒐集提供服務所必要的最少資訊。</p><p><strong>1. 蒐集之資訊</strong><br />為防止濫用並執行使用次數限制,本服務會將使用者的 IP 位址、使用日期及當日使用次數記錄於 Firebase Firestore。此外,介面設定與顯示語言會儲存於使用者瀏覽器的 localStorage。</p><p><strong>2. 利用目的</strong><br />所蒐集之資訊僅用於每 IP 每日使用次數限制(防止濫用)及維持服務品質,不會用於識別個人身分。</p><p><strong>3. 第三方提供</strong><br />使用者輸入的 SSML 文字會傳送至 Google Cloud Text-to-Speech API 以進行語音合成,相關處理依 Google 之政策辦理。本服務並使用 Google Firebase 作為伺服器基礎建設。</p><p><strong>4. 保存期間</strong><br />使用次數限制相關資料僅當日有效,並依清理政策自動刪除。</p><p><strong>5. Cookie 與追蹤</strong><br />本服務不使用 Cookie 或外部追蹤工具,僅使用 localStorage。</p><p><strong>6. 聯絡方式</strong><br />本服務由個人營運,相關詢問僅透過 GitHub Issues 處理。</p>",
      "about.terms_body": "<p><strong>使用須知與免責聲明</strong></p><p>使用本服務(SSML MP3 Studio β,以下簡稱「本服務」)前,請務必同意以下事項。</p><p><strong>1. 生成內容之正確性</strong><br />本服務所生成之語音與 SSML 內容,營運者不保證其正確性與適切性。若作為教材或其他用途使用,請使用者自行負責驗證內容。對於因使用生成結果而產生之任何損害,營運者概不負責。</p><p><strong>2. 商業使用</strong><br />生成語音之商業使用,請遵循 Google Cloud Text-to-Speech 之服務條款,營運者不另設額外限制。</p><p><strong>3. 禁止行為</strong><br />禁止傳送過大之 SSML、非法內容,或將侵害第三人著作權之文字進行語音化。如有違反,營運者得限制其使用權限。</p><p><strong>4. 服務之提供</strong><br />本服務為免費 Beta 試營運版本,得不經預告暫停或終止服務。</p><p><strong>5. 客戶支援</strong><br />本服務由個人營運,客服與詢問之回應將限於最低限度,敬請見諒。</p>",
      "about.changelog_body": "<p><strong>更新紀錄</strong></p><ul><li><strong>v3.1</strong>: 將博士與小健的頭像替換為插畫圖片。修正公開版中 SSML 解說前的音效未播放的問題。準確顯示傳送時的 SSML 大小(目標 4000 bytes 以內)。</li><li><strong>v3.0</strong>: 提示詞改為雙向支援(日本人 × 中文學習 / 台灣人 × 日語學習 雙向對應)。會先詢問母語、學習語言、程度、輸入方式的新模式。</li><li><strong>v2.5</strong>: 設計風格更新為 Frutiger Aero(Aqua Marine)。海洋漸層背景、氣泡動畫、玻璃質感卡片。文字尺寸也整體放大,更易閱讀。</li><li><strong>v2.3 / v2.4</strong>: 新增博士與小健對話劇登陸頁。以淺顯易懂的方式說明「SSML 是什麼?」「這個網站能解決什麼問題?」。</li><li><strong>v2.2</strong>: 新增 ⓘ 資訊彈窗與提示詞複製卡片。同時整理隱私權政策與使用須知。</li><li><strong>v2.1</strong>: 支援日文與繁體中文(台灣華語)介面切換,可依個人偏好選擇操作語言。</li><li><strong>v2.0</strong>: 採用 Firebase 推出 Beta 試營運版本。使用者無需自行輸入 API 金鑰,開啟瀏覽器即可生成 MP3(每日使用次數設有上限)。</li><li><strong>v1.0</strong>: 功能穩定版正式發布。重新調整介面與操作流程,提升使用體驗。</li><li><strong>v0.8</strong>: 串接多個區塊時,可於區塊間插入提示音效(鈴聲),段落分隔更清楚。</li><li><strong>v0.7</strong>: 新增「複誦功能」,於中文解說後再次播放正確的中文句子,提升記憶與學習效率。</li><li><strong>v0.6</strong>: 可將多段 SSML 合併輸出為單一 MP3 檔案,方便整批管理例句教材。</li><li><strong>v0.1</strong>: 首次發布。提供貼上 SSML 即可生成並下載 MP3 的基本功能。</li></ul>",

      // プロンプトコピーカード
      "prompt.title": "📋 用來製作學習音檔 SSML 的提示詞",
      "prompt.intro": "將此提示詞貼到 ChatGPT 或 Claude 後,它會先詢問「母語(日本人/台灣人)」「想學習的語言(日語/華語)」「程度(初級/中級/高級)」。例句可以提供日中對照,也可以只給單一語言的例句(AI 會翻譯)。把產出的 SSML 貼到上方欄位即可生成 MP3。",
      "prompt.copy_btn": "複製提示詞",
      "prompt.copy_success": "✓ 已複製",
      "prompt.copy_failed": "❌ 複製失敗,請手動複製",

      // ランディング会話劇
      "landing.hook": "在學中文時,有沒有想過要 <strong>「日語與華語混合的學習音檔」</strong>?<br />本網站就是為了解決這個煩惱而生。",
      "landing.title": "🎙️ 這個網站可以做什麼?",
      "landing.subtitle": "用博士與小健的對話來說明",
      "landing.kenta_name": "小健",
      "landing.hakase_name": "博士",
      "landing.sample_title": "🎧 可以做出像這樣的教材",
      "landing.sample_desc": "這是實際生成的 MP3 範例。播放看看,先感受一下氛圍。",
      "landing.sample_caption": "(範例:台灣華語 N1-N2 學習用教材,約 1 分鐘)",
      "landing.q1": "博士,我把日語和中文混在一起的句子讓 AI 朗讀,結果讀音怪怪的…",
      "landing.a1": "你發現了好問題。一般的 AI 語音合成會用主要語言(例如日語)整段唸完,所以中間夾雜的中文也會被當成日語來讀。這就是「中日混雜朗讀問題」。",
      "landing.q2": "那要怎麼修正呢?",
      "landing.a2": "可以用 <strong>SSML</strong> 這種「語音指示書」。例如「這裡用日語的聲音、這裡用中文的聲音、語速稍快、這裡停 2 秒」這樣細部指定。Google 的 TTS(語音合成)會解讀 SSML,正確切換不同語言。",
      "landing.q3": "SSML 聽起來很難,我這種程式新手寫得出來嗎…",
      "landing.a3": "別擔心。其實只要把 <strong>製作教材用的提示詞貼給 ChatGPT 或 Claude,它就會幫你寫好整段 SSML</strong>。下方有「製作學習音檔 SSML 的提示詞」的複製按鈕,把它貼給 AI,再給它日中例句即可。",
      "landing.q4": "原來如此,AI 寫好 SSML 後,貼到上面…",
      "landing.a4": "🎉 沒錯! 就能下載 MP3,馬上用耳朵學習。<strong>可以自製運動或通勤時「邊聽邊學」的教材</strong>,這就是本網站的特色。",
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

    // data-i18n 属性付き要素を全部洗って:
    // - data-i18n-attr="<attrName>" があれば該当属性に setAttribute
    // - data-i18n-html="true" があれば innerHTML(法的文書等)
    // - それ以外は textContent
    applyI18n() {
      const nodes = document.querySelectorAll("[data-i18n]");
      nodes.forEach((el) => {
        const key = el.getAttribute("data-i18n");
        if (!key) return;
        const text = this.t(key);
        const attrName = el.getAttribute("data-i18n-attr");
        const isHtml = el.getAttribute("data-i18n-html") === "true";
        if (attrName) {
          el.setAttribute(attrName, text);
        } else if (isHtml) {
          el.innerHTML = text;
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

    // 初回起動時の言語推定: localStorage → navigator.languages → デフォ ja
    // 台湾華語(tw)判定: zh-TW / zh-Hant / zh-HK / tw のいずれかが含まれる場合
    // (zh-CN や zh-Hans-CN は ja 判定 = 大陸ユーザーを誤って tw に振り分けない)
    detectInitialLang() {
      try {
        const saved = localStorage.getItem("ssml_mp3_studio_lang");
        if (saved === "ja" || saved === "tw") return saved;
      } catch (e) {
        // 無視
      }
      const candidates = Array.isArray(navigator.languages) && navigator.languages.length > 0
        ? navigator.languages
        : [navigator.language || ""];
      for (const lang of candidates) {
        const s = String(lang).toLowerCase();
        // 明示的に台湾華語/繁体字/香港 系のみ tw 判定
        if (/^(zh-tw|zh-hant|zh-hk|tw)\b/i.test(s)) return "tw";
        // それ以外の zh-* (zh-CN, zh-Hans) と日本語系は ja を優先
        if (s.startsWith("ja")) return "ja";
      }
      // どっちもヒットしなければデフォ ja
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
