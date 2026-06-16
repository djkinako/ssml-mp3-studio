// SSML MP3 Studio Public — Cloud Functions for Firebase v2 (v2.0.1)
//
// 公開版バックエンド: Google Cloud TTS の API キーを Firebase 側に隠蔽し、
// フロントから来る SSML を Standard 声で MP3 化して返す。
// IP ベースの 1 日 4 回レート制限を Firestore で実装。
//
// firebase-functions v6 系 (v2 SDK) に対応した書き方
// エンドポイント: POST /tts
//   Body: { ssml, jaVoice, zhVoice, jaRate, zhRate }
//   Response: { audioContent: "...base64...", remaining: N, dailyLimit: N, used: N }

const { onRequest } = require("firebase-functions/v2/https");
const { defineSecret } = require("firebase-functions/params");
const admin = require("firebase-admin");
const fs = require("fs");
const path = require("path");

admin.initializeApp();
const db = admin.firestore();

// 解説前効果音(audio/explain.mp3 を Functions 起動時に1回だけ読み込み)
// 24kHz mono 64kbps、Google TTS 出力と完全一致フォーマット
const EXPLAIN_SFX = fs.readFileSync(path.join(__dirname, "audio", "explain.mp3"));

// <!-- explain --> マーカーで SSML を分割
const EXPLAIN_MARKER = /<!--\s*explain\s*-->/i;
function splitOnExplain(ssml) {
  if (!EXPLAIN_MARKER.test(ssml)) return [ssml];
  const m = ssml.match(/^([\s\S]*?<speak[^>]*>)([\s\S]*)(<\/speak>[\s\S]*)$/i);
  if (!m) return [ssml];
  const [, openTag, inner, closeTail] = m;
  const parts = inner.split(EXPLAIN_MARKER);
  if (parts.length < 2) return [ssml];
  return parts.map((p) => `${openTag}${p}${closeTail}`);
}

// Secret として登録した Google TTS API キー
// firebase functions:secrets:set GOOGLE_TTS_API_KEY でセット済み
const GOOGLE_TTS_API_KEY = defineSecret("GOOGLE_TTS_API_KEY");

const DAILY_LIMIT = 4;

// CORS 許可オリジン
const ALLOWED_ORIGINS = [
  "https://ssml-mp3-studio.web.app",
  "https://ssml-mp3-studio.firebaseapp.com",
  "http://localhost:5000",
  "http://127.0.0.1:5000",
  "http://localhost:8000",
];

function setCors(req, res) {
  const origin = req.headers.origin;
  if (ALLOWED_ORIGINS.includes(origin)) {
    res.set("Access-Control-Allow-Origin", origin);
  }
  res.set("Access-Control-Allow-Methods", "POST, OPTIONS");
  res.set("Access-Control-Allow-Headers", "Content-Type");
  res.set("Access-Control-Max-Age", "3600");
}

// IP 取得: x-forwarded-for ヘッダ優先
function getClientIp(req) {
  const xff = req.headers["x-forwarded-for"];
  if (typeof xff === "string") {
    return xff.split(",")[0].trim();
  }
  return req.ip || "unknown";
}

// JST 基準の YYYY-MM-DD
function todayJst() {
  const now = new Date(Date.now() + 9 * 60 * 60 * 1000);
  return now.toISOString().slice(0, 10);
}

// <speak> の中身を抜き出して <lang> を <voice>+<prosody> に書き換える
function buildSsml(raw, zhVoice, jaRate, zhRate) {
  const m = raw.match(/<speak[^>]*>([\s\S]*)<\/speak>/i);
  let inner = m ? m[1] : raw;
  const zhRelative = jaRate ? zhRate / jaRate : zhRate;
  const zhPct = Math.round(zhRelative * 100);
  const jaPct = Math.round(jaRate * 100);
  inner = inner.replace(
    /<lang\s+xml:lang\s*=\s*["'](?:zh|cmn)[^"']*["']\s*>([\s\S]*?)<\/lang>/gi,
    (_, txt) => `<voice name="${zhVoice}"><prosody rate="${zhPct}%">${txt}</prosody></voice>`,
  );
  return `<speak><prosody rate="${jaPct}%">${inner}</prosody></speak>`;
}

function langCodeFromVoice(voiceName) {
  return voiceName.split("-").slice(0, 2).join("-");
}

// Standard 声のみホワイトリスト
const ALLOWED_VOICES = new Set([
  // 日本語 Standard
  "ja-JP-Standard-A", "ja-JP-Standard-B", "ja-JP-Standard-C", "ja-JP-Standard-D",
  // 中国語 Standard
  "cmn-TW-Standard-A", "cmn-TW-Standard-B", "cmn-TW-Standard-C",
  "cmn-CN-Standard-A", "cmn-CN-Standard-B", "cmn-CN-Standard-C", "cmn-CN-Standard-D",
]);

exports.tts = onRequest(
  {
    region: "asia-northeast1",
    timeoutSeconds: 60,
    memory: "256MiB",
    secrets: [GOOGLE_TTS_API_KEY],
    cors: false, // 手動 CORS (ALLOWED_ORIGINS で制御)
  },
  async (req, res) => {
    setCors(req, res);

    if (req.method === "OPTIONS") {
      res.status(204).send("");
      return;
    }
    if (req.method !== "POST") {
      res.status(405).json({ error: "Method Not Allowed" });
      return;
    }

    try {
      const { ssml, jaVoice, zhVoice, jaRate, zhRate } = req.body || {};

      // バリデーション
      if (!ssml || typeof ssml !== "string") {
        return res.status(400).json({ error: "SSML が空やで" });
      }
      if (!ssml.includes("<speak")) {
        return res.status(400).json({ error: "SSML は <speak>...</speak> で囲んでな" });
      }
      if (ssml.length > 5000) {
        return res.status(400).json({ error: "SSML が 5000 文字を超えとる(Google TTS の上限)" });
      }
      if (!ALLOWED_VOICES.has(jaVoice) || !ALLOWED_VOICES.has(zhVoice)) {
        return res.status(400).json({ error: "公開版は Standard 声のみ対応や" });
      }
      const jaR = parseFloat(jaRate);
      const zhR = parseFloat(zhRate);
      if (!(jaR >= 0.5 && jaR <= 1.5) || !(zhR >= 0.5 && zhR <= 1.5)) {
        return res.status(400).json({ error: "速度は 0.5〜1.5 の範囲で指定してな" });
      }

      // レート制限チェック(Firestore トランザクションでアトミック)
      const ip = getClientIp(req);
      const today = todayJst();
      const docId = `${ip}_${today}`;
      const docRef = db.collection("ratelimits").doc(docId);

      const count = await db.runTransaction(async (tx) => {
        const doc = await tx.get(docRef);
        const current = doc.exists ? (doc.data().count || 0) : 0;
        if (current >= DAILY_LIMIT) {
          return current; // 上限到達、インクリメントせず
        }
        tx.set(docRef, {
          count: current + 1,
          lastAccess: admin.firestore.FieldValue.serverTimestamp(),
          ip,
          date: today,
        }, { merge: true });
        return current + 1;
      });

      if (count > DAILY_LIMIT) {
        return res.status(429).json({
          error: `今日の利用上限(${DAILY_LIMIT}回/日)に達したで。明日また来てな。`,
          dailyLimit: DAILY_LIMIT,
          used: count - 1,
          remaining: 0,
        });
      }

      // SSML を <!-- explain --> マーカーで分割
      // - マーカー無し: 1 回 TTS でそのまま返す
      // - マーカー有り: 各パートを TTS して、間に explain.mp3 を挟んで連結
      const apiKey = GOOGLE_TTS_API_KEY.value();
      const parts = splitOnExplain(ssml);

      async function ttsOnce(partSsml) {
        const builtSsml = buildSsml(partSsml, zhVoice, jaR, zhR);
        const ttsRes = await fetch(
          `https://texttospeech.googleapis.com/v1/text:synthesize?key=${encodeURIComponent(apiKey)}`,
          {
            method: "POST",
            headers: { "Content-Type": "application/json" },
            body: JSON.stringify({
              input: { ssml: builtSsml },
              voice: { languageCode: langCodeFromVoice(jaVoice), name: jaVoice },
              audioConfig: {
                audioEncoding: "MP3",
                speakingRate: 1.0,
                sampleRateHertz: 24000,
              },
            }),
          },
        );
        const ttsData = await ttsRes.json();
        if (!ttsRes.ok) {
          const msg = ttsData?.error?.message || `Google TTS HTTP ${ttsRes.status}`;
          throw new Error(msg);
        }
        return Buffer.from(ttsData.audioContent, "base64");
      }

      let mergedAudio;
      try {
        const buffers = [];
        for (let i = 0; i < parts.length; i++) {
          buffers.push(await ttsOnce(parts[i]));
          // パート間(=マーカー位置)に explain.mp3 を挟む
          if (i < parts.length - 1) {
            buffers.push(EXPLAIN_SFX);
          }
        }
        mergedAudio = Buffer.concat(buffers);
      } catch (err) {
        console.error("Google TTS error:", err.message);
        // 失敗時はカウンタをデクリメント(課金されてないのでユーザー保護)
        await docRef.set({
          count: admin.firestore.FieldValue.increment(-1),
        }, { merge: true });
        return res.status(502).json({ error: `音声合成エラー: ${err.message}` });
      }

      return res.status(200).json({
        audioContent: mergedAudio.toString("base64"),
        dailyLimit: DAILY_LIMIT,
        used: count,
        remaining: DAILY_LIMIT - count,
        sfxApplied: parts.length > 1,
      });
    } catch (err) {
      console.error("Function error:", err);
      return res.status(500).json({ error: `内部エラー: ${err.message}` });
    }
  },
);
