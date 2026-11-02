import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../i18n/i18n.dart';
import '../updater.dart';

/// 版本號（來自 pubspec.yaml）與「檢查更新」按鈕；網頁版只顯示版本號
class AppUpdateTile extends StatelessWidget {
  const AppUpdateTile({super.key});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    return FutureBuilder<PackageInfo>(
      future: PackageInfo.fromPlatform(),
      builder: (context, snap) => Wrap(crossAxisAlignment: WrapCrossAlignment.center, spacing: 4, children: [
        if (snap.hasData) Text(tr('upd.version', {'version': snap.data!.version}), style: t.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
        if (updaterAvailable)
          TextButton.icon(
            style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
            onPressed: checkForUpdates,
            icon: const Icon(Icons.system_update_alt, size: 18),
            label: Text(tr('upd.check')),
          ),
      ]),
    );
  }
}
