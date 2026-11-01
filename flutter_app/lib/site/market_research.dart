import 'dart:convert';

import '../i18n/i18n.dart';
import '../json_repair.dart';
import 'site_ai.dart' show askUs;
import 'site_init.dart' show numbersIn;
import 'site_planner.dart' show Ask;
import 'site_style.dart';

/// 報價 AI 的「市場行情」：用網路搜尋找這種店一般提供的服務與價格，由本機模型整理成價目表，
/// 再一鍵加到網站建置器的服務與價格列表。價格只採用搜尋結果裡真的出現過的數字（不讓模型編）。

class SearchHit {
  final String title, url, snippet;
  const SearchHit(this.title, this.url, this.snippet);
}

class PriceRow {
  String name, sub, price;
  PriceRow(this.name, this.sub, this.price);
}

class MarketResult {
  final List<PriceRow> rows;
  final List<SearchHit> sources;
  const MarketResult(this.rows, this.sources);
}

String _unescape(String s, {bool keepLines = false}) => s
    .replaceAll(RegExp(r'<[^>]*>'), '')
    .replaceAllMapped(RegExp(r'&#(\d+);'), (m) => String.fromCharCode(int.parse(m[1]!)))
    .replaceAll('&amp;', '&')
    .replaceAll('&quot;', '"')
    .replaceAll('&#39;', "'")
    .replaceAll('&lt;', '<')
    .replaceAll('&gt;', '>')
    .replaceAll('&nbsp;', ' ')
    .replaceAll(RegExp(keepLines ? r'[ \t\r]+' : r'\s+'), ' ')
    .trim();

/// Bing 的結果連結是 bing.com/ck/a?...&u=a1<base64url 的網址>；解出真正的網址
String decodeBingUrl(String href) {
  final h = href.replaceAll('&amp;', '&');
  final u = Uri.tryParse(h)?.queryParameters['u'];
  if (u != null && u.startsWith('a1')) {
    try {
      var b = u.substring(2).replaceAll('-', '+').replaceAll('_', '/');
      while (b.length % 4 != 0) {
        b += '=';
      }
      final url = utf8.decode(base64.decode(b));
      if (url.startsWith('http')) return url;
    } catch (_) {}
  }
  return h;
}

/// Bing 搜尋結果頁 HTML → 結果（標題、網址、摘要）
List<SearchHit> parseBing(String html) {
  final out = <SearchHit>[];
  for (final m in RegExp(r'<li class="b_algo".*?</li>', dotAll: true).allMatches(html)) {
    final b = m[0]!;
    final a = RegExp(r'<h2[^>]*><a[^>]*href="([^"]+)"[^>]*>(.*?)</a>', dotAll: true).firstMatch(b);
    if (a == null) continue;
    final p = RegExp(r'<p[^>]*>(.*?)</p>', dotAll: true).firstMatch(b);
    final url = decodeBingUrl(a[1]!);
    if (!url.startsWith('http')) continue;
    out.add(SearchHit(_unescape(a[2]!), url, p == null ? '' : _unescape(p[1]!)));
  }
  return out;
}

/// 網頁 HTML → 純文字（去掉 script / style / 標籤）
String htmlToText(String html) => _unescape(html.replaceAll(RegExp(r'<(script|style|noscript|svg)[^>]*>.*?</\1>', dotAll: true, caseSensitive: false), ' ').replaceAll(RegExp(r'<(br|/p|/li|/tr|/div|/h\d)[^>]*>', caseSensitive: false), '\n'), keepLines: true);

/// 取出文字裡含價格的片段（數字 + 貨幣字樣附近），其餘丟掉，讓模型的輸入短而有用
String priceExcerpts(String text, {int max = 1800}) {
  final money = RegExp(r'(¥|￥|円|元|NT\$|\$|€|R\$|TWD|JPY|USD|EUR|BRL)\s?\d|\d[\d,]*\s?(円|元|NT|TWD|JPY|USD|EUR|€|reais)', caseSensitive: false);
  final out = StringBuffer();
  for (final line in text.split('\n')) {
    final l = line.trim();
    if (l.length < 4 || !money.hasMatch(l)) continue;
    out.writeln(l.length > 160 ? l.substring(0, 160) : l);
    if (out.length >= max) break;
  }
  return out.toString();
}

/// 百科、字典、社群網站不會有「一般價格」：搜尋結果裡直接略過
bool skipHost(String host) => RegExp(r'wikipedia|wiktionary|baike|dict\.|youtube|facebook|instagram|twitter|x\.com|tiktok|pinterest|vogue|elle\.|zhihu').hasMatch(host.toLowerCase());

const _priceWords = {
  'en': 'prices cost',
  'ja': '料金 相場 メニュー',
  'zh': '價格 價目表',
  'pt': 'preços valores',
  'es': 'precios tarifas',
};

List<String> marketQueries(String business, String area, String lang) {
  final w = _priceWords[lang] ?? _priceWords['en']!;
  final a = area.trim();
  return [
    '$business ${a.isEmpty ? '' : '$a '}$w',
    '$business $w',
  ];
}

Map<String, dynamic> _str(int max) => {'type': 'string', 'maxLength': max};

Map<String, dynamic> marketSchema() => {
      'type': 'object',
      'properties': {
        'rows': {
          'type': 'array',
          'minItems': 3,
          'maxItems': 8,
          'items': {
            'type': 'object',
            'properties': {'name': _str(24), 'sub': _str(28), 'price': _str(20)},
            'required': ['name', 'sub', 'price'],
            'additionalProperties': false,
          },
        },
      },
      'required': ['rows'],
      'additionalProperties': false,
    };

/// 搜尋摘錄 → 價目表。價格裡的數字必須在摘錄裡出現過，否則換成「請洽詢」。
Future<List<PriceRow>> buildPriceTable({required Ask ask, required Lang lang, required String business, required String area, required String evidence}) async {
  final system = '''You build a price list for a small business website from web search excerpts.
Output JSON only. Write ALL text in ${lang.aiName}, except "sub", which is a short English subtitle.
List 4 to 8 services that a typical $business${area.trim().isEmpty ? '' : ' in $area'} offers, each with a typical price taken from the excerpts.
Use a single price or a range exactly as it appears in the excerpts (with its currency). If the excerpts give no price for a service, write "${askUs[lang.name] ?? askUs['en']!}". Never invent a number.
${writingRules(lang)}''';
  final out = await ask(system, 'Business: $business\nArea: ${area.trim().isEmpty ? '(not given)' : area}\nExcerpts:\n$evidence', marketSchema());
  final j = parseLooseJson(out);
  final said = numbersIn(evidence);
  final ask0 = askUs[lang.name] ?? askUs['en']!;
  String pol(Object? v, int max) {
    final t = polishText(lang.name, '${v ?? ''}'.trim());
    return t.length > max ? t.substring(0, max) : t;
  }

  final rows = <PriceRow>[];
  for (final e in (j?['rows'] as List? ?? const [])) {
    if (e is! Map) continue;
    final name = pol(e['name'], 24);
    if (name.isEmpty || RegExp(r'^[\s.…\-–—_?]*$').hasMatch(name)) continue;
    var price = pol(e['price'], 20);
    final nums = numbersIn(price);
    if (price.isEmpty || (nums.isNotEmpty && !nums.every(said.contains))) price = ask0; // 摘錄裡沒有的數字不採用
    var sub = pol(e['sub'], 28);
    if (RegExp(r'\d').hasMatch(sub)) sub = ''; // 副標是英文名稱，不該有數字（小模型會把價格寫進去）
    rows.add(PriceRow(name, RegExp(r'^[\s.…\-–—_?]*$').hasMatch(sub) ? '' : sub, price));
  }
  final seen = <String>{};
  rows.removeWhere((r) => !seen.add(r.name.toLowerCase()));
  return rows;
}

/// 「加到網站」要送給編輯器的動作：服務列表與價格列表各換成這份價目表
List<Map<String, Object?>> siteActionsFor(List<PriceRow> rows) {
  final r = rows.where((x) => x.name.trim().isNotEmpty).take(8).toList();
  String cell(String s) => s.replaceAll(RegExp(r'[|;]'), ' ').trim();
  return [
    if (r.length >= 2) {'action': 'replace_list', 'list': 'services', 'rows': [for (final x in r.take(8)) '${cell(x.name)}|${cell(x.sub)}'].join('; ')},
    if (r.isNotEmpty) {'action': 'replace_list', 'list': 'prices', 'rows': [for (final x in r) '${cell(x.name)}|${cell(x.price)}'].join('; ')},
  ];
}
