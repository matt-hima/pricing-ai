import 'dart:async';
import 'dart:io';

/// 下載檔案到 [dest]：先寫 .part，支援中斷後續傳（Range），完成才改名。
/// [onProgress] 收到（已下載位元組, 總位元組；未知為 -1）。
Future<void> downloadFile(Uri url, File dest, void Function(int received, int total) onProgress, {HttpClient? client}) async {
  final part = File('${dest.path}.part');
  await dest.parent.create(recursive: true);
  var have = await part.exists() ? await part.length() : 0;
  final http = client ?? HttpClient();
  http.connectionTimeout = const Duration(seconds: 20);
  try {
    final req = await http.getUrl(url);
    req.followRedirects = true;
    req.maxRedirects = 8;
    req.headers.set(HttpHeaders.userAgentHeader, 'pricing-ai-desktop');
    if (have > 0) req.headers.set(HttpHeaders.rangeHeader, 'bytes=$have-');
    final res = await req.close();
    if (res.statusCode == 416 && have > 0) {
      // 已經下載完整
      await part.rename(dest.path);
      return;
    }
    if (res.statusCode != 200 && res.statusCode != 206) {
      await res.drain<void>();
      throw HttpException('HTTP ${res.statusCode}', uri: url);
    }
    final resumed = res.statusCode == 206;
    if (!resumed) have = 0;
    final total = res.contentLength < 0 ? -1 : res.contentLength + have;
    final sink = part.openWrite(mode: resumed ? FileMode.append : FileMode.write);
    var received = have;
    try {
      await for (final chunk in res) {
        sink.add(chunk);
        received += chunk.length;
        onProgress(received, total);
      }
    } finally {
      await sink.close();
    }
    if (total > 0 && received < total) throw HttpException('Download interrupted ($received/$total bytes)', uri: url);
    if (await dest.exists()) await dest.delete();
    await part.rename(dest.path);
  } finally {
    if (client == null) http.close(force: true);
  }
}
