import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:self_quote/app_state.dart';
import 'package:self_quote/i18n/i18n.dart';
import 'package:self_quote/main.dart';
import 'package:self_quote/site/site_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 真正的 Mac App 測試：啟動整個應用程式（WebView 裡的 GrapesJS、llama.cpp 在 GPU 上跑本機模型），
/// 新的日文美容室網站「從聊天開始」→ 第一則訊息描述店家 → 產生整頁 → 再用聊天修改。
/// 偏好設定用記憶體裡的假資料，不會動到平常使用的網站與設定。
/// 執行時螢幕要亮著、視窗要在前景：macOS 不會為睡著的螢幕或被遮住的視窗繪製畫面，測試會卡住。建議：
///   caffeinate -d -i flutter test integration_test/chat_edit_test.dart -d macos
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('a new site starts in chat, the first message builds the page, later messages edit it', (tester) async {
    SharedPreferences.setMockInitialValues({
      'flutter.selfquote.engine.storage': Platform.environment['LIVE_ENGINE_STORAGE'] ?? '/Volumes/dev_disk/pricing-ai',
      'flutter.selfquote.lang.v1': 'en',
    });
    I18n.lang = Lang.en;
    final state = AppState();
    final siteStore = Store();
    await siteStore.init();
    siteStore.createSite('ja'); // 日文範本；initialized = false → 從聊天開始
    expect(siteStore.current.initialized, isFalse);

    await tester.pumpWidget(SelfQuoteApp(state: state, siteStore: siteStore));
    await state.init();
    state.startQuoting(); // 略過介紹頁（只寫進假的偏好設定）
    await tester.pump(const Duration(milliseconds: 500));

    Future<void> waitFor(bool Function() ok, String what, {int seconds = 120}) async {
      final end = DateTime.now().add(Duration(seconds: seconds));
      while (!ok()) {
        if (DateTime.now().isAfter(end)) {
          final texts = [for (final e in find.byType(Text).evaluate()) (e.widget as Text).data ?? ''].where((t) => t.isNotEmpty).toList();
          // ignore: avoid_print
          final chat = [for (final e in find.byType(SelectableText).evaluate()) (e.widget as SelectableText).data ?? ''];
          print('TIMEOUT DUMP: busy=${state.busy} progress="${state.progressText}"\n  chat bubbles (last 3): ${chat.reversed.take(3).map((t) => t.replaceAll('\n', ' / ')).toList()}\n  texts: ${texts.where((t) => t.contains('→') || t.contains('hidden') || t.contains('shown') || t.contains('already') || t.contains('unknown') || t.contains('failed') || t.contains(': ')).toList()}');
          fail('timed out waiting for $what');
        }
        await tester.pump(const Duration(milliseconds: 400));
      }
    }

    // 1) 切到「網站建置」：編輯器載入，聊天面板自動打開（因為網站還沒初始化）
    await tester.tap(find.byIcon(Icons.web_outlined));
    await tester.pump(const Duration(milliseconds: 300));
    await waitFor(() => find.byType(CircularProgressIndicator).evaluate().isEmpty, 'the editor to load', seconds: 60);
    final input = find.byWidgetPredicate((w) => w is TextField && w.decoration?.hintText == 'Describe your business…');
    expect(input, findsOneWidget, reason: 'the chat should open by itself with the "describe your business" prompt');
    expect(find.textContaining("Let's set up your site"), findsOneWidget);

    /// 送出一則訊息，等到結果列表裡出現 [shows]（對話是 ListView.builder，只會建出看得見的訊息，
    /// 所以不能用「訊息數量增加」判斷；結果文字每次都不一樣，可以直接等它出現）
    Future<void> say(String message, {required String shows}) async {
      final box = find.byWidgetPredicate((w) => w is TextField && (w.decoration?.hintText == 'Ask for a change…' || w.decoration?.hintText == 'Describe your business…'));
      expect(box, findsOneWidget);
      final tf = tester.widget<TextField>(box);
      expect(tf.enabled, isTrue, reason: 'the chat input should be enabled between messages');
      tf.controller!.text = message; // 直接寫進 controller（比模擬鍵盤輸入穩定）
      final sendBtn = find.ancestor(of: find.byIcon(Icons.send), matching: find.byType(IconButton));
      expect(sendBtn, findsOneWidget);
      tester.widget<IconButton>(sendBtn).onPressed!.call();
      await tester.pump(const Duration(milliseconds: 200));
      await waitFor(() => find.textContaining(shows).evaluate().isNotEmpty || find.textContaining('Sorry, that did not work').evaluate().isNotEmpty, 'a result containing "$shows" for "$message"', seconds: 240);
      expect(find.textContaining('Sorry, that did not work'), findsNothing, reason: 'the chat reported an error for "$message"');
      await tester.pump(const Duration(milliseconds: 800));
      final lines = [for (final e in find.byType(Text).evaluate()) (e.widget as Text).data ?? ''].where((t) => t.contains('→') || t.contains('booking form') || t.contains('problem') || t.contains('hidden')).toList();
      // ignore: avoid_print
      print('CHAT "$message"\n  result lines: $lines');
    }

    // 2) 第一則訊息：用日文描述美容室（「美容室・サロン」案例：指名、夜間も予約）
    await say('名古屋の美容室です。カット、カラー、パーマ、トリートメントがあります。スタイリストを指名して予約してもらいたいです。営業時間は10時から19時、火曜定休です。夜でもネットで予約を受けたいです。', shows: 'No problems found');
    expect(find.textContaining('Your site is ready'), findsOneWidget);
    await waitFor(() => siteStore.current.initialized, 'the site to be marked initialized', seconds: 10);
    await waitFor(() => !siteStore.current.project.contains('桜エステクリニック'), 'the sample clinic name to be replaced', seconds: 30);
    final p1 = siteStore.current.project;
    expect(p1.contains('ご希望のスタッフ'), isTrue, reason: 'salon booking question (preferred stylist) should be added');
    expect(p1.contains('カット'), isTrue);
    expect(p1.contains('休業') || p1.contains('お問い合わせください'), isTrue);
    expect(find.textContaining('No problems found'), findsWidgets, reason: 'the cheat-sheet check should pass');
    expect(find.byWidgetPredicate((w) => w is TextField && w.decoration?.hintText == 'Ask for a change…'), findsOneWidget, reason: 'after setup the chat switches to edit mode');

    // 3) 之後用聊天修改（每則一件事）
    await say('Use a blue colour', shows: 'main colour →');
    // 主色存在專案的 data-pal；模型可能給 #007bff 或 #2f6fb3，只要是藍色（B 分量最大）、且已被調到白字可讀即可
    String? primary() => RegExp(r'data-pal[^#]*(#[0-9a-fA-F]{6})').firstMatch(siteStore.current.project)?[1];
    await waitFor(() => primary() != null && primary() != '#7a6657', 'the main colour to change', seconds: 30);
    final c = int.parse(primary()!.substring(1), radix: 16);
    expect((c & 0xFF) > ((c >> 16) & 0xFF), isTrue, reason: 'the new main colour ${primary()} should be blue');

    await say('Hide the floating buttons', shows: 'float hidden');
    await waitFor(() => siteStore.current.project.contains('"display":"none"'), 'the floating buttons to be hidden', seconds: 30);

    await tester.pump(const Duration(seconds: 1));
    // ignore: avoid_print
    print('FINAL: brand/format ok, stylist question=${siteStore.current.project.contains('ご希望のスタッフ')} primary=${RegExp(r'data-pal[^#]*(#[0-9a-fA-F]{6})').firstMatch(siteStore.current.project)?[1]} hidden=${siteStore.current.project.contains('"display":"none"')}');
  });
}
