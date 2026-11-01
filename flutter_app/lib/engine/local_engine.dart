import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../i18n/i18n.dart';
import 'catalog.dart';
import 'downloader.dart';
import 'installer.dart';
import 'llama_client.dart';
import 'memory.dart';

typedef Progress = void Function(double progress, String text);

/// 桌面版本機 AI：下載 llama.cpp 官方 llama-server 與 GGUF 模型到使用者資料夾，
/// 以子程序執行（macOS 走 Metal、Windows 走 Vulkan，使用本機 GPU），透過 localhost HTTP 對話。
class LocalEngine {
  LocalEngine({Directory? root}) : _rootOverride = root;
  static final instance = LocalEngine();

  final Directory? _rootOverride;
  Process? _proc;
  LlamaClient? _client;
  String? _runningKey;
  final _stderrTail = <String>[];
  Future<void>? _preparing;
  AppLifecycleListener? _lifecycle;

  /// 使用者選的存放位置（例如外接硬碟上的資料夾）存在這個偏好設定；沒設就用應用程式資料夾
  static const storageKey = 'selfquote.engine.storage';
  static const _sub = 'pricing-ai-engine';

  Future<String?> customStorage() async {
    final v = (await SharedPreferences.getInstance()).getString(storageKey);
    return v == null || v.isEmpty ? null : v;
  }

  /// 設定存放位置（null = 回到預設）。會先停掉執行中的引擎；已下載的檔案不會搬移。
  Future<void> setCustomStorage(String? path) async {
    await stop();
    final prefs = await SharedPreferences.getInstance();
    if (path == null || path.isEmpty) {
      await prefs.remove(storageKey);
    } else {
      await prefs.setString(storageKey, path);
    }
  }

  Future<Directory> root() async {
    final o = _rootOverride;
    if (o != null) return o;
    final custom = await customStorage();
    if (custom != null) return Directory('$custom${Platform.pathSeparator}$_sub');
    return Directory('${(await getApplicationSupportDirectory()).path}${Platform.pathSeparator}$_sub');
  }

  /// 自訂位置所在的資料夾（或外接硬碟）不見了就丟出明確的錯誤，而不是在 /Volumes 底下亂建資料夾
  Future<void> _checkStorage() async {
    if (_rootOverride != null) return;
    final custom = await customStorage();
    if (custom != null && !await Directory(custom).exists()) throw StateError(tr('eng.storageMissing'));
  }

  Future<Directory> get _engineDir async => Directory('${(await root()).path}/engine-$llamaCppTag');
  Future<Directory> get _modelDir async => Directory('${(await root()).path}/models');

  /// 引擎最近的輸出（除錯 / 確認是否使用 GPU）
  String get log => _stderrTail.join('\n');

  bool get running => _proc != null && _client != null;

  /// 引擎（llama-server）是否已安裝
  Future<bool> get engineInstalled async => await findServerBinary(await _engineDir) != null;

  Future<bool> modelDownloaded(String base) async {
    final spec = modelSpecFor(base);
    if (spec == null) return false;
    final f = File('${(await _modelDir).path}/${spec.file}');
    return await f.exists() && await f.length() > spec.sizeMB * 1024 * 1024 * 0.9;
  }

  /// 確保引擎 + 模型都在、伺服器已用這個模型啟動。同時多次呼叫會共用同一次準備。
  Future<void> prepare(String base, Progress onProgress) {
    final p = _preparing;
    if (p != null) return p;
    return _preparing = _prepare(base, onProgress).whenComplete(() => _preparing = null);
  }

  Future<void> _prepare(String base, Progress onProgress) async {
    final spec = modelSpecFor(base);
    if (spec == null) throw StateError('Unknown model: $base');
    _lifecycle ??= AppLifecycleListener(onDetach: stop);
    await _checkStorage();

    final key = '${spec.file}|${spec.gpu}';
    if (_runningKey == key && running && await _client!.healthy()) return;
    await stop();
    await killStale();

    await _checkMemory(spec); // 先檢查記憶體：放不下就不必先下載幾 GB 的檔案
    final bin = await _ensureEngine(onProgress);
    final model = await _ensureModel(spec, onProgress);
    onProgress(1, tr(spec.gpu ? 'eng.startGpu' : 'eng.startCpu'));
    await _start(bin, model, spec);
    _runningKey = key;
    _touch();
  }

  /// 記憶體預算（設定頁可調）：模型需要的記憶體超過預算就不載入，並說明可以怎麼辦
  Future<void> _checkMemory(ModelSpec spec) async {
    final mem = await readMemory();
    if (mem == null) return;
    final limit = await MemorySettings.limitPct();
    final need = textNeedMB(spec.sizeMB);
    if (memVerdict(needMB: need, mem: mem, limitPct: limit) == MemVerdict.tooBig) {
      throw StateError(tr('mem.tooBig', {'need': (need / 1024).toStringAsFixed(1), 'budget': (mem.totalMB * limit / 100 / 1024).toStringAsFixed(1), 'pct': '$limit'}));
    }
  }

  // ---- 閒置自動卸載：最後一次使用後超過設定的分鐘數就關掉 llama-server，把記憶體還給系統 ----
  DateTime _lastUsed = DateTime.now();
  Timer? _idle;

  void _touch() {
    _lastUsed = DateTime.now();
    _idle ??= Timer.periodic(const Duration(seconds: 30), (_) async {
      if (!running) return;
      final min = await MemorySettings.idleMinutes();
      if (min > 0 && DateTime.now().difference(_lastUsed) >= Duration(minutes: min)) await stop();
    });
  }

  /// 已下載的文字模型檔（base → 檔案大小 MB）
  Future<Map<String, int>> installedModels() async {
    final out = <String, int>{};
    for (final m in modelSpecs) {
      final f = File('${(await _modelDir).path}/${m.file}');
      if (await f.exists() && await f.length() > m.sizeMB * 1024 * 1024 * 0.9) out[m.base] = (await f.length()) ~/ 1048576;
    }
    return out;
  }

  /// 使用者在設定頁按下「下載」時才會呼叫（不會自動下載）
  Future<void> downloadModel(String base, Progress onProgress) async {
    final spec = modelSpecFor(base);
    if (spec == null) throw StateError('Unknown model: $base');
    await _checkStorage();
    await _ensureModel(spec, onProgress);
  }

  /// 刪除模型檔（同一個檔案可能對應 GPU 版與 CPU 版，所以以檔名為準）；使用中的先卸載
  Future<void> deleteModel(String base) async {
    final spec = modelSpecFor(base);
    if (spec == null) return;
    if (_runningKey?.startsWith('${spec.file}|') ?? false) await stop();
    final f = File('${(await _modelDir).path}/${spec.file}');
    if (await f.exists()) await f.delete();
  }

  Future<File> _ensureEngine(Progress onProgress) async {
    final dir = await _engineDir;
    final existing = await findServerBinary(dir);
    if (existing != null) return existing;

    final asset = engineAssetFor(isMac: Platform.isMacOS, isWindows: Platform.isWindows, version: Platform.version);
    if (asset == null) throw UnsupportedError(tr('eng.unsupported'));
    final archive = File('${(await root()).path}/downloads/${asset.name}');
    await downloadFile(asset.url, archive, (got, total) {
      final pct = total > 0 ? got / total : 0.0;
      onProgress(pct, tr('eng.dlEngine', {'pct': (pct * 100).round().toString()}));
    });
    onProgress(1, tr('eng.unpack'));
    await extractEngine(archive, asset.kind, dir);
    await archive.delete().catchError((_) => archive);
    final bin = await findServerBinary(dir);
    if (bin == null) throw StateError('llama-server not found in ${asset.name}');
    await makeExecutable(bin);
    if (Platform.isMacOS) await Process.run('xattr', ['-dr', 'com.apple.quarantine', dir.path]);
    return bin;
  }

  Future<File> _ensureModel(ModelSpec spec, Progress onProgress) async {
    final f = File('${(await _modelDir).path}/${spec.file}');
    if (await modelDownloaded(spec.base)) return f;
    await downloadFile(spec.url, f, (got, total) {
      final totalMb = total > 0 ? total / 1048576 : spec.sizeMB.toDouble();
      final pct = (got / 1048576 / totalMb).clamp(0.0, 1.0);
      onProgress(pct, tr('eng.dlModel', {
        'done': (got / 1048576).round().toString(),
        'total': totalMb.round().toString(),
        'pct': (pct * 100).round().toString(),
      }));
    });
    return f;
  }

  Future<int> _freePort() async {
    final s = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    final p = s.port;
    await s.close();
    return p;
  }

  Future<void> _start(File bin, File model, ModelSpec spec) async {
    final port = await _freePort();
    final args = ['-m', model.path, '--host', '127.0.0.1', '--port', '$port', '-c', '8192', '-ngl', spec.gpu ? '99' : '0'];
    _stderrTail.clear();
    final proc = await Process.start(bin.path, args, workingDirectory: bin.parent.path);
    _proc = proc;
    unawaited(_writePid(proc.pid));
    void tail(Stream<List<int>> s) => s.transform(utf8.decoder).transform(const LineSplitter()).listen((l) {
          _stderrTail.add(l);
          if (_stderrTail.length > 40) _stderrTail.removeAt(0);
        });
    tail(proc.stderr);
    tail(proc.stdout);
    var exited = false;
    unawaited(proc.exitCode.then((_) => exited = true));

    final client = LlamaClient(Uri.parse('http://127.0.0.1:$port'));
    final deadline = DateTime.now().add(const Duration(minutes: 4));
    while (DateTime.now().isBefore(deadline)) {
      if (exited) {
        _proc = null;
        throw StateError(tr('eng.exited', {'e': _stderrTail.reversed.take(6).toList().reversed.join(' | ')}));
      }
      if (await client.healthy()) {
        _client = client;
        return;
      }
      await Future<void>.delayed(const Duration(milliseconds: 400));
    }
    await stop();
    throw TimeoutException(tr('eng.timeout'));
  }

  Future<File> get _pidFile async => File('${(await root()).path}/server.pid');

  Future<void> _writePid(int pid) async {
    try {
      final f = await _pidFile;
      await f.parent.create(recursive: true);
      await f.writeAsString('$pid');
    } catch (_) {}
  }

  /// 上一次程式被強制結束（當機、測試被中斷）時，llama-server 會變成孤兒繼續佔記憶體：
  /// 啟動前依 pid 檔把它找出來關掉。只關名稱確實是 llama-server 的程序，避免 pid 被別的程式重用而誤殺。
  @visibleForTesting
  Future<void> killStale() async {
    try {
      final f = await _pidFile;
      if (!await f.exists()) return;
      final pid = int.tryParse((await f.readAsString()).trim());
      await f.delete();
      if (pid == null || pid <= 0) return;
      if (Platform.isWindows) {
        final r = await Process.run('tasklist', ['/FI', 'PID eq $pid', '/FO', 'CSV', '/NH']);
        if ('${r.stdout}'.toLowerCase().contains('llama-server')) await Process.run('taskkill', ['/PID', '$pid', '/F']);
      } else {
        final r = await Process.run('ps', ['-p', '$pid', '-o', 'comm=']);
        if ('${r.stdout}'.contains('llama-server')) Process.killPid(pid, ProcessSignal.sigkill);
      }
    } catch (_) {}
  }

  /// 問模型；回傳完整文字
  Future<String> chat(String system, String user, {bool json = true, int maxTokens = 3072, Map<String, dynamic>? schema, void Function(int tokens)? onToken}) async {
    final c = _client;
    if (c == null) throw StateError('Local AI is not loaded');
    _touch();
    return c.chat(system, user, json: json, maxTokens: maxTokens, schema: schema, onToken: onToken);
  }

  /// 立刻卸載（設定頁的「現在釋放記憶體」）
  Future<void> unload() => stop();

  Future<void> stop() async {
    final p = _proc;
    _proc = null;
    _client = null;
    _runningKey = null;
    if (p == null) return;
    unawaited(_pidFile.then((f) => f.delete()).catchError((_) => File('')));
    p.kill();
    await p.exitCode.timeout(const Duration(seconds: 5), onTimeout: () {
      p.kill(ProcessSignal.sigkill);
      return -1;
    });
  }
}
