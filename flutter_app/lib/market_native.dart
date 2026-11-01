import 'engine/web_search.dart';
import 'site/market_research.dart';

const marketSearchAvailable = true;

/// 搜尋並讀取前幾個網頁，回傳（結果清單, 價格摘錄）。每一步都會回報進度。
Future<({List<SearchHit> hits, String evidence})> gatherMarketEvidence(List<String> queries, String lang, void Function(String) status) async {
  final hits = <SearchHit>[];
  for (final q in queries) {
    status(q);
    for (final h in await bingSearch(q, lang)) {
      final host = Uri.parse(h.url).host;
      if (!skipHost(host) && hits.every((x) => Uri.parse(x.url).host != host)) hits.add(h);
    }
  }
  final used = hits.take(6).toList();
  final evidence = StringBuffer();
  for (final h in used) {
    final ex = priceExcerpts(h.snippet.replaceAll(RegExp(r'\s{2,}'), '\n'), max: 300); // 摘要裡有價格的才採用
    if (ex.isNotEmpty) evidence.writeln(ex);
  }
  for (final h in used.take(4)) {
    status(Uri.parse(h.url).host);
    final ex = priceExcerpts(await fetchPageText(h.url), max: 700);
    if (ex.isNotEmpty) evidence.writeln(ex);
  }
  final text = evidence.toString();
  return (hits: used, evidence: text.length > 5000 ? text.substring(0, 5000) : text);
}
