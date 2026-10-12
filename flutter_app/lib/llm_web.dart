import 'dart:convert';
import 'dart:js_interop';

import 'i18n/i18n.dart';
import 'llm_common.dart';
import 'models.dart';

/// 網頁版：web/llm_bridge.js 暴露的 window.quoteLLM（WebLLM / wllama）
@JS('quoteLLM')
external _Bridge? get _bridge;

extension type _Bridge._(JSObject _) implements JSObject {
  external JSPromise<JSString> detect();
  external JSPromise<JSAny?> load(String id, JSFunction onProgress);
  external JSPromise<JSString> ask(String system, String user, JSFunction onToken, JSFunction onProgress);
  external void download(String filename, String text, String mime);
}

Future<GpuInfo> detectGPU() async {
  final b = _bridge;
  if (b == null) return const GpuInfo(false, false, '@nobridge');
  final j = jsonDecode((await b.detect().toDart).toDart) as Map<String, dynamic>;
  return GpuInfo(j['ok'] == true, j['f16'] == true, '${j['reason'] ?? ''}');
}

String modelId(String base, bool f16) => base.startsWith('cpu:') ? base : '$base-${f16 ? 'q4f16_1' : 'q4f32_1'}-MLC';

Future<void> loadModel(String id, ProgressFn onProgress) async {
  await _bridge!.load(id, ((num p, String t) => onProgress(p.toDouble(), tx(t))).toJS).toDart;
}

void downloadText(String filename, String text, String mime) => _bridge?.download(filename, text, mime);

Future<AiResult> runAI(Quote q, {required void Function(int tokens) onToken, required ProgressFn onProgress}) {
  return runAIWith(
    q,
    (system, user) async => (await _bridge!
            .ask(system, user, ((num n) => onToken(n.toInt())).toJS, ((num p, String t) => onProgress(p.toDouble(), tx(t))).toJS)
            .toDart)
        .toDart,
  );
}
