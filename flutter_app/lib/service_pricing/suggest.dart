import '../i18n/i18n.dart';
import '../json_repair.dart';
import '../site/site_planner.dart' show Ask;
import '../site/site_style.dart';
import 'service_plan.dart';

/// 「どんなサービスを出すか」の案出しだけを AI に任せる（名前と所要時間）。価格は一切出させない：計算は service_plan.dart。
Map<String, dynamic> suggestSchema() => {
      'type': 'object',
      'properties': {
        'services': {
          'type': 'array',
          'minItems': 3,
          'maxItems': 8,
          'items': {
            'type': 'object',
            'properties': {
              'name': {'type': 'string', 'maxLength': 30},
              'minutes': {'type': 'integer', 'minimum': 10, 'maximum': 480},
            },
            'required': ['name', 'minutes'],
            'additionalProperties': false,
          },
        },
      },
      'required': ['services'],
      'additionalProperties': false,
    };

Future<List<ServiceRow>> suggestServices({required Ask ask, required Lang lang, required String business, String area = ''}) async {
  final system = '''You help a small service business plan its menu.
Output JSON only. Write ALL service names in ${lang.aiName}.
List 4 to 7 services that a typical $business${area.trim().isEmpty ? '' : ' in $area'} offers, each with the time one booking takes in minutes (include set-up and clean-up).
Do not write prices or any currency amounts.
${writingRules(lang)}''';
  final j = parseLooseJson(await ask(system, 'Business: $business', suggestSchema()));
  final rows = <ServiceRow>[];
  final seen = <String>{};
  for (final e in (j?['services'] as List? ?? const [])) {
    if (e is! Map) continue;
    final name = polishText(lang.name, '${e['name'] ?? ''}'.trim());
    final minutes = (e['minutes'] as num?)?.toInt() ?? 0;
    if (name.isEmpty || RegExp(r'^[\s.…\-–—_?]*$').hasMatch(name) || RegExp(r'\d{3,}').hasMatch(name)) continue; // 名前に金額のような数字が入ったものは捨てる
    if (!seen.add(name.toLowerCase())) continue;
    rows.add(ServiceRow(name, minutes.clamp(10, 480)));
  }
  return rows;
}
