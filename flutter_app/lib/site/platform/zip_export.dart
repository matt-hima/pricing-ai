import 'dart:convert';

import 'package:archive/archive.dart';

String firebaseJson({String? site}) => const JsonEncoder.withIndent('  ').convert({
      'hosting': {
        if (site != null && site.isNotEmpty) 'site': site,
        'public': 'public',
        'ignore': ['firebase.json', '**/.*'],
      },
    });

String _readme() => '''Deploy this site to your own Firebase project:

  npm install -g firebase-tools
  firebase login
  firebase use --add            # pick your Firebase project
  firebase deploy --only hosting

Or upload the contents of the "public" folder to any static web host.
''';

/// 搜尋引擎用的檔案：robots.txt（允許索引；有網址時指向 sitemap）與 sitemap.xml（只有一個頁面）。沒有公開網址就不產生 sitemap。
Map<String, String> seoFiles(String rawUrl) {
  final hasUrl = RegExp(r'^https?://', caseSensitive: false).hasMatch(rawUrl);
  final url = rawUrl.endsWith('/') ? rawUrl : '$rawUrl/';
  return {
    'public/robots.txt': 'User-agent: *\nAllow: /\n${hasUrl ? 'Sitemap: ${url}sitemap.xml\n' : ''}',
    if (hasUrl)
      'public/sitemap.xml': '<?xml version="1.0" encoding="UTF-8"?>\n<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">\n  <url><loc>$url</loc></url>\n</urlset>\n',
  };
}

/// 網站的 ZIP：public/index.html + robots.txt（+ sitemap.xml）+ firebase.json + README.txt（html 由 GrapesJS 編輯器產生）
List<int> buildZip(String html, {String url = ''}) {
  List<int> utf8Bytes(String s) => utf8.encode(s);
  final a = Archive()
    ..addFile(ArchiveFile.bytes('public/index.html', utf8Bytes(html)))
    ..addFile(ArchiveFile.bytes('firebase.json', utf8Bytes(firebaseJson())))
    ..addFile(ArchiveFile.bytes('README.txt', utf8Bytes(_readme())));
  seoFiles(url).forEach((path, text) => a.addFile(ArchiveFile.bytes(path, utf8Bytes(text))));
  return ZipEncoder().encode(a);
}
