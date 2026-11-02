/// 招標中案件的說明：本機模型讀招標公告，寫「機關要什麼、要準備什麼」；
/// 日期、金額、決標方式與「要注意」由程式直接從公告欄位寫（一定和公告一致），模型寫的句子含有公告外的數字就拿掉，
/// 「要準備」的每一項也要用到公告裡的字（小模型會自己補常見的要求）。
library;

import 'package:flutter/foundation.dart';

import '../i18n/i18n.dart';
import '../json_repair.dart';
import '../site/site_planner.dart' show Ask;
import '../site/site_style.dart';
import 'case_summary.dart' show allowedNumbers, groundSentences;
import 'tender.dart';
import 'zh_hant.dart';

class TenderBrief {
  final String scope; // 機關要什麼（白話）
  final List<String> prepare; // 要準備的東西
  const TenderBrief({required this.scope, required this.prepare});
  bool get isEmpty => scope.isEmpty && prepare.isEmpty;
}

Map<String, dynamic> _str(int max) => {'type': 'string', 'maxLength': max};

Map<String, dynamic> tenderBriefSchema() => {
      'type': 'object',
      'properties': {
        'scope': _str(220),
        'prepare': {'type': 'array', 'minItems': 1, 'maxItems': 5, 'items': _str(90)},
      },
      'required': ['scope', 'prepare'],
      'additionalProperties': false,
    };

/// 本機模型讀招標公告。公告文字太長時只給前面的部分（重點欄位都在前面）。
Future<TenderBrief> readTenderNotice({required Ask ask, required Lang lang, required TenderNotice notice, int maxChars = 3500}) async {
  final text = notice.readable;
  final input = text.length > maxChars ? text.substring(0, maxChars) : text;
  final system = '''You help a vendor decide how to bid on a Taiwan government tender. Read the tender notice the user gives you.
Output JSON only. Write ALL text in ${lang.aiName}.${lang == Lang.zh ? ' Use Traditional Chinese characters (繁體字) only, never Simplified Chinese (简体字).' : ''}
- "scope": 1-2 sentences in plain words: what the agency wants delivered and for how long.
- "prepare": 1-5 concrete documents or items the vendor must prepare to bid, using the notice's own words (for example the qualification proofs it lists). Each item is one short phrase (under 30 characters), not a copied paragraph.
Only use what the notice says. Do not add common requirements the notice does not mention. Do not copy field names. Avoid dates and amounts: the app shows them separately.
${writingRules(lang)}''';
  final out = await ask(system, input, tenderBriefSchema());
  debugPrint('tender brief raw output: $out');
  final j = parseLooseJson(out);
  final allowed = allowedNumbers(text);
  String clean(Object? v) {
    final raw = '${v ?? ''}'.trim();
    if (raw.contains('\n') || raw.contains('：') && raw.length < 12) return ''; // 照抄欄位
    final t = groundSentences(polishText(lang.name, raw), allowed);
    return lang == Lang.zh ? taiwanTerms(toTraditional(t)) : t;
  }

  // 「要準備」：中文時每一項至少要有一段三個字出現在公告裡（去掉「準備、提供」這類動詞後）
  final source = taiwanTerms(toTraditional(text));
  bool grounded(String p) {
    if (lang != Lang.zh) return true;
    final core = p.replaceAll(RegExp(r'^(請)?(準備|提供|提交|繳交|檢附|附上|備妥|取得)'), '').replaceAll(RegExp(r'[，。、；：\s]'), '');
    for (var i = 0; i + 3 <= core.length; i++) {
      if (source.contains(core.substring(i, i + 3))) return true;
    }
    return false;
  }

  // 小模型常把公告的條列整段抄進來：去掉開頭的符號、只是標題的那一行（以冒號結尾），太長的只留括號前的名稱
  String item(String p) {
    var t = p.replaceFirst(RegExp(r'^[-•*·．.、\s\d]+'), '').trim();
    if (RegExp(r'[：:]$').hasMatch(t)) return '';
    if (t.length > 40) {
      final cut = t.indexOf(RegExp(r'[（(：:，,]'));
      t = cut >= 4 && cut <= 40 ? t.substring(0, cut) : '';
    }
    return t;
  }

  final prepare = <String>[];
  for (final x in (j?['prepare'] as List? ?? const [])) {
    final p = item(clean(x));
    // 「提供軟體執行服務」只是標的分類，不是要準備的東西
    final what = p.replaceAll(RegExp(r'^(請)?(準備|提供|提交|繳交|檢附|附上|備妥|取得)'), '');
    if (what.length >= 4 && taiwanTerms(notice['標的分類']).contains(what)) continue;
    if (p.isNotEmpty && grounded(p) && !prepare.contains(p)) prepare.add(p);
  }
  return TenderBrief(scope: clean(j?['scope']), prepare: prepare);
}

/// 小模型的中文常混入大陸用語，換成臺灣的說法
String taiwanTerms(String s) {
  const terms = {'軟件': '軟體', '硬件': '硬體', '網絡': '網路', '信息': '資訊', '數據庫': '資料庫', '服務器': '伺服器', '視頻': '影片', '用戶': '使用者', '質量': '品質', '程序': '程式'};
  for (final e in terms.entries) {
    s = s.replaceAll(e.key, e.value);
  }
  return s;
}

/// 要注意（程式從公告欄位寫）
List<String> tenderRisks(TenderNotice n, {required DateTime now}) {
  final days = n.deadline == null ? null : DateTime(n.deadline!.year, n.deadline!.month, n.deadline!.day).difference(DateTime(now.year, now.month, now.day)).inDays;
  bool yes(String k) => n[k].startsWith('是');
  return [
    if (days != null && days >= 0 && days <= 3) tr('tender.risk.soon', {'n': '$days'}),
    if (yes('是否須繳納押標金')) tr('tender.risk.deposit'),
    if (yes('是否須繳納履約保證金')) tr('tender.risk.bond'),
    if (n.floorPrice) tr('tender.risk.floor'),
    if (yes('是否採行協商措施')) tr('tender.risk.nego'),
    if (n.followUp) tr('tender.risk.followUp'),
    if (n['是否提供電子投標'].startsWith('否')) tr('tender.risk.paper'),
    if (yes('是否複數決標')) tr('tender.risk.multi'),
  ];
}

/// 公告重點（程式從欄位寫）：(標籤, 內容)
List<(String, String)> tenderFacts(TenderNotice n, {required DateTime now, required String Function(double) money}) {
  String ymdhm(DateTime d) => '${d.year}/${d.month}/${d.day}${d.hour == 0 && d.minute == 0 ? '' : ' ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}'}';
  final days = n.deadline == null ? null : DateTime(n.deadline!.year, n.deadline!.month, n.deadline!.day).difference(DateTime(now.year, now.month, now.day)).inDays;
  return [
    if (n.deadline != null)
      (tr('tender.f.deadline'), '${ymdhm(n.deadline!)}${days == null ? '' : days < 0 ? '（${tr('tender.closed')}）' : '（${tr('tender.daysLeft', {'n': '$days'})}）'}'),
    if (n.openAt != null) (tr('tender.f.open'), ymdhm(n.openAt!)),
    (tr('tender.f.budget'), n.budget == null ? tr('tender.budgetHidden') : money(n.budget!)),
    if (n.awardWay.isNotEmpty) (tr('tender.f.awardWay'), '${n.awardWay}${n.bestValue ? '（${tr('tender.bestValueNote')}）' : n.awardWay.contains('最低標') ? '（${tr('tender.lowestNote')}）' : ''}'),
    if (n.tenderWay.isNotEmpty) (tr('tender.f.tenderWay'), [n.tenderWay, if (n.round.isNotEmpty) n.round].join(' · ')),
    if (n['是否訂有底價'].isNotEmpty) (tr('tender.f.floor'), n.floorPrice ? tr('tender.yes') : tr('tender.no')),
    if (n['是否須繳納押標金'].isNotEmpty) (tr('tender.f.deposit'), n['是否須繳納押標金'].split('\n').first),
    if (n['是否須繳納履約保證金'].isNotEmpty) (tr('tender.f.bond'), n['是否須繳納履約保證金'].split('\n').first),
    if (n['履約期限'].isNotEmpty) (tr('tender.f.period'), n['履約期限']),
    if (n['履約地點'].isNotEmpty) (tr('tender.f.place'), n['履約地點']),
    if (n['後續擴充'].isNotEmpty) (tr('tender.f.followUp'), n.followUp ? tr('tender.yes') : tr('tender.no')),
  ];
}
