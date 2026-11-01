import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:drift_flutter/drift_flutter.dart';
import 'package:path_provider/path_provider.dart';

import 'case_db.dart';
import 'case_store.dart';

const caseStoreAvailable = true;

CaseStore? _store;

/// 開啟案件資料庫（App 支援資料夾裡的 cases.sqlite），整個 App 共用一個
Future<CaseStore?> openCaseStore() async =>
    _store ??= CaseStore(CaseDb(driftDatabase(name: 'cases', native: DriftNativeOptions(databaseDirectory: getApplicationSupportDirectory))), _HttpFetcher());

/// 採購網提供的一般檔案下載（資料集下載），不是爬網頁
class _HttpFetcher implements DataFetcher {
  Future<HttpClientResponse?> _open(String method, Uri url) async {
    final http = HttpClient()..connectionTimeout = const Duration(seconds: 15);
    try {
      final req = await http.openUrl(method, url);
      final res = await req.close().timeout(const Duration(seconds: 30));
      if (res.statusCode != 200) {
        await res.drain<void>();
        return null;
      }
      return res;
    } catch (_) {
      return null;
    }
  }

  @override
  Future<int?> size(Uri url) async {
    final res = await _open('HEAD', url);
    if (res == null) return null;
    await res.drain<void>();
    return res.contentLength >= 0 ? res.contentLength : null;
  }

  @override
  Future<String?> get(Uri url) async {
    final res = await _open('GET', url);
    if (res == null) return null;
    try {
      return await res.transform(utf8.decoder).join().timeout(const Duration(seconds: 60));
    } catch (_) {
      return null;
    }
  }
}
