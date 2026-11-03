import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:drift_flutter/drift_flutter.dart';
import 'package:path_provider/path_provider.dart';

import 'case_db.dart';
import 'case_store.dart';
import 'sources/es.dart' show esHost;
import 'sources/fnmt_root.dart';
import 'sources/source.dart';

const caseStoreAvailable = true;

CaseStore? _store;

/// 開啟案件資料庫（App 支援資料夾裡的 cases.sqlite），整個 App 共用一個
Future<CaseStore?> openCaseStore() async =>
    _store ??= CaseStore(CaseDb(driftDatabase(name: 'cases', native: DriftNativeOptions(databaseDirectory: getApplicationSupportDirectory))), _HttpFetcher(), sourceHttp: _SourceHttp());

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

/// 其他國家的官方資料：公開 API 與一般檔案下載。大檔直接寫到暫存檔，不放進記憶體。
class _SourceHttp implements SourceHttp {
  static const _spain = {esHost, 'contrataciondelestado.es'};

  HttpClient _client(Uri url) {
    if (!_spain.contains(url.host)) return HttpClient()..connectionTimeout = const Duration(seconds: 20);
    // 西班牙採購平台的憑證鏈到 FNMT-RCM 的根憑證（在 Mozilla 的信任清單裡，但不是每個作業系統都有）：只對這個網站加信
    final ctx = SecurityContext(withTrustedRoots: true)..setTrustedCertificatesBytes(utf8.encode(fnmtServersRoot));
    return HttpClient(context: ctx)..connectionTimeout = const Duration(seconds: 20);
  }

  /// GET（有 [body] 時是 POST JSON）；伺服器要求等待（429 / 503 + Retry-After）就照做再試，最多 5 次
  Future<HttpClientResponse?> _get(Uri url, void Function(Duration wait)? onWait, {String? body}) async {
    for (var attempt = 0; attempt < 6; attempt++) {
      final http = _client(url);
      try {
        final req = body == null ? await http.getUrl(url) : await http.postUrl(url);
        req.headers.set(HttpHeaders.userAgentHeader, 'PricingAI/0.1 (+https://github.com/matt-hima/pricing-ai)');
        if (body != null) {
          req.headers.contentType = ContentType.json;
          req.add(utf8.encode(body));
        }
        final res = await req.close().timeout(const Duration(seconds: 60));
        if (res.statusCode == 200) return res;
        await res.drain<void>();
        if ((res.statusCode != 429 && res.statusCode != 503) || attempt == 5) return null;
        final s = int.tryParse(res.headers.value(HttpHeaders.retryAfterHeader) ?? '') ?? 60;
        final wait = Duration(seconds: s.clamp(5, 600));
        onWait?.call(wait);
        await Future<void>.delayed(wait);
      } catch (_) {
        return null;
      }
    }
    return null;
  }

  @override
  Future<String?> getText(Uri url, {void Function(Duration wait)? onWait}) async {
    final res = await _get(url, onWait);
    if (res == null) return null;
    try {
      return await res.transform(utf8.decoder).join().timeout(const Duration(minutes: 2));
    } catch (_) {
      return null;
    }
  }

  @override
  Future<String?> postJson(Uri url, String body, {void Function(Duration wait)? onWait}) async {
    final res = await _get(url, onWait, body: body);
    if (res == null) return null;
    try {
      return await res.transform(utf8.decoder).join().timeout(const Duration(minutes: 2));
    } catch (_) {
      return null;
    }
  }

  @override
  Future<File?> download(Uri url, {void Function(int bytes)? onBytes, void Function(Duration wait)? onWait}) async {
    final res = await _get(url, onWait);
    if (res == null) return null;
    final dir = await Directory.systemTemp.createTemp('pricingai-data');
    final file = File('${dir.path}/${url.pathSegments.isEmpty ? 'data' : url.pathSegments.last}');
    final sink = file.openWrite();
    var n = 0;
    try {
      // 西班牙的伺服器有時很慢：不限制總時間，只要 90 秒內有收到資料就繼續
      await for (final chunk in res.timeout(const Duration(seconds: 90))) {
        sink.add(chunk);
        n += chunk.length;
        onBytes?.call(n);
      }
      await sink.close();
      return file;
    } catch (e) {
      await sink.close().catchError((_) {});
      await dir.delete(recursive: true).catchError((_) => dir);
      if (e is SyncCancelled) rethrow;
      return null;
    }
  }
}
