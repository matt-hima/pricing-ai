import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:self_quote/case_analysis/case_db.dart';
import 'package:self_quote/case_analysis/case_store.dart';
import 'package:self_quote/case_analysis/opendata.dart';
import 'package:self_quote/case_analysis/pcc.dart';

/// 案件資料庫（星狀結構）：匯入官方開放資料、存即時查詢的結果、篩選 → 量值 → 分組
void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  final xml = File('test/fixtures/pcc_award_dataset.xml').readAsStringSync();
  final dataset = parseAwardDataset(xml);
  late CaseDb db;
  setUp(() => db = CaseDb(NativeDatabase.memory()));
  tearDown(() => db.close());

  test('official records go into facts and dimensions; re-importing changes nothing', () async {
    expect(await db.importDataset(dataset), 4);
    expect(await db.countAwards(const AwardFilter()), 4);
    expect((await db.select(db.dimAgency).get()).length, 4);
    expect((await db.select(db.factBid).get()).length, 6); // 4 家得標 + 2 家未得標
    expect(await db.importDataset(dataset), 0); // 同一個檔再匯入：沒有變動
  });

  test('questions: filter → metric → group by', () async {
    await db.importDataset(dataset);
    final byWay = await db.breakdown(const AwardFilter(), Dimension.awardWay);
    expect({for (final b in byWay) b.label: b.count}, {'準用最有利標': 2, '最低標': 2});
    final sum = await db.breakdown(const AwardFilter(keywords: ['工程']), Dimension.category, metric: Metric.sum);
    expect({for (final b in sum) b.label: b.value}, {'工程類': 373900000, '勞務類': 78651000});
    final months = await db.breakdown(const AwardFilter(), Dimension.month);
    expect(months.single.label, '2026-08');
    expect(await db.amounts(const AwardFilter(cate: ProcCate.services)), [12773000, 78651000]);
    expect((await db.awards(AwardFilter(keywords: const ['服 裝'], from: DateTime(2026, 8, 1)))).single.agency, '桃園國際機場股份有限公司');
    expect(await db.countAwards(AwardFilter(from: DateTime(2026, 8, 10))), 2);

    final vendors = await db.vendorRecords(const AwardFilter());
    final lost = vendors.firstWhere((v) => v.name == '東建工程顧問有限公司');
    expect((lost.bids, lost.wins, lost.winRate), (1, 0, 0));
    final won = vendors.firstWhere((v) => v.name == '國盛電氣工程有限公司');
    expect((won.bids, won.wins, won.wonTotal), (1, 1, 373900000));
  });

  test('live results: one row per case, full bidder list and committee kept, details reused', () async {
    await db.importDataset(dataset);
    final list = parseAwardList(File('test/fixtures/pcc_awards.html').readAsStringSync()).cases;
    final col = CaseCollection()..cases.addAll(list);
    final detailHtml = File('test/fixtures/pcc_award_bidders.html').readAsStringSync() + File('test/fixtures/pcc_award_committee.html').readAsStringSync();
    col.details[list.first.url] = parseAwardDetail(detailHtml);
    col.totals['kw:網站'] = 178;
    await db.saveCollection(col);
    expect(await db.countAwards(const AwardFilter(source: 'live')), 50);

    final back = await db.detailsFor([list.first.url, list[1].url]);
    expect(back.keys, [list.first.url]); // 只有開過明細的
    expect(back[list.first.url]!.bidderList.length, 7);
    expect(back[list.first.url]!.bidderList.first.id, '53524913'); // 統一編號也存在廠商維度
    expect(back[list.first.url]!.reviewers.length, 5);

    final reviewers = await db.reviewerRecords(const AwardFilter());
    expect(reviewers.length, 5);
    expect(reviewers.first.caseUrls, [list.first.url]);

    // 再存一次同樣的清單：仍是一件一列
    await db.saveCollection(CaseCollection()..cases.addAll(list));
    expect(await db.countAwards(const AwardFilter(source: 'live')), 50);
    expect((await db.detailsFor([list.first.url])).length, 1); // 明細沒有被清掉
  });

  test('an older notice never overwrites a newer one; the dataset and live search merge into one row', () async {
    final a = dataset.first;
    DatasetAward copy({required double amount, required DateTime date}) => DatasetAward(
          name: a.name,
          caseNo: a.caseNo,
          category: a.category,
          agency: a.agency,
          method: a.method,
          awardWay: a.awardWay,
          winner: a.winner,
          loser: a.loser,
          amount: amount,
          noticeDate: date,
        );
    await db.importDataset([copy(amount: 100, date: DateTime(2026, 8, 6))]);
    await db.importDataset([copy(amount: 50, date: DateTime(2026, 7, 1))]); // 較舊的公告
    expect((await db.awards(const AwardFilter())).single.amount, 100);
    await db.importDataset([copy(amount: 120, date: DateTime(2026, 9, 1))]); // 較新的公告（例如契約變更）
    expect((await db.awards(const AwardFilter())).single.amount, 120);

    final live = CaseCollection()
      ..cases.add(AwardCase(agency: a.agency, caseNo: a.caseNo, name: a.name, method: a.method, category: a.category, date: DateTime(2026, 9, 1), amount: 120, url: 'https://web.pcc.gov.tw/x?pk=1'));
    await db.saveCollection(live);
    final rows = await db.awards(const AwardFilter());
    expect(rows.length, 1);
    expect((rows.single.source, rows.single.url), ('dataset', 'https://web.pcc.gov.tw/x?pk=1'));
  });

  test('dataset sync: settled periods are never re-downloaded, recent ones only when the file changed', () async {
    final fetch = _FakeFetcher({'award_20260801.xml': xml});
    final store = CaseStore(db, fetch, pause: Duration.zero);
    final now = DateTime(2026, 8, 20);
    expect(await store.syncDataset(['award_20260801.xml', 'award_20260802.xml'], now: now), 1); // 下半月還沒公開（試了但沒有）
    expect(fetch.gets, 2);
    expect(await db.countAwards(const AwardFilter()), 4);

    // 同一天再同步：最近的期間一天只檢查一次
    expect(await store.syncDataset(['award_20260801.xml'], now: now), 0);
    expect((fetch.gets, fetch.heads), (2, 0)); // 上半月今天剛查過：不動；下半月沒有紀錄的不在這次清單

    // 兩天後：先問大小，沒變就不下載
    final later = now.add(const Duration(days: 2));
    expect(await store.syncDataset(['award_20260801.xml'], now: later), 0);
    expect((fetch.gets, fetch.heads), (2, 1));

    // 檔案變大了（補了資料）：重新下載匯入
    fetch.files['award_20260801.xml'] = xml.replaceFirst('</TENDER_LIST>', '<!-- 補資料 --></TENDER_LIST>');
    expect(await store.syncDataset(['award_20260801.xml'], now: later.add(const Duration(days: 2))), 1);
    expect(fetch.gets, 3);

    // 期間已經結束 45 天以上：不再檢查
    expect(await store.syncDataset(['award_20260801.xml'], now: DateTime(2026, 12, 1)), 0);
    expect((fetch.gets, fetch.heads), (3, 2));
  });
}

class _FakeFetcher implements DataFetcher {
  final Map<String, String> files;
  int gets = 0, heads = 0;
  _FakeFetcher(this.files);

  String? _file(Uri url) => files[url.queryParameters['fileName']];

  @override
  Future<String?> get(Uri url) async {
    gets++;
    return _file(url);
  }

  @override
  Future<int?> size(Uri url) async {
    heads++;
    final f = _file(url);
    return f == null ? null : utf8.encode(f).length;
  }
}
