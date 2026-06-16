// SSML MP3 Studio — ロジック
// SSML を Google Cloud Text-to-Speech API に投げて MP3 を生成・ダウンロードする。
// API キーはコードに埋め込まず、入力欄 → localStorage に保存する。
//
// 日中混在の肝:
//   Google TTS の <lang> タグは "best effort" で、日本語ベース声に中国語を
//   読ませても効かず日本語読みになる。そこで生成直前に SSML を変換し、
//   <lang xml:lang="zh-..."> 部分を <voice name="中国語声"><prosody> に置換する。
//   これで日本語/中国語の声・速度を別々に制御できる。
//
// 複数ブロックの結合 (v0.6.0):
//   各ブロックを順次 Google TTS に投げて MP3 (base64) を取得し、
//   Uint8Array を単純連結して 1 つの Blob にする。MP3 はフレーム独立形式やから
//   バイナリ連結で動く(ffmpeg / Web Audio API 不要)。
//   これで 5000 バイト上限を SSML レベルで気にせんで済む。

const VERSION = "2.0.0";

const KEY_STORAGE = "ssml_mp3_studio_api_key";
const SETTINGS_STORAGE = "ssml_mp3_studio_settings";

// 効果音 (v0.8.0+)
// audio/explain.mp3 : 解説直前 (SSML 内の <!-- explain --> マーカーで分割した境目に挿入)
// audio/transition.mp3 : ブロック間 (各ブロック MP3 の末尾、最後のブロック後は不要)
const SFX = { explain: null, transition: null };
const EXPLAIN_MARKER = /<!--\s*explain\s*-->/i;

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

// ---- 声・速度の設定保存/復元 ----
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
  } catch {
    // 壊れた JSON は黙って無視（デフォルト値で続行）
  }
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

// ---- SSML ブロック管理 (v0.6.0) ----
// 各ブロックは独立した <speak> SSML を持つ。
// 「+ ブロックを追加」で動的に追加、「×」で削除(最低1ブロックは残す)。
function addBlock() {
  const tpl = $("ssml-block-template").content.cloneNode(true);
  $("ssml-blocks").appendChild(tpl);
  const block = $("ssml-blocks").lastElementChild;

  // 各ボタン/textarea にイベントを紐づけ
  block.querySelector(".btn-remove-block").addEventListener("click", () => removeBlock(block));
  block.querySelector(".btn-sample-block").addEventListener("click", () => {
    const ta = block.querySelector(".ssml-block-textarea");
    ta.value = SAMPLE_SSML;
    updateBlockBytes(block);
  });
  block.querySelector(".ssml-block-textarea").addEventListener("input", () => updateBlockBytes(block));

  renumberBlocks();
  updateRemoveButtons();
  updateTotalByteCount();
}

function removeBlock(block) {
  const all = $("ssml-blocks").querySelectorAll(".ssml-block");
  if (all.length <= 1) return; // 最低1つは残す
  block.remove();
  renumberBlocks();
  updateRemoveButtons();
  updateTotalByteCount();
}

function renumberBlocks() {
  $("ssml-blocks").querySelectorAll(".ssml-block").forEach((b, i) => {
    b.querySelector(".ssml-block-num").textContent = String(i + 1);
  });
}

function updateRemoveButtons() {
  const all = $("ssml-blocks").querySelectorAll(".ssml-block");
  all.forEach((b) => {
    b.querySelector(".btn-remove-block").disabled = all.length <= 1;
  });
}

function updateBlockBytes(block) {
  const text = block.querySelector(".ssml-block-textarea").value;
  const bytes = new TextEncoder().encode(text).length;
  const el = block.querySelector(".ssml-block-bytes");
  el.textContent = `${bytes} バイト / 約5000バイト上限`;
  el.style.color = bytes > 5000 ? "#c0392b" : "";
  updateTotalByteCount();
}

function updateTotalByteCount() {
  const all = $("ssml-blocks").querySelectorAll(".ssml-block");
  let total = 0;
  all.forEach((b) => {
    total += new TextEncoder().encode(b.querySelector(".ssml-block-textarea").value).length;
  });
  $("totalByteCount").textContent = `合計 ${total} バイト / ${all.length} ブロック`;
}

$("addBlock").addEventListener("click", addBlock);

// ---- SSML 変換: <lang xml:lang="zh-…"> → 中国語声＋速度 ----
function buildSsml(raw, zhVoice, jaRate, zhRate) {
  const m = raw.match(/<speak[^>]*>([\s\S]*)<\/speak>/i);
  let inner = m ? m[1] : raw;

  // 実速度 = jaRate(外) × (zhRate/jaRate)(内) = zhRate
  const zhRelative = jaRate ? zhRate / jaRate : zhRate;
  const zhPct = Math.round(zhRelative * 100);
  const jaPct = Math.round(jaRate * 100);

  inner = inner.replace(
    /<lang\s+xml:lang\s*=\s*["'](?:zh|cmn)[^"']*["']\s*>([\s\S]*?)<\/lang>/gi,
    (_, txt) => `<voice name="${zhVoice}"><prosody rate="${zhPct}%">${txt}</prosody></voice>`
  );

  return `<speak><prosody rate="${jaPct}%">${inner}</prosody></speak>`;
}

function langCodeFromVoice(voiceName) {
  const parts = voiceName.split("-");
  return parts.slice(0, 2).join("-");
}

// ---- 1 ブロック分の TTS リクエスト ----
async function ttsOnce(apiKey, ssml, jaVoice, zhVoice, jaRate, zhRate) {
  const built = buildSsml(ssml, zhVoice, jaRate, zhRate);
  const payload = {
    input: { ssml: built },
    voice: { languageCode: langCodeFromVoice(jaVoice), name: jaVoice },
    // sampleRateHertz: 24000 を明示。効果音(audio/*.mp3 も 24kHz mono に変換済み)と
    // フォーマットを完全一致させることで、MP3 連結時の再生中断を防ぐ。
    audioConfig: { audioEncoding: "MP3", speakingRate: 1.0, sampleRateHertz: 24000 },
  };
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
    throw new Error(msg);
  }
  return base64ToBytes(data.audioContent);
}

// ---- 効果音ロード (v0.8.0) ----
// audio/*.mp3 を fetch して Uint8Array としてキャッシュする。
// 初回 generate() で1回だけ呼ばれる。失敗時は効果音なしで継続。
async function loadSfx() {
  if (SFX.explain && SFX.transition) return;
  try {
    const [exp, tra] = await Promise.all([
      fetch("audio/explain.mp3").then((r) => r.arrayBuffer()).then((b) => new Uint8Array(b)),
      fetch("audio/transition.mp3").then((r) => r.arrayBuffer()).then((b) => new Uint8Array(b)),
    ]);
    SFX.explain = exp;
    SFX.transition = tra;
  } catch (err) {
    console.warn("効果音ロード失敗(効果音なしで継続):", err);
  }
}

// ---- SSML 内の <!-- explain --> マーカーで分割 ----
// 「正解 → <!-- explain --> → 解説 → リピート」を
// 「正解まで」と「解説〜リピート」の 2 つの <speak> に分けて返す。
// マーカーがなければ単一要素配列で返す(後方互換)。
function splitOnExplain(ssml) {
  if (!EXPLAIN_MARKER.test(ssml)) return [ssml];
  const m = ssml.match(/^([\s\S]*?<speak[^>]*>)([\s\S]*)(<\/speak>[\s\S]*)$/i);
  if (!m) return [ssml];
  const [, openTag, inner, closeTail] = m;
  const parts = inner.split(EXPLAIN_MARKER);
  if (parts.length < 2) return [ssml];
  // 各パートを <speak>...</speak> で包み直す
  return parts.map((p) => `${openTag}${p}${closeTail}`);
}

// ---- MP3 生成(全ブロック順次→連結 + 効果音挿入) ----
// 連結構造 (v0.8.0):
//   ブロック1 前半MP3 → [解説前効果音 explain.mp3] → ブロック1 後半MP3 → [ブロック間効果音 transition.mp3]
//   → ブロック2 前半MP3 → [explain.mp3] → ブロック2 後半MP3 → [transition.mp3]
//   → ... → 最後のブロック後半MP3 (transition は付けない)
$("generate").addEventListener("click", async () => {
  const apiKey = $("apiKey").value.trim();
  if (!apiKey) return setStatus("⚠️ API キーを入力してや", true);

  const blockEls = Array.from($("ssml-blocks").querySelectorAll(".ssml-block"));
  const ssmls = blockEls.map((b) => b.querySelector(".ssml-block-textarea").value.trim());
  const nonEmpty = ssmls.map((s, i) => ({ ssml: s, index: i + 1 })).filter((x) => x.ssml);

  if (nonEmpty.length === 0) return setStatus("⚠️ SSML を 1 ブロック以上貼ってや", true);

  for (const { ssml, index } of nonEmpty) {
    if (!ssml.includes("<speak")) {
      return setStatus(`⚠️ ブロック ${index}: SSML は <speak>...</speak> で囲んでな`, true);
    }
  }

  const jaVoice = $("jaVoice").value;
  const zhVoice = $("zhVoice").value;
  const jaRate = parseFloat($("jaRate").value);
  const zhRate = parseFloat($("zhRate").value);

  $("generate").disabled = true;
  const mp3Parts = [];

  // 効果音を遅延ロード(初回のみ)
  setStatus("⏳ 効果音をロード中…");
  await loadSfx();

  try {
    for (let i = 0; i < nonEmpty.length; i++) {
      const { ssml, index } = nonEmpty[i];
      const parts = splitOnExplain(ssml);
      for (let p = 0; p < parts.length; p++) {
        const partLabel = parts.length > 1 ? `${index}-${p + 1}` : `${index}`;
        setStatus(`⏳ ブロック ${partLabel} を生成中… (${i + 1}/${nonEmpty.length})`);
        try {
          const bytes = await ttsOnce(apiKey, parts[p], jaVoice, zhVoice, jaRate, zhRate);
          mp3Parts.push(bytes);
        } catch (err) {
          return setStatus(`❌ ブロック ${partLabel} エラー: ${err.message}`, true);
        }
        // 「マーカー位置」の前(=前半パート出力後)に解説前効果音を挟む
        if (p < parts.length - 1 && SFX.explain) {
          mp3Parts.push(SFX.explain);
        }
      }
      // ブロック間効果音(最後のブロックの後には付けない)
      if (i < nonEmpty.length - 1 && SFX.transition) {
        mp3Parts.push(SFX.transition);
      }
    }

    // 全 MP3 を Uint8Array で単純連結
    const totalLen = mp3Parts.reduce((s, b) => s + b.length, 0);
    const merged = new Uint8Array(totalLen);
    let pos = 0;
    for (const part of mp3Parts) {
      merged.set(part, pos);
      pos += part.length;
    }
    const blob = new Blob([merged], { type: "audio/mp3" });
    const url = URL.createObjectURL(blob);

    $("player").src = url;
    $("download").href = url;
    $("download").download = `ssml-${timestamp()}.mp3`;
    $("result").classList.remove("hidden");

    const sizeKb = Math.round(blob.size / 1024);
    const sfxNote = (SFX.explain && SFX.transition) ? "(効果音入り)" : "(効果音無し)";
    setStatus(`✅ ${nonEmpty.length} ブロック結合 ${sfxNote} ${sizeKb} KB 完了！下で再生 / DL してな`);
  } catch (err) {
    setStatus(`❌ 通信エラー: ${err.message}`, true);
  } finally {
    $("generate").disabled = false;
  }
});

// ---- ユーティリティ ----
function base64ToBytes(base64) {
  const bin = atob(base64);
  const bytes = new Uint8Array(bin.length);
  for (let i = 0; i < bin.length; i++) bytes[i] = bin.charCodeAt(i);
  return bytes;
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

// ---- 初期化 ----
$("version").textContent = `v${VERSION}`;
loadKey();
loadSettings();
addBlock(); // 起動時に1ブロックを追加
