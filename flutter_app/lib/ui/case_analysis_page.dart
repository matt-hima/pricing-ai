import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../app_state.dart';
import '../case_analysis/keywords.dart';
import '../case_analysis/opendata.dart';
import '../case_analysis/opendata_store.dart';
import '../case_analysis/pcc.dart';
import '../i18n/i18n.dart';
import '../llm.dart' show downloadText;
import '../service_pricing/service_plan.dart' show formatMoney;
import 'case_browser_dialog.dart';
import 'competitor_dialog.dart';

/// 案件分析：查政府電子採購網的決標公告 → 同類案件的金額分布、機關、得標廠商 → 對照自己的報價
class CaseAnalysisPage extends StatefulWidget {
  final AppState state;

  /// 開啟內嵌的採購網收集案件；測試時換成直接回傳固定資料
  final CaseCollect collect;

  /// 下載並讀取官方開放資料；測試時換成讀固定資料
  final Future<List<DatasetAward>> Function(List<String> files, {void Function(int done, int total)? onProgress}) loadData;
  const CaseAnalysisPage({super.key, required this.state, this.collect = openCaseBrowser, this.loadData = loadDataset});

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

  /// 官方開放資料（決標 NT\$100 萬以上）：下載的全部決標；篩選依目前的關鍵字、相關查詢字、採購性質與期間
  List<DatasetAward>? dataset;
  int dataMonths = 0, dataDone = 0, dataTotal = 0;
  bool dataLoading = false;
  bool searched = false;

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
    final r = await widget.collect(context, CaseQuery(primary.first, cate: cate, months: months, more: more), auto: true, details: _autoDetails, rivals: _autoRivals);
    if (r == null || !mounted) return;
    setState(() {
      col = r;
      searched = true;
      showAll = false;
    });
  }

  /// 再打開瀏覽器點開更多案件（延續目前收集的資料）
  Future<void> _openMore() async {
    final k = keyword.text.trim();
    final r = await widget.collect(context, CaseQuery(k.isEmpty ? '網站' : expandKeywords(k).primary.first, cate: cate, months: months), prior: col, auto: false, details: 0, rivals: 0);
    if (r != null && mounted) setState(() => col = r);
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
            child: ListView(padding: const EdgeInsets.fromLTRB(20, 20, 20, 40), children: [
              Text(tr('case.title'), style: t.headlineSmall),
              const SizedBox(height: 4),
              Text(tr('case.intro'), style: t.bodyMedium?.copyWith(color: cs.onSurfaceVariant)),
              const SizedBox(height: 16),
              _queryCard(context),
              if (datasetAvailable) _datasetCard(context),
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

  /// 下載期間內的官方決標資料檔（已下載過的直接讀本機）
  Future<void> _loadDataset() async {
    if (dataLoading) return;
    final files = datasetFiles(DateTime.now(), months);
    setState(() {
      dataLoading = true;
      dataDone = 0;
      dataTotal = files.length;
    });
    try {
      final all = await widget.loadData(files, onProgress: (d, n) {
        if (mounted) {
          setState(() {
            dataDone = d;
            dataTotal = n;
          });
        }
      });
      if (mounted) {
        setState(() {
          dataset = all;
          dataMonths = months;
        });
      }
    } finally {
      if (mounted) setState(() => dataLoading = false);
    }
  }

  List<String> _keywordsNow() {
    final primary = expandKeywords(keyword.text.trim()).primary;
    return [...primary, ...related.where(picked.contains)];
  }

  Widget _datasetCard(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final ks = _keywordsNow();
    final now = DateTime.now();
    final hits = dataset == null || ks.isEmpty ? const <DatasetAward>[] : filterDataset(dataset!, keywords: ks, cate: cate, from: DateTime(now.year, now.month - months, now.day));
    final st = hits.isEmpty ? null : CaseStats.of([for (final a in hits) a.toCase()]);
    final vendors = datasetVendors(hits).take(8).toList();
    final ways = awardWays(hits);
    final recent = [...hits]..sort((a, b) => (b.noticeDate ?? DateTime(0)).compareTo(a.noticeDate ?? DateTime(0)));
    return _card(
      context,
      tr('case.data'),
      sub: tr('case.data.sub'),
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Wrap(spacing: 12, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
          FilledButton.tonalIcon(
            onPressed: dataLoading || ks.isEmpty ? null : _loadDataset,
            icon: const Icon(Icons.dataset_outlined, size: 18),
            label: Text(dataset == null || dataMonths != months ? tr('case.data.run', {'m': '$months'}) : tr('case.data.rerun')),
          ),
          if (dataset != null && !dataLoading) Text(tr('case.data.loaded', {'n': '${dataset!.length}', 'm': '$dataMonths'}), style: t.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
        ]),
        if (dataLoading) ...[
          const SizedBox(height: 10),
          LinearProgressIndicator(value: dataTotal == 0 ? null : dataDone / dataTotal),
          Padding(padding: const EdgeInsets.only(top: 4), child: Text(tr('case.data.progress', {'i': '$dataDone', 'n': '$dataTotal'}), style: t.labelSmall)),
        ],
        if (dataset != null && !dataLoading && hits.isEmpty) Padding(padding: const EdgeInsets.only(top: 12), child: Text(tr('case.data.none'), style: t.bodyMedium)),
        if (st != null) ...[
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
                for (final v in vendors)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Text(
                      '${v.name}  ·  ${tr('case.data.vendor', {'w': '${v.wins}', 't': _short(v.total)})}${v.losses > 0 ? '  ·  ${tr('case.data.lost', {'l': '${v.losses}'})}' : ''}',
                      style: t.bodySmall,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ]),
            ),
            _rank(context, tr('case.topAgencies'), st.topAgencies),
            _rank(context, tr('case.data.ways'), ways.entries.take(4).toList()),
          ]),
          const SizedBox(height: 14),
          Text(tr('case.data.recent'), style: t.titleSmall),
          for (final a in recent.take(8))
            InkWell(
              onTap: () => launchUrl(Uri.parse(a.toCase().url)),
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
    final t = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
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
        const SizedBox(height: 20),
        Text(tr('case.dist'), style: t.titleSmall),
        const SizedBox(height: 8),
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
    final t = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
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
          Text(verdict, style: t.bodyLarge),
          const SizedBox(height: 10),
          _PositionBar(stats: st, price: mine!, color: cs.tertiary, label: _short),
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
