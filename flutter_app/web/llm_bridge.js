// 本地 LLM 橋接層：Flutter 透過 dart:js_interop 呼叫 window.quoteLLM
//  - GPU 後端：WebLLM（WebGPU）。需要 GPU 達到一定的 WebGPU 上限（每個 shader stage 至少 10 個 storage buffer），否則無法啟動。
//    （實測 Transformers.js / ONNX Runtime 的 kernel 需要 9–10 個，上限 8 的 GPU 一樣跑不起來，所以不提供。）
//  - CPU 後端：wllama（llama.cpp 的 WebAssembly 版）。不需要 WebGPU，速度較慢；
//    模型 ID 以 "cpu:" 開頭，用來在 WebGPU 上限不足或不支援時仍能使用本地 AI。
const WEBLLM_URL = "https://cdn.jsdelivr.net/npm/@mlc-ai/web-llm@0.2.80/+esm";
const WLLAMA_BASE = "https://cdn.jsdelivr.net/npm/@wllama/wllama@3.8.1/esm/";
const CPU_MODELS = {
  "cpu:qwen2.5-0.5b": { repo: "Qwen/Qwen2.5-0.5B-Instruct-GGUF", file: "qwen2.5-0.5b-instruct-q4_k_m.gguf" },
  "cpu:qwen2.5-1.5b": { repo: "Qwen/Qwen2.5-1.5B-Instruct-GGUF", file: "qwen2.5-1.5b-instruct-q4_k_m.gguf" },
};

let webllm = null;
let engine = null;
let engineWorker = null; // WebLLM 的 Web Worker（失敗時退回主執行緒）
let lowMemory = false;   // GPU 記憶體不足後改用較小的 context window
let loadedId = null;
let wllamaMod = null;
let wllama = null;
let cpuLoadedId = null;
let active = null; // "gpu" | "cpu"：最近一次載入成功的後端

// WebLLM（TVM runtime）啟動時的硬性需求；不足就無法建立 GPU 裝置。
// 與 @mlc-ai/web-llm 的 detectGPUDevice 一致：maxBufferSize 至少 256 MiB、
// maxStorageBufferBindingSize 至少 128 MiB、workgroup 儲存 32 KiB、每個 shader stage 10 個 storage buffer。
const NEEDED_LIMITS = {
  maxStorageBuffersPerShaderStage: 10,
  maxStorageBufferBindingSize: 134217728,
  maxBufferSize: 268435456,
  maxComputeWorkgroupStorageSize: 32768,
};

function gpuLabel(adapter) {
  const i = adapter.info;
  return i ? [i.vendor, i.architecture].filter(Boolean).join(" ") : "";
}

async function detect() {
  if (!("gpu" in navigator)) return JSON.stringify({ ok: false, reason: "@nowebgpu" });
  try {
    // WebLLM 內部用 high-performance 取得 adapter；偵測必須挑同一張，否則會誤判
    const adapter = await navigator.gpu.requestAdapter({ powerPreference: "high-performance" });
    if (!adapter) return JSON.stringify({ ok: false, reason: "@noadapter" });
    const low = Object.entries(NEEDED_LIMITS)
      .filter(([k, need]) => adapter.limits[k] < need)
      .map(([k, need]) => `${k}: ${adapter.limits[k]} < ${need}`);
    if (low.length) {
      const detail = [gpuLabel(adapter), low.join(", ")].filter(Boolean).join(" · ");
      return JSON.stringify({ ok: false, reason: `@limits:${detail}` });
    }
    return JSON.stringify({ ok: true, f16: adapter.features.has("shader-f16") });
  } catch (e) {
    return JSON.stringify({ ok: false, reason: String(e.message || e) });
  }
}

/** 載入 CPU 版模型（GGUF，從 Hugging Face 下載後由瀏覽器快取） */
async function loadCpu(id, onProgress) {
  const spec = CPU_MODELS[id];
  if (!spec) throw new Error(`@model_not_found:${id}`);
  if (wllama && cpuLoadedId === id) { active = "cpu"; return; }
  onProgress?.(0, "@cpu_runtime");
  wllamaMod ??= await import(WLLAMA_BASE + "index.js");
  if (wllama) { try { await wllama.exit(); } catch {} wllama = null; cpuLoadedId = null; }
  // 換用 CPU 後端時，把 GPU 上的模型釋放掉
  await unloadEngine();
  wllama = new wllamaMod.Wllama({ default: WLLAMA_BASE + "wasm/wllama.wasm" });
  await wllama.loadModelFromHF(
    { repo: spec.repo, file: spec.file },
    {
      n_ctx: 4096,
      progressCallback: ({ loaded, total }) => {
        const p = total ? loaded / total : 0;
        onProgress?.(p, p >= 1 ? "@cpu_loading" : `@cpu_downloading:${Math.round(p * 100)}`);
      },
    },
  );
  cpuLoadedId = id;
  active = "cpu";
}

async function generateCpu(system, user, onToken) {
  const stream = await wllama.createChatCompletion({
    messages: [{ role: "system", content: system }, { role: "user", content: user }],
    temperature: 0.2,
    max_tokens: 2048,
    response_format: { type: "json_object" },
    stream: true,
  });
  let text = "";
  let n = 0;
  for await (const chunk of stream) {
    text += chunk.choices?.[0]?.delta?.content ?? "";
    onToken?.(++n);
  }
  return text;
}

async function load(id, onProgress) {
  if (id.startsWith("cpu:")) return loadCpu(id, onProgress);
  if (engine && loadedId === id) { active = "gpu"; return; }
  onProgress?.(0, "@webllm_loading");
  webllm ??= await import(WEBLLM_URL);
  if (!webllm.prebuiltAppConfig.model_list.some((m) => m.model_id === id)) {
    throw new Error(`@model_not_found:${id}`);
  }
  onProgress?.(0, "@model_preparing");
  await unloadEngine();
  // 記憶體不足時依序降低 context window（KV cache 隨之變小）：4096 → 2048
  const contexts = lowMemory ? [2048] : [4096, 2048];
  for (let i = 0; i < contexts.length; i++) {
    try {
      engine = await createEngine(id, contexts[i], onProgress);
      lowMemory = contexts[i] < 4096;
      break;
    } catch (e) {
      const lim = limitsError(e);
      if (lim) throw lim;
      if (!isOutOfMemory(e)) throw e;
      if (i === contexts.length - 1) throw new Error("@gpu_oom");
      onProgress?.(0, "@lowmem_retry");
    }
  }
  loadedId = id;
  active = "gpu";
  // 換用 WebLLM 時，釋放其他後端佔用的記憶體
  if (wllama) { try { await wllama.exit(); } catch {} wllama = null; cpuLoadedId = null; }
}

/** 建立引擎：優先放進 Web Worker；Worker 不可用就退回主執行緒 */
async function createEngine(id, contextWindow, onProgress) {
  const config = { initProgressCallback: (r) => onProgress?.(r.progress ?? 0, r.text ?? "") };
  const chatOpts = { context_window_size: contextWindow };
  try {
    engineWorker = new Worker(new URL("webllm_worker.js", document.baseURI), { type: "module" });
    return await webllm.CreateWebWorkerMLCEngine(engineWorker, id, config, chatOpts);
  } catch (e) {
    try { engineWorker?.terminate(); } catch {}
    engineWorker = null;
    // GPU 相關錯誤（上限不足、記憶體不足）換執行緒也不會好，直接往外丟
    if (limitsError(e) || isOutOfMemory(e)) throw e;
    console.warn("Web Worker 引擎失敗，改用主執行緒：", e);
    return await webllm.CreateMLCEngine(id, config, chatOpts);
  }
}

async function unloadEngine() {
  try { await engine?.unload(); } catch {}
  try { engineWorker?.terminate(); } catch {}
  engine = null; engineWorker = null; loadedId = null;
}

/** GPU 記憶體不足 / 裝置遺失 */
function isOutOfMemory(e) {
  return /out of memory|\bOOM\b|device (was )?lost|failed to allocate|createBuffer|exceeds? (the )?maxBufferSize|buffer size/i.test(String(e?.message || e));
}

async function generate(system, user, onToken, jsonMode) {
  const stream = await engine.chat.completions.create({
    messages: [{ role: "system", content: system }, { role: "user", content: user }],
    temperature: 0.2,
    max_tokens: lowMemory ? 1024 : 2048, // context 縮小後，輸出上限也要跟著降
    ...(jsonMode ? { response_format: { type: "json_object" } } : {}),
    stream: true,
  });
  let text = "";
  let n = 0;
  for await (const chunk of stream) {
    text += chunk.choices[0]?.delta?.content ?? "";
    onToken?.(++n);
  }
  return text;
}

/**
 * WebLLM 建立裝置失敗時的訊息形如
 * "Cannot initialize runtime because of requested maxStorageBuffersPerShaderStage exceeds limit. requested=10, limit=8."
 * 轉成 @limits 代碼，讓介面顯示可讀的說明（含實際數值）。
 */
function limitsError(e) {
  const m = /requested (\w+) exceeds limit\. requested=([^,]+), limit=([^.\s]+)/.exec(String(e?.message || e));
  return m ? new Error(`@limits:${m[1]}: ${m[3]} < ${m[2]}`) : null;
}

/** 回傳模型原始文字，由 Dart 端解析 JSON */
async function ask(system, user, onToken, onProgress) {
  if (active === "cpu" && wllama) return generateCpu(system, user, onToken);
  if (!engine) throw new Error("@model_not_loaded");
  try {
    return await generate(system, user, onToken, true);
  } catch (e) {
    // WebLLM 的 JSON 文法限制（xgrammar）偶爾因無效 token 讓 WASM 中止，引擎隨之失效：
    // 重新建立引擎後改以一般模式重試。
    console.warn("JSON 模式失敗，改用一般模式重試：", e);
    const id = loadedId;
    if (isOutOfMemory(e)) lowMemory = true; // 推論中記憶體不足：重新載入時改用較小的 context
    await unloadEngine();
    await load(id, (p, t) => onProgress?.(p, `@retry:${t}`));
    return await generate(system, user, onToken, false);
  }
}

/** 下載文字檔（JSON） */
function download(filename, text, mime) {
  const a = document.createElement("a");
  a.href = URL.createObjectURL(new Blob([text], { type: mime }));
  a.download = filename;
  a.click();
  setTimeout(() => URL.revokeObjectURL(a.href), 1000);
}

/** CPU 後端資訊（執行緒數；要多執行緒需要 cross-origin isolation） */
function cpuInfo() {
  return JSON.stringify({
    loaded: !!wllama,
    threads: wllama?.getNumThreads?.() ?? 0,
    multithread: wllama?.isMultithread?.() ?? false,
    isolated: self.crossOriginIsolated === true,
    cores: navigator.hardwareConcurrency || 0,
  });
}

window.quoteLLM = { detect, load, ask, download, cpuInfo };
