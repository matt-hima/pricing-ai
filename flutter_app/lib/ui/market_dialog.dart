import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../app_state.dart';
import '../i18n/i18n.dart';
import '../site/market_research.dart';

/// 市場行情：輸入行業與地區 → 網路搜尋 + 本機模型整理成價目表 → 可修改 → 加到網站的服務與價格
class MarketDialog extends StatefulWidget {
  final AppState state;
  const MarketDialog({super.key, required this.state});

  @override
  State<MarketDialog> createState() => _MarketDialogState();
}

class _MarketDialogState extends State<MarketDialog> {
  final business = TextEditingController();
  final area = TextEditingController();
  MarketResult? result;
  List<List<TextEditingController>> cells = [];
  String? error;
  bool running = false;

  AppState get s => widget.state;

  @override
  void dispose() {
    business.dispose();
    area.dispose();
    for (final r in cells) {
      for (final c in r) {
        c.dispose();
      }
    }
    super.dispose();
  }

  Future<void> _search() async {
    if (business.text.trim().isEmpty) return;
    setState(() {
      running = true;
      error = null;
      result = null;
    });
    try {
      final r = await s.researchMarket(business.text.trim(), area.text.trim());
      cells = [for (final x in r.rows) [TextEditingController(text: x.name), TextEditingController(text: x.sub), TextEditingController(text: x.price)]];
      if (mounted) setState(() => result = r);
    } catch (e) {
      if (mounted) setState(() => error = errText(e));
    } finally {
      if (mounted) setState(() => running = false);
    }
  }

  List<PriceRow> _rows() => [for (final c in cells) PriceRow(c[0].text, c[1].text, c[2].text)];

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    return AlertDialog(
      title: Text(tr('mkt.title')),
      content: SizedBox(
        width: 640,
        child: SingleChildScrollView(
          child: ListenableBuilder(
            listenable: s,
            builder: (context, _) => Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(tr('mkt.intro'), style: t.bodySmall),
              const SizedBox(height: 12),
              Wrap(spacing: 12, runSpacing: 8, children: [
                SizedBox(width: 280, child: TextField(controller: business, decoration: InputDecoration(labelText: tr('mkt.business'), hintText: tr('mkt.businessHint'), border: const OutlineInputBorder(), isDense: true))),
                SizedBox(width: 200, child: TextField(controller: area, decoration: InputDecoration(labelText: tr('mkt.area'), hintText: tr('mkt.areaHint'), border: const OutlineInputBorder(), isDense: true))),
                FilledButton.icon(onPressed: running || s.busy ? null : _search, icon: const Icon(Icons.travel_explore, size: 18), label: Text(tr('mkt.search'))),
              ]),
              if (running) ...[
                const SizedBox(height: 12),
                const LinearProgressIndicator(),
                Padding(padding: const EdgeInsets.only(top: 6), child: Text(s.progressText, style: t.labelSmall)),
              ],
              if (error != null) Padding(padding: const EdgeInsets.only(top: 12), child: Text(error!, style: t.bodyMedium?.copyWith(color: cs.error))),
              if (result != null) ...[
                const SizedBox(height: 16),
                for (var i = 0; i < cells.length; i++)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(children: [
                      Expanded(flex: 4, child: _cell(cells[i][0], tr('mkt.name'))),
                      const SizedBox(width: 6),
                      Expanded(flex: 3, child: _cell(cells[i][1], tr('mkt.sub'))),
                      const SizedBox(width: 6),
                      Expanded(flex: 3, child: _cell(cells[i][2], tr('mkt.price'))),
                      IconButton(
                        tooltip: tr('set.delete'),
                        onPressed: () => setState(() {
                          for (final c in cells.removeAt(i)) {
                            c.dispose();
                          }
                        }),
                        icon: const Icon(Icons.close, size: 18),
                      ),
                    ]),
                  ),
                const SizedBox(height: 8),
                Text(tr('mkt.note'), style: t.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
                const SizedBox(height: 8),
                Text(tr('mkt.sources'), style: t.labelMedium),
                for (final h in result!.sources.take(5))
                  InkWell(
                    onTap: () => launchUrl(Uri.parse(h.url)),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Text('${Uri.parse(h.url).host} — ${h.title}', style: t.bodySmall?.copyWith(color: cs.primary, decoration: TextDecoration.underline), maxLines: 1, overflow: TextOverflow.ellipsis),
                    ),
                  ),
              ],
            ]),
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(tr('mkt.close'))),
        if (result != null && cells.length >= 2 && s.applyServicesToSite != null)
          FilledButton.icon(
            icon: const Icon(Icons.web_outlined, size: 18),
            label: Text(tr('mkt.add')),
            onPressed: () {
              s.applyServicesToSite!(siteActionsFor(_rows()));
              Navigator.pop(context);
            },
          ),
      ],
    );
  }

  Widget _cell(TextEditingController c, String label) => TextField(controller: c, decoration: InputDecoration(labelText: label, border: const OutlineInputBorder(), isDense: true));
}
