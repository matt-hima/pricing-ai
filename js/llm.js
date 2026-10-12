// WebGPU 本地 LLM（WebLLM）：只在需要時動態載入
const WEBLLM_URL = "https://cdn.jsdelivr.net/npm/@mlc-ai/web-llm@0.2.80/+esm";

export const MODEL_OPTIONS = [
  { base: "Qwen2.5-1.5B-Instruct", label: "Qwen2.5 1.5B · 輕量（手機/筆電，約 1 GB）" },
  { base: "Qwen2.5-3B-Instruct", label: "Qwen2.5 3B · 平衡（約 2 GB）" },
  { base: "Qwen2.5-7B-Instruct", label: "Qwen2.5 7B · 精準（桌機獨顯，約 5 GB）" },
  { base: "Llama-3.1-8B-Instruct", label: "Llama 3.1 8B · 精準（桌機獨顯，約 5 GB）" },
];

let webllm = null;
let engine = null;
let loadedId = null;

/** 偵測 WebGPU 與 shader-f16 支援 */
export async function detectGPU() {
  if (!("gpu" in navigator)) return { ok: false, reason: "瀏覽器不支援 WebGPU" };
  try {
    const adapter = await navigator.gpu.requestAdapter();
    if (!adapter) return { ok: false, reason: "找不到可用的 GPU" };
    return { ok: true, f16: adapter.features.has("shader-f16") };
  } catch (e) {
    return { ok: false, reason: e.message };
  }
}

export function modelId(base, f16) {
  return `${base}-${f16 ? "q4f16_1" : "q4f32_1"}-MLC`;
}

export async function loadModel(id, onProgress) {
  if (engine && loadedId === id) return engine;
  onProgress?.(0, "正在載入 WebLLM 執行環境…");
  webllm ??= await import(WEBLLM_URL);
  onProgress?.(0, "正在準備模型（首次使用需下載，請稍候）…");
  const known = webllm.prebuiltAppConfig.model_list.some((m) => m.model_id === id);
  if (!known) throw new Error(`模型 ${id} 不在 WebLLM 預建清單中`);
  if (engine) await engine.unload();
  engine = await webllm.CreateMLCEngine(id, {
    initProgressCallback: (r) => onProgress?.(r.progress ?? 0, r.text ?? ""),
  });
  loadedId = id;
  return engine;
}

export const SYSTEM_PROMPT = `你是一位資深的軟體架構師與專案經理（PM），熟悉台灣/亞洲軟體外包市場。
你的任務：根據客戶勾選的功能模組與白話描述，把每個模組拆解為具體的開發子項目並估計工時（小時）。
規則：
1. 只輸出 JSON，不要任何其他文字。
2. 每個模組請參考提供的「基準工時」，依描述調整為 0.7 到 1.8 倍之間；描述越複雜（金流分期、即時同步、第三方串接、多角色權限）越高。
3. 每個模組拆解 2–4 個子項目，kind 為 "fe"（前端/客戶端）或 "be"（後端/API）。
4. 若「其他特殊需求」或「專案描述」中有清單外的功能，放入 extras（最多 3 項，每項 ≤ 120 小時）。
5. 不要估算金額，金額由系統計算。
6. assumptions 寫 3–5 條評估假設；risks 寫 3–5 條風險或不含項目（例如：第三方 API 申請費用、伺服器費用、內容建置）。
7. 全部使用繁體中文。
輸出格式：
{"complexity":"低|中|高",
 "assumptions":["..."],
 "risks":["..."],
 "modules":[{"id":"模組id","tasks":[{"name":"子項目","kind":"fe","hours":40}]}],
 "extras":[{"name":"功能名稱","tasks":[{"name":"子項目","kind":"be","hours":30}]}]}`;

export function buildUserPrompt(input, baseline, labels) {
  const mods = baseline.modules.map((m) => ({
    id: m.id, 名稱: m.name, 範圍: m.desc, 客戶描述: m.note || "（無）", 基準前端工時: m.fe, 基準後端工時: m.be,
  }));
  return JSON.stringify({
    專案類型: labels.type,
    目標平台: labels.platforms,
    設計等級: labels.design,
    專案描述: input.summary || "（無）",
    其他特殊需求: input.extra || "（無）",
    功能模組: mods,
  }, null, 1);
}

export async function askLLM(input, baseline, labels, onToken, onProgress) {
  if (!engine) throw new Error("模型尚未載入");
  try {
    return await generate(input, baseline, labels, onToken, true);
  } catch (e) {
    // WebLLM 的 JSON 文法限制（xgrammar）偶爾因無效 token 讓 WASM 中止，引擎隨之失效：
    // 重新建立引擎後，改以一般模式再試一次，由 parseJSON 擷取 JSON。
    console.warn("JSON 模式失敗，改用一般模式重試：", e);
    const id = loadedId;
    try { await engine?.unload(); } catch {}
    engine = null; loadedId = null;
    await loadModel(id, onProgress);
    return await generate(input, baseline, labels, onToken, false);
  }
}

async function generate(input, baseline, labels, onToken, jsonMode) {
  const stream = await engine.chat.completions.create({
    messages: [
      { role: "system", content: SYSTEM_PROMPT },
      { role: "user", content: buildUserPrompt(input, baseline, labels) },
    ],
    temperature: 0.2,
    max_tokens: 2048,
    ...(jsonMode ? { response_format: { type: "json_object" } } : {}),
    stream: true,
  });
  let text = "";
  let n = 0;
  for await (const chunk of stream) {
    text += chunk.choices[0]?.delta?.content ?? "";
    onToken?.(++n);
  }
  return parseJSON(text);
}

function parseJSON(text) {
  try { return JSON.parse(text); } catch {}
  const m = text.match(/\{[\s\S]*\}/);
  if (m) return JSON.parse(m[0]);
  throw new Error("AI 回應不是有效的 JSON");
}
