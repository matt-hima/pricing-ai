import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';

import '../i18n/i18n.dart';
import '../llm.dart';

/// 桌面版：顯示並更改 AI 引擎與模型的存放位置（可選外接硬碟）
class EngineStorageTile extends StatefulWidget {
  final bool disabled;
  const EngineStorageTile({super.key, this.disabled = false});

  @override
  State<EngineStorageTile> createState() => _EngineStorageTileState();
}

class _EngineStorageTileState extends State<EngineStorageTile> {
  String path = '';
  bool custom = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final s = await engineStorage();
    if (mounted) {
      setState(() {
        path = s.path;
        custom = s.custom;
      });
    }
  }

  Future<void> _change() async {
    final dir = await getDirectoryPath(confirmButtonText: tr('eng.change'));
    if (dir == null) return;
    await setEngineStorage(dir);
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(tr('eng.storage'), style: t.labelMedium),
      const SizedBox(height: 2),
      Tooltip(
        message: path,
        child: Text(path, style: t.bodySmall?.copyWith(color: cs.onSurfaceVariant), maxLines: 2, overflow: TextOverflow.ellipsis),
      ),
      Wrap(spacing: 4, children: [
        TextButton.icon(
          style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
          onPressed: widget.disabled ? null : _change,
          icon: const Icon(Icons.drive_folder_upload_outlined, size: 18),
          label: Text(tr('eng.change')),
        ),
        if (custom)
          TextButton(
            style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
            onPressed: widget.disabled
                ? null
                : () async {
                    await setEngineStorage(null);
                    await _load();
                  },
            child: Text(tr('eng.useDefault')),
          ),
      ]),
    ]);
  }
}
