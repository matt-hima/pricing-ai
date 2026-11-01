import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

import '../case_analysis/pcc.dart';
import '../i18n/i18n.dart';
import '../service_pricing/service_plan.dart' show formatMoney;

/// 網頁版的內嵌瀏覽器是 iframe，讀不到採購網的內容（跨網域），所以只在 Mac / Windows App 提供
bool get caseBrowserAvailable => !kIsWeb;

/// 每查完一頁結果停一下再查下一個（像人一樣，不連續快速打網站）
const _nextSearchDelay = Duration(seconds: 3);

/// 查詢條件：一個或多個標案名稱關鍵字，或一家廠商（得標 + 投標兩個查詢）
class CaseQuery {
  final List<String> keywords;
  final ProcCate cate;
  final int months;
  final String vendor;
  CaseQuery(String keyword, {this.cate = ProcCate.any, this.months = 12, List<String> more = const []})
      : keywords = [keyword, ...more],
        vendor = '';
  const CaseQuery.vendor(this.vendor, {this.months = 12})
      : keywords = const [],
        cate = ProcCate.any;

  String get keyword => vendor.isNotEmpty ? vendor : keywords.first;

  DateTime get _from {
    final to = DateTime.now();
    return DateTime(to.year, to.month - months, to.day);
  }

  /// 依序要查的網址
  List<Uri> get urls {
    final to = DateTime.now();
    if (vendor.isNotEmpty) {
      return [awardSearchUrl(from: _from, to: to, wonBy: vendor), awardSearchUrl(from: _from, to: to, bidBy: vendor)];
    }
    return [for (final k in keywords) awardSearchUrl(keyword: k, from: _from, to: to, cate: cate)];
  }

  Uri get url => urls.first;
}

/// 開啟採購網、收集案件；使用者關掉視窗時回傳 null。測試時換成直接回傳固定資料。
/// [auto]：全部查完就自動關閉並帶回結果；[details] / [rivals]：查完關鍵字後自動點開幾件決標公告、自動查幾家競爭對手的紀錄（交叉分析）。
typedef CaseCollect = Future<CaseCollection?> Function(BuildContext context, CaseQuery query, {CaseCollection? prior, String? doneLabel, bool auto, int details, int rivals});

Future<CaseCollection?> openCaseBrowser(BuildContext context, CaseQuery query, {CaseCollection? prior, String? doneLabel, bool auto = false, int details = 0, int rivals = 0}) =>
    showDialog<CaseCollection>(
      context: context,
      barrierDismissible: false,
      builder: (_) => CaseBrowserDialog(query: query, prior: prior, doneLabel: doneLabel, auto: auto, autoDetails: details, autoRivals: rivals),
    );

/// 在 App 內的瀏覽器打開 Google 搜尋的 AI 模式給使用者自己看（App 不讀取 Google 的內容）
Future<void> openGoogleAiMode(BuildContext context, String query) =>
    showDialog<void>(context: context, builder: (_) => CaseBrowserDialog(startUrl: googleAiMode(query)));

/// 內嵌瀏覽器：顯示真正的網站，使用者自己瀏覽（翻頁、點開案件）。
/// [query]：採購網模式，App 只讀取畫面上載入的採購網頁面（決標清單 → 案件，決標公告 → 投標廠商、預算）。
/// [startUrl]：只是打開一個網頁給使用者看（例如 Google），不讀取內容。
class CaseBrowserDialog extends StatefulWidget {
  final CaseQuery? query;
  final Uri? startUrl;
  final CaseCollection? prior;
  final String? doneLabel;
  final bool auto;
  final int autoDetails, autoRivals;
  const CaseBrowserDialog({super.key, this.query, this.startUrl, this.prior, this.doneLabel, this.auto = false, this.autoDetails = 0, this.autoRivals = 0});

  @override
  State<CaseBrowserDialog> createState() => _CaseBrowserDialogState();
}

/// 自動執行的階段：關鍵字查詢 → 點開決標公告 → 查競爭對手紀錄 → 完成
enum _Stage { searches, details, rivals, done }

class _CaseBrowserDialogState extends State<CaseBrowserDialog> {
  late final CaseCollection col = widget.prior ?? CaseCollection();
  late final List<Uri> queue = [...?widget.query?.urls];
  InAppWebViewController? web;
  bool loading = true, canBack = false, canForward = false;
  String host = '';
  int next = 1; // 下一個要自動打開的 queue 位置
  int _loads = 0; // 每次開始載入就 +1：使用者自己點了別的頁面，就不自動換下一頁
  bool waiting = false;
  _Stage stage = _Stage.searches;
  final Map<_Stage, (int, int)> _span = {}; // 每個階段在 queue 裡的範圍（開始, 結束）

  bool get collecting => widget.query != null;

  @override
  void initState() {
    super.initState();
    _span[_Stage.searches] = (0, queue.length);
  }

  /// 載入的頁面是不是佇列裡的那一頁：清單頁比查詢代號，決標公告比主鍵（點開後網址會轉址）
  static bool _same(String loaded, Uri queued) {
    if (queued.path.contains('readTenderAgent')) return loaded.contains('readTenderAgent') && searchKey(Uri.parse(loaded)) == searchKey(queued);
    final pk = awardPk(queued.toString());
    return pk != null && awardPk(loaded) == pk;
  }

  Future<void> _read(InAppWebViewController c, WebUri? url) async {
    if (!collecting || url == null || !url.host.endsWith(pccHost)) return;
    try {
      final html = await c.getHtml();
      if (html != null && col.addPage(url.toString(), html) && mounted) setState(() {});
    } catch (_) {} // 讀不到就算了，使用者可以繼續瀏覽
    // 這一頁是佇列裡剛打開的那個：停一下再自動打開下一個（使用者這段時間自己換頁就不動）
    final i = next - 1;
    if (i < 0 || i >= queue.length || !_same(url.toString(), queue[i])) return;
    if (next >= queue.length && !_plan()) return _finish();
    final loadsNow = _loads;
    setState(() => waiting = true);
    await Future<void>.delayed(_nextSearchDelay);
    if (!mounted) return;
    setState(() => waiting = false);
    if (_loads == loadsNow) _runNext();
  }

  /// 目前階段做完了：排下一個階段要打開的頁面。有排到東西就回傳 true。
  bool _plan() {
    while (stage != _Stage.done) {
      final before = queue.length;
      switch (stage) {
        case _Stage.searches:
          stage = _Stage.details;
          queue.addAll(pickForCrossRef(col, widget.autoDetails).map((c) => Uri.parse(c.url)));
        case _Stage.details:
          stage = _Stage.rivals;
          for (final r in pickRivalsToLookUp(col, widget.autoRivals)) {
            queue.addAll(CaseQuery.vendor(r.name).urls);
          }
        case _Stage.rivals || _Stage.done:
          stage = _Stage.done;
      }
      _span[stage] = (before, queue.length);
      if (queue.length > before) return true;
    }
    return false;
  }

  /// 全部做完：自動模式就關閉並帶回結果
  Future<void> _finish() async {
    if (!widget.auto || !mounted) return;
    setState(() => stage = _Stage.done);
    await Future<void>.delayed(const Duration(milliseconds: 800));
    if (mounted && col.cases.isNotEmpty || mounted && col.vendorCases.isNotEmpty) Navigator.pop(context, col);
  }

  void _runNext() {
    if (next >= queue.length) return;
    final u = queue[next++];
    web?.loadUrl(urlRequest: URLRequest(url: WebUri(u.toString())));
    setState(() {});
  }

  /// 進度文字：例如「讀取決標公告 3 / 10」
  String? _progress() {
    final sp = _span[stage];
    if (stage == _Stage.done) return widget.auto ? tr('case.browser.stage.done') : null;
    if (sp == null || sp.$2 <= sp.$1) return null;
    final key = switch (stage) { _Stage.searches => 'case.browser.stage.search', _Stage.details => 'case.browser.stage.details', _ => 'case.browser.stage.rivals' };
    final i = (next - sp.$1).clamp(0, sp.$2 - sp.$1), n = sp.$2 - sp.$1;
    return tr(key, {'i': '$i', 'n': '$n'});
  }

  Future<void> _nav(InAppWebViewController c, WebUri? url) async {
    final b = await c.canGoBack(), f = await c.canGoForward();
    if (mounted) {
      setState(() {
        canBack = b;
        canForward = f;
        host = url?.host ?? host;
      });
    }
  }

  void _open(String url) => web?.loadUrl(urlRequest: URLRequest(url: WebUri(url)));

  String _label(Uri u) {
    final k = searchKey(u);
    if (k.startsWith('won:')) return '${tr('case.browser.won')} · ${k.substring(4)}';
    if (k.startsWith('bid:')) return '${tr('case.browser.bid')} · ${k.substring(4)}';
    return '「${k.substring(3)}」';
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final st = col.cases.isEmpty ? null : CaseStats.of(col.cases);
    final suggest = st == null ? const <AwardCase>[] : sampleForDetail(col.cases, st.median, col.cases.length).where((c) => !col.details.containsKey(c.url)).take(8).toList();
    final start = widget.startUrl ?? queue.first;
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
                const SizedBox(width: 4),
                Icon(Icons.lock_outline, size: 14, color: cs.onSurfaceVariant),
                const SizedBox(width: 4),
                Flexible(child: Text(host.isEmpty ? start.host : host, style: t.bodySmall?.copyWith(color: cs.onSurfaceVariant), overflow: TextOverflow.ellipsis)),
                const Spacer(),
                if (collecting) ...[
                  Text(tr('case.browser.collected', {'n': '${col.cases.length}', 'd': '${col.details.length}'}), style: t.labelLarge),
                  const SizedBox(width: 12),
                ],
                TextButton(onPressed: () => Navigator.pop(context), child: Text(tr('mkt.close'))),
                if (collecting) ...[
                  const SizedBox(width: 6),
                  FilledButton.icon(
                    onPressed: col.cases.isEmpty ? null : () => Navigator.pop(context, col),
                    icon: const Icon(Icons.check, size: 18),
                    label: Text(widget.doneLabel ?? tr('case.browser.use')),
                  ),
                ],
              ]),
            ),
          ),
          if (loading) const LinearProgressIndicator(minHeight: 2),
          Expanded(
            child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Expanded(
                child: InAppWebView(
                  initialUrlRequest: URLRequest(url: WebUri(start.toString())),
                  initialSettings: InAppWebViewSettings(javaScriptEnabled: true, supportMultipleWindows: true, isInspectable: kDebugMode),
                  onWebViewCreated: (c) => web = c,
                  onLoadStart: (c, url) {
                    _loads++;
                    if (mounted) setState(() => loading = true);
                  },
                  onLoadStop: (c, url) async {
                    if (mounted) setState(() => loading = false);
                    await _nav(c, url);
                    await _read(c, url);
                  },
                  // 有些連結開新視窗：在同一個畫面打開
                  onCreateWindow: (c, action) async {
                    final u = action.request.url;
                    if (u != null) c.loadUrl(urlRequest: URLRequest(url: u));
                    return false;
                  },
                ),
              ),
              if (collecting) _panel(context, st, suggest),
            ]),
          ),
        ]),
      ),
    );
  }

  Widget _panel(BuildContext context, CaseStats? st, List<AwardCase> suggest) {
    final t = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    return Container(
      width: 290,
      decoration: BoxDecoration(border: Border(left: BorderSide(color: cs.outlineVariant))),
      child: ListView(padding: const EdgeInsets.all(14), children: [
        Text(tr('case.browser.hint'), style: t.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
        const SizedBox(height: 12),
        // 查詢進度：每個關鍵字（或得標 / 投標）查到幾件
        if (_progress() case final p?) ...[
          Row(children: [
            if (stage != _Stage.done) const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2)) else Icon(Icons.check_circle, size: 16, color: cs.primary),
            const SizedBox(width: 8),
            Expanded(child: Text(p, style: t.labelLarge?.copyWith(color: cs.primary))),
          ]),
          const SizedBox(height: 12),
        ],
        Text(tr('case.browser.searches'), style: t.labelLarge),
        const SizedBox(height: 4),
        for (var i = 0; i < queue.length; i++)
          if (queue[i].path.contains('readTenderAgent'))
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Row(children: [
              Icon(col.totals.containsKey(searchKey(queue[i])) ? Icons.check_circle : (i < next ? Icons.hourglass_top : Icons.radio_button_unchecked), size: 14, color: cs.primary),
              const SizedBox(width: 6),
              Expanded(child: Text(_label(queue[i]), style: t.bodySmall, maxLines: 1, overflow: TextOverflow.ellipsis)),
              if (col.totals[searchKey(queue[i])] case final n?) Text(tr('case.nCases', {'n': '$n'}), style: t.labelSmall),
            ]),
          ),
        if (waiting) Padding(padding: const EdgeInsets.only(top: 4), child: Text(tr('case.browser.nextSoon'), style: t.labelSmall?.copyWith(color: cs.onSurfaceVariant))),
        if (!waiting && next < queue.length)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(onPressed: _runNext, icon: const Icon(Icons.skip_next, size: 16), label: Text(tr('case.browser.next'))),
          ),
        const SizedBox(height: 12),
        if (st != null) ...[
          Text('${tr('case.s.median')}  ${formatMoney(st.median, 'TWD')}', style: t.titleSmall),
          const SizedBox(height: 12),
        ],
        if (suggest.isNotEmpty && widget.query?.vendor.isEmpty == true) ...[
          Text(tr('case.browser.suggest'), style: t.labelLarge),
          const SizedBox(height: 4),
          for (final c in suggest)
            InkWell(
              key: ValueKey('suggest:${c.url}'),
              onTap: () => _open(c.url),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(c.name, style: t.bodySmall?.copyWith(color: cs.primary), maxLines: 2, overflow: TextOverflow.ellipsis),
                  Text('${c.agency} · ${formatMoney(c.amount, 'TWD')}', style: t.labelSmall?.copyWith(color: cs.onSurfaceVariant), maxLines: 1, overflow: TextOverflow.ellipsis),
                ]),
              ),
            ),
        ],
      ]),
    );
  }
}
