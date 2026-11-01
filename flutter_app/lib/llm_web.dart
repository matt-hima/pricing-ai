import 'dart:js_interop';

import 'package:web/web.dart' as web;

import 'i18n/i18n.dart';
import 'llm_common.dart';
import 'models.dart';

/// 網頁版沒有 AI：模型在使用者電腦的 GPU 上跑，只在 Mac / Windows App 提供（lib/llm_native.dart）。
/// 網頁版保留規則引擎報價、網站編輯與匯出 ZIP。
const nativeEngine = false;
const aiAvailable = false;

Future<GpuInfo> detectGPU() async => const GpuInfo(false, false, '');

String modelId(String base, bool f16) => base;

Never _noAi() => throw UnsupportedError(tr('web.noAiMsg'));

Future<void> loadModel(String id, ProgressFn onProgress) async => _noAi();

Future<AiResult> runAI(Quote q, {required void Function(int tokens) onToken, required ProgressFn onProgress}) async => _noAi();

Future<String> askText(String system, String user, {Map<String, dynamic>? schema, void Function(int tokens)? onToken}) async => _noAi();

/// 以瀏覽器下載一個文字檔
void downloadText(String filename, String text, String mime) {
  final blob = web.Blob([text.toJS].toJS, web.BlobPropertyBag(type: mime));
  final url = web.URL.createObjectURL(blob);
  final a = web.HTMLAnchorElement()
    ..href = url
    ..download = filename;
  a.click();
  web.URL.revokeObjectURL(url);
}

/// 網頁版沒有本機存放位置
Future<({String path, bool custom})> engineStorage() async => (path: '', custom: false);

Future<void> setEngineStorage(String? folder) async {}
