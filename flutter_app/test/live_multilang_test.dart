@Timeout(Duration(minutes: 30))
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:self_quote/engine/local_engine.dart';
import 'package:self_quote/i18n/i18n.dart';
import 'package:self_quote/site/site_actions.dart';
import 'package:self_quote/site/site_planner.dart';

/// 聊天要看得懂 5 種語言：屋主用各自的語言說話，模型挑出正確的動作。
/// 內容快照用各語言範本（test/fixtures/snapshots.json，取自編輯器）。預設略過。
/// 執行：LIVE_ENGINE_ROOT=… flutter test test/live_multilang_test.dart
const _messages = {
  'en': ['Use a blue colour', 'Make all the prices 15% cheaper', 'Hide the floating buttons', 'We are closed on Saturdays', 'Send bookings to hello@luna.example'],
  'ja': ['メインカラーを青にしてください', '料金をすべて15%安くしてください', '浮かんでいるボタンを非表示にしてください', '土曜日は休みです', '予約の通知はhello@luna.exampleに送ってください'],
  'zh': ['主色改成藍色', '所有價格調低 15%', '隱藏浮動按鈕', '週六公休', '預約通知寄到 hello@luna.example'],
  'pt': ['Use a cor azul', 'Deixe todos os preços 15% mais baratos', 'Oculte os botões flutuantes', 'Fechamos aos sábados', 'Envie as reservas para hello@luna.example'],
  'es': ['Usa el color azul', 'Haz todos los precios un 15% más baratos', 'Oculta los botones flotantes', 'Cerramos los sábados', 'Envía las reservas a hello@luna.example'],
};

/// 每則訊息預期的動作（依序對應 _messages 的五則）
bool _ok(int i, List<Map<String, Object?>> a) {
  if (a.isEmpty) return false;
  final x = a.first;
  switch (i) {
    case 0:
      final c = '${x['color']}'.toLowerCase();
      const blues = {'blue', '青', '藍', '藍色', '蓝色', 'azul'};
      return x['action'] == 'set_color' && (blues.contains(c) || RegExp(r'^#[0-9a-f]{6}$').hasMatch(c) && int.parse(c.substring(1), radix: 16) & 0xFF > (int.parse(c.substring(1), radix: 16) >> 16) & 0xFF);
    case 1:
      return x['action'] == 'scale_prices' && x['percent'] == -15;
    case 2:
      return x['action'] == 'set_section' && x['section'] == 'float' && x['visible'] == false;
    case 3:
      return x['action'] == 'set_row' && x['list'] == 'hours';
    default:
      return x['action'] == 'set_booking_email' && x['email'] == 'hello@luna.example';
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({});
  final root = Platform.environment['LIVE_ENGINE_ROOT'];
  final skip = root == null ? 'set LIVE_ENGINE_ROOT' : null;

  test('chat understands owners writing in every language', () async {
    HttpOverrides.global = null;
    final engine = LocalEngine(root: Directory(root!));
    await engine.prepare(Platform.environment['LIVE_ENGINE_MODEL'] ?? 'Qwen2.5-1.5B-Instruct', (p, t) {});
    final catalog = parseCatalog(jsonDecode(File('test/fixtures/catalog.json').readAsStringSync()) as List);
    final snaps = jsonDecode(File('test/fixtures/snapshots.json').readAsStringSync()) as Map<String, dynamic>;
    Future<String> ask(String system, String user, Map<String, dynamic> schema) => engine.chat(system, user, schema: schema, maxTokens: 600);

    var pass = 0, total = 0;
    final failures = <String>[];
    for (final lang in _messages.keys) {
      final siteLang = Lang.fromCode(lang == 'zh' ? 'zh-TW' : lang)!;
      for (var i = 0; i < 5; i++) {
        final msg = _messages[lang]![i];
        final plan = await planChat(ask: ask, editorActions: catalog, snapshot: Map<String, dynamic>.from(snaps[lang] as Map), history: const [], message: msg, siteLang: siteLang);
        total++;
        final ok = _ok(i, plan.actions);
        if (ok) {
          pass++;
        } else {
          failures.add('[$lang] "$msg" → routed=${plan.routed} actions=${plan.actions} notes=${plan.notes}');
        }
      }
    }
    // ignore: avoid_print
    print('MULTILANG $pass/$total correct');
    for (final f in failures) {
      // ignore: avoid_print
      print('MISS $f');
    }
    await engine.stop();
  }, skip: skip);
}
