import '../i18n/i18n.dart';
import '../json_repair.dart';
import 'site_actions.dart' show regenParts;
import 'site_planner.dart' show Ask;
import 'site_style.dart';

/// 「重新產生」：只重寫頁面的某一部分（標題 / 服務 / 常見問題 / 流程圖），其餘維持不動。
/// 模型只寫該部分的文字（schema 限制欄位與長度）；寫進頁面的是編輯器動作（set_text / replace_list / set_flow）。
const _partHelp = {
  'headline': 'the hero headline (h1), the second headline (h2), the lead sentence and the booking button text',
  'services': 'the 4 services (name and short English subtitle)',
  'faq': 'the 3 or 4 frequently asked questions with short answers',
  'booking_flow': 'the 3 to 6 steps a customer follows to book online',
  'service_flow': 'the 3 to 6 steps of what happens when the customer visits',
};

Map<String, dynamic> _str(int max) => {'type': 'string', 'maxLength': max};

Map<String, dynamic> regenSchema(String part) => switch (part) {
      'headline' => {
          'type': 'object',
          'properties': {'h1': _str(60), 'h2': _str(80), 'lead': _str(120), 'cta': _str(24)},
          'required': ['h1', 'h2', 'lead', 'cta'],
          'additionalProperties': false,
        },
      'services' => {
          'type': 'object',
          'properties': {
            'services': {
              'type': 'array',
              'minItems': 4,
              'maxItems': 4,
              'items': {
                'type': 'object',
                'properties': {'name': _str(24), 'sub': _str(28)},
                'required': ['name', 'sub'],
                'additionalProperties': false,
              },
            },
          },
          'required': ['services'],
          'additionalProperties': false,
        },
      'faq' => {
          'type': 'object',
          'properties': {
            'faq': {
              'type': 'array',
              'minItems': 3,
              'maxItems': 4,
              'items': {
                'type': 'object',
                'properties': {'q': _str(60), 'a': _str(120)},
                'required': ['q', 'a'],
                'additionalProperties': false,
              },
            },
          },
          'required': ['faq'],
          'additionalProperties': false,
        },
      _ => {
          'type': 'object',
          'properties': {
            'steps': {'type': 'array', 'minItems': 3, 'maxItems': 6, 'items': _str(28)},
          },
          'required': ['steps'],
          'additionalProperties': false,
        },
    };

/// 重新產生某一部分，回傳要交給編輯器執行的動作；模型沒給出可用內容時回傳空清單
Future<List<Map<String, Object?>>> regenerateActions({
  required Ask ask,
  required Lang siteLang,
  required Map<String, dynamic> snapshot,
  required String part,
  String hint = '',
}) async {
  if (!regenParts.contains(part)) return const [];
  final brand = '${snapshot['brand'] ?? ''}', h1 = '${snapshot['h1'] ?? ''}', lead = '${snapshot['lead'] ?? ''}';
  final services = [for (final r in (snapshot['services'] as List? ?? const [])) '${(r as List).first}'].join(', ');
  final system = '''You rewrite one part of a small business's booking website.
Output JSON only. Write ALL text in ${siteLang.aiName}, except "sub" fields, which are short English subtitles.
Write ${_partHelp[part]}. Do not invent prices, phone numbers, email addresses or opening hours.
${writingRules(siteLang)}''';
  final user = 'Business: $brand. ${h1.replaceAll('\n', ' ')} $lead\nServices: $services\n${hint.isEmpty ? '' : 'Owner wishes: $hint\n'}Write a new version of: ${_partHelp[part]}.';
  final j = parseLooseJson(await ask(system, user, regenSchema(part)));
  if (j == null) return const [];
  String pol(Object? v, int max) {
    final t = polishText(siteLang.name, '${v ?? ''}'.trim());
    return t.length > max ? t.substring(0, max) : t;
  }

  bool ok(String s) => s.isNotEmpty && !RegExp(r'^[\s.…\-–—_?]*$').hasMatch(s);
  final out = <Map<String, Object?>>[];
  switch (part) {
    case 'headline':
      for (final k in const ['h1', 'h2', 'lead', 'cta']) {
        final t = pol(j[k], k == 'h1' ? 60 : 120);
        if (ok(t)) out.add({'action': 'set_text', 'target': k, 'text': t});
      }
    case 'services':
      final rows = [
        for (final e in (j['services'] as List? ?? const []))
          if (e is Map && ok(pol(e['name'], 24))) '${pol(e['name'], 24)}|${pol(e['sub'], 28)}',
      ];
      if (rows.length >= 2) out.add({'action': 'replace_list', 'list': 'services', 'rows': rows.join('; ')});
    case 'faq':
      final rows = [
        for (final e in (j['faq'] as List? ?? const []))
          if (e is Map && ok(pol(e['q'], 60)) && ok(pol(e['a'], 120))) '${pol(e['q'], 60).replaceAll(RegExp(r'[|;]'), ' ')}|${pol(e['a'], 120).replaceAll(RegExp(r'[|;]'), ' ')}',
      ];
      if (rows.length >= 2) out.add({'action': 'replace_list', 'list': 'faq', 'rows': rows.join('; ')});
    default:
      final steps = [for (final s in (j['steps'] as List? ?? const [])) pol(s, 28)].where(ok).toList();
      if (steps.length >= 3) out.add({'action': 'set_flow', 'which': part == 'booking_flow' ? 'booking' : 'service', 'steps': steps.join('; ')});
  }
  return out;
}
