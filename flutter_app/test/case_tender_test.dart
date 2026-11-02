import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:self_quote/case_analysis/pcc.dart';
import 'package:self_quote/case_analysis/tender.dart';
import 'package:self_quote/case_analysis/tender_brief.dart';
import 'package:self_quote/i18n/i18n.dart';

/// 招標中的案件：招標查詢（等標期內）、招標公告的欄位、用決標資料找上一次的得標廠商與合理價格
void main() {
  test('open tender search: still open for bids, keyword without spaces', () {
    final u = openTenderSearchUrl(keyword: '網 站', cate: ProcCate.services, page: 2);
    expect(u.path, '/prkms/tender/common/basic/readTenderBasic');
    expect(u.queryParameters['dateType'], 'isSpdt');
    expect(u.queryParameters['tenderType'], 'TENDER_DECLARATION');
    expect(u.queryParameters['tenderName'], '網站');
    expect(u.queryParameters['d-49738-p'], '2');
  });

  test('open tender list: agency, case number and name, deadline, budget (blank when not public)', () {
    final r = parseOpenTenders(File('test/fixtures/pcc_open_tenders.html').readAsStringSync());
    expect(r.total, 8);
    expect(r.tenders.length, 8);
    final a = r.tenders.first;
    expect((a.agency, a.caseNo, a.name, a.method, a.category), ('臺北市教師研習中心', '11522', '臺北教師e教材網站功能優化升級採購案', '公開取得報價單或企劃書', '勞務類'));
    expect((a.noticeDate, a.deadline, a.budget), (DateTime(2026, 10, 30), DateTime(2026, 11, 5), 367379.0));
    expect(a.url, 'https://web.pcc.gov.tw/prkms/urlSelector/common/tpam?pk=NzEzNjYxODA=');
    expect(r.tenders[1].budget, isNull);
    expect(a.daysLeft(DateTime(2026, 11, 2, 15)), 3);
  });

  test('tender notice: fields read by table level, nested tables kept inside their field', () {
    final n = parseTenderNotice(File('test/fixtures/pcc_tender_notice.html').readAsStringSync());
    expect((n.agency, n.caseNo, n.name), ('外交部領事事務局', 'T115035CB', '行政院主計總處薪資管理系統移轉導入暨擴充服務案'));
    expect((n.category, n.budget, n.awardWay, n.round), ('勞務類', 1446930.0, '參考最有利標精神', '第一次公開取得'));
    expect((n.deadline, n.openAt, n.noticeDate), (DateTime(2026, 11, 9, 17), DateTime(2026, 11, 10, 11, 30), DateTime(2026, 11, 2)));
    expect((n.floorPrice, n.followUp, n.bestValue), (true, false, true));
    expect(n['履約期限'], '決標日次日起至116年12月31日止。');
    expect(n['是否訂有與履約能力有關之基本資格'], contains('廠商信用之證明')); // 欄位內的表格沒有被切斷
    expect(n['廠商資格摘要'], contains('具公司登記'));
    expect(n.readable, contains('決標方式：參考最有利標精神'));
    expect(n.readable, isNot(contains('疑義、異議')));
    expect(isTenderNotice(File('test/fixtures/pcc_tender_notice.html').readAsStringSync()), isTrue);
  });

  test('the same case last time: same agency, similar name once years and wording are removed', () {
    expect(coreName('116年度職業心理測驗線上評量網站維運及功能增修案'), '職業心理測驗線上評量網站維運及功能增修');
    expect(nameSimilarity('116年度職業心理測驗線上評量網站維運及功能增修案', '115年度職業心理測驗線上評量網站維運案'), greaterThan(0.6));
    expect(nameSimilarity('116年度職業心理測驗線上評量網站維運及功能增修案', '115年度就業服務資訊系統維護案'), lessThan(0.5));
    AwardCase c(String name, String agency, int year) => AwardCase(agency: agency, caseNo: '$year', name: name, method: '', category: '勞務類', date: DateTime(year, 12, 1), amount: 3000000, url: 'u$year');
    const t = OpenTender(agency: '勞動部勞動力發展署', caseNo: 'wda1150191', name: '116年度職業心理測驗線上評量網站維運及功能增修案', method: '', category: '勞務類', url: '');
    final inc = incumbentOf(t, [
      c('114年度職業心理測驗線上評量網站維運案', '勞動部勞動力發展署', 2024),
      c('115年度職業心理測驗線上評量網站維運案', '勞動部勞動力發展署', 2025),
      c('115年度職業心理測驗線上評量網站維運案', '另一個機關', 2025),
      c('115年度就業服務資訊系統維護案', '勞動部勞動力發展署', 2025),
    ]);
    expect(inc?.caseNo, '2025'); // 同分取最新的
  });

  test('a reasonable price: award / budget of similar cases, same award method when there are enough', () {
    AwardDetail d(double budget, double award, String way) => AwardDetail(budget: budget, award: award, awardWay: way);
    final details = [
      d(1000000, 980000, '最有利標'),
      d(2000000, 1900000, '準用最有利標'),
      d(500000, 495000, '最有利標'),
      d(1000000, 700000, '最低標'),
      d(1000000, 650000, '最低標'),
    ];
    final g = priceGuide(budget: 1446930, bestValue: true, details: details)!;
    expect((g.samples, g.sameAwardWay), (3, true));
    expect(g.ratioMid, closeTo(0.98, 1e-9));
    expect(g.mid, closeTo(1446930 * 0.98, 1));
    final low = priceGuide(budget: null, bestValue: false, details: details)!;
    expect((low.samples, low.sameAwardWay, low.mid), (5, false, null)); // 最低標只有 2 件：用全部；預算不公開
    expect(priceGuide(budget: 100, bestValue: true, details: details.take(2)), isNull);
  });

  test('watch-outs come from the notice fields; the local AI only keeps what the notice says', () async {
    I18n.lang = Lang.zh;
    final n = parseTenderNotice(File('test/fixtures/pcc_tender_notice.html').readAsStringSync());
    // 截止 115/11/09：11/07 時剩 2 天；不用押標金、要履約保證金、有底價、會協商、不接受電子投標
    expect(tenderRisks(n, now: DateTime(2026, 11, 7)), [
      tr('tender.risk.soon', {'n': '2'}),
      tr('tender.risk.bond'),
      tr('tender.risk.floor'),
      tr('tender.risk.nego'),
      tr('tender.risk.paper'),
    ]);
    expect(tenderRisks(n, now: DateTime(2026, 11, 2)), isNot(contains(tr('tender.risk.soon', {'n': '7'}))));
    expect(const OpenTender(agency: '', caseNo: '', name: '', method: '', category: '勞務類', url: '').cate, ProcCate.services);

    // 模型自己補的「詳細價目表」公告裡沒有：拿掉；大陸用語換成臺灣說法
    Future<String> ask(String system, String user, Map<String, dynamic> schema) async =>
        '{"scope": "機關要找廠商移轉導入薪資管理软件。", "prepare": ["提供軟体執行服務", "提供廠商信用之證明", "準備詳細價目表", "- 檢附廠商登記或設立之證明", "- 投標廠商之基本資格須符合以下任一資格：", "廠商納稅之證明（如營業稅或所得稅，公司登記或商業登記之營業項目須符合本案需求並檢附相關證明文件）"]}';
    final b = await readTenderNotice(ask: ask, lang: Lang.zh, notice: n);
    expect(b.scope, contains('軟體'));
    expect(b.prepare, ['提供廠商信用之證明', '檢附廠商登記或設立之證明', '廠商納稅之證明']);
  });
}
