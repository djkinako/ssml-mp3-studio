// SSML MP3 Studio — MVP ロジック
// SSML を Google Cloud Text-to-Speech API に投げて MP3 を生成・ダウンロードする。
// API キーはコードに埋め込まず、入力欄 → localStorage に保存する。

const KEY_STORAGE = "ssml_mp3_studio_api_key";

const $ = (id) => document.getElementById(id);

const SAMPLE_SSML = `<speak>
  今日の表現です。<break time="500ms"/>
  毎日コーヒーを飲むのが習慣です。<break time="700ms"/>
  中国語では、<lang xml:lang="zh-CN">我每天喝咖啡是习惯</lang>。<break time="700ms"/>
  ポイントは <lang xml:lang="zh-CN">习惯</lang> という単語です。<break time="500ms"/>
  もう一度。<lang xml:lang="zh-CN">我每天喝咖啡是习惯</lang>。
</speak>`;

// ---- API キー管理 ----
function loadKey() {
  const saved = localStorage.getItem(KEY_STORAGE);
  if (saved) {
    $("apiKey").value = saved;
    $("keyStatus").textContent = "✅ キー保存済み（このブラウザのみ）";
  }
}

$("saveKey").addEventListener("click", () => {
  const v = $("apiKey").value.trim();
  if (!v) {
    $("keyStatus").textContent = "⚠️ キーが空です";
    return;
  }
  localStorage.setItem(KEY_STORAGE, v);
  $("keyStatus").textContent = "✅ キーを保存しました";
});

$("clearKey").addEventListener("click", () => {
  localStorage.removeItem(KEY_STORAGE);
  $("apiKey").value = "";
  $("keyStatus").textContent = "🗑 キーを削除しました";
});

// ---- 声 / 速度 UI ----
$("rate").addEventListener("input", (e) => {
  $("rateVal").textContent = parseFloat(e.target.value).toFixed(2);
});

// ---- SSML サンプル / バイト数 ----
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

// ---- MP3 生成 ----
$("generate").addEventListener("click", async () => {
  const apiKey = $("apiKey").value.trim();
  const ssml = $("ssml").value.trim();

  if (!apiKey) return setStatus("⚠️ API キーを入力してや", true);
  if (!ssml) return setStatus("⚠️ SSML を貼ってや", true);
  if (!ssml.includes("<speak")) return setStatus("⚠️ SSML は <speak>...</speak> で囲んでな", true);

  const [voiceName, languageCode] = $("voiceName").value.split("|");
  const speakingRate = parseFloat($("rate").value);

  setStatus("⏳ 生成中…");
  $("generate").disabled = true;

  const payload = {
    input: { ssml },
    voice: { languageCode, name: voiceName },
    audioConfig: { audioEncoding: "MP3", speakingRate },
  };

  try {
    const res = await fetch(
      `https://texttospeech.googleapis.com/v1/text:synthesize?key=${encodeURIComponent(apiKey)}`,
      {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify(payload),
      }
    );

    const data = await res.json();

    if (!res.ok) {
      const msg = data?.error?.message || `HTTP ${res.status}`;
      return setStatus(`❌ エラー: ${msg}`, true);
    }

    const audioBase64 = data.audioContent;
    const blob = base64ToBlob(audioBase64, "audio/mp3");
    const url = URL.createObjectURL(blob);

    $("player").src = url;
    $("download").href = url;
    $("download").download = `ssml-${timestamp()}.mp3`;
    $("result").classList.remove("hidden");
    setStatus("✅ 生成できたで！下で再生 / ダウンロードしてな");
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
  // ファイル名用の簡易タイムスタンプ（衝突回避）
  const d = new Date();
  const p = (n) => String(n).padStart(2, "0");
  return `${d.getFullYear()}${p(d.getMonth() + 1)}${p(d.getDate())}-${p(d.getHours())}${p(d.getMinutes())}${p(d.getSeconds())}`;
}

// ---- 初期化 ----
loadKey();
updateByteCount();
