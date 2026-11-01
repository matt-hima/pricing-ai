import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

/// 網頁版：以瀏覽器下載。回傳給使用者看的位置說明
Future<String> saveZip(String fileName, List<int> bytes) async {
  final blob = web.Blob([Uint8List.fromList(bytes).toJS].toJS, web.BlobPropertyBag(type: 'application/zip'));
  final url = web.URL.createObjectURL(blob);
  final a = web.HTMLAnchorElement()
    ..href = url
    ..download = fileName;
  a.click();
  web.URL.revokeObjectURL(url);
  return 'Downloaded $fileName';
}
