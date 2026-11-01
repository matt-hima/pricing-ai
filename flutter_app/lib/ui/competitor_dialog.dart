import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../case_analysis/pcc.dart';
import '../i18n/i18n.dart';
import '../service_pricing/service_plan.dart' show formatMoney;
import 'case_browser_dialog.dart';

/// 競爭對手的公開紀錄：一打開就在 App 內的瀏覽器查這家廠商近 12 個月的「得標」與「投標」決標公告，
/// 算出得標件數、投標件數、得標率、得標金額、常往來的機關；也可以用 Google AI 模式查公司的公開資訊。
class CompetitorDialog extends StatefulWidget {
  final String name, taxId, keyword;
  final CaseCollect collect;
  const CompetitorDialog({super.key, required this.name, this.taxId = '', this.keyword = '', this.collect = openCaseBrowser});

  @override
  State<CompetitorDialog> createState() => _CompetitorDialogState();
}

class _CompetitorDialogState extends State<CompetitorDialog> {
  VendorProfile? profile;
  bool running = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _run();
    });
  }

  Future<void> _run() async {
    if (running) return;
    setState(() => running = true);
    try {
      final r = await widget.collect(context, CaseQuery.vendor(widget.name), doneLabel: tr('comp.useRecord'));
      if (r != null && mounted) setState(() => profile = VendorProfile.of(widget.name, r));
    } finally {
      if (mounted) setState(() => running = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final p = profile;
    final st = p?.stats;
    String money(double v) => formatMoney(v, 'TWD');
    return AlertDialog(
      title: Text(widget.name),
      content: SizedBox(
        width: 640,
        child: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            if (widget.taxId.isNotEmpty) Text(tr('comp.taxId', {'id': widget.taxId}), style: t.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
            const SizedBox(height: 8),
            Text(tr('comp.intro'), style: t.bodySmall),
            const SizedBox(height: 12),
            Wrap(spacing: 8, runSpacing: 8, children: [
              FilledButton.tonalIcon(onPressed: running ? null : _run, icon: const Icon(Icons.history, size: 18), label: Text(p == null ? tr('comp.run') : tr('comp.rerun'))),
              OutlinedButton.icon(
                onPressed: () => openGoogleAiMode(context, tr('case.google.companyQuery', {'name': widget.name, 'id': widget.taxId})),
                icon: const Icon(Icons.travel_explore, size: 18),
                label: Text(tr('comp.google')),
              ),
              if (widget.keyword.isNotEmpty)
                OutlinedButton.icon(
                  onPressed: () => openGoogleAiMode(context, tr('comp.google.vsQuery', {'name': widget.name, 'k': widget.keyword})),
                  icon: const Icon(Icons.manage_search, size: 18),
                  label: Text(tr('comp.google.vs', {'k': widget.keyword})),
                ),
            ]),
            if (p != null) ...[
              const SizedBox(height: 16),
              Wrap(spacing: 12, runSpacing: 12, children: [
                _tile(context, tr('comp.wins'), '${p.wins}'),
                _tile(context, tr('comp.bids'), '${p.bids}'),
                _tile(context, tr('comp.rate'), p.winRate == null ? '—' : '${p.winRate!.round()}%'),
                if (st != null) _tile(context, tr('comp.median'), money(st.median)),
              ]),
              if (st != null) ...[
                const SizedBox(height: 14),
                Text(tr('case.topAgencies'), style: t.titleSmall),
                for (final e in st.topAgencies) Text('${e.key}  ·  ${tr('case.nCases', {'n': '${e.value}'})}', style: t.bodySmall),
                const SizedBox(height: 14),
                Text(tr('comp.recent'), style: t.titleSmall),
                for (final c in ([...p.wonCases]..sort((a, b) => (b.date ?? DateTime(0)).compareTo(a.date ?? DateTime(0)))).take(8))
                  InkWell(
                    onTap: () => launchUrl(Uri.parse(c.url)),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 3),
                      child: Row(children: [
                        Expanded(child: Text('${c.name}  ·  ${c.agency}', style: t.bodySmall?.copyWith(color: cs.primary), maxLines: 1, overflow: TextOverflow.ellipsis)),
                        const SizedBox(width: 8),
                        Text(money(c.amount), style: t.bodySmall),
                      ]),
                    ),
                  ),
              ],
              const SizedBox(height: 10),
              Text(tr('comp.note'), style: t.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
            ],
          ]),
        ),
      ),
      actions: [TextButton(onPressed: () => Navigator.pop(context), child: Text(tr('mkt.close')))],
    );
  }

  Widget _tile(BuildContext context, String label, String value) {
    final t = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    return Container(
      width: 140,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: cs.surfaceContainerHighest.withValues(alpha: .5), borderRadius: BorderRadius.circular(10)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: t.labelSmall?.copyWith(color: cs.onSurfaceVariant)),
        const SizedBox(height: 4),
        Text(value, style: t.titleMedium),
      ]),
    );
  }
}
