import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:self_quote/case_analysis/case_summary.dart';
import 'package:self_quote/case_analysis/keywords.dart';
import 'package:self_quote/case_analysis/pcc.dart';
import 'package:self_quote/i18n/i18n.dart';
import 'package:self_quote/ui/case_browser_dialog.dart';
import 'package:self_quote/ui/competitor_dialog.dart';

/// 關鍵字擴充（依採購網「連續文字比對」的規則）、投標廠商、競爭對手與廠商紀錄
void main() {
  final listHtml = File('test/fixtures/pcc_awards.html').readAsStringSync();
  final biddersHtml = File('test/fixtures/pcc_award_bidders.html').readAsStringSync();
  final oneBidderHtml = File('test/fixtures/pcc_award_detail.html').readAsStringSync();
  setUp(() => I18n.lang = Lang.zh);

  test('every bidder in an award notice is parsed with tax ID and win flag', () {
    final d = parseAwardDetail(biddersHtml);
    expect(d.bidders, 7);
    expect(d.bidderList.length, 7);
    expect(d.bidderList.first, isA<Bidder>().having((b) => b.name, 'name', '市訊資訊有限公司').having((b) => b.id, 'id', '53524913').having((b) => b.won, 'won', true));
    expect(d.bidderList.where((b) => b.won), hasLength(1));
    expect(d.bidderList[4].name, '雅客資訊股份有限公司'); // 英文名稱拿掉
    expect(d.bidderList.last.id, '00046874');
    final one = parseAwardDetail(oneBidderHtml).bidderList;
    expect(one.single.name, '凌網資訊股份有限公司');
    expect(one.single.won, isTrue);
  });

  test('keyword expansion follows the site rule: continuous text, spaces ignored', () {
    final a = expandKeywords('網站');
    expect(a.primary, ['網站']);
    expect(a.suggestions, containsAll(['網頁', '官網', '入口網']));
    final b = expandKeywords('網站 維護');
    expect(b.primary, ['網站維護']); // 採購網會去掉空白
    expect(b.suggestions, containsAll(['網頁維護', '官網維護']));
    expect(b.suggestions, isNot(contains('網站'))); // 比主要字更廣的字不自動加入
    final c = expandKeywords('網站、網站維護');
    expect(c.primary, ['網站', '網站維護']);
    expect(c.suggestions.any((s) => s.contains('網站')), isFalse); // 已被「網站」包含的不用再查
    expect(expandKeywords('平台').suggestions.first, '平臺');
    expect(awardSearchUrl(keyword: '網站 維護', from: DateTime(2026), to: DateTime(2026, 6)).queryParameters['tenderName'], '網站維護');
    expect(awardSearchUrl(from: DateTime(2026), to: DateTime(2026, 6), wonBy: '凌網資訊股份有限公司').queryParameters['gottenVendorName'], '凌網資訊股份有限公司');
  });

  test('results of several searches are merged; totals are counted per search', () {
    final col = CaseCollection();
    final u1 = awardSearchUrl(keyword: '網站', from: DateTime(2026), to: DateTime(2026, 6));
    final u2 = awardSearchUrl(keyword: '網頁', from: DateTime(2026), to: DateTime(2026, 6));
    col.addPage(u1.toString(), listHtml);
    col.addPage(u2.toString(), listHtml); // 同一批案件：不重複加入，但記得兩個查詢都找到
    expect(col.cases.length, 50);
    expect(col.totals, {'kw:網站': 178, 'kw:網頁': 178});
    expect(col.foundBy[col.cases.first.url], {'kw:網站', 'kw:網頁'});
    expect(col.total, 50 + 128 + 128);
  });

  test('competitors and vendor profile', () {
    final details = {'a': parseAwardDetail(biddersHtml), 'b': parseAwardDetail(oneBidderHtml)};
    final comps = competitorsOf(details);
    expect(comps.length, 8);
    expect(comps.first.bids, 1);
    expect(comps.where((c) => c.wins == 1).map((c) => c.name), containsAll(['市訊資訊有限公司', '凌網資訊股份有限公司']));
    expect(competitionFacts(details), contains('常見競爭廠商'));

    final col = CaseCollection();
    const name = '凌網資訊股份有限公司';
    col.addPage(awardSearchUrl(from: DateTime(2026), to: DateTime(2026, 6), wonBy: name).toString(), listHtml);
    col.addPage(awardSearchUrl(from: DateTime(2026), to: DateTime(2026, 6), bidBy: name).toString(), listHtml.replaceFirst(RegExp(r'共有\s*<span class="red">\s*178'), '共有<span class="red"> 200'));
    final p = VendorProfile.of(name, col);
    expect(p.wins, 178);
    expect(p.bids, 200);
    expect(p.winRate, 89);
    expect(p.wonCases.length, 50);
    expect(googleAiMode('x').queryParameters['udm'], '50');
  });

  testWidgets('competitor dialog looks up won + bid records right away', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final asked = <CaseQuery>[];
    Future<CaseCollection?> fake(BuildContext context, CaseQuery q, {CaseCollection? prior, String? doneLabel, bool auto = false, int details = 0, int rivals = 0, KnownDetails? known}) async {
      asked.add(q);
      final col = CaseCollection();
      for (final u in q.urls) {
        col.addPage(u.toString(), listHtml);
      }
      return col;
    }

    tester.view.physicalSize = const Size(1000, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: CompetitorDialog(name: '凌網資訊股份有限公司', taxId: '56610834', keyword: '網站', collect: fake, openStore: () async => null))));
    await tester.pumpAndSettle();
    expect(asked.single.vendor, '凌網資訊股份有限公司');
    expect(asked.single.urls.map(searchKey), ['won:凌網資訊股份有限公司', 'bid:凌網資訊股份有限公司']);
    expect(find.text(tr('comp.wins')), findsOneWidget);
    expect(find.text('100%'), findsOneWidget); // 178 / 178
    expect(find.text(tr('comp.google')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
