import 'dart:io';

import 'package:path_provider/path_provider.dart';

/// 桌面版：寫到「下載」資料夾（取不到就用文件資料夾）
Future<String> saveZip(String fileName, List<int> bytes) async {
  final dir = await getDownloadsDirectory() ?? await getApplicationDocumentsDirectory();
  final file = File('${dir.path}${Platform.pathSeparator}$fileName');
  await file.writeAsBytes(bytes, flush: true);
  return file.path;
}
