import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:self_quote/case_analysis/page_reader.dart';
import 'package:self_quote/case_analysis/site_profile_store.dart';
import 'package:self_quote/i18n/i18n.dart';
import 'package:self_quote/ui/site_learn_dialog.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 學習新網站：讀使用者打開的頁面 → 選頁面種類 → AI 提出對應（這裡用寫好的假答案）→ 使用者改錯的那一個 → 儲存 →
/// 下次同一種頁面不用 AI 直接讀；驗證頁不會被當成學過的頁面
void main() {
  String page(String f) => File('test/fixtures/$f').readAsStringSync();
  final noticeUrl = Uri.parse('https://web.pcc.gov.tw/tps/QueryTender/query/searchTenderDetail?pkPmsMain=1');
  final listUrl = Uri.parse('https://web.pcc.gov.tw/prkms/tender/common/basic/readTenderBasic?tenderName=x');

  Future<void> pumpPanel(WidgetTester tester, SiteProfileStore store, (String, Uri) Function() current, {ProposeMapping? propose, void Function()? onPropose}) async {
    await tester.binding.setSurfaceSize(const Size(600, 1600));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: 420,
          child: SiteLearnPanel(
            current: () async => current(),
            store: store,
            propose: propose ??
                (d, k) async {
                  onPropose?.call();
                  // AI 把截止投標對應錯成「公告日」（也是日期，檢查擋不下來）：使用者要自己改
                  return PageMapping(k, labels: {'title': '標案名稱', 'agency': '機關名稱', 'caseNo': '標案案號', 'budget': '預算金額', 'deadline': '公告日', 'awardMethod': '決標方式'});
                },
          ),
        ),
      ),
    ));
  }

  testWidgets('learn a tender notice, correct one field, save; the next page of that kind is read without AI', (tester) async {
    I18n.lang = Lang.zh;
    SharedPreferences.setMockInitialValues({});
    var store = await SiteProfileStore.load();
    var asked = 0;
    await pumpPanel(tester, store, () => (page('pcc_tender_notice.html'), noticeUrl), onPropose: () => asked++);

    await tester.tap(find.byKey(const ValueKey('learn.read')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('learn.kind:tenderNotice')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('learn.map')));
    await tester.pumpAndSettle();
    expect(asked, 1);
    Text value(String f) => tester.widget<Text>(find.byKey(ValueKey('learn.value:$f')));
    expect(value('title').data, '行政院主計總處薪資管理系統移轉導入暨擴充服務案');
    expect(value('budget').data, '1,446,930元');
    expect(value('deadline').data, '115/11/02'); // AI 選錯的：公告日

    // 使用者把截止投標改成正確的標籤
    await tester.tap(find.byKey(const ValueKey('learn.field:deadline')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('截止投標').last);
    await tester.pumpAndSettle();
    expect(value('deadline').data, '115/11/09 17:00');

    await tester.tap(find.byKey(const ValueKey('learn.save')));
    await tester.pumpAndSettle();
    expect(find.textContaining('已儲存'), findsOneWidget);

    // 重新打開（設定檔從本機讀回來）：同一種頁面直接讀到，不問 AI
    store = await SiteProfileStore.load();
    expect(store.of('web.pcc.gov.tw').kinds, {PageKind.tenderNotice});
    await pumpPanel(tester, store, () => (page('pcc_tender_notice.html'), noticeUrl.replace(query: 'pkPmsMain=2')), onPropose: () => asked++);
    await tester.tap(find.byKey(const ValueKey('learn.read')));
    await tester.pumpAndSettle();
    expect(find.textContaining('這一頁已學過'), findsOneWidget);
    expect(find.text('截止投標：115/11/09 17:00'), findsOneWidget);
    expect(asked, 1);

    // 同一個路徑出現驗證頁：不當成學過的頁面，也沒有可以對應的東西
    const check = '<html><body><h2>驗證碼檢核</h2><p>請輸入圖片中的文字</p><form><input name="code"><button>送出</button></form></body></html>';
    await pumpPanel(tester, store, () => (check, noticeUrl));
    await tester.tap(find.byKey(const ValueKey('learn.read')));
    await tester.pumpAndSettle();
    expect(find.textContaining('這一頁已學過'), findsNothing);
    expect(find.text(tr('learn.noStructure')), findsOneWidget);
    expect(find.byKey(const ValueKey('learn.save')), findsNothing);

    // 清除這個網站
    await pumpPanel(tester, store, () => (page('pcc_tender_notice.html'), noticeUrl));
    await tester.tap(find.byKey(const ValueKey('learn.read')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('learn.forget')));
    await tester.pumpAndSettle();
    expect((await SiteProfileStore.load()).profiles, isEmpty);
  });

  testWidgets('changing the page discards what was read', (tester) async {
    I18n.lang = Lang.zh;
    SharedPreferences.setMockInitialValues({});
    final store = await SiteProfileStore.load();
    Widget panel(int v) => MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 420,
              child: SiteLearnPanel(pageVersion: v, current: () async => (page('pcc_tender_notice.html'), noticeUrl), store: store, propose: (d, k) async => PageMapping(k)),
            ),
          ),
        );
    await tester.binding.setSurfaceSize(const Size(600, 1600));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(panel(0));
    await tester.tap(find.byKey(const ValueKey('learn.read')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('learn.kind:tenderNotice')), findsOneWidget);
    await tester.pumpWidget(panel(1)); // 瀏覽器換了一頁
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('learn.kind:tenderNotice')), findsNothing);
  });

  testWidgets('learn a list: columns proposed, rows read, save needs the required fields', (tester) async {
    I18n.lang = Lang.zh;
    SharedPreferences.setMockInitialValues({});
    final store = await SiteProfileStore.load();
    await pumpPanel(tester, store, () => (page('pcc_open_tenders.html'), listUrl), propose: (d, k) async => PageMapping(k, columns: {'title': 2, 'agency': 1, 'caseNo': 2}));
    await tester.tap(find.byKey(const ValueKey('learn.read')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('learn.kind:tenderList')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('learn.map')));
    await tester.pumpAndSettle();
    // 截止投標（必要）沒對應：不能儲存
    expect(find.text(tr('learn.incomplete')), findsOneWidget);
    expect(tester.widget<FilledButton>(find.byKey(const ValueKey('learn.save'))).onPressed, isNull);
    await tester.tap(find.byKey(const ValueKey('learn.field:deadline')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('7:截止投標').last);
    await tester.pumpAndSettle();
    expect(find.text(tr('learn.rows', {'n': '8'})), findsOneWidget);
    expect(tester.widget<Text>(find.byKey(const ValueKey('learn.value:title'))).data, '臺北教師e教材網站功能優化升級採購案');
    await tester.tap(find.byKey(const ValueKey('learn.save')));
    await tester.pumpAndSettle();
    expect((await SiteProfileStore.load()).of('web.pcc.gov.tw').columns[PageKind.tenderList], {'title': 2, 'agency': 1, 'caseNo': 2, 'deadline': 7});
  });
}
