import 'dart:typed_data';

import 'engine/engine_info.dart';
import 'i18n/i18n.dart';

/// 網頁版沒有本機模型，設定頁不會出現（改顯示下載桌面版的說明）。
const engineAdminAvailable = false;

Never _no() => throw UnsupportedError(tr('web.noAiMsg'));

Future<String> selectedImageModel() async => '';
Future<void> setSelectedImageModel(String id) async {}
Future<EngineSnapshot> engineSnapshot() async => _no();
Future<void> setMemoryLimit(int pct) async {}
Future<void> setIdleMinutes(int min) async {}
Future<void> unloadAll() async {}
Future<void> downloadTextModel(String base, void Function(double, String) onProgress) async => _no();
Future<void> deleteTextModel(String base) async {}
Future<void> downloadImageEngine(void Function(double, String) onProgress) async => _no();
Future<void> downloadImageModel(String id, void Function(double, String) onProgress) async => _no();
Future<void> deleteImageModel(String id) async {}
Future<Uint8List> generateImage(String description, void Function(double, String) onProgress) async => _no();
