import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

import '../case_analysis/page_reader.dart';
import '../case_analysis/site_profile_store.dart';
import '../i18n/i18n.dart';

/// 學習新網站：使用者在內嵌瀏覽器打開一頁（清單或公告）→ 說這是哪一種頁面 → 本機 AI 對應欄位 →
/// 使用者看讀到的內容、需要就改 → 儲存。之後同一個網站同一種頁面由程式直接讀，不用 AI。
/// App 只讀使用者打開的那一頁，不會自己去點別的頁面；網站要求驗證時由使用者自己完成。
typedef ProposeMapping = Future<PageMapping> Function(PageDigest page, PageKind kind);

Future<void> openSiteLearn(BuildContext context, {required ProposeMapping propose, String? modelTip, Uri? start}) => showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => SiteLearnDialog(propose: propose, modelTip: modelTip, start: start),
    );

class SiteLearnDialog extends StatefulWidget {
  final ProposeMapping propose;
  final String? modelTip;
  final Uri? start;
  const SiteLearnDialog({super.key, required this.propose, this.modelTip, this.start});

  @override
  State<SiteLearnDialog> createState() => _SiteLearnDialogState();
}

class _SiteLearnDialogState extends State<SiteLearnDialog> {
  InAppWebViewController? web;
  final address = TextEditingController();
  bool loading = false, canBack = false, canForward = false;
  SiteProfileStore? store;

  @override
  void initState() {
    super.initState();
    address.text = widget.start?.toString() ?? '';
    SiteProfileStore.load().then((s) {
      if (mounted) setState(() => store = s);
    });
  }

  @override
  void dispose() {
    address.dispose();
    super.dispose();
  }

  void _go() {
    var u = address.text.trim();
    if (u.isEmpty) return;
    if (!u.contains('://')) u = 'https://$u';
    web?.loadUrl(urlRequest: URLRequest(url: WebUri(u)));
  }

  Future<(String, Uri)?> _current() async {
    final c = web;
    if (c == null) return null;
    final html = await c.getHtml();
    final url = await c.getUrl();
    if (html == null || url == null) return null;
    return (html, Uri.parse(url.toString()));
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Dialog(
      insetPadding: const EdgeInsets.all(24),
      clipBehavior: Clip.antiAlias,
      child: SizedBox(
        width: 1280,
        height: 860,
        child: Column(children: [
          Material(
            color: cs.surfaceContainerHigh,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 6, 12, 6),
              child: Row(children: [
                IconButton(tooltip: tr('case.browser.back'), onPressed: canBack ? () => web?.goBack() : null, icon: const Icon(Icons.arrow_back)),
                IconButton(tooltip: tr('case.browser.forward'), onPressed: canForward ? () => web?.goForward() : null, icon: const Icon(Icons.arrow_forward)),
                IconButton(tooltip: tr('case.browser.reload'), onPressed: () => web?.reload(), icon: const Icon(Icons.refresh)),
                const SizedBox(width: 6),
                Expanded(
                  child: TextField(
                    key: const ValueKey('learn.address'),
                    controller: address,
                    decoration: InputDecoration(labelText: tr('learn.address'), isDense: true, border: const OutlineInputBorder()),
                    onSubmitted: (_) => _go(),
                  ),
                ),
                const SizedBox(width: 6),
                FilledButton.tonal(onPressed: _go, child: Text(tr('learn.go'))),
                const SizedBox(width: 12),
                Text(tr('learn.title'), style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(width: 12),
                TextButton(onPressed: () => Navigator.pop(context), child: Text(tr('mkt.close'))),
              ]),
            ),
          ),
          if (loading) const LinearProgressIndicator(minHeight: 2),
          Expanded(
            child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Expanded(
                child: InAppWebView(
                  initialUrlRequest: widget.start == null ? null : URLRequest(url: WebUri(widget.start.toString())),
                  initialSettings: InAppWebViewSettings(javaScriptEnabled: true, supportMultipleWindows: true, isInspectable: kDebugMode),
                  onWebViewCreated: (c) => web = c,
                  onLoadStart: (c, url) {
                    if (mounted) setState(() => loading = true);
                  },
                  onLoadStop: (c, url) async {
                    final b = await c.canGoBack(), f = await c.canGoForward();
                    if (!mounted) return;
                    setState(() {
                      loading = false;
                      canBack = b;
                      canForward = f;
                      if (url != null) address.text = url.toString();
                    });
                  },
                  onCreateWindow: (c, action) async {
                    final u = action.request.url;
                    if (u != null) c.loadUrl(urlRequest: URLRequest(url: u));
                    return false;
                  },
                ),
              ),
              Container(
                width: 400,
                decoration: BoxDecoration(border: Border(left: BorderSide(color: cs.outlineVariant))),
                child: store == null ? const Center(child: CircularProgressIndicator()) : SiteLearnPanel(current: _current, store: store!, propose: widget.propose, modelTip: widget.modelTip, open: (u) => web?.loadUrl(urlRequest: URLRequest(url: WebUri(u)))),
              ),
            ]),
          ),
        ]),
      ),
    );
  }
}

/// 右邊的面板（和瀏覽器分開，測試時直接給頁面）
class SiteLearnPanel extends StatefulWidget {
  final Future<(String html, Uri url)?> Function() current;
  final SiteProfileStore store;
  final ProposeMapping propose;
  final String? modelTip;
  final void Function(String url)? open; // 在瀏覽器打開清單裡的一件
  const SiteLearnPanel({super.key, required this.current, required this.store, required this.propose, this.modelTip, this.open});

  @override
  State<SiteLearnPanel> createState() => _SiteLearnPanelState();
}

const _learnKinds = [PageKind.tenderList, PageKind.awardList, PageKind.tenderNotice, PageKind.awardNotice];

class _SiteLearnPanelState extends State<SiteLearnPanel> {
  PageDigest? page;
  Uri? url;
  PageKind? kind;
  PageMapping? mapping;
  PageRead? known; // 學過的頁面：用設定檔直接讀到的
  bool reading = false, busy = false;
  String? error, saved;

  SiteProfile? get profile => url == null ? null : widget.store.of(url!.host);

  Future<void> _read() async {
    setState(() {
      reading = true;
      error = saved = null;
    });
    final cur = await widget.current();
    if (!mounted) return;
    setState(() {
      reading = false;
      if (cur == null) return;
      final (html, u) = cur;
      url = u;
      page = digestPage(html, base: u);
      final p = widget.store.of(u.host);
      final k = p.kindOf(u);
      // 學過的頁面：用設定檔直接讀（必要欄位讀不全就當沒學過，例如這次是驗證頁）
      final m = k == null ? null : PageMapping(k, labels: {...?p.labels[k]}, columns: {...?p.columns[k]});
      known = m != null && m.complete(page!) ? m.read(page!) : null;
      kind = k;
      mapping = m;
    });
  }

  void _pickKind(PageKind k) => setState(() {
        kind = k;
        saved = null;
        final p = profile!;
        mapping = PageMapping(k, labels: {...?p.labels[k]}, columns: {...?p.columns[k]});
      });

  Future<void> _map() async {
    setState(() {
      busy = true;
      error = saved = null;
    });
    try {
      final m = await widget.propose(page!, kind!);
      if (mounted) setState(() => mapping = m);
    } catch (e) {
      if (mounted) setState(() => error = tr('learn.error', {'e': '$e'}));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _save() async {
    final p = profile!..confirm(url!, mapping!);
    await widget.store.save(p);
    if (mounted) setState(() => saved = tr('learn.saved', {'host': url!.host}));
  }

  Future<void> _forget() async {
    await widget.store.forget(url!.host);
    if (mounted) {
      setState(() {
        known = null;
        saved = null;
        mapping = kind == null ? null : PageMapping(kind!);
      });
    }
  }

  String _kindName(PageKind k) => tr('learn.kind.${k.name}');

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final d = page;
    final m = mapping;
    final hasStructure = d != null && (d.mainTable != null || d.labels.length >= 4);
    final p = profile;
    Widget note(String s, {Color? color}) => Padding(padding: const EdgeInsets.only(top: 6), child: Text(s, style: t.bodySmall?.copyWith(color: color ?? cs.onSurfaceVariant)));
    return ListView(padding: const EdgeInsets.all(14), children: [
      Text(tr('learn.intro'), style: t.bodyMedium),
      note(tr('learn.privacy')),
      if (widget.modelTip != null) note(widget.modelTip!, color: cs.tertiary),
      const SizedBox(height: 10),
      Align(
        alignment: Alignment.centerLeft,
        child: FilledButton.icon(
          key: const ValueKey('learn.read'),
          onPressed: reading ? null : _read,
          icon: reading ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.chrome_reader_mode_outlined, size: 18),
          label: Text(reading ? tr('learn.reading') : tr('learn.read')),
        ),
      ),
      if (p != null && p.kinds.isNotEmpty) note(tr('learn.known', {'host': p.host, 'k': p.kinds.map(_kindName).join(Lang.list)})),
      if (d != null && !hasStructure) note(tr('learn.noStructure'), color: cs.error),
      if (known case final r?) ...[
        const SizedBox(height: 10),
        Text(tr('learn.knownRead', {'k': _kindName(r.kind)}), style: t.labelLarge?.copyWith(color: cs.primary)),
        _preview(context, r),
      ],
      if (d != null && hasStructure) ...[
        const SizedBox(height: 14),
        Text(tr('learn.kindQ'), style: t.titleSmall),
        const SizedBox(height: 6),
        Wrap(spacing: 6, runSpacing: 6, children: [
          for (final k in _learnKinds)
            ChoiceChip(key: ValueKey('learn.kind:${k.name}'), label: Text(_kindName(k)), selected: kind == k, onSelected: (_) => _pickKind(k)),
        ]),
      ],
      if (d != null && hasStructure && kind != null && m != null) ...[
        const SizedBox(height: 12),
        Align(
          alignment: Alignment.centerLeft,
          child: OutlinedButton.icon(
            key: const ValueKey('learn.map'),
            onPressed: busy ? null : _map,
            icon: busy ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.auto_awesome, size: 18),
            label: Text(busy ? tr('learn.mapping') : tr('learn.map')),
          ),
        ),
        if (error != null) note(error!, color: cs.error),
        const SizedBox(height: 8),
        _mappingTable(context, d, m),
        if (m.isList) ...[
          note(tr('learn.rows', {'n': '${m.read(d).rows.length}'})),
          _rows(context, m.read(d)),
        ],
        if (!m.complete(d)) note(tr('learn.incomplete'), color: cs.error),
        const SizedBox(height: 10),
        Wrap(spacing: 8, runSpacing: 6, children: [
          FilledButton.icon(key: const ValueKey('learn.save'), onPressed: m.complete(d) ? _save : null, icon: const Icon(Icons.save_outlined, size: 18), label: Text(tr('learn.save'))),
          if (p != null && p.kinds.isNotEmpty) TextButton(key: const ValueKey('learn.forget'), onPressed: _forget, child: Text(tr('learn.forget'))),
        ]),
        if (saved != null) note(saved!, color: cs.primary),
      ],
    ]);
  }

  /// 每個欄位：選標籤或欄（下拉選單），旁邊是讀到的內容
  Widget _mappingTable(BuildContext context, PageDigest d, PageMapping m) {
    final t = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final choices = mappingChoices(d, m.kind);
    final read = m.read(d);
    final first = m.isList ? (read.rows.isEmpty ? const <String, String>{} : read.rows.first) : read.fields;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      for (final f in m.fields)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              SizedBox(width: 92, child: Text('${tr('learn.f.$f')}${m.isRequired(f) ? ' *' : ''}', style: t.labelMedium)),
              Expanded(
                child: DropdownButton<String>(
                  key: ValueKey('learn.field:$f'),
                  isExpanded: true,
                  isDense: true,
                  value: () {
                    final v = m.isList ? (m.columns[f] == null ? '' : choices.firstWhere((c) => c.startsWith('${m.columns[f]}:'), orElse: () => '')) : (m.labels[f] ?? '');
                    return v.isEmpty || choices.contains(v) ? v : '';
                  }(),
                  items: [
                    DropdownMenuItem(value: '', child: Text(tr('learn.none'), style: t.bodySmall)),
                    for (final c in choices) DropdownMenuItem(value: c, child: Text(c, style: t.bodySmall, overflow: TextOverflow.ellipsis)),
                  ],
                  onChanged: (v) => setState(() {
                    saved = null;
                    if (m.isList) {
                      v == null || v.isEmpty ? m.columns.remove(f) : m.columns[f] = int.parse(v.split(':').first);
                    } else {
                      v == null || v.isEmpty ? m.labels.remove(f) : m.labels[f] = v;
                    }
                  }),
                ),
              ),
            ]),
            Padding(
              padding: const EdgeInsets.only(left: 92, top: 2),
              child: Text(
                first[f] ?? ((m.isList ? m.columns.containsKey(f) : m.labels.containsKey(f)) ? tr('learn.bad') : '—'),
                key: ValueKey('learn.value:$f'),
                style: t.bodySmall?.copyWith(color: first[f] == null ? cs.error : null),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ]),
        ),
    ]);
  }

  /// 清單的前幾列：點一下在左邊打開那一件（接著可以學公告頁）
  Widget _rows(BuildContext context, PageRead r) {
    final t = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      for (final (i, row) in r.rows.take(3).indexed)
        InkWell(
          key: ValueKey('learn.row:$i'),
          onTap: row['link'] == null || widget.open == null ? null : () => widget.open!(row['link']!),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Text(
              [row['title'], row['deadline'] ?? row['date']].whereType<String>().join(' · '),
              style: t.bodySmall?.copyWith(color: row['link'] == null ? null : cs.primary),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
      if (r.rows.any((x) => x['link'] != null)) Text(tr('learn.openRow'), style: t.labelSmall?.copyWith(color: cs.onSurfaceVariant)),
    ]);
  }

  Widget _preview(BuildContext context, PageRead r) {
    final t = Theme.of(context).textTheme;
    final lines = r.rows.isNotEmpty
        ? [for (final row in r.rows.take(3)) [row['title'], row['agency'], row['deadline'] ?? row['date'], row['budget'] ?? row['amount']].whereType<String>().join(' · '), tr('learn.rows', {'n': '${r.rows.length}'})]
        : [for (final e in r.fields.entries) '${tr('learn.f.${e.key}')}：${e.value}'];
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [for (final l in lines) Padding(padding: const EdgeInsets.only(top: 3), child: Text(l, style: t.bodySmall))]);
  }
}
