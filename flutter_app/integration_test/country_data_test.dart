import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:self_quote/app_state.dart';
import 'package:self_quote/i18n/i18n.dart';
import 'package:self_quote/main.dart';
import 'package:self_quote/site/site_store.dart';
import 'package:self_quote/ui/case_analysis_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 真正的 Mac App：案件分析分頁的「官方決標開放資料」依序選日本、葡萄牙、英國、西班牙，
/// 用當地語言的關鍵字下載並分析近 3 個月（從各國官方伺服器下載，西班牙可能要好幾分鐘）。
///   COUNTRIES=jp,pt,uk,es CASE_SHOTS=<資料夾> flutter test integration_test/country_data_test.dart -d macos
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('official award data from other countries', (tester) async {
    SharedPreferences.setMockInitialValues({
      'flutter.selfquote.engine.storage': '/Volumes/__no_engine__/pricing-ai',
      'flutter.selfquote.lang.v1': 'zh-TW',
      'flutter.selfquote.case.query': ['網站', 'any', '3'],
    });
    I18n.lang = Lang.zh;
    final state = AppState();
    final siteStore = Store();
    await siteStore.init();
    await tester.pumpWidget(SelfQuoteApp(state: state, siteStore: siteStore));
    await state.init();
    I18n.lang = Lang.zh;
    state.startQuoting();
    await tester.pump(const Duration(milliseconds: 500));

    final shots = Platform.environment['CASE_SHOTS'];
    Future<void> shot(String name) async {
      if (shots == null) return;
      await tester.pump(const Duration(milliseconds: 300));
      final rv = tester.binding.renderViews.first;
      final img = await (rv.debugLayer! as OffsetLayer).toImage(rv.paintBounds);
      final png = await img.toByteData(format: ui.ImageByteFormat.png);
      File('$shots/$name.png').writeAsBytesSync(png!.buffer.asUint8List());
    }

    Future<void> waitFor(bool Function() ok, String what, {int seconds = 90}) async {
      final end = DateTime.now().add(Duration(seconds: seconds));
      while (!ok()) {
        if (DateTime.now().isAfter(end)) {
          await shot('timeout');
          fail('timed out waiting for $what');
        }
        await tester.pump(const Duration(milliseconds: 500));
      }
    }

    Future<void> pause([int ms = 600]) => tester.pump(Duration(milliseconds: ms));
    Future<void> click(Finder target, String what) async {
      await waitFor(() => target.hitTestable().evaluate().isNotEmpty, '"$what" to be clickable', seconds: 60);
      await pause();
      await tester.tap(target.hitTestable().first, kind: PointerDeviceKind.mouse);
      await pause(400);
    }

    Future<void> wheelTo(Finder area, Finder target, String what) async {
      for (var i = 0; i < 60 && target.hitTestable().evaluate().isEmpty; i++) {
        final pointer = TestPointer(1, PointerDeviceKind.mouse)..hover(tester.getCenter(area.first));
        final up = target.evaluate().isNotEmpty && tester.getCenter(target.first).dy < tester.getTopLeft(area.first).dy;
        await tester.sendEventToBinding(pointer.scroll(Offset(0, up ? -120 : 120)));
        await tester.pump(const Duration(milliseconds: 120));
      }
      expect(target.hitTestable(), findsWidgets, reason: 'scrolled but "$what" never appeared');
      await pause(400);
    }

    await click(find.text(tr('shell.cases')), 'Case analysis tab');
    final page = find.byType(CaseAnalysisPage);
    final countries = (Platform.environment['COUNTRIES'] ?? 'jp,pt,uk,es').split(',');
    for (final c in countries) {
      final chip = find.byKey(ValueKey('country:$c'));
      await wheelTo(page, chip, '$c country chip');
      await click(chip, '$c country chip');
      final kw = tester.widget<TextField>(find.byKey(const ValueKey('case.localKeywords'))).controller!.text;
      final run = find.text(tr('case.data.run', {'m': '3'}));
      final sw = Stopwatch()..start();
      await click(run, 'Analyze official data ($c)');
      final loaded = RegExp(r'資料庫裡有 (\d+) 筆符合的決標');
      if (c == 'es') {
        // 西班牙的伺服器很慢：第一個月匯入完就按「停止」，用已匯入的資料分析
        await waitFor(() => find.textContaining(RegExp(r'下載資料檔 [1-9] /')).evaluate().isNotEmpty || find.textContaining(loaded).evaluate().isNotEmpty, 'the first Spanish month', seconds: 3600);
        final stop = find.byKey(const ValueKey('case.data.stop'));
        if (stop.evaluate().isNotEmpty) await click(stop, 'Stop button');
      }
      // 等待中也印出狀態（流量限制的等待、已下載的 MB），確認不是卡住
      var lastStatus = '';
      await waitFor(() {
        final status = [for (final e in find.textContaining(RegExp(r'下載資料檔|伺服器要求等待')).evaluate()) (e.widget as Text).data ?? ''].join(' ');
        if (status.isNotEmpty && status != lastStatus) {
          lastStatus = status;
          // ignore: avoid_print
          print('STATUS $c ${sw.elapsed.inSeconds}s: $status');
        }
        return find.textContaining(loaded).evaluate().isNotEmpty;
      }, 'the $c data', seconds: 3600);
      final texts = [for (final e in find.descendant(of: page, matching: find.byType(Text)).evaluate()) (e.widget as Text).data ?? ''];
      final line = texts.firstWhere(loaded.hasMatch);
      final median = texts.skipWhile((t) => t != tr('case.s.median')).skip(1).firstOrNull;
      final winners = texts.where((t) => t.contains(tr('case.data.vendor', {'w': '', 't': ''}).split(' ').first)).take(3).toList();
      // ignore: avoid_print
      print('COUNTRY $c [$kw] in ${sw.elapsed.inSeconds}s: $line · median $median · $winners');
      await wheelTo(page, find.text(tr('case.data.recent')), 'recent awards ($c)');
      await shot('country_$c');
      expect(int.parse(loaded.firstMatch(line)![1]!), greaterThan(0), reason: '$c should have matching awards');
    }
    expect(tester.takeException(), isNull);
  });
}
