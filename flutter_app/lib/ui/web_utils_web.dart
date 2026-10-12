import 'dart:async';
import 'dart:js_interop';

import 'package:web/web.dart' as web;

import '../i18n/i18n.dart';

/// 開啟檔案選擇器，讀取圖片為 data URL（存於瀏覽器）
Future<({String? dataUrl, String? error})> pickImageDataUrl({required int maxBytes}) {
  final done = Completer<({String? dataUrl, String? error})>();
  final input = web.HTMLInputElement()
    ..type = 'file'
    ..accept = 'image/png,image/jpeg,image/svg+xml,image/webp';
  input.onchange = (web.Event _) {
    final file = input.files?.item(0);
    if (file == null) return done.complete((dataUrl: null, error: null));
    if (file.size > maxBytes) {
      return done.complete((dataUrl: null, error: tr('msg.logoTooBig', {'kb': '${maxBytes ~/ 1024}'})));
    }
    final reader = web.FileReader();
    reader.onload = (web.Event _) {
      done.complete((dataUrl: (reader.result as JSString?)?.toDart, error: null));
    }.toJS;
    reader.onerror = (web.Event _) {
      done.complete((dataUrl: null, error: tr('msg.logoRead')));
    }.toJS;
    reader.readAsDataURL(file);
  }.toJS;
  input.click();
  return done.future;
}

void openUrl(String url) => web.window.location.href = url;
