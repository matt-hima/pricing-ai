import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../app_state.dart';
import '../i18n/i18n.dart';
import '../llm.dart';
import '../market.dart' show marketSearchAvailable;
import '../service_pricing/service_plan.dart';
import '../service_pricing/suggest.dart';
import '../site/market_research.dart' show PriceRow, siteActionsFor;
import '../site/site_model.dart' show langs;
import 'market_dialog.dart';

/// サービス業の価格設計：原価から価格を計算 → 価目表をサイト（サービスと料金）に反映。
class ServicePricingPage extends StatefulWidget {
  final AppState state;
  const ServicePricingPage({super.key, required this.state});

  @override
  State<ServicePricingPage> createState() => _ServicePricingPageState();
}

const _industries = ['salon', 'restaurant', 'school', 'space', 'clinic', 'other'];
const _currencies = ['TWD', 'JPY', 'USD', 'EUR', 'GBP', 'CNY', 'HKD', 'KRW', 'SGD', 'AUD', 'CAD', 'MXN', 'BRL', 'THB'];
const _prefsKey = 'selfquote.service.plan';

class _ServicePricingPageState extends State<ServicePricingPage> {
  late ServicePlan plan;
  bool loaded = false;
  int rev = 0; // 行を作り直したいとき（読み込み・例の読み込み・AI 案）に増やす

  AppState get s => widget.state;

  @override
  void initState() {
    super.initState();
    plan = ServicePlan(siteLang: I18n.lang.name, rows: presetRows('salon', I18n.lang.name));
    _load();
  }

  Future<void> _load() async {
    try {
      final saved = ServicePlan.decode((await SharedPreferences.getInstance()).getString(_prefsKey));
      if (saved != null && mounted) {
        setState(() {
          plan = saved;
          rev++;
        });
      }
    } catch (_) {}
    if (mounted) setState(() => loaded = true);
  }

  Future<void> _save() async {
    try {
      await (await SharedPreferences.getInstance()).setString(_prefsKey, plan.encode());
    } catch (_) {}
  }

  void _changed() {
    setState(() {});
    _save();
  }

  void _loadExamples() {
    final d = currencyDefaults[plan.currency]!;
    plan
      ..rows = presetRows(plan.industry, plan.siteLang)
      ..roundTo = d.roundTo
      ..taxPct = d.tax
      ..taxIncluded = d.included;
    rev++;
    _changed();
  }

  void _setSiteLang(String l) {
    final untouched = rowsAreUntouchedPresets(plan.rows);
    plan.siteLang = l;
    if (untouched) plan.rows = presetRows(plan.industry, l);
    rev++;
    _changed();
  }

  void _setCurrency(String c) {
    final d = currencyDefaults[c]!;
    plan
      ..currency = c
      ..roundTo = d.roundTo
      ..taxPct = d.tax
      ..taxIncluded = d.included;
    rev++;
    _changed();
  }

  Future<void> _suggest() async {
    final business = tr('chat.industry.${plan.industry}', {}).replaceFirst(RegExp(r'^(an? )'), '');
    try {
      final rows = await s.withModel((ask) => suggestServices(ask: (a, b, c) => ask(a, b, schema: c), lang: I18n.lang, business: business));
      if (rows.isEmpty) throw StateError(tr('sp.aiEmpty'));
      plan.rows = rows;
      rev++;
      _changed();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(errText(e))));
    }
  }

  List<PriceRow> _priceRows(ServiceSummary sum) => [
        for (final r in sum.rows) PriceRow(r.name, minutesText(r.minutes, plan.siteLang), formatMoney(r.shownPrice, plan.currency)),
      ];

  void _addToSite(ServiceSummary sum) {
    if (sum.rows.length < 2) return;
    s.applyServicesToSite?.call(siteActionsFor(_priceRows(sum)), plan.siteLang);
  }

  void _csv(ServiceSummary sum) {
    String q(String v) => '"${v.replaceAll('"', '""')}"';
    final lines = [
      [tr('sp.name'), tr('sp.minutes'), tr('sp.materials'), tr('sp.cost'), tr('sp.price'), tr('sp.profit'), tr('sp.margin')].map(q).join(','),
      for (final r in sum.rows) [q(r.name), r.minutes, r.materials.toStringAsFixed(2), r.cost.toStringAsFixed(2), r.shownPrice.toStringAsFixed(2), r.profit.toStringAsFixed(2), r.marginPct.toStringAsFixed(1)].join(','),
    ];
    downloadText('service-prices.csv', '﻿${lines.join('\n')}\n', 'text/csv;charset=utf-8');
  }

  Widget _num(String label, double value, void Function(double) set, {String? suffix, double width = 150, String? help}) {
    return SizedBox(
      width: width,
      child: _NumField(
        key: ValueKey('$label-$rev'),
        label: label,
        value: value,
        suffix: suffix,
        help: help,
        onChanged: (v) {
          set(v);
          _changed();
        },
      ),
    );
  }

  Widget _card(BuildContext context, String title, Widget child, {String? sub}) {
    final t = Theme.of(context).textTheme;
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: t.titleMedium),
          if (sub != null) Padding(padding: const EdgeInsets.only(top: 2), child: Text(sub, style: t.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant))),
          const SizedBox(height: 12),
          child,
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final sum = computeServices(plan);
    String money(double v) => formatMoney(v, plan.currency);
    final ai = aiAvailable;
    return Scaffold(
      backgroundColor: cs.surfaceContainerLow,
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1000),
            child: ListView(padding: const EdgeInsets.fromLTRB(20, 20, 20, 40), children: [
              Text(tr('sp.title'), style: t.headlineSmall),
              const SizedBox(height: 4),
              Text(tr('sp.intro'), style: t.bodyMedium?.copyWith(color: cs.onSurfaceVariant)),
              const SizedBox(height: 16),
              _card(
                context,
                tr('sp.biz'),
                Wrap(spacing: 12, runSpacing: 12, crossAxisAlignment: WrapCrossAlignment.center, children: [
                  SizedBox(
                    width: 240,
                    child: DropdownButtonFormField<String>(
                      key: ValueKey('ind-${plan.industry}-$rev'),
                      initialValue: plan.industry,
                      decoration: InputDecoration(labelText: tr('sp.industry'), border: const OutlineInputBorder(), isDense: true),
                      items: [for (final i in _industries) DropdownMenuItem(value: i, child: Text(i == 'other' ? tr('sp.industry.other') : tr('chat.industry.$i').replaceFirst(RegExp(r'^(an? )'), '')))],
                      onChanged: (v) {
                        plan.industry = v ?? 'salon';
                        _loadExamples();
                      },
                    ),
                  ),
                  SizedBox(
                    width: 140,
                    child: DropdownButtonFormField<String>(
                      key: ValueKey('cur-${plan.currency}-$rev'),
                      initialValue: plan.currency,
                      decoration: InputDecoration(labelText: tr('sp.currency'), border: const OutlineInputBorder(), isDense: true),
                      items: [for (final c in _currencies) DropdownMenuItem(value: c, child: Text('$c  ${formatMoney(0, c).replaceAll(RegExp(r'[0-9.,]'), '')}'))],
                      onChanged: (v) => _setCurrency(v ?? 'TWD'),
                    ),
                  ),
                  SizedBox(
                    width: 170,
                    child: DropdownButtonFormField<String>(
                      key: ValueKey('lang-${plan.siteLang}-$rev'),
                      initialValue: langs.containsKey(plan.siteLang) ? plan.siteLang : 'en',
                      decoration: InputDecoration(labelText: tr('sp.siteLang'), border: const OutlineInputBorder(), isDense: true),
                      items: [for (final e in langs.entries) DropdownMenuItem(value: e.key, child: Text(e.value))],
                      onChanged: (v) => _setSiteLang(v ?? 'en'),
                    ),
                  ),
                  OutlinedButton.icon(onPressed: _loadExamples, icon: const Icon(Icons.restart_alt, size: 18), label: Text(tr('sp.examples'))),
                  if (ai) FilledButton.tonalIcon(onPressed: s.busy ? null : _suggest, icon: const Icon(Icons.auto_awesome, size: 18), label: Text(tr('sp.aiSuggest'))),
                  if (ai && marketSearchAvailable)
                    OutlinedButton.icon(
                      onPressed: () => showDialog<void>(context: context, builder: (_) => MarketDialog(state: s)),
                      icon: const Icon(Icons.travel_explore, size: 18),
                      label: Text(tr('mkt.button')),
                    ),
                ]),
                sub: ai ? null : tr('sp.webNote'),
              ),
              _card(
                context,
                tr('sp.costs'),
                Wrap(spacing: 12, runSpacing: 12, crossAxisAlignment: WrapCrossAlignment.center, children: [
                  _num(tr('sp.labor'), plan.laborPerHour, (v) => plan.laborPerHour = v, suffix: '${plan.currency}/h', width: 190, help: tr('sp.labor.help')),
                  _num(tr('sp.fixed'), plan.fixedPerMonth, (v) => plan.fixedPerMonth = v, suffix: plan.currency, width: 190, help: tr('sp.fixed.help')),
                  _num(tr('sp.hours'), plan.billableHoursPerMonth, (v) => plan.billableHoursPerMonth = v, suffix: 'h', width: 190, help: tr('sp.hours.help')),
                  _num(tr('sp.margin'), plan.marginPct, (v) => plan.marginPct = v.clamp(0, 90).toDouble(), suffix: '%', width: 130, help: tr('sp.margin.help')),
                  _num(tr('sp.tax'), plan.taxPct, (v) => plan.taxPct = v, suffix: '%', width: 110),
                  _num(tr('sp.round'), plan.roundTo, (v) => plan.roundTo = v, width: 120, help: tr('sp.round.help')),
                  FilterChip(label: Text(tr('sp.taxIncluded')), selected: plan.taxIncluded, onSelected: (v) {
                    plan.taxIncluded = v;
                    _changed();
                  }),
                ]),
              ),
              _card(
                context,
                tr('sp.services'),
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  for (var i = 0; i < plan.rows.length; i++)
                    _RowEditor(
                      key: ValueKey('row-$rev-$i'),
                      row: plan.rows[i],
                      result: i < sum.rows.length ? sum.rows[i] : null,
                      currency: plan.currency,
                      onChanged: _changed,
                      onDelete: () {
                        plan.rows.removeAt(i);
                        rev++;
                        _changed();
                      },
                    ),
                  const SizedBox(height: 4),
                  Wrap(spacing: 8, runSpacing: 8, children: [
                    OutlinedButton.icon(
                      onPressed: plan.rows.length >= 12
                          ? null
                          : () {
                              plan.rows.add(ServiceRow('', 60));
                              rev++;
                              _changed();
                            },
                      icon: const Icon(Icons.add, size: 18),
                      label: Text(tr('sp.addRow')),
                    ),
                  ]),
                  const SizedBox(height: 6),
                  Text(tr('sp.formula'), style: t.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
                ]),
                sub: tr('sp.services.sub'),
              ),
              _card(
                context,
                tr('sp.summary'),
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Wrap(spacing: 12, runSpacing: 12, children: [
                    _Stat(tr('sp.s.overhead'), '${money(sum.overheadPerHour)}/h'),
                    _Stat(tr('sp.s.avgHour'), '${money(sum.avgPricePerHourExTax)}/h'),
                    _Stat(tr('sp.s.breakEven'), sum.breakEvenHours == null ? tr('sp.s.never') : tr('sp.s.hoursMonth', {'h': sum.breakEvenHours!.toStringAsFixed(1)})),
                    _Stat(tr('sp.s.monthly'), money(sum.monthlyProfitAtPlan), bad: sum.monthlyProfitAtPlan < 0),
                  ]),
                  const SizedBox(height: 14),
                  Wrap(spacing: 8, runSpacing: 8, children: [
                    FilledButton.icon(
                      onPressed: s.applyServicesToSite == null || sum.rows.length < 2 ? null : () => _addToSite(sum),
                      icon: const Icon(Icons.web_outlined, size: 18),
                      label: Text(tr('sp.addToSite')),
                    ),
                    OutlinedButton.icon(onPressed: sum.rows.isEmpty ? null : () => _csv(sum), icon: const Icon(Icons.download, size: 18), label: Text(tr('sp.csv'))),
                  ]),
                  const SizedBox(height: 8),
                  Text(tr('sp.disclaimer'), style: t.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
                ]),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final String label, value;
  final bool bad;
  const _Stat(this.label, this.value, {this.bad = false});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    return Container(
      width: 210,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: cs.surfaceContainerHighest.withValues(alpha: .5), borderRadius: BorderRadius.circular(10)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: t.labelSmall?.copyWith(color: cs.onSurfaceVariant)),
        const SizedBox(height: 4),
        Text(value, style: t.titleMedium?.copyWith(color: bad ? cs.error : null)),
      ]),
    );
  }
}

class _NumField extends StatefulWidget {
  final String label;
  final double value;
  final String? suffix, help;
  final void Function(double) onChanged;
  const _NumField({super.key, required this.label, required this.value, required this.onChanged, this.suffix, this.help});

  @override
  State<_NumField> createState() => _NumFieldState();
}

class _NumFieldState extends State<_NumField> {
  late final c = TextEditingController(text: _fmt(widget.value));

  static String _fmt(double v) => v == v.roundToDouble() ? '${v.round()}' : '$v';

  @override
  void dispose() {
    c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Tooltip(
        message: widget.help ?? '',
        child: TextField(
          controller: c,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(labelText: widget.label, suffixText: widget.suffix, border: const OutlineInputBorder(), isDense: true),
          onChanged: (v) {
            final n = double.tryParse(v.replaceAll(',', '').trim());
            if (n != null && n >= 0) widget.onChanged(n);
          },
        ),
      );
}

class _RowEditor extends StatefulWidget {
  final ServiceRow row;
  final ServiceResult? result;
  final String currency;
  final VoidCallback onChanged, onDelete;
  const _RowEditor({super.key, required this.row, required this.result, required this.currency, required this.onChanged, required this.onDelete});

  @override
  State<_RowEditor> createState() => _RowEditorState();
}

class _RowEditorState extends State<_RowEditor> {
  late final name = TextEditingController(text: widget.row.name);
  late final minutes = TextEditingController(text: '${widget.row.minutes}');
  late final materials = TextEditingController(text: widget.row.materials == 0 ? '' : '${widget.row.materials}');
  late final price = TextEditingController(text: widget.row.priceOverride == null ? '' : '${widget.row.priceOverride}');

  @override
  void dispose() {
    for (final c in [name, minutes, materials, price]) {
      c.dispose();
    }
    super.dispose();
  }

  InputDecoration _dec(String label, {String? hint}) => InputDecoration(labelText: label, hintText: hint, border: const OutlineInputBorder(), isDense: true);

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final r = widget.result;
    final losing = r != null && r.profit < 0;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Wrap(spacing: 8, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
        SizedBox(width: 220, child: TextField(controller: name, decoration: _dec(tr('sp.name')), onChanged: (v) {
          widget.row.name = v;
          widget.onChanged();
        })),
        SizedBox(width: 90, child: TextField(controller: minutes, keyboardType: TextInputType.number, decoration: _dec(tr('sp.minutes')), onChanged: (v) {
          final n = int.tryParse(v.trim());
          if (n != null && n > 0) {
            widget.row.minutes = n;
            widget.onChanged();
          }
        })),
        SizedBox(width: 110, child: TextField(controller: materials, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: _dec(tr('sp.materials')), onChanged: (v) {
          widget.row.materials = double.tryParse(v.replaceAll(',', '').trim()) ?? 0;
          widget.onChanged();
        })),
        SizedBox(width: 120, child: TextField(controller: price, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: _dec(tr('sp.myPrice'), hint: r == null ? null : formatMoney(r.shownPrice, widget.currency)), onChanged: (v) {
          final n = double.tryParse(v.replaceAll(',', '').trim());
          widget.row.priceOverride = n != null && n > 0 ? n : null;
          widget.onChanged();
        })),
        if (r != null) ...[
          SizedBox(width: 110, child: Text('${tr('sp.cost')}\n${formatMoney(r.cost, widget.currency)}', style: t.bodySmall)),
          SizedBox(width: 120, child: Text('${tr('sp.price')}\n${formatMoney(r.shownPrice, widget.currency)}', style: t.titleSmall)),
          SizedBox(width: 130, child: Text('${tr('sp.profit')}\n${formatMoney(r.profit, widget.currency)} (${r.marginPct.toStringAsFixed(0)}%)', style: t.bodySmall?.copyWith(color: losing ? cs.error : Colors.teal))),
        ],
        IconButton(tooltip: tr('set.delete'), onPressed: widget.onDelete, icon: const Icon(Icons.close, size: 18)),
      ]),
    );
  }
}
