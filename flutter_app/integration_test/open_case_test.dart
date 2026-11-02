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
import 'package:self_quote/ui/case_browser_dialog.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 真正的 Mac App：案件分析分頁找「招標中的案件」→ 點一件的「分析這一案」→ 瀏覽器讀公告、查同機關與同類決標 →
/// 看「這一案怎麼做」：公告重點、本機 AI 讀公告、要贏過誰、多少錢合理。
/// 本機模型用 LIVE_ENGINE_STORAGE=<資料夾> 指定；沒指定時 AI 會失敗，只確認其他部分。截圖存到 CASE_SHOTS（可省略）。
///   caffeinate -d -i flutter test integration_test/open_case_test.dart -d macos
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('open tenders: search, analyze one, local AI reads the notice', (tester) async {
    final engine = Platform.environment['LIVE_ENGINE_STORAGE'];
    SharedPreferences.setMockInitialValues({
      'flutter.selfquote.engine.storage': engine ?? '/Volumes/__no_engine__/pricing-ai',
      'flutter.selfquote.lang.v1': 'zh-TW',
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

    List<String> texts({Finder? within}) => [
          for (final e in (within == null ? find.byType(Text) : find.descendant(of: within, matching: find.byType(Text))).evaluate())
            (e.widget as Text).data ?? (e.widget as Text).textSpan?.toPlainText() ?? '',
        ].where((t) => t.isNotEmpty).toList();

    Future<void> waitFor(bool Function() ok, String what, {int seconds = 90}) async {
      final end = DateTime.now().add(Duration(seconds: seconds));
      while (!ok()) {
        if (DateTime.now().isAfter(end)) {
          // ignore: avoid_print
          print('TIMEOUT DUMP ($what): busy=${state.busy} progress="${state.progressText}"\n  texts: ${texts()}');
          await shot('timeout');
          fail('timed out waiting for $what');
        }
        await tester.pump(const Duration(milliseconds: 400));
      }
    }

    Future<void> pause([int ms = 700]) => tester.pump(Duration(milliseconds: ms));
    Future<void> click(Finder target, String what) async {
      await waitFor(() => target.hitTestable().evaluate().isNotEmpty, '"$what" to be clickable', seconds: 60);
      await pause();
      await tester.tap(target.hitTestable().first, kind: PointerDeviceKind.mouse);
      await pause(400);
    }

    Future<void> wheelTo(Finder area, Finder target, String what) async {
      for (var i = 0; i < 80 && target.hitTestable().evaluate().isEmpty; i++) {
        final center = tester.getCenter(area.first);
        final pointer = TestPointer(1, PointerDeviceKind.mouse)..hover(center);
        final up = target.evaluate().isNotEmpty && tester.getCenter(target.first).dy < tester.getTopLeft(area.first).dy;
        await tester.sendEventToBinding(pointer.scroll(Offset(0, up ? -120 : 120)));
        await tester.pump(const Duration(milliseconds: 120));
      }
      expect(target.hitTestable(), findsWidgets, reason: 'scrolled but "$what" never appeared');
      await pause(500);
    }

    /// 瀏覽器自動跑完並關閉；遇到驗證就略過剩下的公告（測試不處理驗證）
    var sawVerification = false;
    Future<void> autoRun(String name, {int seconds = 300}) async {
      await waitFor(() => find.byType(CaseBrowserDialog).evaluate().isNotEmpty, 'the procurement browser to open', seconds: 20);
      await pause(3000);
      await shot('${name}_running');
      final end = DateTime.now().add(Duration(seconds: seconds));
      while (find.byType(CaseBrowserDialog).evaluate().isNotEmpty) {
        if (find.text(tr('case.browser.verify.title')).evaluate().isNotEmpty) {
          sawVerification = true;
          // ignore: avoid_print
          print('VERIFICATION in $name: skipping the remaining notices');
          await shot('${name}_verification');
          await click(find.text(tr('case.browser.verify.skip')), 'Skip the remaining notices');
        }
        if (DateTime.now().isAfter(end)) fail('timed out waiting for $name to finish');
        await tester.pump(const Duration(milliseconds: 400));
      }
    }

    final page = find.byType(CaseAnalysisPage);
    await click(find.text(tr('shell.cases')), 'Case analysis tab');
    await waitFor(() => find.text(tr('case.title')).hitTestable().evaluate().isNotEmpty, 'the Case analysis page');
    final kw = Platform.environment['OPEN_KEYWORD'] ?? '網站';
    await click(find.byWidgetPredicate((w) => w is TextField && w.decoration?.labelText == tr('case.keyword')), 'keyword field');
    await tester.enterText(find.byWidgetPredicate((w) => w is TextField && w.decoration?.labelText == tr('case.keyword')).hitTestable().first, kw);
    await pause();

    // 1) 找招標中的案件
    await click(find.byKey(const ValueKey('tender.searchOpen')), 'Find open tenders');
    await autoRun('1_open_search', seconds: 120);
    await waitFor(() => find.textContaining(RegExp(r'件還在等標期內')).evaluate().isNotEmpty || find.text(tr('tender.none')).evaluate().isNotEmpty, 'the open tender list');
    final analyze = find.byWidgetPredicate((w) => w.key is ValueKey<String> && (w.key as ValueKey<String>).value.startsWith('tender.analyze:'));
    // ignore: avoid_print
    print('OPEN LIST (${analyze.evaluate().length} analyze buttons): ${texts().where((t) => t.contains('截止投標') || t.contains('等標期')).take(12).toList()}');
    expect(analyze, findsWidgets, reason: 'there should be open tenders for "$kw"');
    await wheelTo(page, analyze, 'first Analyze button');
    await shot('2_open_list');

    // 2) 分析第一件
    final url = ((tester.widget(analyze.first).key! as ValueKey<String>).value).substring('tender.analyze:'.length);
    // ignore: avoid_print
    print('ANALYZE: $url');
    await click(analyze.first, 'Analyze this tender');
    await autoRun('3_tender_browser', seconds: 600);

    // 3) 這一案怎麼做
    await wheelTo(page, find.text(tr('tender.brief')), 'the tender brief card');
    await waitFor(
      () => find.textContaining('${tr('tender.scope')}：').evaluate().isNotEmpty || find.textContaining('本機 AI 讀取失敗').evaluate().isNotEmpty,
      'the local AI to read the notice',
      seconds: 900,
    );
    await pause(1000);
    final brief = find.ancestor(of: find.text(tr('tender.brief')), matching: find.byType(Card));
    final out = texts(within: brief.evaluate().isEmpty ? page : brief.first);
    // ignore: avoid_print
    print('TENDER BRIEF (verification: $sawVerification):\n  ${out.join('\n  ')}');
    await shot('4_tender_brief');
    expect(find.text(tr('tender.noNotice')), findsNothing, reason: 'the notice should have been read');
    expect(find.text(tr('tender.beat')), findsOneWidget);
    expect(find.text(tr('tender.price')), findsOneWidget);
    if (engine != null) expect(find.textContaining('本機 AI 讀取失敗'), findsNothing, reason: 'the local model should read the notice');
    await wheelTo(page, find.text(tr('tender.price')), 'price section');
    await shot('5_tender_price');
    expect(tester.takeException(), isNull);
  });
}
