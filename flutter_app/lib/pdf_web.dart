import 'dart:convert';
import 'dart:js_interop';

import 'app_state.dart';
import 'i18n/i18n.dart';
import 'pdf_doc.dart';

/* ---------- 瀏覽器端 PDF（web/pdf_bridge.js） ---------- */

@JS('quotePdf')
external _Pdf? get _pdf;

extension type _Pdf._(JSObject _) implements JSObject {
  external JSPromise<JSString> download(String docJson, String cjkSet, String filename, JSFunction onStatus);
  external JSPromise<JSString> preview(String docJson, String cjkSet, JSFunction onStatus);
  external bool downloadLast(String filename);
}

String _docJson(AppState s) => jsonEncode(buildQuotePdf(s));

/// 產生並下載 PDF；成功回傳空字串，失敗回傳錯誤訊息（已翻譯）
Future<String> compileQuotePdf(AppState s, void Function(String status) onStatus) async {
  final b = _pdf;
  if (b == null) return tr('js.pdf_nobridge');
  final r = await b
      .download(_docJson(s), I18n.lang.fontSet, '${s.q.ref}.pdf', ((String t) => onStatus(tx(t))).toJS)
      .toDart;
  return tx(r.toDart);
}

/// 產生並更新即時預覽面板；成功回傳空字串，失敗回傳錯誤訊息（已翻譯）
Future<String> previewQuotePdf(AppState s, void Function(String status) onStatus) async {
  final b = _pdf;
  if (b == null) return tr('js.pdf_nobridge');
  final r = await b.preview(_docJson(s), I18n.lang.fontSet, ((String t) => onStatus(tx(t))).toJS).toDart;
  return tx(r.toDart);
}

/// 下載最近一次產生的 PDF
bool downloadLastPdf(String filename) => _pdf?.downloadLast(filename) ?? false;

/// 判斷內容是否改變用的指紋（文件內容 + 語言）
String previewKey(AppState s) => '${I18n.lang.code}|${_docJson(s)}';
