import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:image/image.dart' as img;

import '../i18n/i18n.dart';
import 'catalog.dart';
import 'downloader.dart';
import 'image_catalog.dart';
import 'installer.dart';
import 'local_engine.dart';
import 'memory.dart';

/// 圖片產生：呼叫 stable-diffusion.cpp 的 sd-cli（macOS 走 Metal、Windows 走 Vulkan）。
/// 每次產生是一個獨立的子程序：跑完就結束、記憶體立刻還給系統；執行前先把文字模型卸載（一次只跑一個大型引擎）。
class ImageEngine {
  ImageEngine(this.text);
  static final instance = ImageEngine(LocalEngine.instance);

  final LocalEngine text;
  Process? _proc;

  Future<Directory> get _dir async => Directory('${(await text.root()).path}/sd-cpp-$sdCppTag');
  Future<Directory> get _modelDir async => Directory('${(await text.root()).path}/image-models');

  Future<bool> get engineInstalled async => await findSdBinary(await _dir) != null;

  Future<File> _modelFile(ImageModelSpec m) async => File('${(await _modelDir).path}/${m.file}');

  Future<bool> modelDownloaded(String id) async {
    final m = imageModelFor(id);
    if (m == null) return false;
    final f = await _modelFile(m);
    return await f.exists() && await f.length() > m.sizeMB * 1024 * 1024 * 0.9;
  }

  Future<void> deleteModel(String id) async {
    final m = imageModelFor(id);
    if (m == null) return;
    final f = await _modelFile(m);
    if (await f.exists()) await f.delete();
  }

  /// 這台電腦能不能跑圖片引擎（macOS 只有 Apple Silicon）
  bool get supported => sdAssetFor(isMac: Platform.isMacOS, isWindows: Platform.isWindows, version: Platform.version) != null;

  /// 下載引擎（約 30 MB）。只在使用者按下「下載」時呼叫。
  Future<File> installEngine(Progress onProgress) async {
    final dir = await _dir;
    final have = await findSdBinary(dir);
    if (have != null) return have;
    final asset = sdAssetFor(isMac: Platform.isMacOS, isWindows: Platform.isWindows, version: Platform.version);
    if (asset == null) throw UnsupportedError(tr('img.unsupported'));
    final archive = File('${(await text.root()).path}/downloads/${asset.name}');
    await downloadFile(asset.url, archive, (got, total) {
      final pct = total > 0 ? got / total : 0.0;
      onProgress(pct, tr('img.dlEngine', {'pct': (pct * 100).round().toString()}));
    });
    await extractEngine(archive, ArchiveKind.zip, dir);
    await archive.delete().catchError((_) => archive);
    final bin = await findSdBinary(dir);
    if (bin == null) throw StateError('sd-cli not found in ${asset.name}');
    await makeExecutable(bin);
    if (Platform.isMacOS) await Process.run('xattr', ['-dr', 'com.apple.quarantine', dir.path]);
    return bin;
  }

  Future<File> installModel(ImageModelSpec m, Progress onProgress) async {
    final f = await _modelFile(m);
    if (await modelDownloaded(m.id)) return f;
    await downloadFile(m.url, f, (got, total) {
      final totalMb = total > 0 ? total / 1048576 : m.sizeMB.toDouble();
      final pct = (got / 1048576 / totalMb).clamp(0.0, 1.0);
      onProgress(pct, tr('img.dlModel', {'done': (got / 1048576).round().toString(), 'total': totalMb.round().toString(), 'pct': (pct * 100).round().toString()}));
    });
    return f;
  }

  /// 依描述產生一張圖，回傳 JPEG 位元組。已安裝才會執行（不在這裡自動下載大檔）。
  Future<Uint8List> generate(String description, ImageModelSpec m, Progress onProgress, {int? seed}) {
    return heavyLock.run(() async {
      final bin = await findSdBinary(await _dir);
      if (bin == null || !await modelDownloaded(m.id)) throw StateError(tr('img.notInstalled'));
      final mem = await readMemory();
      final limit = await MemorySettings.limitPct();
      if (mem != null && memVerdict(needMB: imageNeedMB(m.sizeMB), mem: mem, limitPct: limit) == MemVerdict.tooBig) {
        throw StateError(tr('mem.tooBigImage', {'need': '${(imageNeedMB(m.sizeMB) / 1024).toStringAsFixed(1)}', 'budget': '${(mem.totalMB * limit / 100 / 1024).toStringAsFixed(1)}'}));
      }
      onProgress(0, tr('img.freeing'));
      await text.stop(); // 先把文字模型卸載，騰出記憶體
      final out = File('${(await text.root()).path}/tmp/image-${DateTime.now().millisecondsSinceEpoch}.png');
      await out.parent.create(recursive: true);
      final args = [
        '-m', (await _modelFile(m)).path,
        '-p', imagePrompt(description),
        '-n', imageNegative,
        '-o', out.path,
        '-W', '${m.width}',
        '-H', '${m.height}',
        '--steps', '${m.steps}',
        '--cfg-scale', '${m.cfg}',
        '-s', '${seed ?? Random().nextInt(1 << 30)}',
        '--vae-tiling',
      ];
      final proc = await Process.start(bin.path, args, workingDirectory: bin.parent.path);
      _proc = proc;
      final tail = <String>[];
      final stepRe = RegExp(r'(\d+)/(\d+)\s*-\s*[\d.]+\s*s/it|\|\s*(\d+)/(\d+)');
      void watch(Stream<List<int>> s) => s.listen((chunk) {
            final line = String.fromCharCodes(chunk);
            tail.add(line);
            if (tail.length > 30) tail.removeAt(0);
            final mm = stepRe.allMatches(line).lastOrNull;
            if (mm != null) {
              final a = int.tryParse(mm[1] ?? mm[3] ?? ''), b = int.tryParse(mm[2] ?? mm[4] ?? '');
              if (a != null && b != null && b > 0) onProgress((a / b).clamp(0.0, 1.0), tr('img.step', {'a': '$a', 'b': '$b'}));
            }
          });
      watch(proc.stdout);
      watch(proc.stderr);
      final code = await proc.exitCode.timeout(const Duration(minutes: 20), onTimeout: () {
        proc.kill(ProcessSignal.sigkill);
        return -1;
      });
      _proc = null;
      if (code != 0 || !await out.exists()) {
        throw StateError(tr('img.failed', {'e': tail.reversed.take(3).toList().reversed.join(' ').trim()}));
      }
      try {
        return toJpeg(await out.readAsBytes());
      } finally {
        unawaited(out.delete().catchError((_) => out));
      }
    });
  }

  void cancel() => _proc?.kill();
}

/// PNG → JPEG（品質 85）：放進網站頁面時小很多（約 1/8）
Uint8List toJpeg(Uint8List png) {
  final decoded = img.decodeImage(png);
  if (decoded == null) throw StateError('The generated image could not be read');
  return Uint8List.fromList(img.encodeJpg(decoded, quality: 85));
}
