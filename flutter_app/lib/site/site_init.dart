import '../i18n/i18n.dart';
import 'site_ai.dart';
import 'site_industry.dart';
import 'site_planner.dart' show Ask;

/// 「從聊天開始」：屋主用幾句話描述店家，本機模型寫出整頁文字。
/// 輸出用 JSON schema 限制（欄位、列數、長度都固定），再經過文案規則整理（site_style.dart）。

Map<String, dynamic> _str(int max) => {'type': 'string', 'maxLength': max};

Map<String, dynamic> _rows(int min, int max, String a, int maxA, String b, int maxB) => {
      'type': 'array',
      'minItems': min,
      'maxItems': max,
      'items': {
        'type': 'object',
        'properties': {a: _str(maxA), b: _str(maxB)},
        'required': [a, b],
        'additionalProperties': false,
      },
    };

/// 與 [siteSystemPrompt] 範例的格式一致：4 個服務、3–5 個價格、3 列營業時間
Map<String, dynamic> siteContentSchema() => {
      'type': 'object',
      'properties': {
        'industry': {'enum': industryIds},
        'brand': _str(24),
        'brandSub': _str(28),
        'h1': _str(60),
        'h2': _str(80),
        'lead': _str(120),
        'cta': _str(24),
        'services': _rows(4, 4, 'name', 24, 'sub', 28),
        'prices': _rows(3, 5, 'item', 40, 'price', 20),
        'hours': _rows(3, 3, 'day', 24, 'time', 24),
        'address': _str(80),
      },
      'required': ['industry', 'brand', 'brandSub', 'h1', 'h2', 'lead', 'cta', 'services', 'prices', 'hours', 'address'],
      'additionalProperties': false,
    };

/// 描述裡出現過的數字（4,500 / 4500 / ４５００ 都算同一個）
Set<int> numbersIn(String text) {
  final half = text.replaceAllMapped(RegExp(r'[０-９]'), (m) => String.fromCharCode(m[0]!.codeUnitAt(0) - 0xFEE0));
  return {for (final m in RegExp(r'\d[\d,]*').allMatches(half)) if (int.tryParse(m[0]!.replaceAll(',', '')) != null) int.parse(m[0]!.replaceAll(',', ''))};
}

/// 價格只能用屋主自己說過的數字：模型寫的價格若含有描述裡沒有的數字，換成「請洽詢」（不讓模型編價格）。
/// 回傳被換掉的列數。
int groundPrices(Map<String, Object?> content, String description, String langCode) {
  final said = numbersIn(description);
  final rows = content['price'];
  if (rows is! List) return 0;
  final ask = askUs[langCode] ?? askUs['en']!;
  var replaced = 0;
  for (final r in rows) {
    if (r is! List || r.length < 2) continue;
    final nums = numbersIn('${r[1]}');
    if (nums.isNotEmpty && !nums.every(said.contains)) {
      r[1] = ask;
      replaced++;
    }
  }
  return replaced;
}

const _closedWords = ['休', 'closed', 'cerrado', 'fechado', '不營業', '公休', 'holiday', 'day off'];

/// 營業時間也不讓模型編：時間（HH:MM）裡的小時或分鐘若是描述裡沒出現過的數字，這一列的時間換成「請洽詢」。
/// 回傳被換掉的列數。
int groundHours(Map<String, Object?> content, String description, String langCode) {
  final said = numbersIn(description);
  final rows = content['hours'];
  if (rows is! List) return 0;
  final ask = askUs[langCode] ?? askUs['en']!;
  var replaced = 0;
  for (final r in rows) {
    if (r is! List || r.length < 2) continue;
    final times = RegExp(r'(\d{1,2}):(\d{2})').allMatches('${r[1]}').toList();
    if (times.isEmpty) {
      // 「休業」「Closed」：屋主完全沒提過休息日就是模型編的
      final closedRow = _closedWords.any('${r[1]}'.toLowerCase().contains);
      if (closedRow && !_closedWords.any(description.toLowerCase().contains)) {
        r[1] = ask;
        replaced++;
      }
      continue;
    }
    final ok = times.every((m) {
      final h = int.parse(m[1]!), mi = int.parse(m[2]!);
      return said.contains(h) && (mi == 0 || said.contains(mi));
    });
    if (!ok) {
      r[1] = ask;
      replaced++;
    }
  }
  return replaced;
}

String _norm(Object? v) => '${v ?? ''}'.replaceAll(RegExp(r'\s+'), '');

/// 模型是不是直接抄了提示詞裡的範例（店名或主標題與範例相同）
bool copiedExample(Map<String, Object?> content, Lang lang) {
  for (final alt in const [false, true]) {
    final ex = siteExample(lang, alt: alt);
    final brand = _norm(content['brand']), h1 = _norm(content['h1']);
    if (brand.isNotEmpty && (brand == _norm(ex['brand']) || (h1.isNotEmpty && h1 == _norm(ex['h1'])))) return true;
  }
  return false;
}

/// 由描述產生要套用到範本的欄位（與 assets/editor/blocks.js 的字典同名，另含 'industry'）；模型沒給出可用內容時回傳 null。
/// 先用關鍵字判斷業種，把該業種的常見需求寫進提示詞；模型自己判斷的業種若不是 other 就以模型為準。
Future<Map<String, Object?>?> generateSiteContent({required Ask ask, required Lang siteLang, required String description}) async {
  final guess = detectIndustry(description);
  final needs = industryNeeds[guess];
  final alt = guess == 'salon'; // 範例和實際業種相同時，模型會整份照抄，所以換另一份範例
  final system = '${siteSystemPrompt(siteLang, alt: alt)}${needs == null ? '' : '\nThis business looks like $needs Write the services, prices and hours so they fit this kind of business.'}';
  var out = await ask(system, description, siteContentSchema());
  var o = siteOverrides(out, lang: siteLang.name);
  // 小模型常常整份抄範例：發現就提醒一次再問
  if (o != null && copiedExample(o, siteLang)) {
    final ex = siteExample(siteLang, alt: alt);
    out = await ask(
      system,
      '$description\n\nIMPORTANT: your last answer copied the format example ("${ex['brand']}"). Write the page for the business described above. Use its own name, services and wording.',
      siteContentSchema(),
    );
    o = siteOverrides(out, lang: siteLang.name);
    if (o != null && copiedExample(o, siteLang)) {
      for (final k in const ['brand', 'brandSub', 'h1', 'h2', 'lead', 'cta']) {
        o.remove(k); // 還是抄：寧可不改，也不要放上別家店的名字
      }
    }
  }
  if (o == null) return null;
  final modelPick = '${o['industry'] ?? 'other'}';
  o['industry'] = modelPick != 'other' ? modelPick : guess;
  groundPrices(o, description, siteLang.name);
  groundHours(o, description, siteLang.name);
  final steps = industryServiceSteps('${o['industry']}', siteLang.name);
  if (steps != null) o['serviceSteps'] = steps;
  return o;
}
