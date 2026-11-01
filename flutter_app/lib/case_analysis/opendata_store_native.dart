import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import 'opendata.dart';

const datasetAvailable = true;

/// 下載官方決標資料檔並存在本機（每個檔只下載一次；最近 3 個月的檔超過 3 天就重新下載，因為可能還在補資料）。
/// 這是採購網提供的一般檔案下載，不是爬網頁；每個檔之間稍停一下，不連續快速下載。
Future<List<DatasetAward>> loadDataset(List<String> files, {void Function(int done, int total)? onProgress}) async {
  final dir = Directory('${(await getApplicationSupportDirectory()).path}${Platform.pathSeparator}opendata');
  await dir.create(recursive: true);
  final out = <DatasetAward>[];
  final recent = DateTime.now().subtract(const Duration(days: 92));
  for (var i = 0; i < files.length; i++) {
    onProgress?.call(i, files.length);
    final f = File('${dir.path}${Platform.pathSeparator}${files[i]}');
    final m = RegExp(r'award_(\d{4})(\d{2})(\d{2})').firstMatch(files[i]);
    final periodStart = m == null ? DateTime(2000) : DateTime(int.parse(m[1]!), int.parse(m[2]!), m[3] == '02' ? 16 : 1);
    final stale = f.existsSync() && periodStart.isAfter(recent) && DateTime.now().difference(f.lastModifiedSync()) > const Duration(days: 3);
    if (!f.existsSync() || stale) {
      final xml = await _download(datasetUrl(files[i]));
      if (xml != null && xml.contains('<TENDER_LIST')) await f.writeAsString(xml);
      await Future<void>.delayed(const Duration(milliseconds: 600));
    }
    if (f.existsSync()) out.addAll(parseAwardDataset(await f.readAsString()));
  }
  onProgress?.call(files.length, files.length);
  return out;
}

/// 找不到（還沒公開）或連不上就回傳 null，略過這個檔
Future<String?> _download(Uri url) async {
  final http = HttpClient()..connectionTimeout = const Duration(seconds: 15);
  try {
    final req = await http.getUrl(url);
    final res = await req.close().timeout(const Duration(seconds: 30));
    if (res.statusCode != 200) {
      await res.drain<void>();
      return null;
    }
    return await res.transform(utf8.decoder).join().timeout(const Duration(seconds: 60));
  } catch (_) {
    return null;
  } finally {
    http.close(force: true);
  }
}
