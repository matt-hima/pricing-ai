import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../app_state.dart';
import '../config.dart';
import '../estimator.dart';
import '../i18n/i18n.dart';
import '../models.dart';

Uint8List? logoBytes(String dataUrl) {
  final i = dataUrl.indexOf(',');
  if (i < 0) return null;
  try {
    return base64Decode(dataUrl.substring(i + 1));
  } catch (_) {
    return null;
  }
}

/// 中欄：報價單紙張（invoice 生成網站樣式）
class QuotePaper extends StatelessWidget {
  final AppState state;
  const QuotePaper({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    final q = state.q, e = state.estimate, p = state.pricing, ai = state.ai;
    final cs = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    final muted = t.bodySmall?.copyWith(color: cs.onSurfaceVariant);

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 900),
        child: Material(
          color: cs.surface,
          elevation: 1,
          borderRadius: BorderRadius.circular(6),
          child: LayoutBuilder(builder: (context, c) {
            final narrow = c.maxWidth < 600;
            final pad = narrow ? 16.0 : (c.maxWidth < 760 ? 24.0 : 40.0);
            return Padding(
              padding: EdgeInsets.all(pad),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                // ===== 抬頭 =====
                Flex(
                  direction: narrow ? Axis.vertical : Axis.horizontal,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _company(context, q, muted),
                    if (narrow) const SizedBox(height: 20),
                    Column(crossAxisAlignment: narrow ? CrossAxisAlignment.start : CrossAxisAlignment.end, children: [
                      Text(I18n.lang.isCjk ? tr('q.title') : tr('q.title').toUpperCase(),
                          style: t.headlineMedium?.copyWith(fontWeight: FontWeight.w300, letterSpacing: I18n.lang.isCjk ? 4 : 2)),
                      Text(q.ref, style: t.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                      const SizedBox(height: 6),
                      Chip(
                        avatar: Icon(ai != null ? Icons.verified : Icons.edit_note, size: 16),
                        label: Text(tr(ai != null ? 'q.statusAI' : 'q.statusRules')),
                        side: BorderSide(color: ai != null ? Colors.teal : cs.outlineVariant),
                        visualDensity: VisualDensity.compact,
                      ),
                    ]),
                  ],
                ),
                const SizedBox(height: 24),

                // ===== 對象與條件 =====
                Flex(
                  direction: narrow ? Axis.vertical : Axis.horizontal,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _flex(narrow, _client(context, q, muted)),
                    SizedBox(width: 20, height: narrow ? 16 : 0),
                    _flex(
                        narrow,
                        Column(children: [
                          _kv(context, tr('q.date'), fmtDate(q.date)),
                          _kv(context, tr('q.validUntil'), fmtDate(q.date.add(Duration(days: q.validityDays)))),
                          _kv(context, tr('q.refClient'), q.refClient.isEmpty ? '—' : q.refClient),
                          _kv(context, tr('q.payTerm'), payTerms[q.payTerm] ?? ''),
                          _kv(context, tr('q.payMode'), payModes[q.payMode] ?? q.payMode),
                          _kv(context, tr('q.delivery'),
                              e.totalHours > 0 ? tr('unit.months', {'a': '${p.monthsLow}', 'b': '${p.monthsHigh}'}) : '—'),
                        ])),
                  ],
                ),
                const SizedBox(height: 24),

                // ===== 明細 =====
                _lines(context, q, p),
                const SizedBox(height: 16),

                // ===== 合計 =====
                Flex(
                  direction: narrow ? Axis.vertical : Axis.horizontal,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _flex(narrow, _note(context, q, state, muted)),
                    SizedBox(width: 24, height: narrow ? 16 : 0),
                    SizedBox(width: narrow ? double.infinity : 340, child: _totals(context, q, p)),
                  ],
                ),

                // ===== 1. 總價範圍 =====
                _h2(context, tr('s.range')),
                Wrap(spacing: 10, runSpacing: 10, children: [
                  _kpi(context, tr('kpi.total'), '${money(p.ht)} – ${money(p.htHigh)}'),
                  _kpi(context, tr('kpi.complexity'), tr('cx.${p.complexity}')),
                  _kpi(context, tr('kpi.hours'), tr('kpi.hoursV', {'mm': '${p.mm}', 'h': '${e.totalHours.round()}'})),
                  _kpi(context, tr('kpi.schedule'),
                      tr('kpi.scheduleV', {'a': '${p.monthsLow}', 'b': '${p.monthsHigh}', 'n': '${p.team}'})),
                ]),

                // ===== 2. 人月拆解 =====
                _h2(context, tr('s.mm')),
                ..._mmBreakdown(context, q, e, muted),

                // ===== 3. 維護 =====
                _h2(context, tr('s.maint')),
                ..._maintenance(q, p).map((x) => _bullet(context, x.$1, x.$2)),

                if (ai != null) ...[
                  Flex(
                    direction: narrow ? Axis.vertical : Axis.horizontal,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _flex(narrow, Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                        _h2(context, tr('as.title')),
                        for (final a in ai.assumptions) _bullet(context, null, a),
                      ])),
                      SizedBox(width: 20, height: narrow ? 0 : 0),
                      _flex(narrow, Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                        _h2(context, tr('risks.title')),
                        for (final r in ai.risks) _bullet(context, null, r),
                      ])),
                    ],
                  ),
                ],

                // ===== 免責條款 =====
                const SizedBox(height: 28),
                _terms(context, p.buffer, muted),
                const SizedBox(height: 32),
                Row(children: [
                  Expanded(child: _sign(context, tr('sign.company'))),
                  const SizedBox(width: 24),
                  Expanded(child: _sign(context, tr('sign.client'))),
                ]),
              ]),
            );
          }),
        ),
      ),
    );
  }

  /// 免責條款：標題 + 六條條款 + 風險係數說明
  Widget _terms(BuildContext context, double buffer, TextStyle? muted) {
    final t = Theme.of(context).textTheme;
    final clauses = disclaimerClauses();
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.amber.withValues(alpha: .12),
        border: const Border(left: BorderSide(color: Colors.amber, width: 4)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(Icons.warning_amber_rounded, size: 18, color: Colors.amber.shade800),
          const SizedBox(width: 6),
          Text(tr('terms.title'), style: t.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
        ]),
        const SizedBox(height: 8),
        for (var i = 0; i < clauses.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Text.rich(TextSpan(style: t.bodySmall, children: [
              TextSpan(text: '${i + 1}. ${clauses[i].title}  ', style: const TextStyle(fontWeight: FontWeight.w700)),
              TextSpan(text: clauses[i].body),
            ])),
          ),
        const SizedBox(height: 2),
        Text(tr('terms.buffer', {'b': '${buffer}'}), style: muted),
      ]),
    );
  }

  static List<(String?, String)> _maintenance(Quote q, Pricing p) => [
        (tr('m.warranty.l'), tr('m.warranty.v', {'n': fmtNum(q.warrantyMonths)})),
        (
          tr('m.sla.l'),
          tr('m.sla.v', {
            'a': fmtNum(q.maintMinPct),
            'b': fmtNum(q.maintMaxPct),
            'lo': money(p.maintLow),
            'hi': money(p.maintHigh),
            'mlo': money(p.maintLow / 12),
            'mhi': money(p.maintHigh / 12),
          })
        ),
        (tr('m.incl.l'), tr('m.incl.v')),
        (tr('m.excl.l'), tr('m.excl.v')),
      ];

  Widget _flex(bool narrow, Widget child) => narrow ? child : Expanded(child: child);

  Widget _company(BuildContext context, Quote q, TextStyle? muted) {
    final cs = Theme.of(context).colorScheme;
    final bytes = q.logo.isEmpty ? null : logoBytes(q.logo);
    final info = [
      if (q.myTaxId.isNotEmpty) tr('q.taxId', {'v': q.myTaxId}),
      if (q.myAddress.isNotEmpty) q.myAddress,
      [q.myPhone, q.myEmail].where((x) => x.isNotEmpty).join(' · '),
    ].where((x) => x.isNotEmpty);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      if (bytes != null)
        ConstrainedBox(constraints: const BoxConstraints(maxHeight: 56, maxWidth: 180), child: Image.memory(bytes))
      else
        Container(
          width: 52,
          height: 52,
          alignment: Alignment.center,
          decoration: BoxDecoration(color: const Color(0xFF263C5C), borderRadius: BorderRadius.circular(10)),
          child: Text(q.myName.isEmpty ? '₪' : q.myName.characters.first,
              style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800)),
        ),
      const SizedBox(height: 8),
      q.myName.isEmpty
          ? Text(tr('q.noCompany'), style: muted)
          : Text(q.myName, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
      for (final i in info) Text(i, style: muted?.copyWith(color: cs.onSurfaceVariant)),
    ]);
  }

  Widget _client(BuildContext context, Quote q, TextStyle? muted) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      constraints: const BoxConstraints(minHeight: 100),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(border: Border.all(color: cs.outlineVariant), borderRadius: BorderRadius.circular(4)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(tr('q.to'), style: muted?.copyWith(letterSpacing: 1)),
        const SizedBox(height: 4),
        if (q.company.isEmpty)
          Text(tr('q.noClient'), style: muted)
        else
          Text(q.company, style: const TextStyle(fontWeight: FontWeight.w700)),
        if (q.taxId.isNotEmpty) Text(tr('q.taxId', {'v': q.taxId})),
        if (q.contact.isNotEmpty) Text(tr('q.contact', {'v': q.contact})),
        if (q.email.isNotEmpty) Text(q.email),
        if (q.phone.isNotEmpty) Text(q.phone),
        if (q.project.isNotEmpty) Text(tr('q.project', {'v': q.project})),
      ]),
    );
  }

  Widget _kv(BuildContext context, String k, String v) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(child: Text(k, style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant))),
          Flexible(child: Text(v, textAlign: TextAlign.right)),
        ]),
      );

  Widget _lines(BuildContext context, Quote q, Pricing p) {
    final cs = Theme.of(context).colorScheme;
    final vat = '${fmtNum(q.vatPct)}%';
    const head = TextStyle(fontWeight: FontWeight.w600, fontSize: 12);
    TableRow row(List<Widget> cells, {Color? color}) => TableRow(
          decoration: BoxDecoration(color: color, border: Border(bottom: BorderSide(color: cs.outlineVariant))),
          children: [for (final c in cells) Padding(padding: const EdgeInsets.all(8), child: c)],
        );
    Widget num(String s, {TextStyle? style}) => Text(s, textAlign: TextAlign.right, style: style);

    final rows = <TableRow>[
      row([
        Text(tr('th.desc'), style: head),
        num(tr('th.tax'), style: head),
        num(tr('th.unit'), style: head),
        num(tr('th.qty'), style: head),
        Text(tr('th.uom'), style: head),
        num(tr('th.disc'), style: head),
        num(tr('th.sub'), style: head),
      ], color: cs.surfaceContainerHighest),
    ];
    var i = 0;
    for (final l in p.lines) {
      if (l.group != null) {
        rows.add(TableRow(
          decoration: BoxDecoration(border: Border(bottom: BorderSide(color: cs.primary))),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 14, 8, 6),
              child: Text(l.group!, style: TextStyle(color: cs.primary, fontWeight: FontWeight.w700, fontSize: 12)),
            ),
            for (var k = 0; k < 6; k++) const SizedBox.shrink(),
          ],
        ));
        continue;
      }
      rows.add(row([
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Flexible(child: Text(l.name, style: const TextStyle(fontWeight: FontWeight.w600))),
            if (l.ai) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(color: cs.primaryContainer, borderRadius: BorderRadius.circular(3)),
                child: Text('AI', style: TextStyle(fontSize: 10, color: cs.onPrimaryContainer, fontWeight: FontWeight.w700)),
              ),
            ],
          ]),
          Text('${l.sub} · ${tr('unit.hoursApprox', {'n': '${l.hours.round()}'})}', style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
        ]),
        num(vat),
        num(money(p.rate)),
        num(l.qty.toStringAsFixed(2)),
        Text(tr('unit.pm')),
        num('0%'),
        num(money(l.subtotal)),
      ], color: (i++).isOdd ? cs.surfaceContainerLow : null));
    }
    if (p.lines.isEmpty) {
      rows.add(TableRow(children: [
        Padding(
          padding: const EdgeInsets.all(24),
          child: Text(tr('q.empty'), style: TextStyle(color: cs.onSurfaceVariant)),
        ),
        for (var k = 0; k < 6; k++) const SizedBox.shrink(),
      ]));
    }

    final table = Table(
      columnWidths: const {
        0: FlexColumnWidth(),
        1: IntrinsicColumnWidth(),
        2: IntrinsicColumnWidth(),
        3: IntrinsicColumnWidth(),
        4: IntrinsicColumnWidth(),
        5: IntrinsicColumnWidth(),
        6: IntrinsicColumnWidth(),
      },
      defaultVerticalAlignment: TableCellVerticalAlignment.top,
      children: rows,
    );
    return LayoutBuilder(builder: (context, c) {
      if (c.maxWidth >= 520) return table;
      return SingleChildScrollView(scrollDirection: Axis.horizontal, child: SizedBox(width: 680, child: table));
    });
  }

  Widget _note(BuildContext context, Quote q, AppState s, TextStyle? muted) {
    Widget line(String k, String v) => Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Text.rich(TextSpan(style: muted, children: [
            TextSpan(text: k, style: const TextStyle(fontWeight: FontWeight.w700)),
            TextSpan(text: v),
          ])),
        );
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      line(tr('n.type'), byId(projectTypes, q.type, 1).name),
      line(tr('n.platform'), s.platformLabel()),
      line(tr('n.design'), byId(designLevels, q.design, 1).name),
      if (q.summary.isNotEmpty) line(tr('n.summary'), q.summary),
      if (q.extra.isNotEmpty) line(tr('n.extra'), q.extra),
      if (q.urgency == 'rush') line(tr('n.rush'), tr('n.rushV')),
      if (q.urgency == 'flex') line(tr('n.flex'), tr('n.flexV')),
    ]);
  }

  Widget _totals(BuildContext context, Quote q, Pricing p) {
    final cs = Theme.of(context).colorScheme;
    Widget r(String k, String v, {bool grand = false, bool accent = false}) => Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: grand ? cs.surfaceContainerHighest : null,
            border: Border(bottom: BorderSide(color: cs.outlineVariant)),
          ),
          child: Row(children: [
            Expanded(child: Text(k, style: TextStyle(fontWeight: grand || accent ? FontWeight.w700 : null, color: accent ? cs.primary : null))),
            Text(v,
                style: TextStyle(
                    fontWeight: grand || accent ? FontWeight.w700 : null,
                    fontSize: grand ? 16 : null,
                    color: accent ? cs.primary : null)),
          ]),
        );
    return Column(children: [
      r(tr('t.net'), money(p.ht)),
      r(tr('t.vat', {'rate': '${fmtNum(q.vatPct)}%'}), money(p.vat)),
      r(tr('t.gross'), money(p.ttc), grand: true),
      r(tr('t.range'), '${money(p.ttc)} – ${money(p.ttcHigh)}', accent: true),
    ]);
  }

  Widget _h2(BuildContext context, String s) => Container(
        margin: const EdgeInsets.only(top: 28, bottom: 10),
        padding: const EdgeInsets.only(bottom: 6),
        decoration: BoxDecoration(border: Border(bottom: BorderSide(color: Theme.of(context).colorScheme.onSurface, width: 2))),
        child: Text(s, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
      );

  Widget _kpi(BuildContext context, String k, String v) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      constraints: const BoxConstraints(minWidth: 180),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(border: Border.all(color: cs.outlineVariant), borderRadius: BorderRadius.circular(6)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
        Text(k, style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant)),
        const SizedBox(height: 2),
        Text(v, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
      ]),
    );
  }

  List<Widget> _mmBreakdown(BuildContext context, Quote q, Estimate e, TextStyle? muted) {
    if (e.totalHours == 0) return [Text(tr('s.none'), style: muted)];
    final cs = Theme.of(context).colorScheme;
    final groups = mmGroups(e);
    return [
      for (final g in groups.where((g) => g.hours > 0))
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(children: [
              Expanded(child: Text(g.name, style: const TextStyle(fontWeight: FontWeight.w700))),
              Text(tr('unit.mm', {'mm': (g.hours / q.hoursPerMM).toStringAsFixed(2), 'h': '${g.hours.round()}'})),
            ]),
            const SizedBox(height: 4),
            ClipRRect(
              borderRadius: BorderRadius.circular(99),
              child: LinearProgressIndicator(value: g.hours / e.totalHours, minHeight: 6, backgroundColor: cs.surfaceContainerHighest),
            ),
            for (final t in g.tasks)
              Padding(
                padding: const EdgeInsets.only(left: 18, top: 3),
                child: Row(children: [
                  Expanded(child: Text(t.name, style: muted)),
                  Text(tr('unit.hours', {'n': '${t.hours.round()}'}), style: muted),
                ]),
              ),
            const SizedBox(height: 6),
            Divider(height: 1, color: cs.outlineVariant),
          ]),
        ),
    ];
  }

  Widget _bullet(BuildContext context, String? bold, String text) => Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('•  '),
          Expanded(
            child: Text.rich(TextSpan(children: [
              if (bold != null) TextSpan(text: bold, style: const TextStyle(fontWeight: FontWeight.w700)),
              TextSpan(text: text),
            ])),
          ),
        ]),
      );

  Widget _sign(BuildContext context, String label) => Container(
        padding: const EdgeInsets.only(top: 6),
        decoration: BoxDecoration(border: Border(top: BorderSide(color: Theme.of(context).colorScheme.onSurface))),
        child: Text(label, style: Theme.of(context).textTheme.bodySmall),
      );
}

/// 人月拆解分組（報價單與 PDF 共用）
List<({String name, double hours, List<Task> tasks})> mmGroups(Estimate e) {
  final ph = e.phases;
  // 依模組列出前後端工時（子項目名稱顯示於報價明細）
  final fe = [for (final m in e.all) if (m.fe > 0) Task(m.name, 'fe', m.fe)];
  final be = [
    for (final m in e.all) if (m.be > 0) Task(m.name, 'be', m.be),
    if (e.infra > 0) Task(tr('mm.infraTask'), 'be', e.infra),
  ];
  return [
    (name: tr('mm.design'), hours: ph.analysis + ph.design, tasks: [
      Task(tr('line.analysis.n'), '', ph.analysis),
      Task(tr('line.design.n'), '', ph.design),
    ]),
    (name: tr('mm.fe'), hours: ph.frontend, tasks: fe),
    (name: tr('mm.be'), hours: ph.backend, tasks: be),
    (name: tr('mm.qa'), hours: ph.qa, tasks: const <Task>[]),
    (name: tr('mm.pm'), hours: ph.pm, tasks: const <Task>[]),
  ];
}
