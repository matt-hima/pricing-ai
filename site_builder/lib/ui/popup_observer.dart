import 'package:flutter/widgets.dart';

/// 追蹤目前開著的選單 / 對話框數量。網頁版的編輯器是 iframe，會吃掉浮在它上面的 Flutter 選單的點擊，
/// 所以有彈出層時要暫時關閉 iframe 的滑鼠事件。
class PopupObserver extends NavigatorObserver {
  final open = ValueNotifier<int>(0);

  void _change(Route<dynamic> r, int d) {
    if (r is PopupRoute) Future.microtask(() => open.value = (open.value + d).clamp(0, 99));
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) => _change(route, 1);

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) => _change(route, -1);

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) => _change(route, -1);
}
