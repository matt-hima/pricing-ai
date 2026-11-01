import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app_state.dart';
import '../config.dart';
import '../i18n/i18n.dart';
import '../llm.dart';
import 'engine_storage.dart';
import 'get_app.dart';
import 'web_utils.dart';

/// 右欄：AI 評估引擎與動作
class Sidebar extends StatelessWidget {
  final AppState state;
  final VoidCallback onEstimate;
  final void Function(String) onToast;
  const Sidebar({super.key, required this.state, required this.onEstimate, required this.onToast});

  @override
  Widget build(BuildContext context) {
    final s = state, q = s.q;
    final t = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;

    Widget card(String title, List<Widget> children) => Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Text(title.toUpperCase(), style: t.labelMedium?.copyWith(color: cs.onSurfaceVariant, letterSpacing: 1)),
              const SizedBox(height: 12),
              ...children,
            ]),
          ),
        );
    const gap = SizedBox(height: 8);

    final engineAi = card(tr('side.engine'), [
      DropdownButtonFormField<String>(
        key: ValueKey('${s.modelBase}-${s.gpu.ok}-${s.gpuChecked}'),
        initialValue: s.modelBase,
        isExpanded: true,
        decoration: InputDecoration(labelText: tr(nativeEngine ? 'eng.sideModel' : 'side.model')),
        items: [for (final m in s.availableModels) DropdownMenuItem(value: m.base, child: Text(m.label, overflow: TextOverflow.ellipsis))],
        onChanged: s.busy ? null : (v) => s.setModel(v!),
      ),
      gap,
      Text(
        !s.gpuChecked
            ? tr('side.checking')
            : s.gpu.ok
                ? tr(nativeEngine ? 'eng.cacheHint' : 'side.cacheHint')
                : tr('side.noGpu', {'reason': s.gpu.reasonText}),
        style: t.bodySmall,
      ),
      if (nativeEngine) ...[gap, EngineStorageTile(disabled: s.busy)],
      if (s.usingCpuModel) ...[
        gap,
        Text(tr('side.cpuNote'), style: t.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
      ],
      gap,
      ClipRRect(
        borderRadius: BorderRadius.circular(99),
        child: LinearProgressIndicator(
          value: s.busy && s.progress == 0 ? null : s.progress,
          minHeight: 6,
          backgroundColor: cs.surfaceContainerHighest,
        ),
      ),
      const SizedBox(height: 4),
      Text(s.progressText, style: t.labelSmall?.copyWith(color: cs.onSurfaceVariant), maxLines: 3, overflow: TextOverflow.ellipsis),
      const SizedBox(height: 12),
      FilledButton.icon(
        onPressed: s.busy ? null : onEstimate,
        icon: s.busy
            ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
            : const Icon(Icons.auto_awesome),
        label: Text(s.busy ? s.busyLabel : tr('btn.estimate')),
      ),
      gap,
      OutlinedButton(
        onPressed: s.busy
            ? null
            : () {
                s.useRules();
                onToast(tr('msg.rulesRerun'));
              },
        child: Text(tr('side.rulesOnly')),
      ),
    ]);

    // 網頁版沒有 AI：引擎卡片換成「下載 Mac / Windows App」的說明
    final engine = aiAvailable ? engineAi : card(tr('side.engine'), const [GetAppCard()]);

    final actions = card(tr('side.actions'), [
      FilledButton.tonalIcon(
        icon: s.pdfBusy
            ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
            : const Icon(Icons.picture_as_pdf_outlined),
        label: Text(s.pdfBusy ? s.pdfStatus : tr('btn.pdf')),
        onPressed: s.pdfBusy ? null : () async => onToast(await s.buildPdf()),
      ),
      gap,
      OutlinedButton.icon(
        icon: const Icon(Icons.content_copy),
        label: Text(tr('btn.copy')),
        onPressed: () async {
          await Clipboard.setData(ClipboardData(text: s.summaryText()));
          onToast(tr('msg.copied'));
        },
      ),
      gap,
      OutlinedButton.icon(
        icon: const Icon(Icons.download),
        label: Text(tr('btn.json')),
        onPressed: () => downloadText('${q.ref}.json', s.exportJson(), 'application/json'),
      ),
      gap,
      Tooltip(
        message: q.myEmail.isEmpty ? tr('tip.mail') : '',
        child: OutlinedButton.icon(
          icon: const Icon(Icons.mail_outline),
          label: Text(tr('btn.mail')),
          onPressed: q.myEmail.isEmpty
              ? null
              : () {
                  final to = q.myEmail.replaceAll(RegExp(r'[?&#\s]'), '');
                  final subject = Uri.encodeComponent(tr('mail.subject', {'ref': q.ref, 'company': q.company}));
                  openUrl('mailto:$to?subject=$subject&body=${Uri.encodeComponent(s.summaryText())}');
                },
        ),
      ),
      gap,
      TextButton.icon(
        icon: const Icon(Icons.restart_alt),
        label: Text(tr('btn.reset')),
        onPressed: () async {
          final ok = await showDialog<bool>(
            context: context,
            builder: (c) => AlertDialog(
              title: Text(tr('dlg.resetTitle')),
              content: Text(tr('dlg.resetBody')),
              actions: [
                TextButton(onPressed: () => Navigator.pop(c, false), child: Text(tr('btn.cancel'))),
                FilledButton(onPressed: () => Navigator.pop(c, true), child: Text(tr('btn.clear'))),
              ],
            ),
          );
          if (ok == true) s.reset();
        },
      ),
    ]);

    final about = card(tr('side.about'), [
      Text(tr('side.aboutBody'), style: t.bodySmall),
    ]);

    return LayoutBuilder(builder: (context, c) {
      // 每張卡片至少 300px 寬，放得下就並排
      final perRow = (c.maxWidth / 300).floor().clamp(1, 3);
      if (perRow > 1 && c.maxWidth < 1000) {
        final w = (c.maxWidth - 12 * (perRow - 1)) / perRow;
        return Wrap(spacing: 12, runSpacing: 12, children: [
          for (final card in [engine, actions, about]) SizedBox(width: w, child: card),
        ]);
      }
      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        engine,
        const SizedBox(height: 14),
        actions,
        const SizedBox(height: 14),
        about,
      ]);
    });
  }
}
