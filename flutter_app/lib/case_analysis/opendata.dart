/// 政府電子採購網的官方開放資料（資料集下載）：每半個月一個決標 XML（award_YYYYMM01 = 1–15 日，award_YYYYMM02 = 16 日–月底）。
/// 只收「公告金額（新台幣 100 萬）以上」、刊登政府採購公報的決標；每筆有得標廠商與至多一家未得標廠商，沒有預算與評選委員。
/// 授權：政府資料開放授權條款－第1版（需註明出處）。好處是一般的檔案下載，不會遇到驗證碼檢核，也能一次分析好幾年。
library;

import 'pcc.dart';

/// 下載網址
Uri datasetUrl(String file) => Uri.https(pccHost, '/tps/tp/OpenData/downloadFile', {'fileName': file});

/// 涵蓋 [now] 往前 [months] 個月的決標資料檔名（新到舊）：每個月分上半月（01）與下半月（02），
/// 只列已經開始、而且和期間有重疊的半月。最近的檔可能還沒公開，下載時找不到就略過。
List<String> datasetFiles(DateTime now, int months) {
  final from = DateTime(now.year, now.month - months, now.day);
  final out = <String>[];
  for (var i = 0; i <= months; i++) {
    final first = DateTime(now.year, now.month - i, 1);
    final ym = '${first.year}${first.month.toString().padLeft(2, '0')}';
    final last = DateTime(first.year, first.month + 1, 0);
    final halves = [(DateTime(first.year, first.month, 16), last, '02'), (first, DateTime(first.year, first.month, 15), '01')];
    for (final (start, end, half) in halves) {
      if (!start.isAfter(now) && !end.isBefore(from)) out.add('award_$ym$half.xml');
    }
  }
  return out;
}

/// 開放資料裡的一筆決標
class DatasetAward {
  final String name, caseNo, category, agency, method, awardWay, winner, loser;
  final double amount;
  final DateTime? awardDate, noticeDate;
  const DatasetAward({
    required this.name,
    required this.caseNo,
    required this.category,
    required this.agency,
    required this.method,
    required this.awardWay,
    required this.winner,
    required this.loser,
    required this.amount,
    this.awardDate,
    this.noticeDate,
  });

  /// 給共用的統計與清單用（CaseStats 等）。連結到採購網依案號查詢。
  AwardCase toCase() => AwardCase(
        agency: agency,
        caseNo: caseNo,
        name: name,
        method: method,
        category: category,
        date: noticeDate ?? awardDate,
        amount: amount,
        url: Uri.https(pccHost, '/prkms/tender/common/agent/readTenderAgent', {
          'pageSize': '10',
          'firstSearch': 'true',
          'isQuery': 'true',
          'isBinding': 'N',
          'isLogIn': 'N',
          'tenderId': caseNo,
          'tenderStatus': 'TENDER_STATUS_1',
          'tenderWay': 'TENDER_WAY_ALL_DECLARATION',
          'awardAnnounceStartDate': _ymd((noticeDate ?? awardDate ?? DateTime(2000)).subtract(const Duration(days: 1))),
          'awardAnnounceEndDate': _ymd((noticeDate ?? awardDate ?? DateTime(2000)).add(const Duration(days: 1))),
          'tenderRange': 'TENDER_RANGE_ALL',
        }).toString(),
      );
}

String _ymd(DateTime d) => '${d.year}/${d.month.toString().padLeft(2, '0')}/${d.day.toString().padLeft(2, '0')}';

String _xmlText(String s) => s
    .replaceAll('&lt;', '<')
    .replaceAll('&gt;', '>')
    .replaceAll('&quot;', '"')
    .replaceAll('&apos;', "'")
    .replaceAll('&amp;', '&')
    .trim();

DateTime? _date(String s) {
  final m = RegExp(r'(\d{4})/(\d{1,2})/(\d{1,2})').firstMatch(s);
  return m == null ? null : DateTime(int.parse(m[1]!), int.parse(m[2]!), int.parse(m[3]!));
}

/// 公司名稱去掉後面的英文名稱，和決標公告的寫法一致（例如「久裕企業股份有限公司 (ARICH …)」）
String _company(String s) => _xmlText(s).replaceFirst(RegExp(r'\s*\(.*$'), '');

/// 決標資料 XML → 決標清單（欄位順序每筆不同，所以逐一找標籤）
List<DatasetAward> parseAwardDataset(String xml) {
  final out = <DatasetAward>[];
  for (final m in RegExp(r'<TENDER>(.*?)</TENDER>', dotAll: true).allMatches(xml)) {
    final b = m[1]!;
    String tag(String t) => _xmlText(RegExp('<$t>(.*?)</$t>', dotAll: true).firstMatch(b)?[1] ?? '');
    final amount = double.tryParse(tag('TENDER_AWARD_PRICE'));
    final name = tag('TENDER_NAME');
    if (amount == null || name.isEmpty) continue;
    out.add(DatasetAward(
      name: name,
      caseNo: tag('TENDER_CASE_NO'),
      category: tag('PROCUREMENT_ATTR'),
      agency: tag('TENDER_ORG_NAME'),
      method: tag('PROCUREMENT_TYPE'),
      awardWay: tag('TENDER_AWARD_WAY'),
      winner: _company(tag('BIDDER_SUPP_NAME')),
      loser: _company(tag('NOT_OBTAIN_SUPP_NAME')),
      amount: amount,
      awardDate: _date(tag('AWARD_DATE')),
      noticeDate: _date(tag('AWARD_NOTICE_DATE')),
    ));
  }
  return out;
}

/// 依採購網的規則篩選：標案名稱含任一關鍵字（空白忽略、連續文字比對），採購性質與期間相符
List<DatasetAward> filterDataset(Iterable<DatasetAward> all, {required List<String> keywords, ProcCate cate = ProcCate.any, DateTime? from}) {
  const cateName = {ProcCate.works: '工程類', ProcCate.goods: '財物類', ProcCate.services: '勞務類'};
  final ks = [for (final k in keywords) k.replaceAll(RegExp(r'\s+'), '')]..removeWhere((k) => k.isEmpty);
  final seen = <String>{};
  return [
    for (final a in all)
      if (ks.any(a.name.contains) &&
          (cate == ProcCate.any || a.category == cateName[cate]) &&
          (from == null || !(a.noticeDate ?? a.awardDate ?? from).isBefore(from)) &&
          seen.add('${a.caseNo}|${a.name}|${a.amount}'))
        a,
  ];
}

/// 開放資料裡的得標廠商：得標件數、得標總額、未得標次數（資料裡每筆最多記一家未得標廠商）
class DatasetVendor {
  final String name;
  int wins = 0, losses = 0;
  double total = 0;
  final Map<String, int> agencies = {};
  DatasetVendor(this.name);
}

List<DatasetVendor> datasetVendors(Iterable<DatasetAward> awards) {
  final m = <String, DatasetVendor>{};
  for (final a in awards) {
    if (a.winner.isNotEmpty) {
      final v = m[a.winner] ??= DatasetVendor(a.winner);
      v.wins++;
      v.total += a.amount;
      v.agencies[a.agency] = (v.agencies[a.agency] ?? 0) + 1;
    }
    if (a.loser.isNotEmpty) (m[a.loser] ??= DatasetVendor(a.loser)).losses++;
  }
  return m.values.toList()..sort((a, b) => b.wins != a.wins ? b.wins.compareTo(a.wins) : b.total.compareTo(a.total));
}

/// 決標方式的分布（最低標、最有利標…）
Map<String, int> awardWays(Iterable<DatasetAward> awards) {
  final m = <String, int>{};
  for (final a in awards) {
    if (a.awardWay.isNotEmpty) m[a.awardWay] = (m[a.awardWay] ?? 0) + 1;
  }
  return Map.fromEntries(m.entries.toList()..sort((a, b) => b.value.compareTo(a.value)));
}
