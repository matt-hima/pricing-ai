import 'dart:convert';

/// 小模型輸出的 JSON 常有瑕疵（多餘的結尾逗號、被截斷、括號配錯、前後夾雜說明文字）。
/// 依序嘗試：原文 → 截到最後一個 `}` → 逐字修補；全部失敗回傳 null。
Map<String, dynamic>? parseLooseJson(String text) {
  final start = text.indexOf('{');
  if (start < 0) return null;
  final body = text.substring(start);
  final end = body.lastIndexOf('}');
  final candidates = <String>[
    body,
    if (end > 0) body.substring(0, end + 1),
    repairJson(body),
  ];
  for (final c in candidates) {
    try {
      final v = jsonDecode(c);
      if (v is Map<String, dynamic>) return v;
    } catch (_) {}
  }
  return null;
}

/// 逐字掃描並修補：
/// - 字串外的結尾逗號（`,}` / `,]`）移除
/// - 括號種類配錯時，以堆疊頂端應有的種類為準
/// - 第一個完整的最外層物件結束後，捨棄後面的內容
/// - 被截斷時：補上未結束的字串、移除懸空的鍵與逗號、依序補齊括號
String repairJson(String s) {
  final out = StringBuffer();
  final stack = <String>[]; // 期待的收尾字元
  var inStr = false, esc = false;

  String dropTrailingComma() {
    final t = out.toString().trimRight();
    if (t.endsWith(',')) {
      out
        ..clear()
        ..write(t.substring(0, t.length - 1));
    }
    return out.toString();
  }

  for (var i = 0; i < s.length; i++) {
    final c = s[i];
    if (inStr) {
      out.write(c);
      if (esc) {
        esc = false;
      } else if (c == r'\') {
        esc = true;
      } else if (c == '"') {
        inStr = false;
      }
      continue;
    }
    if (c == '"') {
      inStr = true;
      out.write(c);
    } else if (c == '{' || c == '[') {
      stack.add(c == '{' ? '}' : ']');
      out.write(c);
    } else if (c == '}' || c == ']') {
      if (stack.isEmpty) continue;
      dropTrailingComma();
      out.write(stack.removeLast());
      if (stack.isEmpty) break;
    } else {
      out.write(c);
    }
  }

  if (inStr) out.write('"');

  // 被截斷時，結尾可能是懸空的鍵或逗號：`"hours":` / `"name"` / `,`
  var t = out.toString().trimRight();
  for (var guard = 0; guard < 8; guard++) {
    final before = t;
    t = t.replaceFirst(RegExp(r',\s*$'), '');
    t = t.replaceFirst(RegExp(r',?\s*"(?:[^"\\]|\\.)*"\s*:\s*$'), ''); // 沒有值的鍵
    t = t.replaceFirst(RegExp(r'([{,\[])\s*"(?:[^"\\]|\\.)*"\s*$'), r'$1'); // 沒有冒號的孤立鍵
    t = t.trimRight();
    if (t == before) break;
  }
  final closers = stack.reversed.join();
  return '$t$closers';
}
