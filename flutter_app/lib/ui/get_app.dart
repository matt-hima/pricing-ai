import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../i18n/i18n.dart';

/// 下載 Mac / Windows App 的頁面（官網的下載區，依介面語言開對應的語言版）。
/// 測試或自訂發行位置時可用 --dart-define=DESKTOP_DOWNLOAD_URL=… 覆寫。
const _downloadOverride = String.fromEnvironment('DESKTOP_DOWNLOAD_URL');
const _site = 'https://pricingai.minervaelectronics.com';

String get desktopDownloadUrl {
  if (_downloadOverride.isNotEmpty) return _downloadOverride;
  final path = I18n.lang == Lang.en ? '/' : '/${I18n.lang.name}/';
  return '$_site$path#download';
}

void openDesktopDownload() {
  launchUrl(Uri.parse(desktopDownloadUrl), webOnlyWindowName: '_blank');
}

/// 網頁版沒有 AI：說明原因並指向 Mac / Windows App 的下載頁
class GetAppCard extends StatelessWidget {
  final bool compact;
  const GetAppCard({super.key, this.compact = false});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: cs.primaryContainer.withValues(alpha: .5), borderRadius: BorderRadius.circular(12)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(Icons.memory, size: 20, color: cs.primary),
          const SizedBox(width: 8),
          Expanded(child: Text(tr('web.getAppTitle'), style: t.titleSmall)),
        ]),
        if (!compact) ...[
          const SizedBox(height: 8),
          Text(tr('web.getAppBody'), style: t.bodySmall),
        ],
        const SizedBox(height: 10),
        FilledButton.icon(onPressed: openDesktopDownload, icon: const Icon(Icons.download), label: Text(tr('web.getApp'))),
      ]),
    );
  }
}
