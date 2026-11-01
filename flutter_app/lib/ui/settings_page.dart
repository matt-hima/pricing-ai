import 'package:flutter/material.dart';

import '../app_state.dart';
import '../config.dart';
import '../engine/engine_info.dart';
import '../engine_admin.dart';
import '../i18n/i18n.dart';
import 'engine_storage.dart';
import 'get_app.dart';

/// 設定：管理本機模型（文字 / 圖片）、記憶體上限與閒置卸載、存放位置。只有桌面版有本機模型。
class SettingsPage extends StatefulWidget {
  final AppState state;
  const SettingsPage({super.key, required this.state});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  EngineSnapshot? snap;
  String? error;
  double? limit; // 拖曳中的值

  AppState get s => widget.state;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    if (!engineAdminAvailable) return;
    try {
      final v = await engineSnapshot();
      if (mounted) setState(() => snap = v);
    } catch (e) {
      if (mounted) setState(() => error = errText(e));
    }
  }

  String _gb(num mb) => (mb / 1024).toStringAsFixed(1);

  Future<bool> _confirm(String message) async =>
      await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
          content: Text(message),
          actions: [
            TextButton(onPressed: () => Navigator.pop(c, false), child: Text(tr('btn.cancel'))),
            FilledButton(onPressed: () => Navigator.pop(c, true), child: Text(tr('set.yes'))),
          ],
        ),
      ) ??
      false;

  /// 下載與刪除都先讓使用者確認（檔案很大，而且會佔用磁碟）
  Future<void> _run(String label, Future<void> Function(void Function(double, String)) job) async {
    try {
      await s.withBusy(label, (prog) => job(prog));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(errText(e))));
    }
    await _refresh();
  }

  Widget _section(BuildContext context, String title, List<Widget> children) {
    final t = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: t.titleMedium),
        const SizedBox(height: 8),
        ...children,
      ]),
    );
  }

  Widget _row(BuildContext context, {required String title, required String detail, required bool selected, required bool installed, required bool fits, VoidCallback? onUse, VoidCallback? onDownload, VoidCallback? onDelete, bool? radio}) {
    final t = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final busy = s.busy;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 8, 12, 8),
        child: Row(children: [
          if (radio != false)
            Radio<bool>(value: true, groupValue: selected, onChanged: installed && fits && !busy ? (_) => onUse?.call() : null)
          else
            const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: t.bodyMedium),
              Text(detail, style: t.bodySmall?.copyWith(color: fits ? cs.onSurfaceVariant : cs.error)),
            ]),
          ),
          if (installed) ...[
            Chip(label: Text(tr('set.installed')), visualDensity: VisualDensity.compact),
            IconButton(tooltip: tr('set.delete'), onPressed: busy ? null : onDelete, icon: const Icon(Icons.delete_outline)),
          ] else
            FilledButton.tonalIcon(onPressed: busy || !fits ? null : onDownload, icon: const Icon(Icons.download, size: 18), label: Text(tr('set.download'))),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: Text(tr('set.title'))),
      body: ListenableBuilder(
        listenable: s,
        builder: (context, _) {
          if (!engineAdminAvailable) {
            return Padding(padding: const EdgeInsets.all(20), child: Align(alignment: Alignment.topLeft, child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 520), child: const GetAppCard())));
          }
          final v = snap;
          if (v == null) return Center(child: error == null ? const CircularProgressIndicator() : Text(error!));
          final mem = v.memory;
          final pct = (limit ?? v.limitPct.toDouble()).round();
          final budgetMB = mem == null ? null : mem.totalMB * pct / 100;
          bool fits(int need) => fitsBudget(need, mem, pct);
          return ListView(padding: const EdgeInsets.all(20), children: [
            if (s.busy) ...[
              LinearProgressIndicator(value: s.progress > 0 && s.progress < 1 ? s.progress : null),
              Padding(padding: const EdgeInsets.symmetric(vertical: 6), child: Text(s.progressText, style: t.labelSmall)),
              const SizedBox(height: 8),
            ],
            _section(context, tr('set.memory'), [
              if (mem != null) Text(tr('set.memInfo', {'total': _gb(mem.totalMB), 'free': _gb(mem.availableMB)}), style: t.bodyMedium),
              const SizedBox(height: 4),
              Text(tr('set.limit', {'pct': '$pct', 'gb': budgetMB == null ? '?' : _gb(budgetMB)}), style: t.bodyMedium),
              Slider(
                min: 30,
                max: 95,
                divisions: 13,
                value: pct.toDouble().clamp(30, 95),
                label: '$pct%',
                onChanged: (x) => setState(() => limit = x),
                onChangeEnd: (x) async {
                  await setMemoryLimit(x.round());
                  limit = null;
                  await _refresh();
                },
              ),
              Text(tr('set.limitHelp'), style: t.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
              const SizedBox(height: 12),
              Wrap(spacing: 12, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
                Text(tr('set.idle')),
                DropdownButton<int>(
                  value: const [0, 5, 10, 30, 60].contains(v.idleMinutes) ? v.idleMinutes : 10,
                  items: [for (final m in const [0, 5, 10, 30, 60]) DropdownMenuItem(value: m, child: Text(m == 0 ? tr('set.idleNever') : tr('set.idleMin', {'n': '$m'})))],
                  onChanged: (m) async {
                    await setIdleMinutes(m ?? 10);
                    await _refresh();
                  },
                ),
                OutlinedButton.icon(
                  onPressed: s.busy
                      ? null
                      : () async {
                          await unloadAll();
                          await _refresh();
                          if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(tr('set.unloaded'))));
                        },
                  icon: const Icon(Icons.memory_outlined, size: 18),
                  label: Text(tr('set.unload')),
                ),
                Text(v.textRunning ? tr('set.loaded') : tr('set.notLoaded'), style: t.bodySmall),
              ]),
            ]),
            _section(context, tr('set.textModels'), [
              for (final m in v.textModels)
                _row(
                  context,
                  title: modelOptions.firstWhere((o) => o.base == m.base, orElse: () => ModelOption(m.base, m.base)).label,
                  detail: fits(m.needMB) ? tr('set.needs', {'gb': _gb(m.needMB), 'mb': '${m.sizeMB}'}) : tr('set.tooBig', {'gb': _gb(m.needMB)}),
                  selected: s.modelBase == m.base,
                  installed: m.installed,
                  fits: fits(m.needMB),
                  onUse: () {
                    s.setModel(m.base);
                    setState(() {});
                  },
                  onDownload: () async {
                    if (await _confirm(tr('set.confirmDl', {'name': m.base, 'mb': '${m.sizeMB}', 'host': 'huggingface.co'}))) {
                      await _run(tr('set.download'), (p) => downloadTextModel(m.base, p));
                    }
                  },
                  onDelete: () async {
                    if (await _confirm(tr('set.confirmDelete', {'name': m.base}))) {
                      await deleteTextModel(m.base);
                      await _refresh();
                    }
                  },
                ),
            ]),
            _section(context, tr('set.imageModels'), [
              Text(tr('set.imageHelp'), style: t.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
              const SizedBox(height: 8),
              if (!v.imageSupported)
                Text(tr('set.imgUnsupported'), style: t.bodyMedium)
              else ...[
                _row(
                  context,
                  title: tr('set.imgEngine'),
                  detail: v.imageEngineInstalled ? tr('set.imgEngineReady') : tr('set.imgEngineMissing', {'mb': '36'}),
                  selected: false,
                  installed: v.imageEngineInstalled,
                  fits: true,
                  radio: false,
                  onDownload: () async {
                    if (await _confirm(tr('set.confirmDl', {'name': 'stable-diffusion.cpp', 'mb': '36', 'host': 'github.com'}))) {
                      await _run(tr('set.download'), (p) => downloadImageEngine(p));
                    }
                  },
                  onDelete: null,
                ),
                for (final m in v.imageModels)
                  _row(
                    context,
                    title: m.label,
                    detail: '${fits(m.needMB) ? tr('set.needs', {'gb': _gb(m.needMB), 'mb': '${m.sizeMB}'}) : tr('set.tooBig', {'gb': _gb(m.needMB)})} · ${tr('set.license', {'l': m.license})}',
                    selected: v.imageModelId == m.id,
                    installed: m.installed,
                    fits: fits(m.needMB),
                    onUse: () async {
                      await setSelectedImageModel(m.id);
                      await _refresh();
                    },
                    onDownload: () async {
                      if (await _confirm(tr('set.confirmDl', {'name': m.label, 'mb': '${m.sizeMB}', 'host': 'huggingface.co'}))) {
                        await _run(tr('set.download'), (p) => downloadImageModel(m.id, p));
                      }
                    },
                    onDelete: () async {
                      if (await _confirm(tr('set.confirmDelete', {'name': m.label}))) {
                        await deleteImageModel(m.id);
                        await _refresh();
                      }
                    },
                  ),
              ],
            ]),
            _section(context, tr('eng.storage'), [const EngineStorageTile()]),
          ]);
        },
      ),
    );
  }
}
