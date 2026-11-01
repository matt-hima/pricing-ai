import 'dart:convert';
import 'dart:io';

/// 桌面版：直接讀取 Google フォームのページ（短縮リンクのリダイレクトも追う）
const canFetchForm = true;

Future<({String html, String url})> fetchFormPage(String url) async {
  final http = HttpClient()..connectionTimeout = const Duration(seconds: 15);
  try {
    var uri = Uri.parse(url.trim());
    for (var i = 0; i < 6; i++) {
      final req = await http.getUrl(uri);
      req.followRedirects = false;
      req.headers.set(HttpHeaders.userAgentHeader, 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Safari/605.1.15');
      req.headers.set(HttpHeaders.acceptLanguageHeader, 'en');
      final res = await req.close().timeout(const Duration(seconds: 20));
      if (res.isRedirect) {
        await res.drain<void>();
        final loc = res.headers.value(HttpHeaders.locationHeader);
        if (loc == null) break;
        uri = uri.resolve(loc);
        continue;
      }
      final body = await res.transform(utf8.decoder).join();
      if (res.statusCode == 404) return (html: '<title>404 not found</title>', url: uri.toString());
      return (html: body, url: uri.toString());
    }
    throw HttpException('Too many redirects', uri: uri);
  } finally {
    http.close(force: true);
  }
}
