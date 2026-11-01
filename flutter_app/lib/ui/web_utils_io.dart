import 'dart:convert';

import 'package:file_selector/file_selector.dart';
import 'package:url_launcher/url_launcher.dart';

import '../i18n/i18n.dart';

/// 桌面版：用系統檔案對話框選圖片，讀成 data URL（存於本機）
Future<({String? dataUrl, String? error})> pickImageDataUrl({required int maxBytes}) async {
  const group = XTypeGroup(label: 'images', extensions: ['png', 'jpg', 'jpeg', 'svg', 'webp']);
  final file = await openFile(acceptedTypeGroups: [group]);
  if (file == null) return (dataUrl: null, error: null);
  final bytes = await file.readAsBytes();
  if (bytes.length > maxBytes) return (dataUrl: null, error: tr('msg.logoTooBig', {'kb': '${maxBytes ~/ 1024}'}));
  final ext = file.name.split('.').last.toLowerCase();
  final mime = switch (ext) {
    'svg' => 'image/svg+xml',
    'jpg' || 'jpeg' => 'image/jpeg',
    'webp' => 'image/webp',
    _ => 'image/png',
  };
  return (dataUrl: 'data:$mime;base64,${base64Encode(bytes)}', error: null);
}

void openUrl(String url) {
  launchUrl(Uri.parse(url));
}
