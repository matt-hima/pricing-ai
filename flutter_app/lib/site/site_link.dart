import 'package:flutter/foundation.dart';

/// 報價功能與網站建置器之間的橋：報價頁按「套用到網站」→ 這裡暫存 → 網站建置器就緒後套用到價格列表
class SiteLink extends ChangeNotifier {
  Map<String, Object?>? pendingPricing;
  List<Map<String, Object?>>? pendingActions;
  String? pendingLang; // 価目表の言語（いまのサイトと違うときは確認してから新しいサイトを作る）

  /// 外層（AppShell）設定：切到網站建置器分頁
  VoidCallback? showSite;

  /// 外層設定：切到報價分頁
  VoidCallback? showPricing;

  void applyPricing(Map<String, Object?> payload) {
    pendingPricing = payload;
    notifyListeners();
    showSite?.call();
  }

  /// 市場行情的價目表：編輯器動作（replace_list services / prices）
  void applyServices(List<Map<String, Object?>> actions, [String? lang]) {
    pendingActions = actions;
    pendingLang = lang;
    notifyListeners();
    showSite?.call();
  }

  List<Map<String, Object?>>? takeActions() {
    final a = pendingActions;
    pendingActions = null;
    return a;
  }

  String? takeLang() {
    final l = pendingLang;
    pendingLang = null;
    return l;
  }

  Map<String, Object?>? takePricing() {
    final p = pendingPricing;
    pendingPricing = null;
    return p;
  }
}
