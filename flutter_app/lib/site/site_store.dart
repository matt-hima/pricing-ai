import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'site_model.dart';

/// 所有網站專案（存在本機 shared_preferences）與目前選取的專案
class Store extends ChangeNotifier {
  /// false（網頁版）：沒有 AI，新網站直接用範本（不走「從聊天開始」）
  final bool aiAvailable;
  Store({this.aiAvailable = true});

  Site _newSite(String lang) {
    final s = Site.create(lang);
    if (!aiAvailable) s.initialized = true;
    return s;
  }

  static const _sitesKey = 'sb.sites.v2';
  static const _currentKey = 'sb.current.v2';

  final Map<String, Site> sites = {};
  late Site current;
  SharedPreferences? _prefs;

  String _systemLang() {
    final l = PlatformDispatcher.instance.locale;
    return langs.containsKey(l.languageCode) ? l.languageCode : 'en';
  }

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    for (final raw in _prefs!.getStringList(_sitesKey) ?? const <String>[]) {
      try {
        final s = Site.decode(raw);
        sites[s.slug] = s;
      } catch (_) {}
    }
    final cur = _prefs!.getString(_currentKey);
    if (cur != null && sites.containsKey(cur)) {
      current = sites[cur]!;
    } else if (sites.isNotEmpty) {
      current = sites.values.first;
    } else {
      current = _newSite(_systemLang());
      sites[current.slug] = current;
    }
  }

  void _persist() {
    final p = _prefs;
    if (p == null) return;
    p.setStringList(_sitesKey, [for (final s in sites.values) s.encode()]);
    p.setString(_currentKey, current.slug);
  }

  /// 編輯後存檔；notify=false 用於編輯器自動回報的內容（不需要重繪外層）
  void changed({bool notify = true}) {
    sites[current.slug] = current;
    _persist();
    if (notify) notifyListeners();
  }

  void switchTo(String slug) {
    current = sites[slug]!;
    _persist();
    notifyListeners();
  }

  void createSite(String lang) {
    current = _newSite(lang);
    changed();
  }

  void deleteCurrent() {
    sites.remove(current.slug);
    current = sites.isEmpty ? _newSite(current.lang) : sites.values.first;
    changed();
  }

  /// 改網址（slug）：以新 slug 重新登記
  bool rename(String slug) {
    if (!slugRe.hasMatch(slug) || (slug != current.slug && sites.containsKey(slug))) return false;
    sites.remove(current.slug);
    current.slug = slug;
    changed();
    return true;
  }
}
