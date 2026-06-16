// SSML MP3 Studio Public (v2.0.0) — フロント JS
//
// 個人版との違い:
// - API キー入力欄なし(バックエンドの Firebase Functions が隠蔽)
// - 単一ブロック固定(複数 SSML → 1 MP3 結合なし、効果音なし)
// - Standard 声のみ
// - 1 ユーザー / 1 日 / 4 回までのレート制限(IP 単位、サーバー側で実装)
// - 残量(あと N 回)を画面に表示

const VERSION = "2.0.0";

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
  el.textContent = `${bytes} バイト / 約5000バイト上限`;
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

function renderRateInfo(remaining, dailyLimit) {
  const el = $("rateInfo");
  el.textContent = `今日の残り利用回数: ${remaining} / ${dailyLimit} 回`;
  if (remaining <= 0) {
    el.style.color = "#c0392b";
  } else if (remaining <= 1) {
    el.style.color = "#e67e22";
  } else {
    el.style.color = "";
  }
}

// MP3 生成
$("generate").addEventListener("click", async () => {
  const ssml = $("ssml").value.trim();
  if (!ssml) return setStatus("⚠️ SSML を貼ってや", true);
  if (!ssml.includes("<speak")) return setStatus("⚠️ SSML は <speak>...</speak> で囲んでな", true);
  if (new TextEncoder().encode(ssml).length > 5000) {
    return setStatus("⚠️ SSML が 5000 バイトを超えとる。短くしてな", true);
  }

  const payload = {
    ssml,
    jaVoice: $("jaVoice").value,
    zhVoice: $("zhVoice").value,
    jaRate: parseFloat($("jaRate").value),
    zhRate: parseFloat($("zhRate").value),
  };

  setStatus("⏳ 生成中…");
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
        return setStatus(`❌ ${data.error || "今日の利用上限に達したで"}`, true);
      }
      return setStatus(`❌ エラー: ${data.error || `HTTP ${res.status}`}`, true);
    }

    const blob = base64ToBlob(data.audioContent, "audio/mp3");
    const url = URL.createObjectURL(blob);
    $("player").src = url;
    $("download").href = url;
    $("download").download = `ssml-${timestamp()}.mp3`;
    $("result").classList.remove("hidden");
    const sizeKb = Math.round(blob.size / 1024);
    setStatus(`✅ 生成できたで! (${sizeKb} KB) 下で再生 / DL してな`);
  } catch (err) {
    setStatus(`❌ 通信エラー: ${err.message}`, true);
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

// 初期化
$("version").textContent = `v${VERSION}`;
loadSettings();
updateByteCount();
loadUsageCache();
