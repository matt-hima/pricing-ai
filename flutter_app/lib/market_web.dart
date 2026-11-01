import 'site/market_research.dart';

/// 網頁版沒有本機 AI，也不做網路搜尋（瀏覽器的跨網站限制）
const marketSearchAvailable = false;

Future<({List<SearchHit> hits, String evidence})> gatherMarketEvidence(List<String> queries, String lang, void Function(String) status) async =>
    (hits: const <SearchHit>[], evidence: '');
