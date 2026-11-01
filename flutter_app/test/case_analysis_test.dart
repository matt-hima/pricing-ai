import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:self_quote/case_analysis/pcc.dart';

/// 固定資料是 2026/11/01 從政府電子採購網存下來的決標查詢（關鍵字「網站」）與一筆決標明細
void main() {
  test('award list page parses rows, names, amounts and total', () {
    final r = parseAwardList(File('test/fixtures/pcc_awards.html').readAsStringSync());
    expect(r.total, 178);
    expect(r.cases.length, 50);
    final c = r.cases.first;
    expect(c.agency, '中央銀行');
    expect(c.caseNo, '1150034729');
    expect(c.name, '中央銀行網站「臺灣之美系列鈔券主題圖案偏好調查」增修案');
    expect(c.category, '勞務類');
    expect(c.method, '限制性招標(未經公開評選或公開徵求)');
    expect(c.date, DateTime(2026, 10, 29));
    expect(c.amount, 625573);
    expect(c.url, 'https://web.pcc.gov.tw/prkms/urlSelector/common/atm?pk=NzEzMTY5MDg=');
  });

  test('award detail page parses budget, floor, award, bidders and winner', () {
    final d = parseAwardDetail(File('test/fixtures/pcc_award_detail.html').readAsStringSync());
    expect(d.budget, 634000);
    expect(d.floor, 625573);
    expect(d.award, 625573);
    expect(d.bidders, 1);
    expect(d.winner, '凌網資訊股份有限公司');
    expect(d.awardWay, '最低標');
  });

  test('search URL uses Gregorian dates and the category parameter', () {
    final u = awardSearchUrl(keyword: ' 網站 ', from: DateTime(2026, 5, 1), to: DateTime(2026, 11, 1), cate: ProcCate.services, page: 2);
    expect(u.queryParameters['tenderName'], '網站');
    expect(u.queryParameters['awardAnnounceStartDate'], '2026/05/01');
    expect(u.queryParameters['radProctrgCate'], 'RAD_PROCTRG_CATE_3');
    expect(u.queryParameters['d-16396-p'], '2');
  });

  test('stats: quantiles, bands, percentile', () {
    AwardCase c(double a, String agency) => AwardCase(agency: agency, caseNo: '', name: '', method: 'm', category: '', date: null, amount: a, url: '$a');
    final cases = [c(50000, 'A'), c(200000, 'A'), c(400000, 'B'), c(800000, 'A'), c(5000000, 'C')];
    final st = CaseStats.of(cases);
    expect(st.count, 5);
    expect(st.median, 400000);
    expect(st.p25, 200000);
    expect(st.p75, 800000);
    expect(st.bands, [1, 1, 2, 0, 1, 0]);
    expect(st.topAgencies.first.key, 'A');
    expect(CaseStats.percentile(cases, 400000), 60);
  });

  test('detail stats: bidders and award / budget ratio', () {
    final ds = DetailStats.of(const [
      AwardDetail(budget: 1000000, award: 900000, bidders: 3, winner: 'X'),
      AwardDetail(budget: 1000000, award: 800000, bidders: 1, winner: 'X'),
      AwardDetail(bidders: 2, winner: 'Y'),
    ]);
    expect(ds.avgBidders, 2);
    expect(ds.singleBidPct, closeTo(33.3, .1));
    expect(ds.awardToBudget, closeTo(.85, 1e-9));
    expect(ds.topWinners.first, isA<MapEntry<String, int>>().having((e) => e.key, 'key', 'X'));
  });

  test('ROC date and short TWD formatting', () {
    expect(parseRocDate('115/1/2'), DateTime(2026, 1, 2));
    expect(shortTwd(625573), '62.6萬');
    expect(shortTwd(12000000), '1200萬');
    expect(shortTwd(100000), '10萬');
    expect(shortTwd(1000000, cjk: false), '1M');
    expect(shortTwd(625573, cjk: false), '626K');
  });

  test('pages seen in the browser are collected: list pages add cases, detail pages add details', () {
    final col = CaseCollection();
    final list = File('test/fixtures/pcc_awards.html').readAsStringSync();
    expect(col.addPage('https://web.pcc.gov.tw/prkms/tender/common/agent/readTenderAgent?tenderName=x', list), isTrue);
    expect(col.addPage('https://web.pcc.gov.tw/prkms/tender/common/agent/readTenderAgent?tenderName=x', list), isFalse); // 同一頁不重複
    expect(col.cases.length, 50);
    expect(col.total, 178);
    // 點開案件後網址會轉到 QueryAtmAwardDetail?pkAtmMain=…，要對回清單裡的案件
    final detail = File('test/fixtures/pcc_award_detail.html').readAsStringSync();
    expect(col.addPage('https://web.pcc.gov.tw/tps/atm/AtmAwardWithoutSso/QueryAtmAwardDetail?pkAtmMain=NzEzMTY5MDg=', detail), isTrue);
    expect(col.details[col.cases.first.url]?.bidders, 1);
    expect(col.addPage('https://web.pcc.gov.tw/pis/', '<html></html>'), isFalse);
  });
}
