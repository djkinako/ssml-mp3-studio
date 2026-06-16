// SSML MP3 Studio Public (v2.0.0) — フロント JS
//
// 個人版との違い:
// - API キー入力欄なし(バックエンドの Firebase Functions が隠蔽)
// - 単一ブロック固定(複数 SSML → 1 MP3 結合なし、効果音なし)
// - Standard 声のみ
// - 1 ユーザー / 1 日 / 4 回までのレート制限(IP 単位、サーバー側で実装)
// - 残量(あと N 回)を画面に表示

const VERSION = "2.4.0";

const SETTINGS_STORAGE = "ssml_mp3_studio_public_settings";
const USAGE_STORAGE = "ssml_mp3_studio_public_usage"; // { date: 'YYYY-MM-DD', remaining: N }

// Firebase Hosting の /api/tts(同一オリジン)に rewrite される
const TTS_ENDPOINT = "/api/tts";

const $ = (id) => document.getElementById(id);

const SAMPLE_SSML = `<speak>
  今日の表現です。<break time="500ms"/>
  毎日コーヒーを飲むのが習慣です。<break time="700ms"/>
  中国語では、<lang xml:lang="zh-TW">我每天喝咖啡是習慣</lang>。<break time="700ms"/>
  ポイントは <lang xml:lang="zh-TW">習慣</lang> という単語です。<break time="500ms"/>
  もう一度。<lang xml:lang="zh-TW">我每天喝咖啡是習慣</lang>。
</speak>`;

// 設定永続化
function loadSettings() {
  try {
    const raw = localStorage.getItem(SETTINGS_STORAGE);
    if (!raw) return;
    const s = JSON.parse(raw);
    if (s.jaVoice && $("jaVoice").querySelector(`option[value="${s.jaVoice}"]`)) {
      $("jaVoice").value = s.jaVoice;
    }
    if (s.zhVoice && $("zhVoice").querySelector(`option[value="${s.zhVoice}"]`)) {
      $("zhVoice").value = s.zhVoice;
    }
    if (s.jaRate != null) {
      $("jaRate").value = s.jaRate;
      $("jaRateVal").textContent = parseFloat(s.jaRate).toFixed(2);
    }
    if (s.zhRate != null) {
      $("zhRate").value = s.zhRate;
      $("zhRateVal").textContent = parseFloat(s.zhRate).toFixed(2);
    }
  } catch {}
}

function saveSettings() {
  localStorage.setItem(SETTINGS_STORAGE, JSON.stringify({
    jaVoice: $("jaVoice").value,
    zhVoice: $("zhVoice").value,
    jaRate: $("jaRate").value,
    zhRate: $("zhRate").value,
  }));
}

$("jaRate").addEventListener("input", (e) => {
  $("jaRateVal").textContent = parseFloat(e.target.value).toFixed(2);
  saveSettings();
});
$("zhRate").addEventListener("input", (e) => {
  $("zhRateVal").textContent = parseFloat(e.target.value).toFixed(2);
  saveSettings();
});
$("jaVoice").addEventListener("change", saveSettings);
$("zhVoice").addEventListener("change", saveSettings);

// サンプル投入 + バイト数
$("sampleBtn").addEventListener("click", () => {
  $("ssml").value = SAMPLE_SSML;
  updateByteCount();
});

function updateByteCount() {
  const bytes = new TextEncoder().encode($("ssml").value).length;
  const el = $("byteCount");
  el.textContent = window.I18N
    ? window.I18N.t("ssml.byte_count_template", { bytes })
    : `${bytes} バイト / 約5000バイト上限`;
  el.style.color = bytes > 5000 ? "#c0392b" : "";
}
$("ssml").addEventListener("input", updateByteCount);

// 残量表示(localStorage キャッシュ)
function todayJst() {
  const now = new Date(Date.now() + 9 * 60 * 60 * 1000);
  return now.toISOString().slice(0, 10);
}

function loadUsageCache() {
  try {
    const raw = localStorage.getItem(USAGE_STORAGE);
    if (!raw) return;
    const u = JSON.parse(raw);
    if (u.date === todayJst() && typeof u.remaining === "number") {
      renderRateInfo(u.remaining, u.dailyLimit || 4);
    }
  } catch {}
}

function saveUsageCache(remaining, dailyLimit) {
  localStorage.setItem(USAGE_STORAGE, JSON.stringify({
    date: todayJst(),
    remaining,
    dailyLimit,
  }));
}

// 直近の残量表示用キャッシュ(言語切替時に再描画するため)
let lastRateInfo = null;

function renderRateInfo(remaining, dailyLimit) {
  lastRateInfo = { remaining, dailyLimit };
  const el = $("rateInfo");
  el.textContent = window.I18N
    ? window.I18N.t("rate.info_template", { remaining, dailyLimit })
    : `今日の残り利用回数: ${remaining} / ${dailyLimit} 回`;
  if (remaining <= 0) {
    el.style.color = "#c0392b";
  } else if (remaining <= 1) {
    el.style.color = "#e67e22";
  } else {
    el.style.color = "";
  }
}

// 言語フォールバック付きの t() ヘルパー
function t(key, replacements = {}) {
  return window.I18N ? window.I18N.t(key, replacements) : key;
}

// MP3 生成
$("generate").addEventListener("click", async () => {
  const ssml = $("ssml").value.trim();
  if (!ssml) return setStatus(t("status.no_ssml"), true);
  if (!ssml.includes("<speak")) return setStatus(t("status.no_speak"), true);
  if (new TextEncoder().encode(ssml).length > 5000) {
    return setStatus(t("status.over_size"), true);
  }

  const payload = {
    ssml,
    jaVoice: $("jaVoice").value,
    zhVoice: $("zhVoice").value,
    jaRate: parseFloat($("jaRate").value),
    zhRate: parseFloat($("zhRate").value),
  };

  setStatus(t("status.generating"));
  $("generate").disabled = true;

  try {
    const res = await fetch(TTS_ENDPOINT, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify(payload),
    });
    const data = await res.json();

    // 残量更新(成功時もエラー時も来る)
    if (typeof data.remaining === "number" && typeof data.dailyLimit === "number") {
      renderRateInfo(data.remaining, data.dailyLimit);
      saveUsageCache(data.remaining, data.dailyLimit);
    }

    if (!res.ok) {
      if (res.status === 429) {
        return setStatus(
          data.error
            ? `❌ ${data.error}`
            : t("status.limit_reached_template", { dailyLimit: data.dailyLimit || 4 }),
          true,
        );
      }
      return setStatus(
        t("status.error_template", { message: data.error || `HTTP ${res.status}` }),
        true,
      );
    }

    const blob = base64ToBlob(data.audioContent, "audio/mp3");
    const url = URL.createObjectURL(blob);
    $("player").src = url;
    $("download").href = url;
    $("download").download = `ssml-${timestamp()}.mp3`;
    $("result").classList.remove("hidden");
    const sizeKb = Math.round(blob.size / 1024);
    setStatus(t("status.success_template", { size_kb: sizeKb }));
  } catch (err) {
    setStatus(t("status.network_error_template", { message: err.message }), true);
  } finally {
    $("generate").disabled = false;
  }
});

function base64ToBlob(base64, mime) {
  const bin = atob(base64);
  const bytes = new Uint8Array(bin.length);
  for (let i = 0; i < bin.length; i++) bytes[i] = bin.charCodeAt(i);
  return new Blob([bytes], { type: mime });
}

function setStatus(msg, isError = false) {
  const el = $("status");
  el.textContent = msg;
  el.style.color = isError ? "#c0392b" : "";
}

function timestamp() {
  const d = new Date();
  const p = (n) => String(n).padStart(2, "0");
  return `${d.getFullYear()}${p(d.getMonth() + 1)}${p(d.getDate())}-${p(d.getHours())}${p(d.getMinutes())}${p(d.getSeconds())}`;
}

// 言語切替時に動的テキスト(byteCount / rateInfo / version label)を再描画
window.addEventListener("langchange", () => {
  updateByteCount();
  if (lastRateInfo) {
    renderRateInfo(lastRateInfo.remaining, lastRateInfo.dailyLimit);
  }
  updateModalVersion();
});

// ⓘ モーダル制御
function updateModalVersion() {
  const el = $("modalVersionLine");
  if (!el) return;
  el.textContent = window.I18N
    ? window.I18N.t("version.label_template", { version: VERSION })
    : `現在のバージョン: v${VERSION}`;
}

function openModal() {
  const m = $("infoModal");
  m.classList.remove("hidden");
  updateModalVersion();
  // 開いた瞬間に閉じるボタンへフォーカス
  setTimeout(() => $("modalClose").focus(), 0);
  document.addEventListener("keydown", onEscClose);
}
function closeModal() {
  $("infoModal").classList.add("hidden");
  document.removeEventListener("keydown", onEscClose);
}
function onEscClose(e) {
  if (e.key === "Escape") closeModal();
}

$("infoBtn").addEventListener("click", openModal);
$("modalClose").addEventListener("click", closeModal);
$("infoModal").addEventListener("click", (e) => {
  // 背景タップで閉じる(ダイアログ本体は伝播停止)
  if (e.target === e.currentTarget) closeModal();
});

// タブ切替
document.querySelectorAll(".tab-btn").forEach((btn) => {
  btn.addEventListener("click", () => {
    const tab = btn.getAttribute("data-tab");
    document.querySelectorAll(".tab-btn").forEach((b) => {
      b.classList.toggle("active", b === btn);
    });
    document.querySelectorAll(".tab-content").forEach((c) => {
      c.classList.toggle("active", c.getAttribute("data-tab-panel") === tab);
    });
  });
});

// プロンプトコピー機能(<details> 展開時に lazy load)
let promptCache = null;
async function loadPrompt() {
  if (promptCache) return promptCache;
  const res = await fetch("/zhtw-v4.md");
  if (!res.ok) throw new Error(`HTTP ${res.status}`);
  promptCache = await res.text();
  return promptCache;
}

document.querySelector(".prompt-card details").addEventListener("toggle", async (e) => {
  if (!e.target.open) return;
  const ta = $("promptText");
  if (ta.value) return;
  try {
    ta.value = "Loading...";
    ta.value = await loadPrompt();
  } catch (err) {
    ta.value = `Failed to load: ${err.message}`;
  }
});

$("copyPromptBtn").addEventListener("click", async () => {
  const ta = $("promptText");
  if (!ta.value || ta.value === "Loading...") {
    ta.value = await loadPrompt();
  }
  try {
    await navigator.clipboard.writeText(ta.value);
    $("copyStatus").textContent = t("prompt.copy_success");
    $("copyStatus").style.color = "#2d7d46";
    setTimeout(() => {
      $("copyStatus").textContent = "";
    }, 2500);
  } catch (err) {
    $("copyStatus").textContent = t("prompt.copy_failed");
    $("copyStatus").style.color = "#c0392b";
  }
});

// 初期化
loadSettings();
updateByteCount();
loadUsageCache();
