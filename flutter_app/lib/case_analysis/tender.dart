/// 招標中的案件（政府電子採購網「招標查詢」，等標期內）與招標公告的內容。
/// 決標資料只用來分析這些招標中的案件：怎麼準備、對手是誰（上次得標的廠商、常得標的廠商）、多少錢合理。
library;

import 'dart:math' as math;

import 'pcc.dart';

/// 招標查詢：等標期內（還能投標）的招標公告
Uri openTenderSearchUrl({String keyword = '', ProcCate cate = ProcCate.any, int page = 1, String agency = ''}) =>
    Uri.https(pccHost, '/prkms/tender/common/basic/readTenderBasic', {
      'pageSize': '',
      'firstSearch': 'true',
      'searchType': 'basic',
      'isBinding': 'N',
      'isLogIn': 'N',
      'level_1': 'on',
      'orgName': agency,
      'orgId': '',
      'tenderName': keyword.replaceAll(RegExp(r'\s+'), ''),
      'tenderId': '',
      'tenderType': 'TENDER_DECLARATION',
      'tenderWay': 'TENDER_WAY_ALL_DECLARATION',
      'dateType': 'isSpdt', // 等標期內（isNow 是「當日」公告）
      'radProctrgCate': cate.param,
      'policyAdvocacy': '',
      if (page > 1) 'd-49738-p': '$page',
    });

/// 民國日期（115/11/09 或 115/11/09 17:00）→ DateTime
DateTime? rocDate(String s) {
  final m = RegExp(r'(\d{2,3})/(\d{1,2})/(\d{1,2})(?:\s+(\d{1,2}):(\d{2}))?').firstMatch(s);
  if (m == null) return null;
  return DateTime(int.parse(m[1]!) + 1911, int.parse(m[2]!), int.parse(m[3]!), int.parse(m[4] ?? '0'), int.parse(m[5] ?? '0'));
}

/// 招標查詢清單上的一筆
class OpenTender {
  final String agency, caseNo, name, method, category, url;
  final DateTime? noticeDate, deadline;
  final double? budget; // 預算不公開時是 null
  const OpenTender({
    required this.agency,
    required this.caseNo,
    required this.name,
    required this.method,
    required this.category,
    required this.url,
    this.noticeDate,
    this.deadline,
    this.budget,
  });

  /// 採購性質（工程類、財物類、勞務類）：查同機關的決標時只看同一類，大機關三年的決標常有幾百件
  ProcCate get cate => category.contains('工程')
      ? ProcCate.works
      : category.contains('財物')
          ? ProcCate.goods
          : category.contains('勞務')
              ? ProcCate.services
              : ProcCate.any;

  /// 截止投標前還有幾天（今天截止是 0；已過是負數）
  int? daysLeft(DateTime now) => deadline == null ? null : DateTime(deadline!.year, deadline!.month, deadline!.day).difference(DateTime(now.year, now.month, now.day)).inDays;
}

String _text(String html) => html
    .replaceAll(RegExp(r'<!--.*?-->', dotAll: true), '')
    .replaceAll(RegExp(r'<(br|/p|/li|/div|/tr|hr)\b[^>]*>', caseSensitive: false), '\n')
    .replaceAll(RegExp(r'<li\b[^>]*>', caseSensitive: false), '\n• ')
    .replaceAll(RegExp(r'<[^>]+>'), ' ')
    .replaceAll('&nbsp;', ' ')
    .replaceAll('&amp;', '&')
    .replaceAll('&lt;', '<')
    .replaceAll('&gt;', '>')
    .replaceAll('&quot;', '"')
    .replaceAll('⼀', '一') // 康熙部首字（公告常見）換回一般漢字
    .replaceAll('⼆', '二')
    .replaceAll('⼈', '人')
    .replaceAll('⼯', '工')
    .replaceAll('⼩', '小')
    .replaceAll('⽅', '方')
    .replaceAll('⾃', '自')
    .replaceAll('⾏', '行')
    .replaceAll('⾸', '首')
    .replaceAll('⻑', '長')
    .replaceAll('⽤', '用')
    .replaceAll('⽋', '欠')
    .split('\n')
    .map((l) => l.replaceAll(RegExp(r'[ \t\r]+'), ' ').trim())
    .where((l) => l.isNotEmpty && l != '•')
    .join('\n');

double? _money(String s) {
  final t = s.replaceAll(RegExp(r'[^\d.]'), '');
  return t.isEmpty ? null : double.tryParse(t);
}

/// 招標查詢結果 → 招標中的案件與總筆數
({List<OpenTender> tenders, int? total}) parseOpenTenders(String html) {
  final total = int.tryParse(RegExp(r'共有\s*([\d,]+)\s*筆').firstMatch(html)?[1]?.replaceAll(',', '') ?? '');
  final body = RegExp(r'<table[^>]*id="tpam"[^>]*>.*?<tbody>(.*?)</tbody>', dotAll: true).firstMatch(html)?[1] ?? '';
  final out = <OpenTender>[];
  for (final r in RegExp(r'<tr\b[^>]*>(.*?)</tr>', dotAll: true).allMatches(body)) {
    final cells = [for (final c in RegExp(r'<td\b[^>]*>(.*?)</td>', dotAll: true).allMatches(r[1]!)) c[1]!];
    if (cells.length < 9) continue;
    final link = RegExp(r'href="([^"]*tpam\?pk=[^"]+)"').firstMatch(cells[2])?[1];
    if (link == null) continue;
    final idName = cells[2].split(RegExp(r'<br\s*/?>'));
    out.add(OpenTender(
      agency: _text(cells[1]),
      caseNo: _text(idName.first),
      name: _text(idName.length > 1 ? idName[1] : cells[2]),
      method: _text(cells[4]),
      category: _text(cells[5]),
      noticeDate: rocDate(_text(cells[6])),
      deadline: rocDate(_text(cells[7])),
      budget: _money(_text(cells[8])),
      url: Uri.https(pccHost, '').resolve(link.replaceAll('&amp;', '&')).toString(),
    ));
  }
  return (tenders: out, total: total);
}

/// 招標公告（明細頁）的欄位：「欄位名稱 → 內容」。表格裡還有表格，所以依 <table> 的層數找每個欄位的那一列。
Map<String, String> noticeFields(String html) {
  final out = <String, String>{};
  final tag = RegExp(r'<(/?)(table|tr|td)\b[^>]*>', caseSensitive: false);
  var depth = 0;
  final bases = <int>[]; // 有 summary 的表格（公告的各區塊）開始時的層數
  final cells = <String>[];
  int? cellStart;
  for (final m in tag.allMatches(html)) {
    final close = m[1] == '/', name = m[2]!.toLowerCase();
    final top = bases.isNotEmpty && depth == bases.last + 1;
    if (name == 'table') {
      if (!close) {
        if (m[0]!.contains('summary=')) bases.add(depth);
        depth++;
      } else {
        depth--;
        if (bases.isNotEmpty && depth == bases.last) bases.removeLast();
      }
    } else if (top && name == 'td') {
      if (!close) {
        cellStart = m.end;
      } else if (cellStart != null) {
        cells.add(html.substring(cellStart, m.start));
        cellStart = null;
      }
    } else if (top && name == 'tr' && close) {
      if (cells.length >= 2) {
        final label = _text(cells[0]).replaceAll('\n', '');
        if (label.isNotEmpty) out[label] = cells[1];
      }
      cells.clear();
    } else if (top && name == 'tr' && !close) {
      cells.clear();
    }
  }
  return out;
}

/// 招標公告的重點：程式直接取欄位；文字部分（資格、附加說明、履約期限…）交給本機模型讀
class TenderNotice {
  final Map<String, String> fields; // 欄位名稱 → 純文字
  final double? budget;
  final DateTime? deadline, openAt, noticeDate;
  const TenderNotice(this.fields, {this.budget, this.deadline, this.openAt, this.noticeDate});

  String operator [](String k) => fields[k] ?? '';
  String get agency => this['機關名稱'];
  String get caseNo => this['標案案號'];
  String get name => this['標案名稱'];
  String get category => this['標的分類'].split('\n').first;
  String get tenderWay => this['招標方式'];
  String get awardWay => this['決標方式'];
  String get round => this['招標狀態'];
  bool get floorPrice => this['是否訂有底價'].startsWith('是');
  bool get followUp => this['後續擴充'].startsWith('是');

  /// 最有利標（含「參考最有利標精神」「準用最有利標」）：評選委員依企劃書評分，價格不是唯一因素
  bool get bestValue => awardWay.contains('最有利標');

  /// 給模型讀的文字：去掉受理申訴、檢舉單位這類固定內容（聯絡資料不在欄位裡）
  String get readable => [
        for (final e in fields.entries)
          if (!_skip.any(e.key.contains) && e.value.isNotEmpty) '${e.key}：${e.value}',
      ].join('\n');

  static const _skip = ['疑義、異議', '機關代碼', '聯絡人', '聯絡電話', '傳真', '電子郵件', '機關地址', '單位名稱', '收受投標文件地點', '開標地點'];
}

TenderNotice parseTenderNotice(String html) {
  final raw = noticeFields(html);
  final f = {for (final e in raw.entries) e.key: _text(e.value)};
  final budgetHidden = RegExp(r'id="budget"\s+value="(\d+(?:\.\d+)?)"').firstMatch(html)?[1];
  return TenderNotice(
    f,
    budget: budgetHidden != null ? double.tryParse(budgetHidden) : _money((f['預算金額'] ?? '').split('\n').first),
    deadline: rocDate(f['截止投標'] ?? ''),
    openAt: rocDate(f['開標時間'] ?? ''),
    noticeDate: rocDate(f['公告日'] ?? ''),
  );
}

/// 招標公告頁（不是驗證頁、也不是錯誤頁）
bool isTenderNotice(String html) => html.contains('截止投標') && html.contains('標案名稱');

// ---------- 用決標資料分析招標中的案件 ----------

/// 案名的核心：去掉年度、期別、「採購案」這類字，比對「同一案的上一次」用
String coreName(String name) => name
    .replaceAll(RegExp(r'\d{2,4}\s*[-~～至、]\s*\d{2,4}\s*年度?'), '')
    .replaceAll(RegExp(r'(民國)?\d{2,4}\s*年度?'), '')
    .replaceAll(RegExp(r'\d{4}'), '')
    .replaceAll(RegExp(r'(第[一二三四五六七八九十\d]+[期次年]|後續擴充|契約變更|勞務採購案|財物採購案|採購案|委託案|委辦案|計畫|專案|服務案|案)'), '')
    .replaceAll(RegExp(r'[「」『』（）()〔〕\[\]【】\s、，,.:：\-_]'), '');

/// 兩個案名有多像（字元雙字組的 Dice 係數，0–1）
double nameSimilarity(String a, String b) {
  Set<String> grams(String s) => {for (var i = 0; i + 1 < s.length; i++) s.substring(i, i + 2)};
  final x = grams(coreName(a)), y = grams(coreName(b));
  if (x.isEmpty || y.isEmpty) return 0;
  return 2 * x.intersection(y).length / (x.length + y.length);
}

/// 上一次同一案（同機關、案名相近）的決標：通常就是現在的承包商，也是最需要贏過的對手
AwardCase? incumbentOf(OpenTender t, Iterable<AwardCase> agencyAwards, {double threshold = 0.5}) {
  AwardCase? best;
  var bestScore = threshold;
  for (final c in agencyAwards) {
    if (c.agency != t.agency) continue;
    final s = nameSimilarity(t.name, c.name);
    final newer = best == null || (c.date ?? DateTime(0)).isAfter(best.date ?? DateTime(0));
    if (s > bestScore || (s == bestScore && newer)) {
      best = c;
      bestScore = s;
    }
  }
  return best;
}

/// 合理價格：同類案件「決標金額 / 預算」的分布 × 這一案的預算。決標方式相同的樣本夠多時只用同一種。
class PriceGuide {
  final int samples;
  final double ratioLow, ratioMid, ratioHigh; // 25%、中位數、75%
  final double? low, mid, high; // 依預算換算；預算不公開時是 null
  final bool sameAwardWay;
  const PriceGuide({required this.samples, required this.ratioLow, required this.ratioMid, required this.ratioHigh, this.low, this.mid, this.high, this.sameAwardWay = false});
}

double _q(List<double> s, double p) {
  if (s.length == 1) return s.first;
  final i = (s.length - 1) * p;
  final lo = i.floor(), hi = math.min(i.ceil(), s.length - 1);
  return s[lo] + (s[hi] - s[lo]) * (i - lo);
}

/// [details] 是點開過的同類決標公告（有預算與決標金額）。少於 3 件不提供。
PriceGuide? priceGuide({double? budget, required bool bestValue, required Iterable<AwardDetail> details}) {
  List<double> ratios(bool Function(AwardDetail) keep) => [
        for (final d in details)
          if (keep(d) && d.budget != null && d.budget! > 0 && d.award != null && d.award! > 0 && d.award! <= d.budget! * 1.05) d.award! / d.budget!,
      ]..sort();
  var r = ratios((d) => (d.awardWay ?? '').contains('最有利標') == bestValue);
  final same = r.length >= 3;
  if (!same) r = ratios((_) => true);
  if (r.length < 3) return null;
  final lo = _q(r, .25), mid = _q(r, .5), hi = _q(r, .75);
  return PriceGuide(
    samples: r.length,
    ratioLow: lo,
    ratioMid: mid,
    ratioHigh: hi,
    low: budget == null ? null : budget * lo,
    mid: budget == null ? null : budget * mid,
    high: budget == null ? null : budget * hi,
    sameAwardWay: same,
  );
}
