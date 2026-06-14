// SSML MP3 Studio — ロジック
// SSML を Google Cloud Text-to-Speech API に投げて MP3 を生成・ダウンロードする。
// API キーはコードに埋め込まず、入力欄 → localStorage に保存する。
//
// 日中混在の肝:
//   Google TTS の <lang> タグは "best effort" で、日本語ベース声に中国語を
//   読ませても効かず日本語読みになる。そこで生成直前に SSML を変換し、
//   <lang xml:lang="zh-..."> 部分を <voice name="中国語声"><prosody> に置換する。
//   これで日本語/中国語の声・速度を別々に制御できる。

const KEY_STORAGE = "ssml_mp3_studio_api_key";

const $ = (id) => document.getElementById(id);

// サンプルは Claude が自然に出す <lang> 入り SSML（台湾華語=繁体字）。
// アプリが <lang> を中国語声に自動変換するので、このまま生成して動く。
const SAMPLE_SSML = `<speak>
  今日の表現です。<break time="500ms"/>
  毎日コーヒーを飲むのが習慣です。<break time="700ms"/>
  中国語では、<lang xml:lang="zh-TW">我每天喝咖啡是習慣</lang>。<break time="700ms"/>
  ポイントは <lang xml:lang="zh-TW">習慣</lang> という単語です。<break time="500ms"/>
  もう一度。<lang xml:lang="zh-TW">我每天喝咖啡是習慣</lang>。
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

// ---- 速度スライダー UI ----
$("jaRate").addEventListener("input", (e) => {
  $("jaRateVal").textContent = parseFloat(e.target.value).toFixed(2);
});
$("zhRate").addEventListener("input", (e) => {
  $("zhRateVal").textContent = parseFloat(e.target.value).toFixed(2);
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

// ---- SSML 変換: <lang xml:lang="zh-…"> → 中国語声＋速度 ----
// raw      : ユーザーが貼った SSML（<speak>…</speak>）
// zhVoice  : 中国語パートに使う声の name（例 cmn-TW-Wavenet-A）
// jaRate   : 日本語（ベース）の速度倍率
// zhRate   : 中国語パートの速度倍率（絶対値として扱う）
// 戻り値   : 変換後の SSML 文字列
function buildSsml(raw, zhVoice, jaRate, zhRate) {
  // <speak …> の中身だけ取り出す（属性が付いていても拾う）
  const m = raw.match(/<speak[^>]*>([\s\S]*)<\/speak>/i);
  let inner = m ? m[1] : raw;

  // 全体を日本語速度の <prosody> で包むため、中国語の <prosody> は
  // 外側と打ち消し合う相対値にして「絶対 zhRate」に見せる。
  // 実速度 = jaRate(外) × (zhRate/jaRate)(内) = zhRate
  const zhRelative = jaRate ? zhRate / jaRate : zhRate;
  const zhPct = Math.round(zhRelative * 100);
  const jaPct = Math.round(jaRate * 100);

  // <lang xml:lang="zh-…"> または "cmn-…" を中国語声＋速度に置換
  inner = inner.replace(
    /<lang\s+xml:lang\s*=\s*["'](?:zh|cmn)[^"']*["']\s*>([\s\S]*?)<\/lang>/gi,
    (_, txt) => `<voice name="${zhVoice}"><prosody rate="${zhPct}%">${txt}</prosody></voice>`
  );

  return `<speak><prosody rate="${jaPct}%">${inner}</prosody></speak>`;
}

// "ja-JP-Wavenet-B" → "ja-JP"（languageCode を声名から導出）
function langCodeFromVoice(voiceName) {
  const parts = voiceName.split("-");
  return parts.slice(0, 2).join("-");
}

// ---- MP3 生成 ----
$("generate").addEventListener("click", async () => {
  const apiKey = $("apiKey").value.trim();
  const ssml = $("ssml").value.trim();

  if (!apiKey) return setStatus("⚠️ API キーを入力してや", true);
  if (!ssml) return setStatus("⚠️ SSML を貼ってや", true);
  if (!ssml.includes("<speak")) return setStatus("⚠️ SSML は <speak>...</speak> で囲んでな", true);

  const jaVoice = $("jaVoice").value;
  const zhVoice = $("zhVoice").value;
  const jaRate = parseFloat($("jaRate").value);
  const zhRate = parseFloat($("zhRate").value);

  const builtSsml = buildSsml(ssml, zhVoice, jaRate, zhRate);

  setStatus("⏳ 生成中…");
  $("generate").disabled = true;

  const payload = {
    input: { ssml: builtSsml },
    voice: { languageCode: langCodeFromVoice(jaVoice), name: jaVoice },
    // 速度は SSML 内の <prosody> で制御するので、ここは等倍に固定
    audioConfig: { audioEncoding: "MP3", speakingRate: 1.0 },
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
