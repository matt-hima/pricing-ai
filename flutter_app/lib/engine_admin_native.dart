import 'dart:typed_data';

import 'package:shared_preferences/shared_preferences.dart';

import 'engine/catalog.dart';
import 'engine/engine_info.dart';
import 'engine/image_catalog.dart';
import 'engine/image_engine.dart';
import 'engine/local_engine.dart';
import 'engine/memory.dart';

/// 設定頁用的桌面版後端：模型管理、記憶體設定、圖片產生。
const engineAdminAvailable = true;

const _imageModelKey = 'selfquote.image.model';

Future<String> selectedImageModel() async => (await SharedPreferences.getInstance()).getString(_imageModelKey) ?? imageModels.first.id;

Future<void> setSelectedImageModel(String id) async => (await SharedPreferences.getInstance()).setString(_imageModelKey, id);

Future<EngineSnapshot> engineSnapshot() async {
  final mem = await readMemory();
  final text = LocalEngine.instance;
  final installed = await text.installedModels();
  final image = ImageEngine.instance;
  return EngineSnapshot(
    memory: mem == null ? null : MemoryReading(mem.totalMB, mem.availableMB),
    limitPct: await MemorySettings.limitPct(),
    idleMinutes: await MemorySettings.idleMinutes(),
    textRunning: text.running,
    imageSupported: image.supported,
    imageEngineInstalled: await image.engineInstalled,
    textModels: [
      for (final m in modelSpecs.where((m) => m.gpu)) TextModelRow(m.base, m.sizeMB, textNeedMB(m.sizeMB), installed.containsKey(m.base)),
    ],
    imageModels: [
      for (final m in imageModels) ImageModelRow(m.id, m.label, m.license, m.sizeMB, imageNeedMB(m.sizeMB), await image.modelDownloaded(m.id)),
    ],
    imageModelId: await selectedImageModel(),
  );
}

Future<void> setMemoryLimit(int pct) => MemorySettings.setLimitPct(pct);
Future<void> setIdleMinutes(int min) => MemorySettings.setIdleMinutes(min);

Future<void> unloadAll() => LocalEngine.instance.unload();
Future<void> downloadTextModel(String base, void Function(double, String) onProgress) => LocalEngine.instance.downloadModel(base, onProgress);
Future<void> deleteTextModel(String base) => LocalEngine.instance.deleteModel(base);

Future<void> downloadImageEngine(void Function(double, String) onProgress) async {
  await ImageEngine.instance.installEngine(onProgress);
}

Future<void> downloadImageModel(String id, void Function(double, String) onProgress) async {
  final m = imageModelFor(id);
  if (m != null) await ImageEngine.instance.installModel(m, onProgress);
}

Future<void> deleteImageModel(String id) => ImageEngine.instance.deleteModel(id);

/// 依描述產生 JPEG（用目前選的圖片模型）；沒安裝會丟出說明訊息，不會自動下載
Future<Uint8List> generateImage(String description, void Function(double, String) onProgress) async {
  final m = imageModelFor(await selectedImageModel()) ?? imageModels.first;
  return ImageEngine.instance.generate(description, m, onProgress);
}
