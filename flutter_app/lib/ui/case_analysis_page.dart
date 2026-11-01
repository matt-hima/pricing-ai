import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../app_state.dart';
import '../case_analysis/keywords.dart';
import '../case_analysis/opendata.dart';
import '../case_analysis/case_db.dart';
import '../case_analysis/case_report.dart';
import '../case_analysis/case_store.dart';
import '../case_analysis/case_store_open.dart';
import '../case_analysis/case_summary.dart' show priceFacts, competitionFacts;
import '../case_analysis/pcc.dart';
import '../i18n/i18n.dart';
import '../llm.dart' show downloadText;
import '../pdf_export.dart' show renderPdfDoc;
import '../service_pricing/service_plan.dart' show formatMoney;
import 'case_browser_dialog.dart';
import 'chart_frame.dart';
import 'competitor_dialog.dart';
import 'save_file.dart';

/// 案件分析：查政府電子採購網的決標公告 → 同類案件的金額分布、機關、得標廠商 → 對照自己的報價
class CaseAnalysisPage extends StatefulWidget {
  final AppState state;

  /// 開啟內嵌的採購網收集案件；測試時換成直接回傳固定資料
  final CaseCollect collect;

  /// 案件資料庫（官方開放資料與即時查詢的結果）；測試時換成記憶體裡的資料庫
  final OpenCaseStore openStore;
  const CaseAnalysisPage({super.key, required this.state, this.collect = openCaseBrowser, this.openStore = openCaseStore});

  @override
  State<CaseAnalysisPage> createState() => _CaseAnalysisPageState();
}

const _prefsKey = 'selfquote.case.query';
const _periods = [3, 6, 12, 24]; // 月
const _autoDetails = 5; // 交叉分析自動點開的決標公告數（採購網對連續打開公告會要求驗證碼檢核，所以不多開）
const _autoRivals = 3; // 自動查紀錄的競爭對手數

enum _Sort { date, amountDesc, amountAsc }

class _CaseAnalysisPageState extends State<CaseAnalysisPage> {
  final keyword = TextEditingController();
  final myPrice = TextEditingController();
  ProcCate cate = ProcCate.any;
  int months = 12;
  _Sort sort = _Sort.date;
  bool showAll = false;

  CaseCollection col = CaseCollection();

  /// 官方開放資料：匯入本機資料庫後，用「篩選 → 量值 → 分組」的方式提問（參考 Metabase）
  _DataView? data;
  int dataDone = 0, dataTotal = 0;
  bool dataLoading = false;
  bool searched = false;

  /// 圖表（可複製成圖片、下載 PNG，匯出 PDF 時也放進報告）
  final _distChart = GlobalKey(), _posChart = GlobalKey(), _trendChart = GlobalKey();
  bool exporting = false;

  /// 相關查詢字（採購網是連續文字比對，「網站」找不到「網頁」的案子）：預設勾選前 3 個
  List<String> related = [];
  final Set<String> picked = {};
  String _relatedFor = '';

  void _refreshRelated() {
    final k = keyword.text.trim();
    if (k == _relatedFor) return;
    _relatedFor = k;
    related = expandKeywords(k).suggestions;
    picked
      ..clear()
      ..addAll(related.take(3));
  }
  List<AwardCase> get cases => col.cases;
  Map<String, AwardDetail> get details => col.details;
  int get total => col.total;

  AppState get s => widget.state;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    keyword.dispose();
    myPrice.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final v = (await SharedPreferences.getInstance()).getStringList(_prefsKey);
      if (v != null && v.length >= 3 && mounted) {
        setState(() {
          keyword.text = v[0];
          cate = ProcCate.values.firstWhere((c) => c.name == v[1], orElse: () => ProcCate.any);
          months = int.tryParse(v[2]) ?? 12;
          _refreshRelated();
        });
      }
    } catch (_) {}
  }

  Future<void> _save() async {
    try {
      await (await SharedPreferences.getInstance()).setStringList(_prefsKey, [keyword.text.trim(), cate.name, '$months']);
    } catch (_) {}
  }

  /// 打開內嵌瀏覽器查詢：使用者在真正的採購網上瀏覽，關閉時帶回看過的案件
  Future<void> _search() async {
    final k = keyword.text.trim();
    if (k.isEmpty) return;
    _save();
    _refreshRelated();
    final primary = expandKeywords(k).primary;
    final more = [...primary.skip(1), ...related.where(picked.contains)];
    // 直接執行交叉分析：查關鍵字 → 自動點開決標公告 → 自動查前幾家競爭對手的紀錄 → 自動帶回結果
    final r = await widget.collect(context, CaseQuery(primary.first, cate: cate, months: months, more: more), auto: true, details: _autoDetails, rivals: _autoRivals, known: _known);
    if (r == null || !mounted) return;
    _saveCases(r);
    setState(() {
      col = r;
      searched = true;
      showAll = false;
    });
  }

  /// 再打開瀏覽器點開更多案件（延續目前收集的資料）
  Future<void> _openMore() async {
    final k = keyword.text.trim();
    final r = await widget.collect(context, CaseQuery(k.isEmpty ? '網站' : expandKeywords(k).primary.first, cate: cate, months: months), prior: col, auto: false, details: 0, rivals: 0, known: _known);
    if (r != null && mounted) {
      setState(() => col = r);
      _saveCases(r);
    }
  }

  void _useEstimate() {
    final v = s.pricing.ttc;
    setState(() => myPrice.text = v > 0 ? '$v' : '');
  }

  void _csv() {
    final header = [tr('case.col.date'), tr('case.col.agency'), tr('case.col.caseNo'), tr('case.col.name'), tr('case.col.method'), tr('case.col.category'), tr('case.col.amount'), tr('case.col.budget'), tr('case.col.bidders'), tr('case.col.winner'), 'URL'];
    downloadText('pcc-cases.csv', casesCsv(_sorted(), details, header), 'text/csv;charset=utf-8');
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(tr('case.csvSaved'))));
  }

  List<AwardCase> _sorted() {
    final l = [...cases];
    switch (sort) {
      case _Sort.date:
        l.sort((a, b) => (b.date ?? DateTime(0)).compareTo(a.date ?? DateTime(0)));
      case _Sort.amountDesc:
        l.sort((a, b) => b.amount.compareTo(a.amount));
      case _Sort.amountAsc:
        l.sort((a, b) => a.amount.compareTo(b.amount));
    }
    return l;
  }

  String _money(double v) => formatMoney(v, 'TWD');
  String _short(double v) => 'NT\$${shortTwd(v, cjk: I18n.lang.isCjk)}';

  Widget _card(BuildContext context, String title, Widget child, {String? sub, Widget? trailing}) {
    final t = Theme.of(context).textTheme;
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Text(title, style: t.titleMedium)),
            ?trailing,
          ]),
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
    final st = cases.isEmpty ? null : CaseStats.of(cases);
    final mine = double.tryParse(myPrice.text.replaceAll(',', '').trim());
    return Scaffold(
      backgroundColor: cs.surfaceContainerLow,
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1000),
            // 不用 lazy 的 ListView：畫面外的圖表也要畫好，匯出 PDF 時才擷取得到
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Text(tr('case.title'), style: t.headlineSmall),
              const SizedBox(height: 4),
              Text(tr('case.intro'), style: t.bodyMedium?.copyWith(color: cs.onSurfaceVariant)),
              const SizedBox(height: 16),
              _queryCard(context),
              if (st != null || (data?.amounts.isNotEmpty ?? false)) _shareCard(context),
              if (caseStoreAvailable) _datasetCard(context),
              if (searched && cases.isEmpty) _card(context, tr('case.noResults'), Text(tr('case.noResultsHint'), style: t.bodyMedium)),
              if (st != null) ...[
                _summaryCard(context, st),
                _positionCard(context, st, mine),
                _detailCard(context, st),
                if (competitorsOf(details).isNotEmpty) _competitorCard(context),
                if (details.isNotEmpty) _reviewerCard(context),
                _listCard(context),
              ],
            ]),
            ),
          ),
        ),
      ),
    );
  }

  Widget _queryCard(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    if (!caseBrowserAvailable) {
      return _card(
        context,
        tr('case.query'),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(tr('case.webNote'), style: t.bodyMedium),
          const SizedBox(height: 12),
          FilledButton.icon(onPressed: () => launchUrl(awardSearchPage), icon: const Icon(Icons.open_in_new, size: 18), label: Text(tr('case.openPcc'))),
        ]),
      );
    }
    return _card(
      context,
      tr('case.query'),
      Wrap(spacing: 12, runSpacing: 12, crossAxisAlignment: WrapCrossAlignment.center, children: [
        SizedBox(
          width: 260,
          child: TextField(
            controller: keyword,
            decoration: InputDecoration(labelText: tr('case.keyword'), hintText: tr('case.keywordHint'), border: const OutlineInputBorder(), isDense: true),
            onChanged: (_) => setState(_refreshRelated),
            onSubmitted: (_) => _search(),
          ),
        ),
        SizedBox(
          width: 150,
          child: DropdownButtonFormField<ProcCate>(
            isExpanded: true,
            initialValue: cate,
            key: ValueKey('cate-$cate'),
            decoration: InputDecoration(labelText: tr('case.cate'), border: const OutlineInputBorder(), isDense: true),
            items: [for (final c in ProcCate.values) DropdownMenuItem(value: c, child: Text(tr('case.cate.${c.name}')))],
            onChanged: (v) => setState(() => cate = v ?? ProcCate.any),
          ),
        ),
        SizedBox(
          width: 170,
          child: DropdownButtonFormField<int>(
            isExpanded: true,
            initialValue: months,
            key: ValueKey('months-$months'),
            decoration: InputDecoration(labelText: tr('case.period'), border: const OutlineInputBorder(), isDense: true),
            items: [for (final m in _periods) DropdownMenuItem(value: m, child: Text(tr('case.months', {'n': '$m'})))],
            onChanged: (v) => setState(() => months = v ?? 12),
          ),
        ),
        FilledButton.icon(onPressed: _search, icon: const Icon(Icons.manage_search, size: 18), label: Text(tr('case.search'))),
        OutlinedButton.icon(
          onPressed: keyword.text.trim().isEmpty ? null : () => openGoogleAiMode(context, tr('case.google.marketQuery', {'k': keyword.text.trim()})),
          icon: const Icon(Icons.travel_explore, size: 18),
          label: Text(tr('case.google')),
        ),
        if (related.isNotEmpty)
          SizedBox(
            width: double.infinity,
            child: Wrap(spacing: 6, runSpacing: 6, crossAxisAlignment: WrapCrossAlignment.center, children: [
              Tooltip(message: tr('case.related.help'), child: Text(tr('case.related'), style: t.labelMedium)),
              for (final r in related)
                FilterChip(
                  label: Text(r),
                  selected: picked.contains(r),
                  visualDensity: VisualDensity.compact,
                  onSelected: (v) => setState(() => v ? picked.add(r) : picked.remove(r)),
                ),
            ]),
          ),
        Text(tr('case.source'), style: t.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
      ]),
    );
  }

  AwardFilter _filter({String? source}) {
    final now = DateTime.now();
    return AwardFilter(keywords: _keywordsNow(), cate: cate, from: DateTime(now.year, now.month - months, now.day), source: source);
  }

  /// 官方資料：只下載還沒匯入或最近有更新的檔，然後對資料庫提問
  Future<void> _analyzeDataset() async {
    if (dataLoading) return;
    final store = await widget.openStore();
    if (store == null) return;
    final files = datasetFiles(DateTime.now(), months);
    setState(() {
      dataLoading = true;
      dataDone = 0;
      dataTotal = files.length;
    });
    try {
      final downloaded = await store.syncDataset(files, onProgress: (d, n) {
        if (mounted) {
          setState(() {
            dataDone = d;
            dataTotal = n;
          });
        }
      });
      final v = await _DataView.ask(store.db, _filter(source: 'dataset'), downloaded);
      if (mounted) setState(() => data = v);
    } finally {
      if (mounted) setState(() => dataLoading = false);
    }
  }

  Future<void> _saveCases(CaseCollection c) => saveCasesTo(widget.openStore, c);
  Future<Map<String, AwardDetail>> _known(Iterable<String> urls) => knownDetailsIn(widget.openStore, urls);

  List<String> _keywordsNow() {
    final primary = expandKeywords(keyword.text.trim()).primary;
    return [...primary, ...related.where(picked.contains)];
  }

  String _kv(String label, String value) => I18n.lang.isCjk ? '$label：$value' : '$label: $value';

  /// 報告內容（分享文字與 PDF 共用）：數字都由程式依統計寫成句子；評選委員只寫人數
  CaseReport _report({ReportChart? dist, ReportChart? pos, ReportChart? trend}) {
    final kws = _keywordsNow();
    final st = cases.isEmpty ? null : CaseStats.of(cases);
    final mine = double.tryParse(myPrice.text.replaceAll(',', '').trim());
    final ds = DetailStats.of(details.values);
    final v = data;
    final vst = v == null || v.amounts.isEmpty ? null : CaseStats.ofAmounts(v.amounts);
    final withCommittee = details.values.where((d) => d.reviewers.isNotEmpty).length;
    final reviewers = reviewerCrossRef(details);
    String date(DateTime? d) => d == null ? '' : '${d.year}/${d.month}/${d.day}';
    return CaseReport(
      title: tr('report.title', {'k': kws.isEmpty ? keyword.text.trim() : kws.first}),
      subtitle: tr('report.subtitle', {'d': fileDate(), 'k': kws.join(Lang.list), 'c': tr('case.cate.${cate.name}'), 'm': tr('case.months', {'n': '$months'})}),
      sections: [
        if (st != null)
          ReportSection(
            tr('case.summary'),
            lines: [priceFacts(cases, total), '${_kv(tr('case.s.mean'), _money(st.mean))}  ·  ${_kv(tr('case.s.range'), '${_short(st.min)} – ${_short(st.max)}')}'],
            bullets: [
              if (st.topAgencies.isNotEmpty) _kv(tr('case.topAgencies'), st.topAgencies.take(5).map((e) => '${e.key} (${e.value})').join(Lang.list)),
              if (st.methods.isNotEmpty) _kv(tr('case.methods'), st.methods.take(4).map((e) => '${e.key} (${e.value})').join(Lang.list)),
            ],
            chart: dist,
          ),
        if (st != null && mine != null && mine > 0)
          ReportSection(
            tr('case.position'),
            lines: [
              '${tr('case.pos.pct', {'price': _money(mine), 'pct': '${CaseStats.percentile(cases, mine).round()}'})}${I18n.lang.isCjk ? '' : ' '}${mine < st.p25 ? tr('case.pos.low') : (mine > st.p75 ? tr('case.pos.high') : tr('case.pos.mid'))}',
            ],
            chart: pos,
          ),
        if (ds.sampled > 0)
          ReportSection(
            tr('case.detail'),
            lines: [competitionFacts(details)],
            bullets: [
              for (final c in competitorsOf(details).take(6))
                [
                  c.name,
                  tr('case.comp.counts', {'b': '${c.bids}', 'w': '${c.wins}'}),
                  if (col.totals.containsKey('won:${c.name}'))
                    () {
                      final p = VendorProfile.of(c.name, col);
                      return tr('case.comp.record', {'w': '${p.wins}', 'b': '${p.bids}', 'r': p.winRate == null ? '—' : '${p.winRate!.round()}%'});
                    }(),
                ].join('  ·  '),
            ],
          ),
        if (withCommittee > 0)
          ReportSection(tr('case.rev'), lines: [
            tr('report.reviewers', {'d': '${details.length}', 'c': '$withCommittee', 'n': '${reviewers.length}', 'r': '${reviewers.where((r) => r.caseUrls.length > 1).length}'}),
          ]),
        if (v != null && vst != null)
          ReportSection(
            tr('case.data'),
            lines: [
              tr('hist.f.price', {'n': '${vst.count}', 'median': _money(vst.median), 'p25': _short(vst.p25), 'p75': _short(vst.p75)}),
            ],
            bullets: [
              if (v.vendors.isNotEmpty) _kv(tr('case.data.winners'), v.vendors.take(5).map((r) => '${r.name} (${tr('case.data.vendor', {'w': '${r.wins}', 't': _short(r.wonTotal)})})').join(Lang.list)),
              if (v.agencies.isNotEmpty) _kv(tr('case.topAgencies'), v.agencies.map((b) => '${b.label} (${b.count})').join(Lang.list)),
              if (v.ways.isNotEmpty) _kv(tr('case.data.ways'), v.ways.map((b) => '${b.label} (${b.count})').join(Lang.list)),
            ],
            chart: trend,
            table: [
              if (st == null) ...[
                [tr('case.col.name'), tr('case.col.agency'), tr('case.col.winner'), tr('case.col.date'), tr('case.col.amount')],
                for (final a in v.recent) [a.name, a.agency, a.winner, date(a.noticeDate), _money(a.amount)],
              ],
            ],
          ),
        if (st != null)
          ReportSection(tr('report.cases'), table: [
            [tr('case.col.name'), tr('case.col.agency'), tr('case.col.bidders'), tr('case.col.date'), tr('case.col.amount')],
            for (final c in _sorted().take(20)) [c.name, c.agency, '${details[c.url]?.bidders ?? ''}', date(c.date), _money(c.amount)],
          ]),
      ],
      note: tr('case.disclaimer'),
      sources: [if (st != null) tr('report.source.pcc'), if (vst != null) tr('case.data.source')],
    );
  }

  /// 匯出 PDF：擷取畫面上的圖表一起放進報告
  Future<void> _exportPdf() async {
    if (exporting) return;
    final m = ScaffoldMessenger.of(context);
    setState(() => exporting = true);
    try {
      final doc = _report(dist: await captureChart(_distChart), pos: await captureChart(_posChart), trend: await captureChart(_trendChart)).toPdfDoc();
      final pdf = await renderPdfDoc(doc);
      final at = await saveBytes(pdf, 'case-analysis-${fileDate()}.pdf', 'application/pdf');
      if (at != null) m.showSnackBar(SnackBar(content: Text(tr('case.pdf.saved', {'p': at}))));
    } catch (e) {
      m.showSnackBar(SnackBar(content: Text(tr('case.pdf.failed', {'e': errText(e)}))));
    } finally {
      if (mounted) setState(() => exporting = false);
    }
  }

  /// 分享用的摘要文字：有結果就一定有，可以直接複製
  Widget _shareCard(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final text = _report().toText();
    return _card(
      context,
      tr('case.share'),
      sub: tr('case.share.sub'),
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          width: double.infinity,
          constraints: const BoxConstraints(maxHeight: 260),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: cs.surfaceContainerHighest.withValues(alpha: .45), borderRadius: BorderRadius.circular(8)),
          child: SingleChildScrollView(child: SelectableText(text, key: const ValueKey('case.share.text'), style: t.bodySmall?.copyWith(height: 1.45))),
        ),
        const SizedBox(height: 10),
        Wrap(spacing: 10, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
          FilledButton.tonalIcon(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: text));
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(tr('case.share.copied'))));
            },
            icon: const Icon(Icons.copy, size: 18),
            label: Text(tr('case.share.copy')),
          ),
          OutlinedButton.icon(
            onPressed: exporting ? null : _exportPdf,
            icon: exporting ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.picture_as_pdf_outlined, size: 18),
            label: Text(exporting ? tr('case.pdf.making') : tr('case.pdf')),
          ),
        ]),
      ]),
    );
  }

  Widget _datasetCard(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final v = data;
    final st = v == null || v.amounts.isEmpty ? null : CaseStats.ofAmounts(v.amounts);
    final maxMonth = v == null ? 1 : v.months.fold<int>(1, (m, b) => b.count > m ? b.count : m);
    return _card(
      context,
      tr('case.data'),
      sub: tr('case.data.sub'),
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Wrap(spacing: 12, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
          FilledButton.tonalIcon(
            onPressed: dataLoading || _keywordsNow().isEmpty ? null : _analyzeDataset,
            icon: const Icon(Icons.dataset_outlined, size: 18),
            label: Text(tr('case.data.run', {'m': '$months'})),
          ),
          if (v != null && !dataLoading) Text(tr('case.data.loaded', {'n': '${v.amounts.length}', 'd': '${v.downloaded}'}), style: t.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
        ]),
        if (dataLoading) ...[
          const SizedBox(height: 10),
          LinearProgressIndicator(value: dataTotal == 0 ? null : dataDone / dataTotal),
          Padding(padding: const EdgeInsets.only(top: 4), child: Text(tr('case.data.progress', {'i': '$dataDone', 'n': '$dataTotal'}), style: t.labelSmall)),
        ],
        if (v != null && !dataLoading && v.amounts.isEmpty) Padding(padding: const EdgeInsets.only(top: 12), child: Text(tr('case.data.none'), style: t.bodyMedium)),
        if (v != null && st != null) ...[
          const SizedBox(height: 14),
          Wrap(spacing: 12, runSpacing: 12, children: [
            _Stat(tr('case.s.count'), '${st.count}'),
            _Stat(tr('case.s.median'), _money(st.median)),
            _Stat(tr('case.s.iqr'), '${_short(st.p25)} – ${_short(st.p75)}'),
            _Stat(tr('case.s.mean'), _money(st.mean)),
          ]),
          const SizedBox(height: 16),
          Wrap(spacing: 32, runSpacing: 12, children: [
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(tr('case.data.winners'), style: t.titleSmall),
                const SizedBox(height: 6),
                for (final r in v.vendors)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Text(
                      '${r.name}  ·  ${tr('case.data.vendor', {'w': '${r.wins}', 't': _short(r.wonTotal)})}${r.bids > r.wins ? '  ·  ${tr('case.data.lost', {'l': '${r.bids - r.wins}'})}' : ''}',
                      style: t.bodySmall,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ]),
            ),
            _rank(context, tr('case.topAgencies'), [for (final b in v.agencies) MapEntry(b.label, b.count)]),
            _rank(context, tr('case.data.ways'), [for (final b in v.ways) MapEntry(b.label, b.count)]),
          ]),
          if (v.months.length > 1) ...[
            const SizedBox(height: 16),
            ChartFrame(
              boundary: _trendChart,
              title: '${tr('case.data.trend')} · ${_keywordsNow().join(Lang.list)}',
              filename: 'case-awards-per-month',
              builder: (context) {
                final t = Theme.of(context).textTheme;
                final cs = Theme.of(context).colorScheme;
                return SizedBox(
                height: 110,
                child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  for (final b in v.months)
                    Expanded(
                      child: Tooltip(
                        message: '${b.label}  ·  ${tr('case.nCases', {'n': '${b.count}'})}',
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 2),
                          child: Column(children: [
                            Expanded(
                              child: Column(mainAxisAlignment: MainAxisAlignment.end, children: [
                                Text('${b.count}', style: t.labelSmall),
                                Flexible(
                                  child: FractionallySizedBox(
                                    heightFactor: b.count / maxMonth,
                                    child: Container(decoration: BoxDecoration(color: cs.primary, borderRadius: const BorderRadius.vertical(top: Radius.circular(3)))),
                                  ),
                                ),
                              ]),
                            ),
                            Text(b.label.substring(5), style: t.labelSmall?.copyWith(color: cs.onSurfaceVariant)),
                          ]),
                        ),
                      ),
                    ),
                ]),
              );
              },
            ),
          ],
          const SizedBox(height: 14),
          Text(tr('case.data.recent'), style: t.titleSmall),
          for (final a in v.recent)
            InkWell(
              onTap: () => launchUrl(Uri.parse(a.url.isNotEmpty ? a.url : DatasetAward(name: a.name, caseNo: a.caseNo, category: a.category, agency: a.agency, method: a.tenderMethod, awardWay: a.awardWay, winner: a.winner, loser: '', amount: a.amount, noticeDate: a.noticeDate).toCase().url)),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(children: [
                  Expanded(child: Text('${a.name}  ·  ${a.agency}${a.winner.isEmpty ? '' : '  ·  ${a.winner}'}', style: t.bodySmall?.copyWith(color: cs.primary), maxLines: 1, overflow: TextOverflow.ellipsis)),
                  const SizedBox(width: 8),
                  Text(_money(a.amount), style: t.bodySmall),
                ]),
              ),
            ),
        ],
        const SizedBox(height: 10),
        Text(tr('case.data.source'), style: t.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
      ]),
    );
  }

  Widget _summaryCard(BuildContext context, CaseStats st) {
    final maxBand = st.bands.fold<int>(1, (a, b) => b > a ? b : a);
    final mine = double.tryParse(myPrice.text.replaceAll(',', '').trim());
    String bandLabel(int i) => i == st.bands.length - 1 ? '≥ ${_short(amountBands[i])}' : '${i == 0 ? '0' : _short(amountBands[i])} – ${_short(amountBands[i + 1])}';
    return _card(
      context,
      tr('case.summary'),
      sub: total > cases.length ? tr('case.partial', {'n': '${cases.length}', 'total': '$total'}) : tr('case.found', {'n': '${cases.length}'}),
      trailing: OutlinedButton.icon(onPressed: _csv, icon: const Icon(Icons.download, size: 18), label: Text(tr('case.csv'))),
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Wrap(spacing: 12, runSpacing: 12, children: [
          _Stat(tr('case.s.count'), '${st.count}'),
          _Stat(tr('case.s.median'), _money(st.median)),
          _Stat(tr('case.s.iqr'), '${_short(st.p25)} – ${_short(st.p75)}'),
          _Stat(tr('case.s.mean'), _money(st.mean)),
          _Stat(tr('case.s.range'), '${_short(st.min)} – ${_short(st.max)}'),
        ]),
        const SizedBox(height: 16),
        ChartFrame(
          boundary: _distChart,
          title: '${tr('case.dist')} · ${total > st.count ? tr('case.partial', {'n': '${st.count}', 'total': '$total'}) : tr('case.found', {'n': '${st.count}'})}',
          filename: 'case-amounts',
          builder: (context) {
            final t = Theme.of(context).textTheme;
            final cs = Theme.of(context).colorScheme;
            return Column(children: [
        for (var i = 0; i < st.bands.length; i++)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Row(children: [
              SizedBox(width: 150, child: Text(bandLabel(i), style: t.bodySmall, textAlign: TextAlign.right)),
              const SizedBox(width: 10),
              Expanded(
                child: LayoutBuilder(builder: (context, c) {
                  final here = mine != null && mine >= amountBands[i] && mine < amountBands[i + 1];
                  final w = st.bands[i] == 0 ? 0.0 : (c.maxWidth - 40) * st.bands[i] / maxBand;
                  return Row(children: [
                    Container(
                      width: w < 3 && st.bands[i] > 0 ? 3 : w,
                      height: 18,
                      decoration: BoxDecoration(color: here ? cs.tertiary : cs.primary, borderRadius: const BorderRadius.horizontal(right: Radius.circular(4))),
                    ),
                    const SizedBox(width: 6),
                    Text('${st.bands[i]}', style: t.labelSmall),
                  ]);
                }),
              ),
            ]),
          ),
          ]);
          },
        ),
        const SizedBox(height: 16),
        Wrap(spacing: 32, runSpacing: 12, children: [
          _rank(context, tr('case.topAgencies'), st.topAgencies),
          _rank(context, tr('case.methods'), st.methods),
        ]),
      ]),
    );
  }

  Widget _rank(BuildContext context, String title, List<MapEntry<String, int>> items) {
    final t = Theme.of(context).textTheme;
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 420),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: t.titleSmall),
        const SizedBox(height: 6),
        for (final e in items)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Text('${e.key}  ·  ${tr('case.nCases', {'n': '${e.value}'})}', style: t.bodySmall, maxLines: 1, overflow: TextOverflow.ellipsis),
          ),
      ]),
    );
  }

  Widget _positionCard(BuildContext context, CaseStats st, double? mine) {
    String? verdict;
    if (mine != null && mine > 0) {
      final pct = CaseStats.percentile(cases, mine).round();
      final where = mine < st.p25 ? tr('case.pos.low') : (mine > st.p75 ? tr('case.pos.high') : tr('case.pos.mid'));
      verdict = '${tr('case.pos.pct', {'price': _money(mine), 'pct': '$pct'})} $where';
    }
    return _card(
      context,
      tr('case.position'),
      sub: tr('case.position.sub'),
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Wrap(spacing: 12, runSpacing: 12, crossAxisAlignment: WrapCrossAlignment.center, children: [
          SizedBox(
            width: 220,
            child: TextField(
              controller: myPrice,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(labelText: tr('case.myPrice'), suffixText: 'TWD', border: const OutlineInputBorder(), isDense: true),
              onChanged: (_) => setState(() {}),
            ),
          ),
          OutlinedButton.icon(onPressed: _useEstimate, icon: const Icon(Icons.request_quote_outlined, size: 18), label: Text(tr('case.useEstimate'))),
        ]),
        if (verdict != null) ...[
          const SizedBox(height: 12),
          ChartFrame(
            boundary: _posChart,
            title: verdict,
            filename: 'case-price-position',
            builder: (context) => _PositionBar(stats: st, price: mine!, color: Theme.of(context).colorScheme.tertiary, label: _short),
          ),
        ],
      ]),
    );
  }

  Widget _detailCard(BuildContext context, CaseStats st) {
    final t = Theme.of(context).textTheme;
    final ds = DetailStats.of(details.values);
    String pct(double? v) => v == null ? '—' : '${v.toStringAsFixed(0)}%';
    return _card(
      context,
      tr('case.detail'),
      sub: tr('case.detail.sub'),
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        FilledButton.tonalIcon(
          onPressed: _openMore,
          icon: const Icon(Icons.open_in_browser, size: 18),
          label: Text(details.isEmpty ? tr('case.detail.run') : tr('case.detail.more')),
        ),
        if (ds.sampled > 0) ...[
          const SizedBox(height: 14),
          Wrap(spacing: 12, runSpacing: 12, children: [
            _Stat(tr('case.d.sampled'), '${ds.sampled}'),
            _Stat(tr('case.d.bidders'), ds.avgBidders == null ? '—' : ds.avgBidders!.toStringAsFixed(1)),
            _Stat(tr('case.d.single'), pct(ds.singleBidPct)),
            _Stat(tr('case.d.ratio'), pct(ds.awardToBudget == null ? null : ds.awardToBudget! * 100)),
          ]),
          const SizedBox(height: 8),
          Text(tr('case.d.ratioHelp'), style: t.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
          if (ds.topWinners.isNotEmpty) ...[
            const SizedBox(height: 14),
            _rank(context, tr('case.d.winners'), ds.topWinners),
          ],
        ],
      ]),
    );
  }

  /// 評選委員交叉分析：點開的公告裡（最有利標的案件才公開委員）每位委員評選過哪些案件、那些案件由誰得標
  Widget _reviewerCard(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final recs = reviewerCrossRef(details);
    final byUrl = {for (final c in cases) c.url: c};
    final withCommittee = details.values.where((d) => d.reviewers.isNotEmpty).length;
    return _card(
      context,
      tr('case.rev'),
      sub: tr('case.rev.sub', {'d': '${details.length}', 'c': '$withCommittee'}),
      Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        if (recs.isEmpty) Text(tr('case.rev.none'), style: t.bodyMedium),
        for (final r in recs.take(15))
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 5),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Flexible(child: Text('${r.name} · ${r.job}', style: t.bodyMedium, maxLines: 1, overflow: TextOverflow.ellipsis)),
                if (r.caseUrls.length > 1) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
                    decoration: BoxDecoration(color: cs.tertiaryContainer, borderRadius: BorderRadius.circular(99)),
                    child: Text(tr('case.rev.repeat'), style: t.labelSmall?.copyWith(color: cs.onTertiaryContainer)),
                  ),
                ],
              ]),
              Text(
                [
                  tr('case.rev.cases', {'n': '${r.caseUrls.length}', 'a': '${r.attended}'}),
                  if (r.winners.isNotEmpty) tr('case.rev.winners', {'w': r.winners.entries.map((e) => e.value > 1 ? '${e.key} ×${e.value}' : e.key).join(Lang.list)}),
                ].join('  ·  '),
                style: t.labelSmall?.copyWith(color: cs.onSurfaceVariant),
              ),
              for (final u in r.caseUrls.take(3))
                if (byUrl[u] case final c?)
                  InkWell(
                    onTap: () => launchUrl(Uri.parse(c.url)),
                    child: Text('· ${c.name}', style: t.labelSmall?.copyWith(color: cs.primary), maxLines: 1, overflow: TextOverflow.ellipsis),
                  ),
            ]),
          ),
        const SizedBox(height: 8),
        Text(tr('case.rev.note'), style: t.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
      ]),
    );
  }

  Widget _competitorCard(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final list = competitorsOf(details).take(10).toList();
    return _card(
      context,
      tr('case.comp'),
      sub: tr('case.comp.sub', {'d': '${details.length}'}),
      Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        for (final c in list)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(c.name, style: t.bodyMedium, maxLines: 1, overflow: TextOverflow.ellipsis),
                  Text(tr('case.comp.counts', {'b': '${c.bids}', 'w': '${c.wins}'}), style: t.labelSmall?.copyWith(color: cs.onSurfaceVariant)),
                  // 交叉分析已自動查過這家的紀錄：直接顯示近 12 個月的得標 / 投標 / 得標率
                  if (col.totals.containsKey('won:${c.name}'))
                    Builder(builder: (_) {
                      final p = VendorProfile.of(c.name, col);
                      return Text(
                        tr('case.comp.record', {'w': '${p.wins}', 'b': '${p.bids}', 'r': p.winRate == null ? '—' : '${p.winRate!.round()}%'}),
                        style: t.labelSmall?.copyWith(color: cs.primary, fontWeight: FontWeight.w600),
                      );
                    }),
                ]),
              ),
              TextButton.icon(
                onPressed: () => showDialog<void>(context: context, builder: (_) => CompetitorDialog(name: c.name, taxId: c.id, keyword: keyword.text.trim(), collect: widget.collect)),
                icon: const Icon(Icons.history, size: 16),
                label: Text(tr('case.comp.history')),
              ),
              TextButton.icon(
                onPressed: () => openGoogleAiMode(context, tr('case.google.companyQuery', {'name': c.name, 'id': c.id})),
                icon: const Icon(Icons.travel_explore, size: 16),
                label: Text(tr('case.google')),
              ),
            ]),
          ),
      ]),
    );
  }

  Widget _listCard(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final rows = _sorted();
    final shown = showAll ? rows : rows.take(30).toList();
    return _card(
      context,
      tr('case.list'),
      trailing: DropdownButton<_Sort>(
        value: sort,
        isDense: true,
        underline: const SizedBox.shrink(),
        items: [for (final x in _Sort.values) DropdownMenuItem(value: x, child: Text(tr('case.sort.${x.name}'), style: t.bodySmall))],
        onChanged: (v) => setState(() => sort = v ?? _Sort.date),
      ),
      Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        for (final c in shown)
          InkWell(
            onTap: () => launchUrl(Uri.parse(c.url)),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(c.name, style: t.bodyMedium?.copyWith(color: cs.primary), maxLines: 2, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 2),
                    Text(
                      [
                        if (c.date != null) '${c.date!.year}/${c.date!.month}/${c.date!.day}',
                        c.agency,
                        c.category,
                        c.method,
                        if (details[c.url]?.bidders != null) tr('case.nBidders', {'n': '${details[c.url]!.bidders}'}),
                        ?details[c.url]?.winner,
                      ].join('  ·  '),
                      style: t.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ]),
                ),
                const SizedBox(width: 12),
                Text(_money(c.amount), style: t.titleSmall),
              ]),
            ),
          ),
        if (!showAll && rows.length > shown.length)
          Align(alignment: Alignment.centerLeft, child: TextButton(onPressed: () => setState(() => showAll = true), child: Text(tr('case.showAll', {'n': '${rows.length}'})))),
        const SizedBox(height: 6),
        Text(tr('case.disclaimer'), style: t.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
      ]),
    );
  }
}

class _Stat extends StatelessWidget {
  final String label, value;
  const _Stat(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    return Container(
      width: 170,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: cs.surfaceContainerHighest.withValues(alpha: .5), borderRadius: BorderRadius.circular(10)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: t.labelSmall?.copyWith(color: cs.onSurfaceVariant)),
        const SizedBox(height: 4),
        Text(value, style: t.titleMedium),
      ]),
    );
  }
}

/// 對數刻度的位置條：最小 ~ 最大，中間 50% 區間加深，標出自己的報價
class _PositionBar extends StatelessWidget {
  final CaseStats stats;
  final double price;
  final Color color;
  final String Function(double) label;
  const _PositionBar({required this.stats, required this.price, required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    final lo = (stats.min < price ? stats.min : price).clamp(1, double.infinity).toDouble();
    final hi = (stats.max > price ? stats.max : price).clamp(lo * 1.01, double.infinity).toDouble();
    double x(double v) => ((_log(v.clamp(lo, hi)) - _log(lo)) / (_log(hi) - _log(lo))).clamp(0.0, 1.0);
    return LayoutBuilder(builder: (context, c) {
      final w = c.maxWidth;
      return SizedBox(
        height: 54,
        child: Stack(clipBehavior: Clip.none, children: [
          Positioned(left: 0, right: 0, top: 14, child: Container(height: 8, decoration: BoxDecoration(color: cs.surfaceContainerHighest, borderRadius: BorderRadius.circular(4)))),
          Positioned(left: w * x(stats.p25), width: (w * (x(stats.p75) - x(stats.p25))).clamp(2, w), top: 14, child: Container(height: 8, decoration: BoxDecoration(color: cs.primary.withValues(alpha: .45), borderRadius: BorderRadius.circular(4)))),
          Positioned(left: w * x(stats.median) - 1, top: 10, child: Container(width: 2, height: 16, color: cs.primary)),
          Positioned(left: (w * x(price) - 7).clamp(0, w - 14), top: 0, child: Icon(Icons.arrow_drop_down, color: color, size: 14)),
          Positioned(left: (w * x(price) - 2).clamp(0, w - 4), top: 10, child: Container(width: 4, height: 16, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2)))),
          Positioned(left: 0, top: 32, child: Text(label(lo), style: t.labelSmall)),
          Positioned(right: 0, top: 32, child: Text(label(hi), style: t.labelSmall)),
          Positioned(left: (w * x(stats.median) - 40).clamp(48, w - 128), width: 80, top: 32, child: Text(label(stats.median), style: t.labelSmall?.copyWith(color: cs.primary), textAlign: TextAlign.center)),
        ]),
      );
    });
  }

  static double _log(double v) => math.log(v);
}

/// 官方資料的一次提問結果（依目前的篩選條件）
class _DataView {
  final List<double> amounts;
  final List<VendorRecord> vendors;
  final List<Breakdown> agencies, ways, months;
  final List<AwardRow> recent;
  final int downloaded;
  const _DataView(this.amounts, this.vendors, this.agencies, this.ways, this.months, this.recent, this.downloaded);

  static Future<_DataView> ask(CaseDb db, AwardFilter f, int downloaded) async => _DataView(
        await db.amounts(f),
        await db.vendorRecords(f, limit: 8),
        await db.breakdown(f, Dimension.agency, limit: 5),
        await db.breakdown(f, Dimension.awardWay, limit: 4),
        await db.breakdown(f, Dimension.month, limit: 36),
        await db.awards(f, limit: 8),
        downloaded,
      );
}
