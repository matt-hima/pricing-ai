// WebLLM 引擎跑在 Web Worker：模型載入與推論都不佔用主執行緒，頁面不會在產生估價時卡住。
import { WebWorkerMLCEngineHandler } from "https://cdn.jsdelivr.net/npm/@mlc-ai/web-llm@0.2.80/+esm";

const handler = new WebWorkerMLCEngineHandler();
self.onmessage = (msg) => handler.onmessage(msg);
