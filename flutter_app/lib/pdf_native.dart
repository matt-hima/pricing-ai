import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_inappwebview/flutter_inappwebview.dart';

import 'app_state.dart';
import 'i18n/i18n.dart';

/// 桌面版 PDF：尚未提供（網頁版用 pdfmake）
Future<String> compileQuotePdf(AppState s, void Function(String status) onStatus) async => tr('js.pdf_nobridge');

Future<String> previewQuotePdf(AppState s, void Function(String status) onStatus) async => tr('js.pdf_nobridge');

bool downloadLastPdf(String filename) => false;

String previewKey(AppState s) => '';

/// 網頁版 App 的位置：桌面版借用它的 pdf_bridge.js 與 pdfmake（字型同樣從 jsDelivr 下載，失敗才用網站備份）
const pdfBridgeBase = 'https://pricingai.minervaelectronics.com/app/';

/// 用 pdfmake 把文件描述排成 PDF：在看不見的 WebView 裡執行和網頁版相同的 pdf_bridge.js，所以分頁與字型一致
Future<Uint8List> renderPdfDoc(Map<String, dynamic> doc) async {
  final loaded = Completer<void>();
  final view = HeadlessInAppWebView(
    initialData: InAppWebViewInitialData(
      data: '<!doctype html><html><head><meta charset="utf-8"><script src="pdf_bridge.js"></script></head><body></body></html>',
      baseUrl: WebUri(pdfBridgeBase),
    ),
    onLoadStop: (_, _) {
      if (!loaded.isCompleted) loaded.complete();
    },
    onReceivedError: (_, req, err) {
      if (req.isForMainFrame == true && !loaded.isCompleted) loaded.completeError(StateError(err.description));
    },
  );
  await view.run();
  try {
    await loaded.future.timeout(const Duration(seconds: 30));
    final r = await view.webViewController!.callAsyncJavaScript(
      functionBody: '''
        if (!window.quotePdf) throw new Error("@pdf_nobridge");
        const pdf = await window.quotePdf.render(doc, cjkSet, null);
        let s = "";
        for (let i = 0; i < pdf.length; i += 0x8000) s += String.fromCharCode.apply(null, pdf.subarray(i, i + 0x8000));
        return btoa(s);''',
      arguments: {'doc': jsonEncode(doc), 'cjkSet': I18n.lang.fontSet},
    ).timeout(const Duration(minutes: 3));
    if (r == null || r.error != null || r.value is! String) throw StateError(tx(r?.error ?? '@pdf_failed'));
    return base64Decode(r.value as String);
  } finally {
    await view.dispose();
  }
}
