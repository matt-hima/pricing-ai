import 'dart:convert';

import 'case_db.dart';
import 'opendata.dart';
import 'pcc.dart';

/// 下載官方資料檔用：先問大小（HEAD），需要時才下載內容。找不到或連不上回傳 null。
abstract class DataFetcher {
  Future<int?> size(Uri url);
  Future<String?> get(Uri url);
}

/// 案件資料的存放處：官方開放資料匯入資料庫（XML 不保留），即時查詢的結果也存進同一個資料庫
class CaseStore {
  final CaseDb db;
  final DataFetcher fetcher;
  final Duration pause;
  CaseStore(this.db, this.fetcher, {this.pause = const Duration(milliseconds: 600)});

  /// 已經過了 45 天的期間不會再變：匯入過就不再下載
  static const settledAfter = Duration(days: 45);

  /// 最近的期間：一天最多檢查一次，大小沒變就不重新匯入
  static const recheckEvery = Duration(days: 1);

  /// 匯入期間內的官方資料檔。只下載還沒有、或最近期間有更新的檔。回傳實際下載的檔數。
  Future<int> syncDataset(List<String> files, {void Function(int done, int total)? onProgress, DateTime? now}) async {
    final t = now ?? DateTime.now();
    var downloaded = 0;
    for (var i = 0; i < files.length; i++) {
      onProgress?.call(i, files.length);
      final name = files[i];
      final row = await db.datasetFileRow(name);
      final end = _periodEnd(name);
      if (row != null && end != null && end.isBefore(t.subtract(settledAfter))) continue; // 已結束的期間：不再下載
      if (row != null && t.difference(row.checkedAt) < recheckEvery) continue;
      final url = datasetUrl(name);
      if (row != null) {
        final size = await fetcher.size(url);
        if (size != null && size == row.size) {
          await db.markDatasetFile(name, records: row.records, size: row.size, checkedAt: t); // 沒變：只記下檢查時間
          await Future<void>.delayed(pause);
          continue;
        }
      }
      final xml = await fetcher.get(url);
      await Future<void>.delayed(pause);
      if (xml == null || !xml.contains('<TENDER_LIST')) continue; // 還沒公開或連不上：下次再試
      final awards = parseAwardDataset(xml);
      await db.importDataset(awards);
      await db.markDatasetFile(name, records: awards.length, size: utf8.encode(xml).length, checkedAt: t); // 和 HEAD 的 Content-Length 一樣以位元組計
      downloaded++;
    }
    onProgress?.call(files.length, files.length);
    return downloaded;
  }

  /// 即時查詢的結果存起來；之後交叉分析可沿用開過的公告明細
  Future<void> saveCollection(CaseCollection col) => db.saveCollection(col);

  Future<Map<String, AwardDetail>> detailsFor(Iterable<String> urls) => db.detailsFor(urls);

  static DateTime? _periodEnd(String name) {
    final m = RegExp(r'award_(\d{4})(\d{2})(0[12])').firstMatch(name);
    if (m == null) return null;
    final y = int.parse(m[1]!), mo = int.parse(m[2]!);
    return m[3] == '01' ? DateTime(y, mo, 15) : DateTime(y, mo + 1, 0);
  }
}

/// 開資料庫的函式（App 用 openCaseStore，測試可換成記憶體資料庫或 null）
typedef OpenCaseStore = Future<CaseStore?> Function();

/// 即時查詢的結果存進資料庫；存不了（例如網頁版）就略過
Future<void> saveCasesTo(OpenCaseStore open, CaseCollection c) async {
  try {
    await (await open())?.saveCollection(c);
  } catch (_) {}
}

/// 資料庫裡已經有明細的公告（交叉分析沿用，不再打開）
Future<Map<String, AwardDetail>> knownDetailsIn(OpenCaseStore open, Iterable<String> urls) async {
  try {
    return await (await open())?.detailsFor(urls) ?? const {};
  } catch (_) {
    return const {};
  }
}
