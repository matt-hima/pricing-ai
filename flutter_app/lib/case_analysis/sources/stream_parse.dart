/// 大檔串流解析：zip 一個檔一個檔解壓（不整包讀進記憶體）、JSON 陣列逐筆切開、XML 逐個元素切開。
/// 葡萄牙一年的資料解壓後約 365 MB，西班牙一個月好幾個 ATOM 檔，所以都邊讀邊解析。
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

/// zip 裡的一個檔
class ZipEntry {
  final String name;
  final int method, compressedSize, headerOffset;
  const ZipEntry(this.name, this.method, this.compressedSize, this.headerOffset);
}

/// 讀中央目錄，列出 zip 裡的檔（不解壓）
Future<List<ZipEntry>> zipEntries(File f) async {
  final raf = await f.open();
  try {
    final len = await raf.length();
    final tail = len < 66000 ? len : 66000;
    await raf.setPosition(len - tail);
    final end = ByteData.sublistView(await raf.read(tail));
    var eocd = -1;
    for (var i = end.lengthInBytes - 22; i >= 0; i--) {
      if (end.getUint32(i, Endian.little) == 0x06054b50) {
        eocd = i;
        break;
      }
    }
    if (eocd < 0) throw const FormatException('not a zip file');
    final count = end.getUint16(eocd + 10, Endian.little);
    final cdSize = end.getUint32(eocd + 12, Endian.little);
    final cdOffset = end.getUint32(eocd + 16, Endian.little);
    await raf.setPosition(cdOffset);
    final cd = ByteData.sublistView(await raf.read(cdSize));
    final out = <ZipEntry>[];
    var p = 0;
    for (var i = 0; i < count && p + 46 <= cd.lengthInBytes; i++) {
      if (cd.getUint32(p, Endian.little) != 0x02014b50) break;
      final method = cd.getUint16(p + 10, Endian.little);
      final csize = cd.getUint32(p + 20, Endian.little);
      final nlen = cd.getUint16(p + 28, Endian.little), xlen = cd.getUint16(p + 30, Endian.little), clen = cd.getUint16(p + 32, Endian.little);
      final offset = cd.getUint32(p + 42, Endian.little);
      final name = utf8.decode(Uint8List.sublistView(cd, p + 46, p + 46 + nlen), allowMalformed: true);
      if (!name.endsWith('/')) out.add(ZipEntry(name, method, csize, offset));
      p += 46 + nlen + xlen + clen;
    }
    return out;
  } finally {
    await raf.close();
  }
}

/// 一個檔的內容（串流解壓成文字）
Stream<String> zipEntryText(File f, ZipEntry e) async* {
  final raf = await f.open();
  int start;
  try {
    await raf.setPosition(e.headerOffset);
    final h = ByteData.sublistView(await raf.read(30));
    if (h.getUint32(0, Endian.little) != 0x04034b50) throw const FormatException('bad zip entry');
    start = e.headerOffset + 30 + h.getUint16(26, Endian.little) + h.getUint16(28, Endian.little);
  } finally {
    await raf.close();
  }
  Stream<List<int>> bytes = f.openRead(start, start + e.compressedSize);
  if (e.method == 8) {
    bytes = bytes.transform(ZLibDecoder(raw: true));
  } else if (e.method != 0) {
    throw FormatException('zip method ${e.method}');
  }
  yield* bytes.transform(const Utf8Decoder(allowMalformed: true));
}

/// JSON 陣列 → 一個一個物件的文字（陣列最外層的每個 {...}）
Stream<String> jsonArrayObjects(Stream<String> text) async* {
  final buf = StringBuffer();
  var depth = 0;
  var inString = false, escaped = false;
  await for (final chunk in text) {
    for (var i = 0; i < chunk.length; i++) {
      final c = chunk.codeUnitAt(i);
      if (depth > 0) buf.writeCharCode(c);
      if (inString) {
        if (escaped) {
          escaped = false;
        } else if (c == 0x5C) {
          escaped = true;
        } else if (c == 0x22) {
          inString = false;
        }
        continue;
      }
      if (c == 0x22 && depth > 0) {
        inString = true;
      } else if (c == 0x7B) {
        if (depth == 0) buf.writeCharCode(c);
        depth++;
      } else if (c == 0x7D && depth > 0) {
        depth--;
        if (depth == 0) {
          yield buf.toString();
          buf.clear();
        }
      }
    }
  }
}

/// XML → 每個 <tag>...</tag> 元素的文字（不處理同名巢狀）
Stream<String> xmlElements(Stream<String> text, String tag) async* {
  final open = '<$tag', close = '</$tag>';
  var buf = '';
  await for (final chunk in text) {
    buf += chunk;
    while (true) {
      final s = buf.indexOf(open);
      if (s < 0) {
        buf = buf.length > open.length ? buf.substring(buf.length - open.length) : buf;
        break;
      }
      final e = buf.indexOf(close, s);
      if (e < 0) {
        buf = buf.substring(s);
        break;
      }
      yield buf.substring(s, e + close.length);
      buf = buf.substring(e + close.length);
    }
  }
}

/// 分批：每 [size] 筆送出一次
Stream<List<T>> batches<T>(Stream<T> items, [int size = 2000]) async* {
  var b = <T>[];
  await for (final x in items) {
    b.add(x);
    if (b.length >= size) {
      yield b;
      b = <T>[];
    }
  }
  if (b.isNotEmpty) yield b;
}

/// 在背景 isolate 執行 [make]（例如解壓並解析一個大檔），結果分批傳回，畫面不會卡住
Stream<T> inIsolate<T>(Stream<T> Function(String arg) make, String arg) {
  final port = ReceivePort();
  final out = StreamController<T>();
  Isolate? iso;
  port.listen((m) {
    if (m is _Done) {
      if (m.error != null) out.addError(StateError(m.error!));
      port.close();
      out.close();
    } else {
      out.add(m as T);
    }
  });
  Isolate.spawn(_isolateMain<T>, (port.sendPort, make, arg)).then((i) => iso = i, onError: (Object e) {
    out.addError(e);
    port.close();
    out.close();
  });
  out.onCancel = () {
    iso?.kill();
    port.close();
  };
  return out.stream;
}

class _Done {
  final String? error;
  const _Done([this.error]);
}

Future<void> _isolateMain<T>((SendPort, Stream<T> Function(String), String) msg) async {
  final (send, make, arg) = msg;
  try {
    await for (final x in make(arg)) {
      send.send(x);
    }
    send.send(const _Done());
  } catch (e) {
    send.send(_Done('$e'));
  }
}
