import 'dart:convert';
import 'dart:io';

import 'case_db.dart';
import 'opendata.dart';
import 'pcc.dart';
import 'sources/es.dart';
import 'sources/jp.dart';
import 'sources/pt.dart';
import 'sources/source.dart';
import 'sources/ted.dart';
import 'sources/uk.dart';

/// 下載官方資料檔用：先問大小（HEAD），需要時才下載內容。找不到或連不上回傳 null。
abstract class DataFetcher {
  Future<int?> size(Uri url);
  Future<String?> get(Uri url);
}

/// 案件資料的存放處：官方開放資料匯入資料庫（XML 不保留），即時查詢的結果也存進同一個資料庫
class CaseStore {
  final CaseDb db;
  final DataFetcher fetcher;
  final SourceHttp? sourceHttp; // 其他國家的資料（桌面版才有）
  final Duration pause;
  CaseStore(this.db, this.fetcher, {this.sourceHttp, this.pause = const Duration(milliseconds: 600)});

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

  /// 其他國家的官方決標資料：已結束的期間匯入過就不再下載；最近的期間一天最多更新一次。
  /// 回傳這次實際取得的單位數。取不到的單位（還沒公開、連不上）不記錄，下次再試。
  /// [cancelled] 回傳 true 時停止（已匯入的資料留著）。
  Future<int> syncSource(
    List<AwardSource> sources,
    int months, {
    List<String> keywords = const [],
    void Function(int done, int total)? onProgress,
    void Function(int bytes)? onBytes,
    void Function(Duration wait)? onWait,
    bool Function()? cancelled,
    DateTime? now,
  }) async {
    final base = sourceHttp;
    if (base == null) return 0;
    final http = _ProgressHttp(base, onBytes, onWait, cancelled);
    final t = now ?? DateTime.now();
    final work = [
      for (final s in sources)
        for (final u in s.unitsFor(t, months, keywords)) (s, u),
    ];
    var fetched = 0;
    for (var i = 0; i < work.length; i++) {
      if (cancelled?.call() ?? false) break;
      onProgress?.call(i, work.length);
      final (src, unit) = work[i];
      final row = await db.datasetFileRow(unit.name);
      if (row != null && unit.periodEnd.isBefore(t.subtract(src.settledAfter))) continue;
      if (row != null && t.difference(row.checkedAt) < recheckEvery) continue;
      var n = 0, any = false;
      try {
        await for (final b in src.fetch(unit, http)) {
          any = true;
          n += await db.importAwards(src.country, b);
          if (cancelled?.call() ?? false) throw const SyncCancelled();
        }
      } on SyncCancelled {
        break; // 這個單位沒做完：不記錄，下次再取
      } catch (_) {
        continue; // 下次再試
      }
      if (!any) continue;
      await db.markDatasetFile(unit.name, records: n, checkedAt: t);
      fetched++;
    }
    onProgress?.call(work.length, work.length);
    return fetched;
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

/// 回報下載進度與等待（西班牙的伺服器很慢、英國的 API 會要求等待，畫面上要看得到在做什麼），並在使用者按停止時中斷
class _ProgressHttp implements SourceHttp {
  final SourceHttp inner;
  final void Function(int bytes)? bytes;
  final void Function(Duration wait)? wait;
  final bool Function()? cancelled;
  _ProgressHttp(this.inner, this.bytes, this.wait, this.cancelled);

  void _check() {
    if (cancelled?.call() ?? false) throw const SyncCancelled();
  }

  @override
  Future<String?> getText(Uri url, {void Function(Duration wait)? onWait}) {
    _check();
    return inner.getText(url, onWait: (d) {
      wait?.call(d);
      onWait?.call(d);
    });
  }

  @override
  Future<String?> postJson(Uri url, String body, {void Function(Duration wait)? onWait}) {
    _check();
    return inner.postJson(url, body, onWait: (d) {
      wait?.call(d);
      onWait?.call(d);
    });
  }

  @override
  Future<File?> download(Uri url, {void Function(int bytes)? onBytes, void Function(Duration wait)? onWait}) {
    _check();
    return inner.download(url, onBytes: (n) {
      _check();
      bytes?.call(n);
      onBytes?.call(n);
    }, onWait: (d) {
      wait?.call(d);
      onWait?.call(d);
    });
  }
}

/// 每個國家的官方來源
List<AwardSource> sourcesFor(Country c) => switch (c) {
      Country.tw => const [],
      Country.uk => [UkSource(UkService.contractsFinder), UkSource(UkService.findATender)],
      Country.es => [SpainSource()],
      Country.pt => [PortugalSource()],
      Country.jp => [JapanSource()],
      Country.eu => [TedSource()],
    };
