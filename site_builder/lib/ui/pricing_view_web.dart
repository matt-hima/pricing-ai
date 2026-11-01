import 'dart:async';
import 'dart:js_interop';
import 'dart:ui_web' as ui_web;

import 'package:flutter/widgets.dart';
import 'package:web/web.dart' as web;

/// 網頁版：Pricing AI 放在 iframe，結果以 postMessage 回傳
class PricingAiView extends StatefulWidget {
  final String url;
  final ValueChanged<Map<String, dynamic>> onResult;
  const PricingAiView({super.key, required this.url, required this.onResult});

  @override
  State<PricingAiView> createState() => _PricingAiViewState();
}

class _PricingAiViewState extends State<PricingAiView> {
  static var _count = 0;
  final _viewType = 'sb-pricing-ai-${_count++}';
  late final web.HTMLIFrameElement _iframe;
  StreamSubscription<web.MessageEvent>? _sub;

  @override
  void initState() {
    super.initState();
    _iframe = web.HTMLIFrameElement()
      ..src = widget.url
      ..allow = 'clipboard-write; fullscreen'
      ..style.border = '0'
      ..style.width = '100%'
      ..style.height = '100%';
    ui_web.platformViewRegistry.registerViewFactory(_viewType, (int _) => _iframe);
    _sub = web.EventStreamProviders.messageEvent.forTarget(web.window).listen((e) {
      if ((e.source as JSAny?) != (_iframe.contentWindow as JSAny?)) return;
      final d = e.data.dartify();
      if (d is Map && d['type'] == 'pricing-ai-result') widget.onResult(Map<String, dynamic>.from(d));
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => HtmlElementView(viewType: _viewType);
}
