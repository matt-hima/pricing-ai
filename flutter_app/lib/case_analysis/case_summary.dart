import 'package:flutter/foundation.dart';

import '../i18n/i18n.dart';
import '../json_repair.dart';
import '../site/site_init.dart' show numbersIn;
import '../site/site_planner.dart' show Ask;
import '../site/site_style.dart';
import 'pcc.dart';
import 'zh_hant.dart';

/// 歷史案件摘要。小模型處理數字不可靠（會照抄欄位、把件數當成廠商數），所以分工：
/// - 價格、競爭：由程式依統計直接寫成句子（數字一定正確）
/// - 概況、報價建議：交給本機模型，只給文字資料（案件名稱、機關、報價位置的描述），並要求不寫數字；
///   含有資料外數字或照抄欄位名稱的句子整句拿掉

class CaseSummary {
  final String overview, price, competition;
  final List<String> advice;
  const CaseSummary({required this.overview, required this.price, required this.competition, required this.advice});
  bool get isEmpty => overview.isEmpty && price.isEmpty && competition.isEmpty && advice.isEmpty;
}

String _twd(double v) => 'NT\$${v.round().toString().replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => ',')}';
String _short(double v) => 'NT\$${shortTwd(v, cjk: I18n.lang.isCjk)}';

/// 價格：件數、中位數、中間 50% 範圍
String priceFacts(List<AwardCase> cases, int total) {
  final st = CaseStats.of(cases);
  return tr('hist.f.price', {'n': '${total > st.count ? total : st.count}', 'median': _twd(st.median), 'p25': _short(st.p25), 'p75': _short(st.p75)});
}

/// 競爭：點開過的公告裡的投標家數、決標金額 / 預算、常見得標廠商；沒點開就說明沒有資料
String competitionFacts(Map<String, AwardDetail> details) {
  final ds = DetailStats.of(details.values);
  if (ds.sampled == 0 || ds.avgBidders == null) return tr('hist.f.noDetail');
  final parts = [
    tr('hist.f.bidders', {'d': '${ds.sampled}', 'b': ds.avgBidders!.toStringAsFixed(1), 'single': '${ds.singleBidPct!.round()}'}),
    if (ds.awardToBudget != null) tr('hist.f.ratio', {'r': '${(ds.awardToBudget! * 100).round()}'}),
    if (ds.topWinners.isNotEmpty) tr('hist.f.winners', {'w': ds.topWinners.take(3).map((e) => e.key).join(Lang.list)}),
    if (competitorsOf(details).take(4).toList() case final r when r.length > 1)
      tr('hist.f.rivals', {'r': r.map((c) => tr('hist.f.rival', {'name': c.name, 'b': '${c.bids}', 'w': '${c.wins}'})).join(Lang.list)}),
    if (ds.sampled < 3) tr('hist.f.few'),
  ];
  return parts.join(I18n.lang.isCjk ? '' : ' ');
}

/// 我的報價在同類案件裡的位置（給模型的文字描述，不含數字）
String _quotePosition(List<AwardCase> cases, double? myPrice) {
  if (myPrice == null || myPrice <= 0) return 'not given';
  final st = CaseStats.of(cases);
  if (myPrice < st.p25) return 'low: cheaper than most similar awarded cases';
  if (myPrice > st.p75) return 'high: more expensive than most similar awarded cases';
  return 'typical: within the usual range of similar awarded cases';
}

/// 給模型看的資料：只有文字（關鍵字、常見機關、招標方式、代表案件名稱、報價位置、競爭的描述）
String caseNotes({required String keyword, required List<AwardCase> cases, required Map<String, AwardDetail> details, double? myPrice}) {
  final st = CaseStats.of(cases);
  final ds = DetailStats.of(details.values);
  final competition = ds.avgBidders == null
      ? 'unknown (no award notices opened)'
      : ds.singleBidPct! >= 50
          ? 'weak: many cases had only one bidder'
          : (ds.avgBidders! >= 3 ? 'strong: several bidders per case' : 'moderate');
  final b = StringBuffer()
    ..writeln('Search keyword: $keyword')
    ..writeln('Agencies that buy most often: ${st.topAgencies.map((e) => e.key).join(', ')}')
    ..writeln('Common tender methods: ${st.methods.map((e) => e.key).join(', ')}')
    ..writeln("Vendor's quote compared with similar cases: ${_quotePosition(cases, myPrice)}")
    ..writeln('Price competition: $competition')
    ..writeln('Example project names:');
  for (final c in representativeCases(cases, details, st.median, 10)) {
    b.writeln('- ${c.name} (${c.agency})');
  }
  return b.toString();
}

/// 代表案件：先放有明細的，再補離中位數最近的
List<AwardCase> representativeCases(List<AwardCase> cases, Map<String, AwardDetail> details, double median, int n) {
  final near = sampleForDetail(cases, median, cases.length);
  return [...near.where((c) => details.containsKey(c.url)), ...near.where((c) => !details.containsKey(c.url))].take(n).toList();
}

Map<String, dynamic> _str(int max) => {'type': 'string', 'maxLength': max};

Map<String, dynamic> caseSummarySchema() => {
      'type': 'object',
      'properties': {
        'overview': _str(200),
        'advice': {'type': 'array', 'minItems': 2, 'maxItems': 4, 'items': _str(100)},
      },
      'required': ['overview', 'advice'],
      'additionalProperties': false,
    };

/// 小數拆成兩個整數（1.5 → 1 和 5），比對時兩邊用同樣的拆法
Set<int> _nums(String text) => numbersIn(text.replaceAllMapped(RegExp(r'(\d)\.(\d)'), (m) => '${m[1]} ${m[2]}'));

/// 一個數字是否「資料裡有」：原樣出現過；或是以萬 / 億為單位的金額，和資料裡某個金額差不到 3%（四捨五入不算編造）
bool _numberOk(String num, String? unit, Set<int> allowed) {
  if (unit == null) return _nums(num).every(allowed.contains);
  final v = double.tryParse(num.replaceAll(',', ''));
  if (v == null) return false;
  final amount = v * (unit == '億' || unit == '亿' ? 1e8 : 1e4);
  return allowed.any((a) => a >= 10000 && (a - amount).abs() <= a * 0.03) || _nums(num).every(allowed.contains);
}

/// 拿掉含有資料外數字的句子（年份、件數、百分比、金額都算）。英文在「. 」切句，小數點不切。
String groundSentences(String text, Set<int> allowed) {
  final cjk = text.contains(RegExp(r'[。！？]'));
  final token = RegExp(r'(\d[\d,]*(?:\.\d+)?)\s*(萬|万|億|亿)?');
  final kept = [
    for (final s in text.split(RegExp(r'(?<=[。！？!?])|(?<=\.)\s+')))
      if (s.trim().isNotEmpty && token.allMatches(s).every((m) => _numberOk(m[1]!, m[2], allowed))) s.trim(),
  ];
  return kept.join(cjk ? '' : ' ');
}

Set<int> allowedNumbers(String evidence) => {..._nums(evidence), 50}; // 「中間 50%」是固定說法

/// 照抄資料欄位（「Search keyword:」這類）或一段裡有換行的，不是自己寫的句子
bool _copiesNotes(String text) => text.contains('\n') || RegExp(r'(keyword|Agencies|tender methods|quote compared|competition|project names)\s*:', caseSensitive: false).hasMatch(text);

Future<CaseSummary> summarizeCases({required Ask ask, required Lang lang, required String keyword, required List<AwardCase> cases, required int total, required Map<String, AwardDetail> details, double? myPrice}) async {
  final notes = caseNotes(keyword: keyword, cases: cases, details: details, myPrice: myPrice);
  final system = '''You are a bidding consultant for Taiwan government procurement. A vendor is preparing a quote and has looked up similar past awarded cases.
Output JSON only. Write ALL text in ${lang.aiName}.${lang == Lang.zh ? ' Use Traditional Chinese characters (繁體字) only, never Simplified Chinese (简体字).' : ''}
- "overview": in your own words, 1-2 sentences on what kinds of projects these are and which kinds of agencies buy them.
- "advice": 2-4 short, practical pricing tips for this vendor, based on how the vendor's quote compares and on the price competition.
Do not write any numbers, amounts or percentages: the app shows those separately. Do not copy the field names.
${writingRules(lang)}''';
  final out = await ask(system, notes, caseSummarySchema());
  debugPrint('case summary raw output: $out');
  final j = parseLooseJson(out);
  final allowed = allowedNumbers(notes);
  String clean(Object? v) {
    final raw = '${v ?? ''}'.trim();
    if (_copiesNotes(raw)) return '';
    final t = groundSentences(polishText(lang.name, raw), allowed);
    return lang == Lang.zh ? toTraditional(t) : t; // 小模型常寫成簡體字
  }

  return CaseSummary(
    overview: clean(j?['overview']),
    price: priceFacts(cases, total),
    competition: competitionFacts(details),
    advice: [for (final a in (j?['advice'] as List? ?? const [])) clean(a)]..removeWhere((a) => a.isEmpty),
  );
}
