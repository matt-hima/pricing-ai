import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:self_quote/app_state.dart';
import 'package:self_quote/case_analysis/site_profile_store.dart';
import 'package:self_quote/i18n/i18n.dart';
import 'package:self_quote/main.dart';
import 'package:self_quote/site/site_store.dart';
import 'package:self_quote/ui/site_learn_dialog.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 真正的 Mac App：案件分析 → 學習新網站 → 打開一個清單頁、讓本機 AI 對應欄位、儲存 → 點開清單裡的第一件公告、同樣學起來。
///   `MODEL=Qwen2.5-7B-Instruct LIVE_ENGINE_STORAGE=/path/to/pricing-ai flutter test integration_test/site_learn_app_test.dart -d macos`
/// LEARN_URL 可以換成別的網站的清單頁（預設是政府電子採購網的招標查詢「網站」）。截圖存到 CASE_SHOTS（可省略）。
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('learn a site: list page and one notice, mapped by the local AI and saved', (tester) async {
    SharedPreferences.setMockInitialValues({
      'flutter.selfquote.engine.storage': Platform.environment['LIVE_ENGINE_STORAGE'] ?? '/Volumes/dev_disk/pricing-ai',
      'flutter.selfquote.lang.v1': 'zh-TW',
    });
    I18n.lang = Lang.zh;
    final state = AppState();
    final siteStore = Store();
    await siteStore.init();
    await tester.pumpWidget(SelfQuoteApp(state: state, siteStore: siteStore));
    await state.init();
    if (Platform.environment['MODEL'] case final m?) state.setModel(m);
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
        await tester.pump(const Duration(milliseconds: 400));
      }
    }

    Future<void> click(Finder target, String what) async {
      await waitFor(() => target.hitTestable().evaluate().isNotEmpty, '"$what" to be clickable', seconds: 60);
      await tester.pump(const Duration(milliseconds: 600));
      await tester.tap(target.hitTestable().first, kind: PointerDeviceKind.mouse);
      await tester.pump(const Duration(milliseconds: 400));
    }

    String value(String f) => find.byKey(ValueKey('learn.value:$f')).evaluate().isEmpty ? '' : tester.widget<Text>(find.byKey(ValueKey('learn.value:$f'))).data ?? '';
    final panel = find.byType(SiteLearnPanel);
    final fieldsOf = {
      'tenderList': ['title', 'agency', 'caseNo', 'deadline', 'budget'],
      'tenderNotice': ['title', 'agency', 'caseNo', 'budget', 'deadline', 'awardMethod'],
    };

    /// 打開網址 → 讀這一頁（頁面載入完才讀得到東西）→ 選種類 → AI 對應 → 印出讀到的值 → 儲存
    Future<void> learn(String? url, String kind) async {
      if (url != null) {
        final address = find.byKey(const ValueKey('learn.address'));
        await click(address, 'address field');
        await tester.enterText(address, url);
        await tester.testTextInput.receiveAction(TextInputAction.done);
        await tester.pump(const Duration(seconds: 6));
      }
      final chip = find.byKey(ValueKey('learn.kind:$kind'));
      for (var i = 0; i < 10 && chip.evaluate().isEmpty; i++) {
        await click(find.byKey(const ValueKey('learn.read')), 'Read this page');
        await tester.pump(const Duration(seconds: 3));
      }
      expect(chip, findsOneWidget, reason: 'the page should have a table or labelled fields');
      await click(chip, kind);
      final watch = Stopwatch()..start();
      await click(find.byKey(const ValueKey('learn.map')), 'Let the local AI map the fields');
      await waitFor(() => tester.widget<OutlinedButton>(find.byKey(const ValueKey('learn.map'))).onPressed != null, 'the local AI to map the fields', seconds: 600);
      final texts = [for (final e in find.descendant(of: panel, matching: find.byType(Text)).evaluate()) (e.widget as Text).data ?? ''].where((t) => t.contains('失敗') || t.contains('列')).toList();
      // ignore: avoid_print
      print('LEARN $kind (${(watch.elapsedMilliseconds / 1000).toStringAsFixed(0)} s, ${state.modelBase}): ${[for (final f in fieldsOf[kind]!) '$f="${value(f)}"'].join(' · ')} ${texts.join(' ')}');
      await shot('learn_$kind');
      final save = find.byKey(const ValueKey('learn.save'));
      if (tester.widget<FilledButton>(save).onPressed != null) {
        await click(save, 'Save');
        await waitFor(() => find.textContaining('已儲存').evaluate().isNotEmpty, 'saved');
      } else {
        // ignore: avoid_print
        print('LEARN $kind: required fields missing, not saved');
      }
    }

    await click(find.text(tr('shell.cases')), 'Case analysis tab');
    await click(find.byKey(const ValueKey('learn.open')), 'Learn a new site');
    await waitFor(() => find.byType(SiteLearnDialog).evaluate().isNotEmpty, 'the learn dialog');
    final listUrl = Platform.environment['LEARN_URL'] ??
        'https://web.pcc.gov.tw/prkms/tender/common/basic/readTenderBasic?pageSize=&firstSearch=true&searchType=basic&isBinding=N&isLogIn=N&level_1=on&orgName=&orgId=&tenderName=%E7%B6%B2%E7%AB%99&tenderId=&tenderType=TENDER_DECLARATION&tenderWay=TENDER_WAY_ALL_DECLARATION&dateType=isSpdt&radProctrgCate=&policyAdvocacy=';
    await learn(listUrl, 'tenderList');

    expect((await SiteProfileStore.load()).of(Uri.parse(listUrl).host).kinds, isNotEmpty, reason: 'the list should be saved');

    // 點清單第一列：左邊打開那一件公告，接著學公告頁（網址不用自己打）
    await click(find.byKey(const ValueKey('learn.row:0')), 'first row');
    await tester.pump(const Duration(seconds: 6));
    await learn(null, 'tenderNotice');
    expect(tester.takeException(), isNull);
  });
}
