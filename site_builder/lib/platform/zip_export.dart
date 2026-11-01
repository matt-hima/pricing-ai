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

/// 網站的 ZIP：public/index.html + firebase.json + README.txt（html 由 GrapesJS 編輯器產生）
List<int> buildZip(String html) {
  List<int> utf8Bytes(String s) => utf8.encode(s);
  final a = Archive()
    ..addFile(ArchiveFile.bytes('public/index.html', utf8Bytes(html)))
    ..addFile(ArchiveFile.bytes('firebase.json', utf8Bytes(firebaseJson())))
    ..addFile(ArchiveFile.bytes('README.txt', utf8Bytes(_readme())));
  return ZipEncoder().encode(a);
}
