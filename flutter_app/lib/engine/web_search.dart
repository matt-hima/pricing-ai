import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../site/market_research.dart';

const _ua = 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Safari/605.1.15';

Future<String> _get(Uri url, {String? lang, int maxBytes = 1500000}) async {
  final http = HttpClient()..connectionTimeout = const Duration(seconds: 12);
  try {
    final req = await http.getUrl(url);
    req.headers.set(HttpHeaders.userAgentHeader, _ua);
    if (lang != null) req.headers.set(HttpHeaders.acceptLanguageHeader, lang);
    final res = await req.close().timeout(const Duration(seconds: 15));
    if (res.statusCode != 200) {
      await res.drain<void>();
      throw HttpException('HTTP ${res.statusCode}', uri: url);
    }
    final bytes = <int>[];
    await for (final c in res.timeout(const Duration(seconds: 15))) {
      bytes.addAll(c);
      if (bytes.length > maxBytes) break;
    }
    return utf8.decode(bytes, allowMalformed: true);
  } finally {
    http.close(force: true);
  }
}

/// Bing 網頁搜尋（不需要金鑰；解析結果頁，版面改了可能失效，所以失敗時回傳空清單而不是丟錯）
Future<List<SearchHit>> bingSearch(String query, String lang) async {
  const market = {'ja': 'ja-JP', 'zh': 'zh-TW', 'en': 'en-US', 'pt': 'pt-BR', 'es': 'es-ES'};
  try {
    final html = await _get(Uri.https('www.bing.com', '/search', {'q': query, 'setlang': lang, 'count': '10'}), lang: market[lang]);
    return parseBing(html);
  } catch (_) {
    return const [];
  }
}

/// 抓網頁並轉成純文字；失敗回傳空字串
Future<String> fetchPageText(String url) async {
  try {
    return htmlToText(await _get(Uri.parse(url)));
  } catch (_) {
    return '';
  }
}
