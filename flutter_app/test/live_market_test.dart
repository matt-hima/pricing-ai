@Timeout(Duration(minutes: 15))
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:self_quote/engine/local_engine.dart';
import 'package:self_quote/engine/web_search.dart';
import 'package:self_quote/i18n/i18n.dart';
import 'package:self_quote/site/market_research.dart';

/// 市場行情的真實測試：真的上 Bing 搜尋、讀網頁，再交給本機模型整理成價目表。預設略過。
/// 執行：LIVE_ENGINE_ROOT=… flutter test test/live_market_test.dart
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({});
  final root = Platform.environment['LIVE_ENGINE_ROOT'];

  test('search the web, then build a price table from what was found', () async {
    HttpOverrides.global = null;
    final engine = LocalEngine(root: Directory(root!));
    await engine.prepare(Platform.environment['LIVE_ENGINE_MODEL'] ?? 'Qwen2.5-1.5B-Instruct', (p, t) {});
    for (final c in const [(Lang.ja, '美容室', '渋谷'), (Lang.zh, '美髮沙龍', '台北')]) {
      final queries = marketQueries(c.$2, c.$3, c.$1.name);
      final hits = <SearchHit>[];
      for (final q in queries) {
        hits.addAll((await bingSearch(q, c.$1.name)).where((h) => !skipHost(Uri.parse(h.url).host)));
      }
      // ignore: avoid_print
      print('MKT ${c.$1.name}: ${hits.length} hits, first: ${hits.isEmpty ? '-' : '${hits.first.url} ${hits.first.title}'}');
      final ev = StringBuffer();
      for (final h in hits.take(6)) {
        ev.writeln(priceExcerpts(h.snippet.replaceAll(RegExp(r'\s{2,}'), '\n'), max: 300));
      }
      for (final h in hits.take(3)) {
        ev.writeln(priceExcerpts(await fetchPageText(h.url), max: 700));
      }
      // ignore: avoid_print
      print('MKT evidence chars=${ev.length}');
      expect(hits, isNotEmpty);
      if (ev.toString().trim().isEmpty) continue; // 查不到價格：應用程式會顯示「找不到價格資料」
      final rows = await buildPriceTable(
        ask: (s, u, schema) => engine.chat(s, u, schema: schema, maxTokens: 900),
        lang: c.$1,
        business: c.$2,
        area: c.$3,
        evidence: ev.toString(),
      );
      // ignore: avoid_print
      print('MKT rows: ${rows.map((r) => '${r.name}|${r.sub}|${r.price}').join(' ; ')}');
      expect(rows, isNotEmpty);
    }
    await engine.stop();
  }, skip: root == null ? 'set LIVE_ENGINE_ROOT' : null);
}
