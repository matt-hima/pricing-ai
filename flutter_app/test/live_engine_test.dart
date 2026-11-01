@Timeout(Duration(minutes: 15))
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:self_quote/engine/local_engine.dart';
import 'package:self_quote/i18n/i18n.dart';
import 'package:self_quote/llm_common.dart';
import 'package:self_quote/models.dart';
import 'dart:convert';

import 'package:self_quote/site/site_actions.dart';
import 'package:self_quote/site/site_ai.dart';
import 'package:self_quote/site/site_planner.dart';

/// 真實的本機 GPU 推論測試（會下載引擎與模型）。預設略過，
/// 執行：LIVE_ENGINE_ROOT=/某個資料夾 flutter test test/live_engine_test.dart
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({});
  final root = Platform.environment['LIVE_ENGINE_ROOT'];
  final skip = root == null ? 'set LIVE_ENGINE_ROOT to run' : null;

  test('download engine + model, start on GPU, run a pricing estimate and a site generation', () async {
    HttpOverrides.global = null; // 測試環境預設擋網路
    final engine = LocalEngine(root: Directory(root!));
    var lastText = '';
    await engine.prepare(Platform.environment['LIVE_ENGINE_MODEL'] ?? 'Qwen2.5-0.5B-Instruct', (p, t) {
      if (t != lastText && (t.endsWith('0%') || t.contains('100%') || !t.contains('%'))) {
        // ignore: avoid_print
        print('[progress] $t');
      }
      lastText = t;
    });
    // ignore: avoid_print
    print('--- engine log ---\n${engine.log}\n------------------');
    expect(engine.running, isTrue);

    final q = Quote()
      ..company = 'ACME'
      ..contact = 'Wang'
      ..summary = 'A booking website for a nail salon with online payment'
      ..modules = {'booking': 'by service and staff', 'payment': 'credit card'};
    final ai = await runAIWith(q, (system, user) => engine.chat(system, user, onToken: (n) {}));
    // ignore: avoid_print
    print('pricing: ${ai.est.modules.length} modules, ${ai.est.totalHours} hours');
    expect(ai.est.modules, isNotEmpty);

    final text = await engine.chat(siteSystemPrompt(Lang.en), 'A small nail salon in Taipei. Gel nails, manicure, nail art. Open 11:00-20:00, closed Mondays.');
    // ignore: avoid_print
    print('site raw: $text');
    final o = siteOverrides(text);
    expect(o, isNotNull);
    // ignore: avoid_print
    print('site overrides: $o');
    final catalog = parseCatalog(jsonDecode(File('test/fixtures/catalog.json').readAsStringSync()) as List);
    final snapshot = {
      'brand': 'Mia Nails', 'cta': 'Book a visit',
      'services': [['Gel Nails', 'Gel'], ['Manicure', 'Manicure']],
      'prices': [['Gel Nails', '\$50'], ['Manicure', '\$30'], ['Nail Art', '\$20']],
      'hours': [['Tue – Sun', '11:00 – 20:00'], ['Monday', '11:00 – 20:00']],
      'color': '#7a6657',
      'hidden': <String>[],
    };
    Future<String> ask(String system, String user, Map<String, dynamic> schema) => engine.chat(system, user, schema: schema, maxTokens: 600);
    for (final say in [
      'We are closed on Mondays, make the prices 10% cheaper and use a pink colour',
      'Hide the floating buttons and rename the business to Mia Nail Studio',
      'Change the booking email to hello@mia.example',
      'Add a service called Facial for \$60',
    ]) {
      final plan = await planChat(ask: ask, editorActions: catalog, snapshot: snapshot, history: const [], message: say, siteLang: Lang.en);
      // ignore: avoid_print
      print('chat "$say"\n  routed=${plan.routed}\n  actions=${plan.actions}');
      expect(plan.routed, isNotEmpty);
    }
    await engine.stop();
  }, skip: skip);
}
