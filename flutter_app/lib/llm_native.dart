import 'dart:io';

import 'package:path_provider/path_provider.dart';

import 'engine/local_engine.dart';
import 'llm_common.dart';
import 'models.dart';

/// 桌面版（macOS / Windows）：llama.cpp 的 llama-server 子程序，使用本機 GPU（Metal / Vulkan）
const nativeEngine = true;
const aiAvailable = true;

Future<GpuInfo> detectGPU() async => const GpuInfo(true, true, '');

String modelId(String base, bool f16) => base;

Future<void> loadModel(String id, ProgressFn onProgress) => LocalEngine.instance.prepare(id, onProgress);

/// 存到「下載」資料夾
void downloadText(String filename, String text, String mime) {
  () async {
    final dir = await getDownloadsDirectory() ?? await getApplicationDocumentsDirectory();
    await File('${dir.path}${Platform.pathSeparator}$filename').writeAsString(text);
  }();
}

Future<AiResult> runAI(Quote q, {required void Function(int tokens) onToken, required ProgressFn onProgress}) {
  return runAIWith(q, (system, user) => LocalEngine.instance.chat(system, user, onToken: onToken));
}

/// 通用提問（網站內容生成用）：模型必須已載入；回傳模型原始文字
Future<String> askText(String system, String user, {Map<String, dynamic>? schema, void Function(int tokens)? onToken}) =>
    LocalEngine.instance.chat(system, user, maxTokens: 1200, schema: schema, onToken: onToken);

/// 引擎與模型的存放位置（顯示用）與是否為使用者自訂
Future<({String path, bool custom})> engineStorage() async {
  final e = LocalEngine.instance;
  return (path: (await e.root()).path, custom: await e.customStorage() != null);
}

Future<void> setEngineStorage(String? folder) => LocalEngine.instance.setCustomStorage(folder);
