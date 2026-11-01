import 'dart:async';

import 'package:flutter/widgets.dart';

import 'bridge_desktop.dart' if (dart.library.js_interop) 'bridge_web.dart' as impl;

/// Flutter ⇄ GrapesJS 編輯器頁（assets/editor）的橋接。
/// 指令：call('load' | 'reset' | 'project' | 'html', args)，回傳編輯器端的結果；
/// 事件：events 會收到 {type: 'ready' | 'changed', payload: …}。
abstract class EditorBridge {
  final _pending = <int, Completer<dynamic>>{};
  final _events = StreamController<Map<String, dynamic>>.broadcast();
  int _nextId = 0;

  factory EditorBridge() => impl.createBridge();
  EditorBridge.base();

  Stream<Map<String, dynamic>> get events => _events.stream;

  /// 內嵌編輯器的畫面
  Widget build(BuildContext context);

  /// 有 Flutter 彈出層時暫停編輯器接收滑鼠事件（只有網頁版的 iframe 需要）
  void setInteractive(bool value) {}

  /// 平台實作：把指令送進編輯器頁
  void send(int id, String method, List<dynamic> args);

  Future<T?> call<T>(String method, [List<dynamic> args = const []]) {
    final id = _nextId++;
    final c = Completer<dynamic>();
    _pending[id] = c;
    send(id, method, args);
    return c.future.timeout(const Duration(seconds: 30), onTimeout: () {
      _pending.remove(id);
      throw TimeoutException('Editor did not respond ($method)');
    }).then((v) => v as T?);
  }

  /// 平台實作收到編輯器訊息時呼叫
  void handleMessage(Map<String, dynamic> msg) {
    if (msg['type'] == 'result') {
      final p = Map<String, dynamic>.from(msg['payload'] as Map);
      final c = _pending.remove((p['id'] as num).toInt());
      if (c == null) return;
      if (p['error'] != null) {
        c.completeError(Exception(p['error']));
      } else {
        c.complete(p['result']);
      }
    } else {
      _events.add(msg);
    }
  }

  @mustCallSuper
  void dispose() {
    _events.close();
  }
}
