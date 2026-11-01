/// 本機 LLM：網頁版用 WebLLM / wllama（web/llm_bridge.js），桌面版用 llama.cpp（lib/engine）
export 'llm_common.dart';
export 'llm_web.dart' if (dart.library.io) 'llm_native.dart';
