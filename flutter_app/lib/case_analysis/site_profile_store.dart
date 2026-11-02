/// 學過的網站設定檔，存在本機（每個網站一份）。
library;

import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'page_reader.dart';

class SiteProfileStore {
  static const _key = 'selfquote.siteProfiles.v1';
  final Map<String, SiteProfile> profiles = {};

  static Future<SiteProfileStore> load() async {
    final s = SiteProfileStore();
    try {
      final raw = (await SharedPreferences.getInstance()).getString(_key);
      if (raw != null) {
        for (final e in (jsonDecode(raw) as Map<String, dynamic>).entries) {
          s.profiles[e.key] = SiteProfile.fromJson(e.value as Map<String, dynamic>);
        }
      }
    } catch (_) {} // 壞掉的設定就當沒有
    return s;
  }

  SiteProfile of(String host) => profiles[host] ?? SiteProfile(host);

  Future<void> save(SiteProfile p) async {
    profiles[p.host] = p;
    await _write();
  }

  Future<void> forget(String host) async {
    profiles.remove(host);
    await _write();
  }

  Future<void> _write() async => (await SharedPreferences.getInstance()).setString(_key, jsonEncode({for (final e in profiles.entries) e.key: e.value.toJson()}));
}
