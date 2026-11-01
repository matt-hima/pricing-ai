import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

import 'editor_bridge.dart';

EditorBridge createBridge() => _DesktopBridge();

const _port = 8091;

/// macOS / Windows：用系統 WebView 載入 assets/editor，經本機 localhost 靜態伺服器提供檔案
/// （ES module 在 file:// 下會被擋）。編輯器回報事件走 JS handler，指令用 evaluateJavascript 送入。
class _DesktopBridge extends EditorBridge {
  static InAppLocalhostServer? _server;
  static Future<void>? _starting;

  InAppWebViewController? _controller;

  _DesktopBridge() : super.base();

  static Future<void> _ensureServer() => _starting ??= () async {
        _server = InAppLocalhostServer(port: _port, documentRoot: 'assets/editor');
        await _server!.start();
      }();

  @override
  Widget build(BuildContext context) => FutureBuilder<void>(
        future: _ensureServer(),
        builder: (context, snap) {
          if (snap.hasError) return Center(child: Text('Could not start the editor: ${snap.error}'));
          if (snap.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
          return InAppWebView(
            initialUrlRequest: URLRequest(url: WebUri('http://localhost:$_port/index.html')),
            initialSettings: InAppWebViewSettings(javaScriptEnabled: true, transparentBackground: false, isInspectable: true),
            onWebViewCreated: (c) {
              _controller = c;
              c.addJavaScriptHandler(
                handlerName: 'sb',
                callback: (args) {
                  if (args.isNotEmpty && args.first is Map) handleMessage(Map<String, dynamic>.from(args.first as Map));
                  return null;
                },
              );
            },
          );
        },
      );

  @override
  void send(int id, String method, List<dynamic> args) {
    _controller?.evaluateJavascript(source: 'sbCall($id, ${jsonEncode(method)}, ${jsonEncode(args)})');
  }
}
