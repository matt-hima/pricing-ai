import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app_state.dart';
import '../config.dart';
import '../i18n/i18n.dart';
import '../models.dart';
import 'web_utils.dart';

/// 左欄：Dolibarr「新增報價單」卡片，四個分頁
class FormPanel extends StatefulWidget {
  final AppState state;
  final VoidCallback onEstimate;
  final void Function(String) onToast;
  const FormPanel({super.key, required this.state, required this.onEstimate, required this.onToast});

  @override
  State<FormPanel> createState() => _FormPanelState();
}

class _FormPanelState extends State<FormPanel> with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 4, vsync: this, initialIndex: 1);
  bool _firstVisitHandled = false;

  AppState get s => widget.state;
  Quote get q => s.q;

  @override
  void initState() {
    super.initState();
    _tabs.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  void _go(int i) => _tabs.animateTo(i);

  @override
  Widget build(BuildContext context) {
    // 首次使用：先填寫自己的公司資料
    if (!_firstVisitHandled && s.gpuChecked) {
      _firstVisitHandled = true;
      if (q.myName.isEmpty) WidgetsBinding.instance.addPostFrameCallback((_) => _go(0));
    }
    final t = Theme.of(context).textTheme;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(tr('form.breadcrumb'), style: t.bodySmall),
      const SizedBox(height: 4),
      Text(tr('form.title'), style: t.titleLarge),
      const SizedBox(height: 12),
      Card(
        clipBehavior: Clip.antiAlias,
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          TabBar(
            controller: _tabs,
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            tabs: [Tab(text: tr('tab.me')), Tab(text: tr('tab.card')), Tab(text: tr('tab.spec')), Tab(text: tr('tab.note'))],
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(16),
            // 重設時 ref 改變，key 改變讓所有欄位以新值重建
            child: KeyedSubtree(
              key: ValueKey('${s.formKey}-${_tabs.index}'),
              child: [_me, _card, _spec, _note][_tabs.index](),
            ),
          ),
        ]),
      ),
    ]);
  }

  /* ---------- 共用欄位 ---------- */

  Widget _section(String title) => Padding(
        padding: const EdgeInsets.only(top: 8, bottom: 12),
        child: Text(title,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(color: Theme.of(context).colorScheme.primary)),
      );

  Widget _text(String label, String value, void Function(String) onChanged,
      {bool required = false,
      String? hint,
      int maxLines = 1,
      TextInputType? keyboard,
      int? maxLength,
      bool invalidate = true,
      List<TextInputFormatter>? formatters}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        initialValue: value,
        maxLines: maxLines,
        minLines: maxLines > 1 ? 2 : 1,
        keyboardType: keyboard,
        maxLength: maxLength,
        inputFormatters: formatters,
        decoration: InputDecoration(labelText: required ? '$label *' : label, hintText: hint, counterText: ''),
        onChanged: (v) => s.update((_) => onChanged(v.trim()), invalidate: invalidate),
      ),
    );
  }

  Widget _number(String label, double value, void Function(double) onChanged, {String? suffix}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        initialValue: fmtNum(value),
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
        decoration: InputDecoration(labelText: label, suffixText: suffix),
        onChanged: (v) {
          final n = double.tryParse(v);
          if (n != null) s.update((_) => onChanged(n));
        },
      ),
    );
  }

  Widget _select<T>(String label, T value, Map<T, String> items, void Function(T) onChanged) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: DropdownButtonFormField<T>(
        initialValue: items.containsKey(value) ? value : items.keys.first,
        isExpanded: true,
        decoration: InputDecoration(labelText: label),
        items: [for (final e in items.entries) DropdownMenuItem(value: e.key, child: Text(e.value))],
        onChanged: (v) => v == null ? null : s.update((_) => onChanged(v)),
      ),
    );
  }

  Widget _next(int to, String label, {int? back}) => Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [
          if (back != null) ...[OutlinedButton(onPressed: () => _go(back), child: Text(tr('btn.prev'))), const SizedBox(width: 8)],
          FilledButton(onPressed: () => _go(to), child: Text(label)),
        ]),
      );

  /* ---------- 0 · 我的公司 ---------- */

  Widget _me() {
    final digits = [FilteringTextInputFormatter.digitsOnly];
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      _section(tr('sec.company')),
      _text(tr('f.myName'), q.myName, (v) => q.myName = v, required: true, hint: tr('h.myName'), invalidate: false),
      _text(tr('f.taxId'), q.myTaxId, (v) => q.myTaxId = v,
          hint: tr('h.taxId'), maxLength: 8, keyboard: TextInputType.number, formatters: digits, invalidate: false),
      _text(tr('f.address'), q.myAddress, (v) => q.myAddress = v, invalidate: false),
      _text(tr('f.phone'), q.myPhone, (v) => q.myPhone = v, keyboard: TextInputType.phone, invalidate: false),
      _text(tr('f.myEmail'), q.myEmail, (v) => q.myEmail = v,
          hint: tr('h.myEmail'), keyboard: TextInputType.emailAddress, invalidate: false),
      Row(children: [
        OutlinedButton.icon(
          icon: const Icon(Icons.image_outlined),
          label: Text(tr(q.logo.isEmpty ? 'f.logoUpload' : 'f.logoChange')),
          onPressed: () async {
            final r = await pickImageDataUrl(maxBytes: 300 * 1024);
            if (r.error != null) widget.onToast(r.error!);
            if (r.dataUrl != null) {
              s.update((q) => q.logo = r.dataUrl!, invalidate: false);
              widget.onToast(tr('msg.logoUpdated'));
            }
          },
        ),
        const SizedBox(width: 8),
        if (q.logo.isNotEmpty)
          TextButton(onPressed: () => s.update((q) => q.logo = '', invalidate: false), child: Text(tr('f.logoRemove'))),
      ]),
      Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Text(tr('f.logoHint'), style: Theme.of(context).textTheme.bodySmall),
      ),
      const SizedBox(height: 12),
      _section(tr('sec.pricing')),
      _number(tr('f.rate'), q.rate, (v) => q.rate = v, suffix: 'TWD'),
      _number(tr('f.hpm'), q.hoursPerMM, (v) => q.hoursPerMM = v.clamp(1, 400), suffix: tr('u.hours')),
      _number(tr('f.vat'), q.vatPct, (v) => q.vatPct = v.clamp(0, 100), suffix: '%'),
      _number(tr('f.warranty'), q.warrantyMonths, (v) => q.warrantyMonths = v.roundToDouble(), suffix: tr('u.months')),
      Row(children: [
        Expanded(child: _number(tr('f.maintMin'), q.maintMinPct, (v) => q.maintMinPct = v, suffix: '%')),
        const SizedBox(width: 8),
        Expanded(child: _number(tr('f.maintMax'), q.maintMaxPct, (v) => q.maintMaxPct = v, suffix: '%')),
      ]),
      Text(tr('f.localNote'), style: Theme.of(context).textTheme.bodySmall),
      _next(1, tr('btn.next.card')),
    ]);
  }

  /* ---------- 1 · 報價卡片 ---------- */

  Widget _card() {
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      _section(tr('sec.client')),
      _text(tr('f.company'), q.company, (v) => q.company = v, required: true, hint: tr('h.company')),
      _text(tr('f.taxId'), q.taxId, (v) => q.taxId = v,
          hint: tr('h.taxIdOpt'), maxLength: 8, keyboard: TextInputType.number, formatters: [FilteringTextInputFormatter.digitsOnly]),
      _text(tr('f.contact'), q.contact, (v) => q.contact = v, required: true),
      _text(tr('f.clientEmail'), q.email, (v) => q.email = v, keyboard: TextInputType.emailAddress),
      _text(tr('f.phone'), q.phone, (v) => q.phone = v, keyboard: TextInputType.phone),
      _text(tr('f.refClient'), q.refClient, (v) => q.refClient = v, hint: tr('h.refClient')),
      _section(tr('sec.terms')),
      _text(tr('f.project'), q.project, (v) => q.project = v, hint: tr('h.project')),
      Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: InkWell(
          onTap: () async {
            final d = await showDatePicker(
                context: context, initialDate: q.date, firstDate: DateTime(2020), lastDate: DateTime(2100));
            if (d != null) s.update((q) => q.date = d, invalidate: false);
          },
          child: InputDecorator(
            decoration: InputDecoration(labelText: tr('f.date'), suffixIcon: const Icon(Icons.calendar_today, size: 18)),
            child: Text(fmtDate(q.date)),
          ),
        ),
      ),
      _select<int>(tr('f.validity'), q.validityDays,
          {for (final d in [7, 14, 30, 45, 60, 90]) d: tr('f.validityOpt', {'d': '$d', 'date': fmtDate(q.date.add(Duration(days: d)))})},
          (v) => q.validityDays = v),
      _select(tr('f.payTerm'), q.payTerm, payTerms, (v) => q.payTerm = v),
      _select(tr('f.payMode'), q.payMode, payModes, (v) => q.payMode = v),
      _select(tr('f.urgency'), q.urgency, urgencies, (v) => q.urgency = v),
      _select(tr('f.budget'), q.budget, budgets, (v) => q.budget = v),
      _select(tr('f.source'), q.source, sources, (v) => q.source = v),
      _next(2, tr('btn.next.spec'), back: 0),
    ]);
  }

  /* ---------- 2 · 平台與模組 ---------- */

  Widget _choice(List<Option> opts, bool Function(String) selected, void Function(String) onTap, {bool multi = false}) {
    return Wrap(spacing: 8, runSpacing: 8, children: [
      for (final o in opts)
        multi
            ? FilterChip(label: Text(o.name), selected: selected(o.id), onSelected: (_) => onTap(o.id))
            : ChoiceChip(label: Text(o.name), selected: selected(o.id), onSelected: (_) => onTap(o.id)),
    ]);
  }

  Widget _spec() {
    final cs = Theme.of(context).colorScheme;
    final bothApps = q.platforms.contains('ios') && q.platforms.contains('android');
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      _section(tr('sec.type')),
      _choice(projectTypes, (id) => q.type == id, (id) => s.update((q) => q.type = id)),
      const SizedBox(height: 16),
      _section(tr('sec.platform')),
      _choice(platforms, q.platforms.contains, (id) {
        s.update((q) => q.platforms.contains(id) ? q.platforms.remove(id) : q.platforms.add(id));
      }, multi: true),
      if (bothApps) ...[
        const SizedBox(height: 8),
        Text(tr('spec.techHint'), style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 8),
        _choice(appTechs, (id) => q.appTech == id, (id) => s.update((q) => q.appTech = id)),
      ],
      const SizedBox(height: 16),
      _section(tr('sec.design')),
      _choice(designLevels, (id) => q.design == id, (id) => s.update((q) => q.design = id)),
      const SizedBox(height: 16),
      Row(children: [
        _section(tr('sec.modules')),
        const SizedBox(width: 8),
        Chip(label: Text(tr('spec.aiHint')), visualDensity: VisualDensity.compact, labelStyle: Theme.of(context).textTheme.labelSmall),
      ]),
      for (final m in modules)
        Padding(
          key: ValueKey(m.id),
          padding: const EdgeInsets.only(bottom: 8),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: q.modules.containsKey(m.id) ? cs.primary : cs.outlineVariant),
              color: q.modules.containsKey(m.id) ? cs.primaryContainer.withValues(alpha: .25) : null,
            ),
            child: Column(children: [
              CheckboxListTile(
                dense: true,
                value: q.modules.containsKey(m.id),
                controlAffinity: ListTileControlAffinity.leading,
                title: Text(m.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                subtitle: Text(m.desc),
                onChanged: (on) => s.update((q) => on == true ? q.modules[m.id] = '' : q.modules.remove(m.id)),
              ),
              if (q.modules.containsKey(m.id))
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                  child: TextFormField(
                    initialValue: q.modules[m.id],
                    maxLines: 3,
                    minLines: 1,
                    decoration: InputDecoration(hintText: m.hint, labelText: tr('f.moduleNote')),
                    onChanged: (v) => s.update((q) => q.modules[m.id] = v.trim()),
                  ),
                ),
            ]),
          ),
        ),
      _next(3, tr('btn.next.note'), back: 1),
    ]);
  }

  /* ---------- 3 · 備註 ---------- */

  Widget _note() {
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      _section(tr('sec.summary')),
      _text(tr('f.summary'), q.summary, (v) => q.summary = v, maxLines: 6, hint: tr('h.summary')),
      _section(tr('sec.extra')),
      _text(tr('f.extra'), q.extra, (v) => q.extra = v, maxLines: 4, hint: tr('h.extra')),
      _section(tr('sec.refsite')),
      _text(tr('f.refsite'), q.refSite, (v) => q.refSite = v, hint: tr('h.refsite'), keyboard: TextInputType.url, invalidate: false),
      Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [
          OutlinedButton(onPressed: () => _go(2), child: Text(tr('btn.prev'))),
          const SizedBox(width: 8),
          FilledButton.icon(
            onPressed: s.busy ? null : widget.onEstimate,
            icon: const Icon(Icons.auto_awesome),
            label: Text(s.busy ? s.busyLabel : tr('btn.estimate')),
          ),
        ]),
      ),
    ]);
  }
}
