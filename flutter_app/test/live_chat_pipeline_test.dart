@Timeout(Duration(minutes: 15))
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:self_quote/engine/local_engine.dart';
import 'package:self_quote/i18n/i18n.dart';
import 'package:self_quote/site/site_actions.dart';
import 'package:self_quote/site/site_planner.dart';

/// 聊天編輯的真實流程第一半：真正的模型（GPU）讀取編輯器的內容快照，規劃出動作清單並寫成 JSON，
/// 第二半（在編輯器裡套用並檢查頁面）由瀏覽器端執行。預設略過。
/// 執行：LIVE_ENGINE_ROOT=… CHAT_SNAPSHOT=snapshot.json CHAT_OUT=plans.json flutter test test/live_chat_pipeline_test.dart
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({});
  final root = Platform.environment['LIVE_ENGINE_ROOT'];
  final snap = Platform.environment['CHAT_SNAPSHOT'];
  final out = Platform.environment['CHAT_OUT'];
  final skip = root == null || snap == null || out == null ? 'set LIVE_ENGINE_ROOT, CHAT_SNAPSHOT and CHAT_OUT' : null;

  test('plan chat messages with the real model', () async {
    HttpOverrides.global = null;
    final engine = LocalEngine(root: Directory(root!));
    await engine.prepare(Platform.environment['LIVE_ENGINE_MODEL'] ?? 'Qwen2.5-1.5B-Instruct', (p, t) {});
    final catalog = parseCatalog(jsonDecode(File('test/fixtures/catalog.json').readAsStringSync()) as List);
    final snapshot = jsonDecode(File(snap!).readAsStringSync()) as Map<String, dynamic>;
    final messages = (jsonDecode(Platform.environment['CHAT_MESSAGES'] ?? '[]') as List).cast<String>();
    Future<String> ask(String system, String user, Map<String, dynamic> schema) => engine.chat(system, user, schema: schema, maxTokens: 600);

    final plans = <Map<String, Object?>>[];
    for (final m in messages) {
      final plan = await planChat(ask: ask, editorActions: catalog, snapshot: snapshot, history: const [], message: m, siteLang: Lang.en);
      plans.add({'message': m, 'routed': plan.routed, 'actions': plan.actions, 'notes': plan.notes});
    }
    File(out!).writeAsStringSync(jsonEncode(plans));
    await engine.stop();
  }, skip: skip);
}
