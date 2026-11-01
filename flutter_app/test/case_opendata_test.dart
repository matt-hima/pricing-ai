import 'dart:convert';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:self_quote/app_state.dart';
import 'package:self_quote/case_analysis/case_db.dart';
import 'package:self_quote/case_analysis/case_store.dart';
import 'package:self_quote/case_analysis/opendata.dart';
import 'package:self_quote/case_analysis/sources/source.dart';
import 'package:self_quote/case_analysis/pcc.dart';
import 'package:self_quote/i18n/i18n.dart';
import 'package:self_quote/ui/case_analysis_page.dart';

/// 官方開放資料（政府電子採購網 資料集下載 的決標 XML）
void main() {
  final xml = File('test/fixtures/pcc_award_dataset.xml').readAsStringSync(); // 聯絡人與電話已換成測試資料
  final all = parseAwardDataset(xml);

  test('award dataset records are parsed', () {
    expect(all.length, 4);
    final a = all.first;
    expect(a.name, '臺北市萬華區東園社會住宅統包工程委託專案管理（含監造）技術服務案');
    expect(a.category, '勞務類');
    expect(a.amount, 78651000);
    expect(a.agency, '臺北市政府工務局');
    expect(a.awardWay, '準用最有利標');
    expect(a.winner, '陳聖中建築師事務所');
    expect(a.loser, '東建工程顧問有限公司');
    expect(a.noticeDate, DateTime(2026, 8, 6));
    expect(all[2].winner, '慶嶸實業股份有限公司'); // 英文名稱拿掉
    expect(all[2].loser, '');
    expect(Uri.parse(a.toCase().url).queryParameters['tenderId'], a.caseNo); // 連到採購網依案號查詢
  });

  test('half-month files covering a period, newest first; future halves left out', () {
    expect(datasetFiles(DateTime(2026, 11, 1), 3), [
      'award_20261101.xml',
      'award_20261002.xml',
      'award_20261001.xml',
      'award_20260902.xml',
      'award_20260901.xml',
      'award_20260802.xml',
      'award_20260801.xml',
    ]);
    expect(datasetFiles(DateTime(2026, 11, 20), 0), ['award_20261102.xml']); // 1–15 日已在期間之前
    expect(datasetUrl('award_20260801.xml').toString(), 'https://web.pcc.gov.tw/tps/tp/OpenData/downloadFile?fileName=award_20260801.xml');
  });

  test('filter by keyword (continuous text), category and date; duplicates removed', () {
    expect(filterDataset(all, keywords: ['服裝']).map((a) => a.name), ['115-120年度員工服裝設計與製作採購案']);
    expect(filterDataset(all, keywords: ['工程']).length, 2); // 「工程」出現在兩筆的名稱裡
    expect(filterDataset(all, keywords: ['工程'], cate: ProcCate.works).single.category, '工程類');
    expect(filterDataset(all, keywords: ['服 裝']).length, 1); // 空白忽略，和採購網一樣
    expect(filterDataset(all, keywords: ['工程'], from: DateTime(2026, 8, 10)).single.noticeDate, DateTime(2026, 8, 18));
    expect(filterDataset([...all, ...all], keywords: ['案']).length, 2); // 同一筆出現在兩個檔：只算一次
  });

  test('winners, losers and award methods', () {
    final v = datasetVendors(all);
    expect(v.where((x) => x.wins == 1).length, 4);
    expect(v.firstWhere((x) => x.name == '東建工程顧問有限公司').losses, 1);
    expect(v.firstWhere((x) => x.name == '國盛電氣工程有限公司').total, 373900000);
    expect(awardWays(all), {'準用最有利標': 2, '最低標': 2});
  });

  testWidgets('case page downloads and analyzes the official dataset', (tester) async {
    SharedPreferences.setMockInitialValues({});
    I18n.lang = Lang.zh;
    // 測試資料是 2026 年 8 月的；把日期改成最近，讓「近 12 個月」包含它們
    final d = DateTime.now().subtract(const Duration(days: 30));
    String ymd(DateTime x) => '${x.year}/${x.month.toString().padLeft(2, '0')}/${x.day.toString().padLeft(2, '0')}';
    final recent = xml.replaceAll(RegExp(r'2026/08/\d\d'), ymd(d));
    final fetch = _FakeFetcher(recent);
    final store = CaseStore(CaseDb(NativeDatabase.memory()), fetch, pause: Duration.zero);
    addTearDown(store.db.close);

    tester.view.physicalSize = const Size(1100, 2600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(home: CaseAnalysisPage(state: AppState(), openStore: () async => store)));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, '工程');
    await tester.pump();
    await tester.tap(find.text(tr('case.data.run', {'m': '12'})));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 300))); // 資料庫在背景執行
    await tester.pumpAndSettle();

    expect(fetch.asked.length, greaterThanOrEqualTo(24)); // 近 12 個月 = 至少 24 個半月檔
    // 每個檔都回傳同樣的 4 筆：依案號存成一件一列，只算 2 筆含「工程」
    expect(find.text(tr('case.data.loaded', {'n': '2', 'd': '${fetch.asked.length}'})), findsOneWidget);
    expect(find.text(tr('case.data.winners')), findsOneWidget);
    expect(find.textContaining('國盛電氣工程有限公司'), findsWidgets);
    expect(find.text(tr('case.data.source')), findsOneWidget); // 授權要求的出處
    expect(tester.takeException(), isNull);
  });
  testWidgets('other countries: pick the UK, local keywords are filled in, results in pounds with the UK attribution', (tester) async {
    SharedPreferences.setMockInitialValues({});
    I18n.lang = Lang.zh;
    final d = DateTime.now().subtract(const Duration(days: 3)).toUtc().toIso8601String();
    final page = jsonEncode({
      'releases': [
        for (final (i, amount) in [(1, 30000), (2, 45000), (3, 60000)])
          {
            'ocid': 'ocds-b5fd17-$i',
            'id': 'r$i',
            'date': d,
            'buyer': {'name': 'Example Borough Council'},
            'tender': {'title': 'Council website support $i', 'mainProcurementCategory': 'services'},
            'awards': [
              {'status': 'active', 'date': d, 'value': {'amount': amount, 'currency': 'GBP'}, 'suppliers': [{'name': 'Example Web Ltd'}]},
            ],
          },
      ],
    });
    final store = CaseStore(CaseDb(NativeDatabase.memory()), _FakeFetcher(''), sourceHttp: _UkHttp(page));
    addTearDown(store.db.close);
    tester.view.physicalSize = const Size(1100, 2600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(home: CaseAnalysisPage(state: AppState(), openStore: () async => store)));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, '網站維護');
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('country:uk')));
    await tester.pump();
    final kw = tester.widget<TextField>(find.byKey(const ValueKey('case.localKeywords'))).controller!.text;
    expect(kw, contains('website'));
    expect(kw, contains('maintenance'));
    await tester.tap(find.text(tr('case.data.run', {'m': '12'})));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 300)));
    await tester.pumpAndSettle();
    expect(find.text('£45,000'), findsWidgets); // 中位數
    expect(find.textContaining('Example Web Ltd'), findsWidgets);
    expect(find.text(tr('case.src.uk')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

}

class _FakeFetcher implements DataFetcher {
  final String xml;
  final asked = <String>{};
  _FakeFetcher(this.xml);

  @override
  Future<String?> get(Uri url) async {
    asked.add(url.queryParameters['fileName']!);
    return xml;
  }

  @override
  Future<int?> size(Uri url) async => null;
}

class _UkHttp implements SourceHttp {
  final String page;
  _UkHttp(this.page);

  @override
  Future<String?> getText(Uri url, {void Function(Duration wait)? onWait}) async => url.host.contains('contractsfinder') ? page : jsonEncode({'releases': []});

  @override
  Future<File?> download(Uri url, {void Function(int bytes)? onBytes, void Function(Duration wait)? onWait}) async => null;
}
