/// 設定頁顯示用的資料（不依賴 dart:io，網頁版也能編譯）
class MemoryReading {
  final int totalMB, availableMB;
  const MemoryReading(this.totalMB, this.availableMB);
}

class TextModelRow {
  final String base;
  final int sizeMB, needMB;
  final bool installed;
  const TextModelRow(this.base, this.sizeMB, this.needMB, this.installed);
}

class ImageModelRow {
  final String id, label, license;
  final int sizeMB, needMB;
  final bool installed;
  const ImageModelRow(this.id, this.label, this.license, this.sizeMB, this.needMB, this.installed);
}

class EngineSnapshot {
  final MemoryReading? memory;
  final int limitPct, idleMinutes;
  final bool textRunning, imageSupported, imageEngineInstalled;
  final List<TextModelRow> textModels;
  final List<ImageModelRow> imageModels;
  final String imageModelId;
  const EngineSnapshot({
    required this.memory,
    required this.limitPct,
    required this.idleMinutes,
    required this.textRunning,
    required this.imageSupported,
    required this.imageEngineInstalled,
    required this.textModels,
    required this.imageModels,
    required this.imageModelId,
  });
}

/// 這個模型放不放得進記憶體預算：預算 = 總記憶體 × limitPct%
bool fitsBudget(int needMB, MemoryReading? mem, int limitPct) => mem == null || needMB <= mem.totalMB * limitPct / 100;
