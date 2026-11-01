import 'dart:async';
import 'dart:js_interop';
import 'dart:ui_web' as ui_web;

import 'package:flutter/widgets.dart';
import 'package:web/web.dart' as web;

import 'editor_bridge.dart';

EditorBridge createBridge() => _WebBridge();

/// 網頁版：編輯器頁放在 iframe，以 postMessage 溝通
class _WebBridge extends EditorBridge {
  static var _count = 0;
  late final String _viewType = 'sb-editor-${_count++}';
  late final web.HTMLIFrameElement _iframe;
  StreamSubscription<web.MessageEvent>? _sub;

  _WebBridge() : super.base() {
    _iframe = web.HTMLIFrameElement()
      ..src = 'assets/assets/editor/index.html'
      ..style.border = '0'
      ..style.width = '100%'
      ..style.height = '100%';
    ui_web.platformViewRegistry.registerViewFactory(_viewType, (int _) => _iframe);
    _sub = web.EventStreamProviders.messageEvent.forTarget(web.window).listen((e) {
      if ((e.source as JSAny?) != (_iframe.contentWindow as JSAny?)) return;
      final d = e.data.dartify();
      if (d is Map && d['sb'] == true) handleMessage(Map<String, dynamic>.from(d));
    });
  }

  @override
  Widget build(BuildContext context) => HtmlElementView(viewType: _viewType);

  @override
  void setInteractive(bool value) => _iframe.style.pointerEvents = value ? 'auto' : 'none';

  @override
  void send(int id, String method, List<dynamic> args) {
    _iframe.contentWindow?.postMessage({'sb': true, 'id': id, 'method': method, 'args': args}.jsify(), '*'.toJS);
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
