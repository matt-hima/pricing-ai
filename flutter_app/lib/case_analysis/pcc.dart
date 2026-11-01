import 'dart:math' as math;

/// 案件分析：查政府電子採購網（web.pcc.gov.tw）的「決標公告」，整理同類案件的決標金額分布、
/// 常見機關、得標廠商與投標家數，讓使用者對照自己的報價落在哪個位置。
/// 這裡只放純邏輯（查詢網址、解析 HTML、統計）；實際抓網頁在 pcc_fetch_*.dart。

const pccHost = 'web.pcc.gov.tw';

/// 採購性質：網站表單的 radProctrgCate 值（1 工程、2 財物、3 勞務、空白 不限）
enum ProcCate {
  any(''),
  works('RAD_PROCTRG_CATE_1'),
  goods('RAD_PROCTRG_CATE_2'),
  services('RAD_PROCTRG_CATE_3');

  final String param;
  const ProcCate(this.param);
}

String _ymd(DateTime d) => '${d.year}/${d.month.toString().padLeft(2, '0')}/${d.day.toString().padLeft(2, '0')}';

/// 決標查詢的網址（GET 即可）。page 從 1 開始。
/// 採購網的標案名稱查詢會去掉空白、當成一整串連續文字比對（沒有 AND / OR），所以「網站 維護」= 「網站維護」。
/// [wonBy] / [bidBy]：依得標廠商 / 投標廠商名稱查（要用完整名稱，部分名稱會混到別家公司）。
Uri awardSearchUrl({String keyword = '', required DateTime from, required DateTime to, ProcCate cate = ProcCate.any, int page = 1, int pageSize = 100, String wonBy = '', String bidBy = ''}) =>
    Uri.https(pccHost, '/prkms/tender/common/agent/readTenderAgent', {
      'pageSize': '$pageSize',
      'firstSearch': 'true',
      'isQuery': 'true',
      'isBinding': 'N',
      'isLogIn': 'N',
      'tenderName': keyword.replaceAll(RegExp(r'\s+'), ''),
      if (wonBy.isNotEmpty) 'gottenVendorName': wonBy,
      if (bidBy.isNotEmpty) 'submitVendorName': bidBy,
      'tenderStatus': 'TENDER_STATUS_1', // 只看決標公告
      'tenderWay': 'TENDER_WAY_ALL_DECLARATION',
      'awardAnnounceStartDate': _ymd(from),
      'awardAnnounceEndDate': _ymd(to),
      'radProctrgCate': cate.param,
      'tenderRange': 'TENDER_RANGE_ALL',
      'radReConstruct': '',
      'policyAdvocacy': '',
      'isCpp': '',
      'd-16396-p': '$page',
    });

/// 網頁版開給使用者自己查的頁面
final awardSearchPage = Uri.https(pccHost, '/prkms/tender/common/agent/indexTenderAgent');

class AwardCase {
  final String agency, caseNo, name, method, category, url;
  final DateTime? date;
  final double amount;
  const AwardCase({required this.agency, required this.caseNo, required this.name, required this.method, required this.category, required this.date, required this.amount, required this.url});
}

/// 投標廠商（決標公告會列出所有投標的廠商與是否得標）
class Bidder {
  final String id, name;
  final bool won;
  const Bidder(this.id, this.name, this.won);
}

/// 評選委員：以最有利標決標的案件，決標公告會依法公開評選委員（姓名、職業、是否出席）
class Reviewer {
  final String name, job;
  final bool attended;
  const Reviewer(this.name, this.job, this.attended);
}

/// 決標公告的明細（只取分析用得到的欄位；機關沒公開的欄位是 null）
class AwardDetail {
  final double? budget, floor, award;
  final int? bidders;
  final String? winner, awardWay;
  final List<Bidder> bidderList;
  final List<Reviewer> reviewers;
  const AwardDetail({this.budget, this.floor, this.award, this.bidders, this.winner, this.awardWay, this.bidderList = const [], this.reviewers = const []});
}

/// 決標公告的「評選委員」表格：每列是 項次、出席會議（是/否）、姓名、職業、學經歷
List<Reviewer> parseReviewers(String html) {
  final i = html.indexOf('>評選委員<');
  if (i < 0) return const [];
  final end = html.indexOf('</table>', i); // 內層的委員表格會先結束
  if (end < 0) return const [];
  String cell(String c) => _text(c);
  final out = <Reviewer>[];
  for (final r in RegExp(r'<tr[^>]*>(.*?)</tr>', dotAll: true).allMatches(html.substring(i, end))) {
    final tds = [for (final m in RegExp(r'<td[^>]*>(.*?)</td>', dotAll: true).allMatches(r[1]!)) cell(m[1]!)];
    if (tds.length < 4 || !RegExp(r'^\d+$').hasMatch(tds[0]) || tds[2].isEmpty) continue;
    out.add(Reviewer(tds[2], tds[3], tds[1] == '是'));
  }
  return out;
}

String _unescape(String s) => s
    .replaceAllMapped(RegExp(r'&#(\d+);'), (m) => String.fromCharCode(int.parse(m[1]!)))
    .replaceAll('&amp;', '&')
    .replaceAll('&quot;', '"')
    .replaceAll('&#39;', "'")
    .replaceAll('&lt;', '<')
    .replaceAll('&gt;', '>')
    .replaceAll('&nbsp;', ' ')
    .replaceAll('&emsp;', ' ');

String _text(String html) => _unescape(html.replaceAll(RegExp(r'<(script|style)[^>]*>.*?</\1>', dotAll: true, caseSensitive: false), ' ').replaceAll(RegExp(r'<[^>]+>'), ' ')).replaceAll(RegExp(r'\s+'), ' ').trim();

/// 民國日期「115/10/29」→ 2026-10-29
DateTime? parseRocDate(String s) {
  final m = RegExp(r'(\d{2,3})/(\d{1,2})/(\d{1,2})').firstMatch(s);
  if (m == null) return null;
  return DateTime(int.parse(m[1]!) + 1911, int.parse(m[2]!), int.parse(m[3]!));
}

double? parseAmount(String s) {
  final m = RegExp(r'\d[\d,]*(\.\d+)?').firstMatch(s);
  return m == null ? null : double.tryParse(m[0]!.replaceAll(',', ''));
}

/// 決標查詢結果頁 → 案件清單與總筆數
({List<AwardCase> cases, int total}) parseAwardList(String html) {
  final t = html.indexOf('id="atm"');
  if (t < 0) return (cases: const <AwardCase>[], total: 0);
  final b0 = html.indexOf('<tbody', t), b1 = html.indexOf('</tbody>', b0);
  final body = b0 < 0 || b1 < 0 ? '' : html.substring(b0, b1);
  final out = <AwardCase>[];
  for (final r in RegExp(r'<tr[^>]*>(.*?)</tr>', dotAll: true).allMatches(body)) {
    final tds = [for (final m in RegExp(r'<td[^>]*>(.*?)</td>', dotAll: true).allMatches(r[1]!)) m[1]!];
    if (tds.length < 7) continue;
    // 標案名稱寫在連結的 title（畫面上的名稱是用 script 畫成圖片）
    final link = RegExp(r'<a href="([^"]+)"[^>]*title="([^"]*)"').firstMatch(tds[2]);
    final amount = parseAmount(_text(tds[6]));
    if (link == null || amount == null) continue;
    out.add(AwardCase(
      agency: _text(tds[1]),
      caseNo: _text(tds[2].split(RegExp(r'<br', caseSensitive: false)).first),
      name: _unescape(link[2]!).trim(),
      method: _text(tds[3]),
      category: _text(tds[4]),
      date: parseRocDate(_text(tds[5])),
      amount: amount,
      url: Uri.https(pccHost, '').resolve(_unescape(link[1]!)).toString(),
    ));
  }
  final total = RegExp(r'共有\s*(?:<[^>]*>\s*)*([\d,]+)').firstMatch(html);
  return (cases: out, total: total == null ? out.length : int.parse(total[1]!.replaceAll(',', '')));
}

/// 決標公告明細頁 → 預算、底價、決標金額、投標家數、得標廠商
AwardDetail parseAwardDetail(String html) {
  final text = _unescape(html
      .replaceAll(RegExp(r'<(script|style)[^>]*>.*?</\1>', dotAll: true, caseSensitive: false), ' ')
      .replaceAll(RegExp(r'<(br|/tr|/td|/th|/p|/div)[^>]*>', caseSensitive: false), '\n')
      .replaceAll(RegExp(r'<[^>]+>'), ' '));
  final lines = [for (final l in text.split('\n')) l.replaceAll(RegExp(r'\s+'), ' ').trim()]..removeWhere((l) => l.isEmpty);
  String? after(String label) {
    final i = lines.indexOf(label);
    return i < 0 || i + 1 >= lines.length ? null : lines[i + 1];
  }

  double? money(String label) {
    final v = after(label);
    return v != null && v.contains('元') ? parseAmount(v) : null;
  }

  final winner = after('得標廠商')?.replaceFirst(RegExp(r'\s*\(.*$'), '');
  final bidders = int.tryParse(after('投標廠商家數') ?? '');
  // 「投標廠商N」之後依序是 廠商代碼、廠商名稱、是否得標；到簽約廠商 / 決標品項就結束
  final list = <Bidder>[];
  String? id, name;
  bool? won;
  void flush() {
    if (name != null && name!.isNotEmpty) list.add(Bidder(id ?? '', name!, won ?? false));
    id = name = null;
    won = null;
  }

  var inBidders = false;
  for (var i = 0; i < lines.length - 1; i++) {
    final l = lines[i];
    if (RegExp(r'^投標廠商\d+$').hasMatch(l)) {
      flush();
      inBidders = true;
    } else if (l == '簽約廠商' || l == '決標品項' || l == '簽約廠商家數' || l == '決標品項數') {
      if (inBidders) flush();
      inBidders = false;
    } else if (inBidders && l == '廠商代碼') {
      id = lines[i + 1];
    } else if (inBidders && l == '廠商名稱') {
      name = lines[i + 1].replaceFirst(RegExp(r'\s*\(.*$'), '');
    } else if (inBidders && l == '是否得標') {
      won = lines[i + 1] == '是';
    }
  }
  if (inBidders) flush();
  return AwardDetail(
    budget: money('預算金額'),
    floor: money('底價金額'),
    award: money('總決標金額') ?? money('決標金額'),
    bidders: bidders,
    winner: winner == null || winner.isEmpty ? null : winner,
    awardWay: after('決標方式'),
    bidderList: list,
    reviewers: parseReviewers(html),
  );
}

double _quantile(List<double> sorted, double q) {
  if (sorted.isEmpty) return 0;
  final pos = (sorted.length - 1) * q;
  final lo = pos.floor(), hi = pos.ceil();
  return sorted[lo] + (sorted[hi] - sorted[lo]) * (pos - lo);
}

/// 決標金額的區間（新台幣）：一般人看得懂的整數級距
const amountBands = [0.0, 100000.0, 300000.0, 1000000.0, 3000000.0, 10000000.0, double.infinity];

class CaseStats {
  final int count;
  final double min, p25, median, p75, max, mean;
  final List<int> bands; // 每個 amountBands 區間的件數
  final List<MapEntry<String, int>> topAgencies, methods;
  const CaseStats({required this.count, required this.min, required this.p25, required this.median, required this.p75, required this.max, required this.mean, required this.bands, required this.topAgencies, required this.methods});

  static CaseStats of(List<AwardCase> cases) {
    final a = [for (final c in cases) c.amount]..sort();
    List<MapEntry<String, int>> top(Iterable<String> keys, int n) {
      final m = <String, int>{};
      for (final k in keys) {
        if (k.isNotEmpty) m[k] = (m[k] ?? 0) + 1;
      }
      return (m.entries.toList()..sort((x, y) => y.value.compareTo(x.value))).take(n).toList();
    }

    final bands = List.filled(amountBands.length - 1, 0);
    for (final v in a) {
      for (var i = 0; i < bands.length; i++) {
        if (v >= amountBands[i] && v < amountBands[i + 1]) {
          bands[i]++;
          break;
        }
      }
    }
    return CaseStats(
      count: a.length,
      min: a.isEmpty ? 0 : a.first,
      p25: _quantile(a, .25),
      median: _quantile(a, .5),
      p75: _quantile(a, .75),
      max: a.isEmpty ? 0 : a.last,
      mean: a.isEmpty ? 0 : a.reduce((x, y) => x + y) / a.length,
      bands: bands,
      topAgencies: top(cases.map((c) => c.agency), 5),
      methods: top(cases.map((c) => c.method), 4),
    );
  }

  /// 有幾 % 的案件決標金額 ≤ price
  static double percentile(List<AwardCase> cases, double price) => cases.isEmpty ? 0 : 100 * cases.where((c) => c.amount <= price).length / cases.length;
}

/// 抽樣明細的統計：平均投標家數、一家投標的比例、決標金額 / 預算、常見得標廠商
class DetailStats {
  final int sampled;
  final double? avgBidders, singleBidPct, awardToBudget;
  final List<MapEntry<String, int>> topWinners;
  const DetailStats({required this.sampled, this.avgBidders, this.singleBidPct, this.awardToBudget, required this.topWinners});

  static DetailStats of(Iterable<AwardDetail> details) {
    final d = details.toList();
    final bidders = [for (final x in d) if (x.bidders != null && x.bidders! > 0) x.bidders!];
    final ratios = [
      for (final x in d)
        if (x.budget != null && x.award != null && x.budget! > 0) x.award! / x.budget!
    ]..sort();
    final w = <String, int>{};
    for (final x in d) {
      if (x.winner != null) w[x.winner!] = (w[x.winner!] ?? 0) + 1;
    }
    return DetailStats(
      sampled: d.length,
      avgBidders: bidders.isEmpty ? null : bidders.reduce((a, b) => a + b) / bidders.length,
      singleBidPct: bidders.isEmpty ? null : 100 * bidders.where((b) => b == 1).length / bidders.length,
      awardToBudget: ratios.isEmpty ? null : _quantile(ratios, .5),
      topWinners: (w.entries.toList()..sort((x, y) => y.value.compareTo(x.value))).take(5).toList(),
    );
  }
}

/// 分析結果匯出成 CSV（含 BOM，Excel 開中文不會亂碼）
String casesCsv(List<AwardCase> cases, Map<String, AwardDetail> details, List<String> header) {
  String q(String v) => '"${v.replaceAll('"', '""')}"';
  String n(double? v) => v == null ? '' : v.round().toString();
  final lines = [
    header.map(q).join(','),
    for (final c in cases)
      [
        q(c.date == null ? '' : _ymd(c.date!)),
        q(c.agency),
        q(c.caseNo),
        q(c.name),
        q(c.method),
        q(c.category),
        n(c.amount),
        n(details[c.url]?.budget),
        '${details[c.url]?.bidders ?? ''}',
        q(details[c.url]?.winner ?? ''),
        q(c.url),
      ].join(','),
  ];
  return '﻿${lines.join('\n')}\n';
}

/// 金額縮寫（萬 / 億）給圖表軸與統計用；完整金額仍用 formatMoney
String shortTwd(double v, {bool cjk = true}) {
  String f(double x, int digits) => x.toStringAsFixed(digits).replaceFirst(RegExp(r'\.0$'), '');
  if (!cjk) {
    if (v >= 1e9) return '${f(v / 1e9, 1)}B';
    if (v >= 1e6) return '${f(v / 1e6, v >= 1e7 ? 0 : 1)}M';
    if (v >= 1e3) return '${(v / 1e3).toStringAsFixed(0)}K';
    return v.round().toString();
  }
  if (v >= 1e8) return '${f(v / 1e8, 1)}億';
  if (v >= 1e4) return '${f(v / 1e4, v >= 1e6 ? 0 : 1)}萬';
  return v.round().toString();
}

/// 明細抽樣：取離中位數最近的幾件（最能代表「一般行情」），不是只取最新的
List<AwardCase> sampleForDetail(List<AwardCase> cases, double median, int n) {
  final s = [...cases]..sort((a, b) => (math.log(a.amount + 1) - math.log(median + 1)).abs().compareTo((math.log(b.amount + 1) - math.log(median + 1)).abs()));
  return s.take(n).toList();
}

/// 決標公告的主鍵（清單連結是 atm?pk=…，點開後轉到 QueryAtmAwardDetail?pkAtmMain=…，兩者同一個值）
String? awardPk(String url) {
  final q = Uri.tryParse(url)?.queryParameters;
  return q?['pk'] ?? q?['pkAtmMain'];
}

/// 明細的統一網址：和清單裡案件的 url 相同，方便對應
String awardUrlForPk(String pk) => 'https://$pccHost/prkms/urlSelector/common/atm?pk=$pk'; // 和網站上的連結一樣，結尾的 = 不編碼

/// 一次查詢的代號：kw:關鍵字 / won:得標廠商 / bid:投標廠商
String searchKey(Uri url) {
  final q = url.queryParameters;
  final won = q['gottenVendorName'] ?? '', bid = q['submitVendorName'] ?? '';
  if (won.isNotEmpty) return 'won:$won';
  if (bid.isNotEmpty) return 'bid:$bid';
  return 'kw:${q['tenderName'] ?? ''}';
}

/// 在內嵌瀏覽器裡看過的頁面所收集到的案件與明細
class CaseCollection {
  final List<AwardCase> cases;
  final Map<String, AwardDetail> details; // key = AwardCase.url
  final Map<String, int> totals = {}; // 查詢代號 → 網站上的總筆數
  final Map<String, int> loaded = {}; // 查詢代號 → 已讀到的筆數
  final Map<String, Set<String>> foundBy = {}; // AwardCase.url → 哪些查詢找到它
  /// 依廠商查的結果（won:/bid:）另外放：那是廠商的所有案件，不該混進關鍵字的統計
  final Map<String, List<AwardCase>> vendorCases = {};
  CaseCollection({List<AwardCase>? cases, Map<String, AwardDetail>? details})
      : cases = cases ?? [],
        details = details ?? {};

  /// 網站上符合的案件數（估計）：已收集的 + 各關鍵字查詢還沒翻到的
  int get total => cases.length + totals.entries.where((e) => e.key.startsWith('kw:')).fold<int>(0, (n, e) => n + (e.value - (loaded[e.key] ?? 0)).clamp(0, 1 << 30));

  /// 某個查詢找到的案件
  List<AwardCase> casesFrom(String key) => key.startsWith('kw:') ? [for (final c in cases) if (foundBy[c.url]?.contains(key) ?? false) c] : (vendorCases[key] ?? const []);

  /// 讀到的頁面：決標清單就加入案件，決標明細就加入明細。回傳是否有新資料。
  bool addPage(String url, String html) {
    final u = Uri.tryParse(url);
    if (u != null && url.contains('readTenderAgent')) {
      final r = parseAwardList(html);
      final key = searchKey(u);
      final page = u.queryParameters['d-16396-p'] ?? '1';
      final pageKey = '$key#$page';
      final seen = {for (final c in cases) c.url};
      var changed = false;
      if (!_pages.contains(pageKey)) {
        _pages.add(pageKey);
        loaded[key] = (loaded[key] ?? 0) + r.cases.length;
        totals[key] = r.total;
        changed = true;
      }
      if (!key.startsWith('kw:')) {
        final list = vendorCases[key] ??= [];
        final have = {for (final c in list) c.url};
        list.addAll(r.cases.where((c) => have.add(c.url)));
        return changed;
      }
      for (final c in r.cases) {
        if (seen.add(c.url)) cases.add(c);
        changed = (foundBy[c.url] ??= {}).add(key) || changed;
      }
      return changed;
    }
    final pk = awardPk(url);
    if (pk != null && (url.contains('QueryAtmAwardDetail') || url.contains('common/atm'))) {
      final d = parseAwardDetail(html);
      if (d.award == null && d.bidders == null) return false;
      details[awardUrlForPk(pk)] = d;
      return true;
    }
    return false;
  }

  final Set<String> _pages = {};
}

/// 潛在競爭對手：點開過的決標公告裡出現的投標廠商，依投標次數排序
class Competitor {
  final String id, name;
  int bids = 0, wins = 0;
  Competitor(this.id, this.name);
}

List<Competitor> competitorsOf(Map<String, AwardDetail> details) {
  final m = <String, Competitor>{};
  for (final d in details.values) {
    for (final b in d.bidderList) {
      final c = m[b.id.isEmpty ? b.name : b.id] ??= Competitor(b.id, b.name);
      c.bids++;
      if (b.won) c.wins++;
    }
  }
  return m.values.toList()..sort((a, b) => b.bids != a.bids ? b.bids.compareTo(a.bids) : b.wins.compareTo(a.wins));
}

/// 廠商的得標紀錄：用「得標廠商」與「投標廠商」兩個查詢的結果算出得標件數、投標件數、得標率、常見機關
class VendorProfile {
  final String name;
  final int wins, bids;
  final List<AwardCase> wonCases;
  const VendorProfile(this.name, this.wins, this.bids, this.wonCases);
  double? get winRate => bids > 0 ? 100 * wins / bids : null;
  CaseStats? get stats => wonCases.isEmpty ? null : CaseStats.of(wonCases);

  static VendorProfile of(String name, CaseCollection col) => VendorProfile(
        name,
        col.totals['won:$name'] ?? 0,
        col.totals['bid:$name'] ?? 0,
        col.casesFrom('won:$name'),
      );
}

/// Google 搜尋的 AI 模式（udm=50）；沒有開放 AI 模式的帳號 / 地區會顯示一般搜尋結果
Uri googleAiMode(String query) => Uri.https('www.google.com', '/search', {'q': query, 'udm': '50'});

/// 自動交叉分析要點開的決標公告：優先「評選」類的招標方式（會公開評選委員），其次離中位數近的；已讀過的跳過
List<AwardCase> pickForCrossRef(CaseCollection col, int n) {
  if (col.cases.isEmpty) return const [];
  final median = CaseStats.of(col.cases).median;
  final near = sampleForDetail(col.cases, median, col.cases.length).where((c) => !col.details.containsKey(c.url)).toList();
  final evaluated = near.where((c) => c.method.contains('評選')).toList();
  return [...evaluated, ...near.where((c) => !c.method.contains('評選'))].take(n).toList();
}

/// 要自動查紀錄的競爭對手：在點開的公告裡投標次數最多的幾家（已查過的跳過）
List<Competitor> pickRivalsToLookUp(CaseCollection col, int n) =>
    competitorsOf(col.details).where((c) => !col.totals.containsKey('won:${c.name}')).take(n).toList();

/// 評選委員交叉分析：每位委員在點開的公告裡評選過幾件、出席幾次，以及那些案件的得標廠商
class ReviewerRecord {
  final String name, job;
  final List<String> caseUrls = [];
  int attended = 0;
  final Map<String, int> winners = {};
  ReviewerRecord(this.name, this.job);
}

List<ReviewerRecord> reviewerCrossRef(Map<String, AwardDetail> details) {
  final m = <String, ReviewerRecord>{};
  details.forEach((url, d) {
    for (final r in d.reviewers) {
      final rec = m[r.name] ??= ReviewerRecord(r.name, r.job);
      if (rec.caseUrls.contains(url)) continue;
      rec.caseUrls.add(url);
      if (r.attended) rec.attended++;
      final w = d.winner;
      if (w != null) rec.winners[w] = (rec.winners[w] ?? 0) + 1;
    }
  });
  return m.values.toList()..sort((a, b) => b.caseUrls.length != a.caseUrls.length ? b.caseUrls.length.compareTo(a.caseUrls.length) : a.name.compareTo(b.name));
}
