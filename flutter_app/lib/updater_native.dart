import 'dart:io';

import 'package:auto_updater/auto_updater.dart';
import 'package:flutter/foundation.dart';

/// 更新來源：GitHub 最新 Release 的 appcast.xml（tool/release_mac.sh 產生，內含 EdDSA 簽章與該版 DMG 的網址）。
/// 測試時可用 --dart-define=APPCAST_URL=http://localhost:8000/appcast.xml 指向本機
const appcastUrl = String.fromEnvironment('APPCAST_URL',
    defaultValue: 'https://github.com/matt-hima/pricing-ai/releases/latest/download/appcast.xml');

/// 目前只有 macOS 有安裝檔與 appcast（Sparkle）；Windows 版發佈後再接 WinSparkle
final updaterAvailable = Platform.isMacOS;

/// 啟動時在背景檢查一次，之後由 Sparkle 每天檢查；有新版才會跳出 Sparkle 的更新視窗。
/// 開發中（flutter run）不檢查，以免每次執行都提示更新
Future<void> initUpdater() async {
  if (!updaterAvailable || kDebugMode) return;
  try {
    await autoUpdater.setFeedURL(appcastUrl);
    await autoUpdater.setScheduledCheckInterval(86400);
    await autoUpdater.checkForUpdates(inBackground: true);
  } catch (e) {
    debugPrint('update check failed: $e');
  }
}

/// 使用者按「檢查更新」：Sparkle 會顯示結果（已是最新版 / 有新版 / 錯誤）
Future<void> checkForUpdates() async {
  if (!updaterAvailable) return;
  await autoUpdater.setFeedURL(appcastUrl);
  await autoUpdater.checkForUpdates();
}
