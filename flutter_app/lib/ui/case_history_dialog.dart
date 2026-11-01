import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../app_state.dart';
import '../case_analysis/case_summary.dart';
import '../case_analysis/keywords.dart';
import '../case_analysis/pcc.dart';
import '../i18n/i18n.dart';
import '../service_pricing/service_plan.dart' show formatMoney;
import 'case_browser_dialog.dart';

/// 專案類型 → 採購網常見的標案名稱關鍵字
const _typeKeywords = {'corporate': '網站', 'ecommerce': '電子商務', 'app': 'APP', 'saas': '平台', 'erp': '系統'};

/// 歷史案件：在內嵌的採購網查同類決標案件（使用者自己瀏覽、點開案件）→ 本機模型寫摘要，對照目前的報價
class CaseHistoryDialog extends StatefulWidget {
  final AppState state;

  /// 開啟內嵌的採購網收集案件；測試時換成直接回傳固定資料
  final CaseCollect collect;
  const CaseHistoryDialog({super.key, required this.state, this.collect = openCaseBrowser});

  @override
  State<CaseHistoryDialog> createState() => _CaseHistoryDialogState();
}

class _CaseHistoryDialogState extends State<CaseHistoryDialog> {
  late final keyword = TextEditingController(text: _typeKeywords[widget.state.q.type] ?? '網站');
  ProcCate cate = ProcCate.services;
  int months = 12;

  bool running = false, closed = false;
  String status = '';
  String? error;
  List<AwardCase> cases = [];
  int total = 0;
  Map<String, AwardDetail> details = {};
  CaseSummary? summary;
  double? myPrice;

  AppState get s => widget.state;

  @override
  void initState() {
    super.initState();
    // 打開就自動開啟採購網查詢（模型正忙時才等使用者按）
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_alive && !s.busy) _run();
    });
  }

  @override
  void dispose() {
    closed = true;
    keyword.dispose();
    super.dispose();
  }

  bool get _alive => mounted && !closed;

  Future<void> _run() async {
    final k = keyword.text.trim();
    if (k.isEmpty || running) return;
    final price = s.pricing.ttc.toDouble();
    setState(() {
      running = true;
      error = null;
      summary = null;
      myPrice = price > 0 ? price : null;
      status = tr('hist.browsing');
    });
    try {
      final kw = expandKeywords(k);
      final r = await widget.collect(context, CaseQuery(kw.primary.first, cate: cate, months: months, more: [...kw.primary.skip(1), ...kw.suggestions.take(3)]), doneLabel: tr('hist.useAndSummarize'), auto: true, details: 3, rivals: 0);
      if (!_alive || r == null) return;
      if (r.cases.isEmpty) throw StateError(tr('case.noResultsHint'));
      setState(() {
        cases = r.cases;
        total = r.total;
        details = r.details;
        status = tr('hist.summarizing');
      });
      final sum = await s.withModel((ask) => summarizeCases(ask: (a, b, c) => ask(a, b, schema: c), lang: I18n.lang, keyword: k, cases: cases, total: total, details: details, myPrice: myPrice));
      if (!_alive) return;
      setState(() => summary = sum.isEmpty ? null : sum);
      if (sum.isEmpty) setState(() => error = tr('hist.noSummary'));
    } catch (e) {
      if (_alive) setState(() => error = cases.isEmpty ? errText(e) : tr('hist.aiError', {'e': errText(e)}));
    } finally {
      if (_alive) setState(() => running = false);
    }
  }

  String _summaryText() {
    final x = summary!;
    return [x.overview, x.price, x.competition, for (final a in x.advice) '• $a'].where((l) => l.isNotEmpty).join('\n');
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final st = cases.isEmpty ? null : CaseStats.of(cases);
    String money(double v) => formatMoney(v, 'TWD');
    String short(double v) => 'NT\$${shortTwd(v, cjk: I18n.lang.isCjk)}';
    return AlertDialog(
      title: Text(tr('hist.title')),
      content: SizedBox(
        width: 680,
        child: SingleChildScrollView(
          child: ListenableBuilder(
            listenable: s,
            builder: (context, _) => Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(tr('hist.intro'), style: t.bodySmall),
              const SizedBox(height: 12),
              Wrap(spacing: 12, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
                SizedBox(
                  width: 200,
                  child: TextField(
                    controller: keyword,
                    decoration: InputDecoration(labelText: tr('case.keyword'), hintText: tr('case.keywordHint'), border: const OutlineInputBorder(), isDense: true),
                    onSubmitted: (_) => _run(),
                  ),
                ),
                SizedBox(
                  width: 130,
                  child: DropdownButtonFormField<ProcCate>(
                    isExpanded: true,
                    initialValue: cate,
                    decoration: InputDecoration(labelText: tr('case.cate'), border: const OutlineInputBorder(), isDense: true),
                    items: [for (final c in ProcCate.values) DropdownMenuItem(value: c, child: Text(tr('case.cate.${c.name}')))],
                    onChanged: running ? null : (v) => setState(() => cate = v ?? ProcCate.services),
                  ),
                ),
                SizedBox(
                  width: 140,
                  child: DropdownButtonFormField<int>(
                    isExpanded: true,
                    initialValue: months,
                    decoration: InputDecoration(labelText: tr('case.period'), border: const OutlineInputBorder(), isDense: true),
                    items: [for (final m in const [6, 12, 24]) DropdownMenuItem(value: m, child: Text(tr('case.months', {'n': '$m'})))],
                    onChanged: running ? null : (v) => setState(() => months = v ?? 12),
                  ),
                ),
                FilledButton.icon(onPressed: running || s.busy ? null : _run, icon: const Icon(Icons.auto_awesome, size: 18), label: Text(cases.isEmpty ? tr('hist.run') : tr('hist.rerun'))),
                OutlinedButton.icon(
                  onPressed: () => openGoogleAiMode(context, tr('case.google.marketQuery', {'k': keyword.text.trim()})),
                  icon: const Icon(Icons.travel_explore, size: 18),
                  label: Text(tr('case.google')),
                ),
              ]),
              if (running) ...[
                const SizedBox(height: 12),
                LinearProgressIndicator(value: s.busy && s.progress > 0 && s.progress < 1 ? s.progress : null),
                Padding(padding: const EdgeInsets.only(top: 6), child: Text(s.busy ? s.progressText : status, style: t.labelSmall)),
              ],
              if (error != null) Padding(padding: const EdgeInsets.only(top: 12), child: Text(error!, style: t.bodyMedium?.copyWith(color: cs.error))),
              if (st != null) ...[
                const SizedBox(height: 16),
                Text(
                  [
                    total > st.count ? tr('case.partial', {'n': '${st.count}', 'total': '$total'}) : tr('case.found', {'n': '${st.count}'}),
                    '${tr('case.s.median')} ${money(st.median)}',
                    '${tr('case.s.iqr')} ${short(st.p25)} – ${short(st.p75)}',
                  ].join('  ·  '),
                  style: t.titleSmall,
                ),
                if (myPrice != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(tr('case.pos.pct', {'price': money(myPrice!), 'pct': '${CaseStats.percentile(cases, myPrice!).round()}'}), style: t.bodyMedium),
                  ),
              ],
              if (summary != null) ...[
                const SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(color: cs.secondaryContainer.withValues(alpha: .45), borderRadius: BorderRadius.circular(10)),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      Icon(Icons.auto_awesome, size: 16, color: cs.primary),
                      const SizedBox(width: 6),
                      Expanded(child: Text(tr('hist.summary'), style: t.titleSmall)),
                      IconButton(
                        tooltip: tr('hist.copy'),
                        visualDensity: VisualDensity.compact,
                        icon: const Icon(Icons.copy, size: 16),
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: _summaryText()));
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(tr('hist.copied'))));
                        },
                      ),
                    ]),
                    for (final (label, text) in [(tr('hist.overview'), summary!.overview), (tr('hist.price'), summary!.price), (tr('hist.competition'), summary!.competition)])
                      if (text.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text.rich(TextSpan(children: [
                            TextSpan(text: '$label  ', style: t.labelLarge?.copyWith(color: cs.primary)),
                            TextSpan(text: text, style: t.bodyMedium),
                          ])),
                        ),
                    if (summary!.advice.isNotEmpty) ...[
                      Padding(padding: const EdgeInsets.only(top: 10), child: Text(tr('hist.advice'), style: t.labelLarge?.copyWith(color: cs.primary))),
                      for (final a in summary!.advice) Padding(padding: const EdgeInsets.only(top: 4), child: Text('• $a', style: t.bodyMedium)),
                    ],
                  ]),
                ),
              ],
              if (st != null) ...[
                const SizedBox(height: 16),
                Text(tr('hist.cases'), style: t.labelMedium),
                for (final c in representativeCases(cases, details, st.median, 6))
                  InkWell(
                    onTap: () => launchUrl(Uri.parse(c.url)),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(children: [
                        Expanded(
                          child: Text(
                            '${c.name}  ·  ${c.agency}${details[c.url]?.bidders == null ? '' : '  ·  ${tr('case.nBidders', {'n': '${details[c.url]!.bidders}'})}'}',
                            style: t.bodySmall?.copyWith(color: cs.primary, decoration: TextDecoration.underline),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(money(c.amount), style: t.bodySmall),
                      ]),
                    ),
                  ),
                const SizedBox(height: 8),
                Text(tr('hist.note'), style: t.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
              ],
            ]),
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(tr('mkt.close'))),
      ],
    );
  }
}
