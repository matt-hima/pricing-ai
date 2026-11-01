import 'dart:async';
import 'dart:convert';
import 'dart:io';

/// llama-server 的 OpenAI 相容介面（/v1/chat/completions，串流）
class LlamaClient {
  final Uri base;
  LlamaClient(this.base);

  Future<bool> healthy({HttpClient? client}) async {
    final http = client ?? HttpClient();
    try {
      final req = await http.getUrl(base.resolve('/health')).timeout(const Duration(seconds: 3));
      final res = await req.close().timeout(const Duration(seconds: 3));
      await res.drain<void>();
      return res.statusCode == 200;
    } catch (_) {
      return false;
    } finally {
      if (client == null) http.close(force: true);
    }
  }

  /// 送出對話並回傳完整文字；每收到一段內容呼叫一次 [onToken]（參數是累計片段數）。
  /// [json] = true 時要求模型只輸出 JSON 物件（llama-server 會用文法限制輸出）；
  /// 再給 [schema] 就連欄位名稱與列舉值都限制住。
  Future<String> chat(
    String system,
    String user, {
    bool json = true,
    double temperature = 0.2,
    int maxTokens = 3072,
    Map<String, dynamic>? schema,
    void Function(int tokens)? onToken,
  }) async {
    final http = HttpClient()..connectionTimeout = const Duration(seconds: 10);
    try {
      final req = await http.postUrl(base.resolve('/v1/chat/completions'));
      req.headers.contentType = ContentType.json;
      req.add(utf8.encode(jsonEncode({
        'model': 'local',
        'messages': [
          {'role': 'system', 'content': system},
          {'role': 'user', 'content': user},
        ],
        'stream': true,
        'temperature': temperature,
        'top_p': 0.9,
        'repeat_penalty': 1.08, // 小模型容易無限重複同一句或同一個數字
        'max_tokens': maxTokens,
        // 有 schema 時，llama.cpp 會把它轉成文法，模型只能產生符合 schema 的 JSON
        if (json) 'response_format': {'type': 'json_object', if (schema != null) 'schema': schema},
      })));
      final res = await req.close();
      if (res.statusCode != 200) {
        final body = await utf8.decodeStream(res);
        throw HttpException('HTTP ${res.statusCode}: ${body.length > 300 ? body.substring(0, 300) : body}');
      }
      final out = StringBuffer();
      var n = 0;
      await for (final line in res.transform(utf8.decoder).transform(const LineSplitter())) {
        final piece = parseSseLine(line);
        if (piece == null) continue;
        if (piece == sseDone) break;
        out.write(piece);
        onToken?.call(++n);
      }
      return out.toString();
    } finally {
      http.close(force: true);
    }
  }
}

const sseDone = '\u0000done';

/// 解析一行 SSE：回傳內容片段、[sseDone]（結束），或 null（與內容無關的行）
String? parseSseLine(String line) {
  if (!line.startsWith('data:')) return null;
  final data = line.substring(5).trim();
  if (data == '[DONE]') return sseDone;
  try {
    final j = jsonDecode(data) as Map<String, dynamic>;
    final choices = j['choices'];
    if (choices is List && choices.isNotEmpty) {
      final delta = (choices.first as Map)['delta'];
      final c = delta is Map ? delta['content'] : null;
      if (c is String && c.isNotEmpty) return c;
    }
  } catch (_) {}
  return null;
}
