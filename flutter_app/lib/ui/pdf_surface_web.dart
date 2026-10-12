import 'dart:js_interop';
import 'dart:ui_web' as ui_web;

import 'package:flutter/widgets.dart';
import 'package:web/web.dart' as web;

const _viewType = 'quote-pdf-preview';
bool _registered = false;

/// 註冊預覽用的 HTML 容器；pdf_preview.js 會把 PDF 頁面畫進這個 div
void registerPdfPreview() {
  if (_registered) return;
  _registered = true;
  ui_web.platformViewRegistry.registerViewFactory(_viewType, (int id) {
    final div = web.HTMLDivElement()
      ..style.cssText = 'width:100%;height:100%;overflow:auto;background:#e9edf2;padding:12px 0;box-sizing:border-box;';
    _attach(div);
    return div;
  });
}

@JS('quotePreview.attach')
external void _attach(web.HTMLElement el);


/// PDF 預覽畫布：pdf_preview.js 會把 PDF 頁面畫進這個 HTML 元素
class PdfSurface extends StatelessWidget {
  const PdfSurface({super.key});

  @override
  Widget build(BuildContext context) => const HtmlElementView(viewType: _viewType);
}
