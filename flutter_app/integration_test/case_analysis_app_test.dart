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
import 'package:self_quote/ui/competitor_dialog.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 真正的 Mac App：案件分析分頁在內嵌瀏覽器打開政府電子採購網，像使用者一樣點開案件；再到專案估價打開「查歷史案件」並讓 AI 摘要。
/// 模型存放位置設成不存在的資料夾，AI 摘要會立刻失敗（不會下載模型），用來確認失敗時仍顯示查詢結果；
/// 已裝好模型時用 LIVE_ENGINE_STORAGE=<資料夾> 指定，就會跑真的摘要。截圖存到 CASE_SHOTS（可省略）。
///   caffeinate -d -i flutter test integration_test/case_analysis_app_test.dart -d macos
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('case analysis tab searches PCC; past-case popup searches and summarizes', (tester) async {
    SharedPreferences.setMockInitialValues({
      'flutter.selfquote.engine.storage': Platform.environment['LIVE_ENGINE_STORAGE'] ?? '/Volumes/__no_engine__/pricing-ai',
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

    Future<void> waitFor(bool Function() ok, String what, {int seconds = 90}) async {
      final end = DateTime.now().add(Duration(seconds: seconds));
      while (!ok()) {
        if (DateTime.now().isAfter(end)) {
          final texts = [for (final e in find.byType(Text).hitTestable().evaluate()) (e.widget as Text).data ?? ''].where((t) => t.isNotEmpty).toList();
          // ignore: avoid_print
          print('TIMEOUT DUMP ($what): busy=${state.busy} progress="${state.progressText}"\n  visible texts: $texts');
          await shot('timeout');
          fail('timed out waiting for $what');
        }
        await tester.pump(const Duration(milliseconds: 400));
      }
    }

    // ---- 像真人一樣操作：等東西出現在畫面上、停一下、用滑鼠點、用鍵盤打字、用滾輪捲動 ----
    Future<void> pause([int ms = 700]) => tester.pump(Duration(milliseconds: ms));

    /// 等 [target] 真的出現在畫面上（不是被別的頁面蓋住），再用滑鼠點它中心
    Future<void> click(Finder target, String what) async {
      await waitFor(() => target.hitTestable().evaluate().isNotEmpty, '"$what" to be clickable', seconds: 60);
      await pause();
      await tester.tap(target.hitTestable().first, kind: PointerDeviceKind.mouse);
      await pause(400);
    }

    /// 點輸入框、全選刪掉原本的字、打新的字
    Future<void> typeInto(Finder field, String text, String what) async {
      await click(field, what);
      await tester.enterText(field.hitTestable().first, text);
      await pause(500);
    }

    /// 在 [area] 上用滑鼠滾輪往下捲，直到 [target] 出現在畫面上
    Future<void> wheelTo(Finder area, Finder target, String what) async {
      for (var i = 0; i < 60 && target.hitTestable().evaluate().isEmpty; i++) {
        final center = tester.getCenter(area.first);
        final pointer = TestPointer(1, PointerDeviceKind.mouse)..hover(center);
        await tester.sendEventToBinding(pointer.scroll(const Offset(0, 120)));
        await tester.pump(const Duration(milliseconds: 120));
      }
      expect(target.hitTestable(), findsWidgets, reason: 'scrolled but "$what" never appeared');
      await pause(500);
    }

    /// 在內嵌瀏覽器裡：等搜尋結果載入 → 像使用者一樣從側欄點開 [open] 件案件 → 按完成鈕
    var sawVerification = false, checkedContinue = false;

    /// 自動模式：瀏覽器自己依序查詢、點開公告、查競爭對手，完成後自動關閉。只等它，不點任何東西。
    Future<void> autoRun(String shotName, {int seconds = 300}) async {
      await waitFor(() => find.byType(CaseBrowserDialog).evaluate().isNotEmpty, 'the procurement browser to open', seconds: 20);
      await pause(3000);
      await shot('${shotName}_running');
      final end = DateTime.now().add(Duration(seconds: seconds));
      while (find.byType(CaseBrowserDialog).evaluate().isNotEmpty) {
        // 採購網要求驗證：App 停下來交給使用者。測試不會（也不該）通過驗證，像使用者一樣選「略過剩下的公告」
        if (find.text(tr('case.browser.verify.title')).evaluate().isNotEmpty) {
          sawVerification = true;
          // ignore: avoid_print
          print('VERIFICATION: paused and handed to the user; skipping the remaining notices');
          await shot('${shotName}_verification');
          await pause(3000); // 確認真的停住，沒有繼續自動點開
          expect(find.text(tr('case.browser.verify.title')), findsOneWidget, reason: 'should stay paused until the user acts');
          // 沒有完成驗證就按「已完成驗證，繼續」：App 應該重新確認，發現還沒通過，繼續停著並提示
          if (!checkedContinue) {
            checkedContinue = true;
            await click(find.text(tr('case.browser.verify.done')), 'Done, continue (without completing the check)');
            await waitFor(() => find.text(tr('case.browser.verify.notYet')).evaluate().isNotEmpty, 'the not-yet-passed message', seconds: 45);
            expect(find.text(tr('case.browser.verify.title')), findsOneWidget, reason: 'should still be paused');
            // ignore: avoid_print
            print('CONTINUE CHECK: not passed detected, still paused');
            await shot('${shotName}_not_yet');
          }
          await click(find.text(tr('case.browser.verify.skip')), 'Skip the remaining notices');
        }
        if (DateTime.now().isAfter(end)) fail('timed out waiting for the automatic cross-reference to finish and close');
        await tester.pump(const Duration(milliseconds: 400));
      }
    }

    // 1) 案件分析分頁：點分頁 → 打關鍵字 → 點「分析」→ 在內嵌的採購網看結果、點開兩件 → 使用這些案件
    await click(find.text(tr('shell.cases')), 'Case analysis tab');
    await waitFor(() => find.text(tr('case.title')).hitTestable().evaluate().isNotEmpty, 'the Case analysis page');
    await typeInto(find.byWidgetPredicate((w) => w is TextField && w.decoration?.labelText == tr('case.keyword')), '網站', 'keyword field');
    // 相關查詢字出現（採購網是連續文字比對）：預設勾選 網頁、官網、入口網
    await waitFor(() => find.widgetWithText(FilterChip, '網頁').evaluate().isNotEmpty, 'related keyword chips');
    expect(tester.widget<FilterChip>(find.widgetWithText(FilterChip, '網頁')).selected, isTrue);
    await click(find.text(tr('case.search')), 'Analyze button');
    await autoRun('1_browser');
    await waitFor(() => find.text(tr('case.summary')).evaluate().isNotEmpty, 'the results on the Case analysis page');
    await shot('2_case_tab');

    final page = find.byType(CaseAnalysisPage);
    await wheelTo(page, find.text(tr('case.useEstimate')), 'Use project estimate button');
    await click(find.text(tr('case.useEstimate')), 'Use project estimate button');
    final noticesRead = find.text(tr('case.d.winners')).evaluate().isNotEmpty || find.text(tr('case.comp')).evaluate().isNotEmpty || !sawVerification;
    // ignore: avoid_print
    print('NOTICES READ: $noticesRead (verification: $sawVerification)');
    if (noticesRead) {
      await wheelTo(page, find.text(tr('case.d.winners')), 'Frequent winners section');
      await wheelTo(page, find.textContaining(RegExp(r'近 12 個月得標')), 'auto-looked-up competitor record');
      await shot('3a_competitors');
      await wheelTo(page, find.text(tr('case.rev')), 'Reviewer cross-reference card');
      final rev = [for (final e in find.byType(Text).hitTestable().evaluate()) (e.widget as Text).data ?? ''].where((t) => t.contains('評選') || t.contains('得標：')).toList();
      // ignore: avoid_print
      print('REVIEWERS: $rev');
      await shot('3e_reviewers');
      final texts = [for (final e in find.byType(Text).hitTestable().evaluate()) (e.widget as Text).data ?? ''].where((t) => t.isNotEmpty).toList();
      // ignore: avoid_print
      print('CASES: $texts');
      await shot('3_case_competition');
    }

    if (noticesRead) {
      // 潛在競爭對手 → 第一家的「得標紀錄」：瀏覽器依序查得標、投標 → 使用這份紀錄 → 看得標率等
      await wheelTo(page, find.text(tr('case.comp')), 'Potential competitors card');
      await wheelTo(page, find.text(tr('case.comp.history')), 'Award record button');
      await click(find.text(tr('case.comp.history')), 'Award record button');
      await autoRun('3b_vendor_browser', seconds: 90);
      await waitFor(() => find.text(tr('comp.rate')).evaluate().isNotEmpty, 'the competitor record');
      final comp = [for (final e in find.descendant(of: find.byType(CompetitorDialog), matching: find.byType(Text)).evaluate()) (e.widget as Text).data ?? ''].where((t) => t.isNotEmpty).toList();
      // ignore: avoid_print
      print('COMPETITOR: $comp');
      await shot('3c_competitor');

      // Google AI 模式：在 App 內的瀏覽器打開，給使用者看（App 不讀取 Google 的內容）
      await click(find.text(tr('comp.google')), 'Google AI Mode button');
      await waitFor(() => find.byType(CaseBrowserDialog).evaluate().isNotEmpty, 'Google AI Mode to open');
      await pause(6000);
      expect(find.descendant(of: find.byType(CaseBrowserDialog), matching: find.textContaining('google')), findsWidgets);
      await shot('3d_google');
      await click(find.descendant(of: find.byType(CaseBrowserDialog), matching: find.text(tr('mkt.close'))), 'Close Google');
      await waitFor(() => find.byType(CaseBrowserDialog).evaluate().isEmpty, 'Google to close', seconds: 10);
      await click(find.descendant(of: find.byType(CompetitorDialog), matching: find.text(tr('mkt.close'))), 'Close competitor');
      await waitFor(() => find.byType(CompetitorDialog).evaluate().isEmpty, 'the competitor dialog to close', seconds: 10);
    }

    // 2) 專案估價：點「查歷史案件」→ 採購網自動打開 → 點開一件 → 「AI 摘要這些案件」→ 等摘要 → 關閉
    await click(find.text(tr('shell.pricing')), 'Project estimate tab');
    await click(find.text(tr('hist.button')), 'Past cases button');
    await autoRun('4_hist_browser');
    await waitFor(() => find.text(tr('hist.summary')).evaluate().isNotEmpty || find.textContaining('AI 摘要失敗').evaluate().isNotEmpty, 'the AI summary', seconds: 300);
    expect(find.text(tr('hist.cases')), findsOneWidget);
    final popup = [for (final e in find.descendant(of: find.byType(AlertDialog), matching: find.byType(Text)).evaluate()) (e.widget as Text).data ?? ''].where((t) => t.isNotEmpty).toList();
    // ignore: avoid_print
    print('POPUP: $popup');
    await shot('5_history_summary');
    expect(find.text(tr('hist.summary')), findsOneWidget, reason: 'the local AI should write a summary');
    await click(find.text(tr('mkt.close')).last, 'Close button');
    await waitFor(() => find.byType(AlertDialog).evaluate().isEmpty, 'the popup to close', seconds: 10);
    expect(tester.takeException(), isNull);
  });
}
