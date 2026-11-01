import 'dart:typed_data';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/foundation.dart';

/// 整合測試用：不跳出存檔對話框，直接交給測試處理
@visibleForTesting
Future<String?> Function(Uint8List bytes, String filename, String mime)? debugSaveBytes;

/// 存檔：桌面版讓使用者選位置（回傳路徑；取消回傳 null），網頁版直接下載（回傳檔名）
Future<String?> saveBytes(Uint8List bytes, String filename, String mime) async {
  if (debugSaveBytes case final f?) return f(bytes, filename, mime);
  final file = XFile.fromData(bytes, mimeType: mime, name: filename);
  if (kIsWeb) {
    await file.saveTo(filename);
    return filename;
  }
  final ext = filename.contains('.') ? filename.split('.').last : '';
  final at = await getSaveLocation(
    suggestedName: filename,
    acceptedTypeGroups: [if (ext.isNotEmpty) XTypeGroup(label: ext.toUpperCase(), extensions: [ext], mimeTypes: [mime])],
  );
  if (at == null) return null;
  await file.saveTo(at.path);
  return at.path;
}

/// 檔名用的日期（2026-11-01）
String fileDate([DateTime? d]) {
  final x = d ?? DateTime.now();
  return '${x.year}-${x.month.toString().padLeft(2, '0')}-${x.day.toString().padLeft(2, '0')}';
}
