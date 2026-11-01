import 'package:flutter/widgets.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

/// macOS / Windows：Pricing AI 在系統 WebView 裡開啟，結果走 JS handler 'pricingAi'
class PricingAiView extends StatelessWidget {
  final String url;
  final ValueChanged<Map<String, dynamic>> onResult;
  const PricingAiView({super.key, required this.url, required this.onResult});

  @override
  Widget build(BuildContext context) => InAppWebView(
        initialUrlRequest: URLRequest(url: WebUri(url)),
        initialSettings: InAppWebViewSettings(javaScriptEnabled: true, transparentBackground: false),
        onWebViewCreated: (c) => c.addJavaScriptHandler(
          handlerName: 'pricingAi',
          callback: (args) {
            if (args.isNotEmpty && args.first is Map) onResult(Map<String, dynamic>.from(args.first as Map));
            return null;
          },
        ),
      );
}
