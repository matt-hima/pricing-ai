import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:self_quote/app_state.dart';
import 'package:self_quote/case_analysis/pcc.dart';
import 'package:self_quote/case_analysis/tender.dart';
import 'package:self_quote/i18n/i18n.dart';
import 'package:self_quote/ui/case_analysis_page.dart';
import 'package:self_quote/ui/case_browser_dialog.dart';

/// 案件分析以招標中的案件為主：先找等標期內的案件，選一件分析（上一次同一案的得標廠商、合理價格、公告重點）
void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    I18n.lang = Lang.zh;
  });

  testWidgets('find open tenders, analyze one: incumbent, price range and notice facts', (tester) async {
    final listHtml = File('test/fixtures/pcc_open_tenders.html').readAsStringSync();
    final noticeHtml = File('test/fixtures/pcc_tender_notice.html').readAsStringSync();
    final queries = <CaseQuery>[];
    Future<CaseCollection?> fake(BuildContext context, CaseQuery q, {CaseCollection? prior, String? doneLabel, bool auto = false, int details = 0, int rivals = 0, KnownDetails? known}) async {
      queries.add(q);
      final col = CaseCollection();
      if (q.open) {
        col.addPage(q.url.toString(), listHtml);
        return col;
      }
      final t = q.tender!;
      col.notices[t.url] = parseTenderNotice(noticeHtml);
      final inc = AwardCase(agency: t.agency, caseNo: 'wda1140191', name: '115年度職業心理測驗線上評量網站維運案', method: '', category: '勞務類', date: DateTime(2025, 12, 20), amount: 3500000, url: 'https://web.pcc.gov.tw/x?pk=inc');
      col.vendorCases['org:${t.agency}'] = [inc];
      col.details[inc.url] = AwardDetail(budget: 3600000, award: 3500000, bidders: 2, winner: '測試資訊股份有限公司', awardWay: '準用最有利標');
      for (var i = 0; i < 3; i++) {
        final c = AwardCase(agency: '某機關$i', caseNo: '$i', name: '網站維運案$i', method: '', category: '勞務類', date: DateTime(2026, 5, i + 1), amount: 900000, url: 'https://web.pcc.gov.tw/x?pk=$i');
        col.cases.add(c);
        col.details[c.url] = AwardDetail(budget: 1000000, award: 900000.0 + i * 30000, bidders: 3, winner: '範例數位有限公司', awardWay: '最有利標');
      }
      return col;
    }

    tester.view.physicalSize = const Size(1100, 3200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(home: CaseAnalysisPage(state: AppState(), collect: fake, openStore: () async => null)));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, '網站');
    await tester.tap(find.byKey(const ValueKey('tender.searchOpen')));
    await tester.pumpAndSettle();

    expect(queries.single.open, isTrue);
    expect(queries.single.url.queryParameters['dateType'], 'isSpdt');
    expect(find.text(tr('tender.open')), findsOneWidget);
    expect(find.text(tr('tender.analyze')), findsNWidgets(8));
    expect(find.text(tr('tender.budgetHidden')), findsOneWidget); // 預算不公開的那一件

    const target = 'https://web.pcc.gov.tw/prkms/urlSelector/common/tpam?pk=NzEzNjUzODM='; // 116年度職業心理測驗線上評量網站維運及功能增修案
    await tester.tap(find.byKey(const ValueKey('tender.analyze:$target')));
    await tester.pumpAndSettle();

    final q = queries.last;
    expect(q.tender!.agency, '勞動部勞動力發展署');
    expect(q.urls.first.toString(), target); // 先讀招標公告
    expect(q.urls[1].queryParameters['orgName'], '勞動部勞動力發展署'); // 再查同機關的決標
    expect(find.text(tr('tender.brief')), findsOneWidget);
    expect(find.textContaining('測試資訊股份有限公司'), findsWidgets); // 上一次同一案的得標廠商
    expect(find.textContaining(tr('tender.incumbentRatio', {'r': '97%'})), findsOneWidget);
    // 公告預算 1,446,930 × 同類最有利標案件（含上一次同一案，共 4 件）決標比例的中位數 0.945
    expect(find.textContaining('同類 4 件'), findsWidgets); // 卡片與分享用摘要
    expect(find.textContaining('NT\$1,367,349'), findsWidgets);
    expect(find.textContaining('參考最有利標精神'), findsWidgets);
    expect(find.text(tr('tender.data')), findsOneWidget);
    // 測試環境沒有本機模型：顯示讀取失敗與「再讀一次」，其他分析照常
    expect(find.text(tr('tender.retry')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
