import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:self_quote/app_state.dart';
import 'package:self_quote/case_analysis/opendata.dart';
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
    final asked = <List<String>>[];
    Future<List<DatasetAward>> fake(List<String> files, {void Function(int done, int total)? onProgress}) async {
      asked.add(files);
      onProgress?.call(files.length, files.length);
      // 測試資料是 2026 年 8 月的；把日期改成最近，讓「近 12 個月」包含它們
      final now = DateTime.now();
      return [
        for (final a in all)
          DatasetAward(
            name: a.name,
            caseNo: a.caseNo,
            category: a.category,
            agency: a.agency,
            method: a.method,
            awardWay: a.awardWay,
            winner: a.winner,
            loser: a.loser,
            amount: a.amount,
            noticeDate: now.subtract(const Duration(days: 30)),
          ),
      ];
    }

    tester.view.physicalSize = const Size(1100, 2600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(home: CaseAnalysisPage(state: AppState(), loadData: fake)));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, '工程');
    await tester.pump();
    await tester.tap(find.text(tr('case.data.run', {'m': '12'})));
    await tester.pumpAndSettle();

    expect(asked.single.length, greaterThanOrEqualTo(24)); // 近 12 個月 = 至少 24 個半月檔
    expect(find.text(tr('case.data.loaded', {'n': '4', 'm': '12'})), findsOneWidget);
    expect(find.text(tr('case.data.winners')), findsOneWidget);
    expect(find.textContaining('國盛電氣工程有限公司'), findsWidgets);
    expect(find.text(tr('case.data.source')), findsOneWidget); // 授權要求的出處
    expect(tester.takeException(), isNull);
  });
}
