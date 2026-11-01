import 'dart:async';
import 'dart:io';

import 'package:shared_preferences/shared_preferences.dart';

/// 記憶體管理：本機模型（文字 / 圖片）都很吃記憶體，同時載入會讓整台電腦變慢甚至當機。
/// 規則：一次只載入一個大型引擎；載入前先檢查預算（使用者設定的「AI 最多可用記憶體 %」）；閒置一段時間自動卸載。

class MemInfo {
  final int totalMB, availableMB;
  const MemInfo(this.totalMB, this.availableMB);
}

/// macOS `vm_stat` 輸出 → 可立即使用的 MB（free + inactive + speculative + purgeable）
int? parseVmStatAvailableMB(String out) {
  final page = int.tryParse(RegExp(r'page size of (\d+) bytes').firstMatch(out)?[1] ?? '');
  if (page == null) return null;
  var pages = 0;
  for (final k in const ['Pages free', 'Pages inactive', 'Pages speculative', 'Pages purgeable']) {
    pages += int.tryParse(RegExp('$k:\\s+(\\d+)').firstMatch(out)?[1] ?? '') ?? 0;
  }
  return (pages * page / 1048576).round();
}

/// Windows `Get-CimInstance Win32_OperatingSystem` 的「總量 空閒」（KB，空白分隔）→ MemInfo
MemInfo? parseWindowsMem(String out) {
  final m = RegExp(r'(\d+)\s+(\d+)').firstMatch(out.trim());
  if (m == null) return null;
  return MemInfo((int.parse(m[1]!) / 1024).round(), (int.parse(m[2]!) / 1024).round());
}

Future<MemInfo?> readMemory() async {
  try {
    if (Platform.isMacOS) {
      final total = int.tryParse('${(await Process.run('sysctl', ['-n', 'hw.memsize'])).stdout}'.trim());
      final avail = parseVmStatAvailableMB('${(await Process.run('vm_stat', [])).stdout}');
      if (total == null) return null;
      return MemInfo((total / 1048576).round(), avail ?? 0);
    }
    if (Platform.isWindows) {
      final r = await Process.run('powershell', [
        '-NoProfile',
        '-Command',
        r'$o=Get-CimInstance Win32_OperatingSystem; "$($o.TotalVisibleMemorySize) $($o.FreePhysicalMemory)"',
      ]);
      return parseWindowsMem('${r.stdout}');
    }
  } catch (_) {}
  return null;
}

enum MemVerdict { fits, tight, tooBig }

/// 預算 = 總記憶體 × limitPct%。需要量超過預算 → tooBig（不載入）；超過目前可用量 → tight（可以載入，但會提醒）。
MemVerdict memVerdict({required int needMB, required MemInfo mem, required int limitPct}) {
  final budget = mem.totalMB * limitPct / 100;
  if (needMB > budget) return MemVerdict.tooBig;
  if (mem.availableMB > 0 && needMB > mem.availableMB) return MemVerdict.tight;
  return MemVerdict.fits;
}

/// 文字模型載入後大約佔用的記憶體（權重 + KV cache + 執行時）
int textNeedMB(int fileMB) => (fileMB * 1.15).round() + 500;

/// 圖片模型（stable-diffusion.cpp）：權重 + 文字編碼器 / VAE / 暫存
int imageNeedMB(int fileMB) => (fileMB * 1.2).round() + 900;

/// 設定值（偏好設定）：記憶體上限 % 與閒置自動卸載分鐘數
class MemorySettings {
  static const limitKey = 'selfquote.mem.limitPct';
  static const idleKey = 'selfquote.mem.idleMin';
  static const defaultLimitPct = 75;
  static const defaultIdleMin = 10;

  static Future<int> limitPct() async => ((await SharedPreferences.getInstance()).getInt(limitKey) ?? defaultLimitPct).clamp(30, 95);
  static Future<int> idleMinutes() async => ((await SharedPreferences.getInstance()).getInt(idleKey) ?? defaultIdleMin).clamp(0, 240);

  static Future<void> setLimitPct(int v) async => (await SharedPreferences.getInstance()).setInt(limitKey, v.clamp(30, 95));
  static Future<void> setIdleMinutes(int v) async => (await SharedPreferences.getInstance()).setInt(idleKey, v.clamp(0, 240));
}

/// 一次只讓一個大型引擎工作：文字模型與圖片模型共用。後來的呼叫排隊等前一個結束。
class HeavyLock {
  Future<void> _tail = Future.value();

  Future<T> run<T>(Future<T> Function() body) {
    final done = Completer<void>();
    final prev = _tail;
    _tail = done.future;
    return prev.then((_) => body()).whenComplete(done.complete);
  }
}

final heavyLock = HeavyLock();
