/// 關鍵字擴充：採購網的標案名稱查詢會去掉空白、當成一整串連續文字比對（沒有 AND / OR），
/// 所以「網站」找不到「網頁」「官網」的案子，要分開查再合併。這裡依政府標案常見的寫法列出相關的查詢字。
library;

/// 常見寫法：key 是使用者可能輸入的字，value 是標案名稱裡常見的其他寫法（都是較短、彼此不重複包含的字）
const _related = <String, List<String>>{
  '網站': ['網頁', '官網', '入口網', '資訊網', '網路平臺'],
  '網頁': ['網站', '官網', '入口網'],
  '官網': ['網站', '網頁', '形象網'],
  'APP': ['App', '行動應用', '應用程式', '手機'],
  'App': ['APP', '行動應用', '應用程式', '手機'],
  '行動應用': ['APP', 'App', '應用程式'],
  '電子商務': ['電商', '購物網', '網路商店', '商城'],
  '電商': ['電子商務', '購物網', '網路商店'],
  '平臺': ['平台', '系統', '網路平臺'],
  '平台': ['平臺', '系統'],
  '系統': ['平臺', '資訊系統', '管理系統'],
  '維護': ['維運', '委外維護', '維修'],
  '維運': ['維護', '委外維運'],
  '建置': ['開發', '建置案', '設計'],
  '開發': ['建置', '設計'],
  '資訊': ['資訊服務', '資訊系統'],
  'AI': ['人工智慧', '智慧'],
  '人工智慧': ['AI', '智慧'],
  '數位': ['數位化', '電子化', 'e化'],
  'ERP': ['企業資源規劃', '管理系統', '資訊系統'],
  'SaaS': ['雲端服務', '雲端', '平臺'],
  '雲端': ['雲端服務', 'SaaS'],
};

/// 臺 / 台 兩種寫法都要查（機關多用「臺」，廠商與一般用語常用「台」）
String? _taiVariant(String k) {
  if (k.contains('臺')) return k.replaceAll('臺', '台');
  if (k.contains('台')) return k.replaceAll('台', '臺');
  return null;
}

/// 一個字串是否已被清單裡較短的字包含（採購網是子字串比對，「網站維護」的結果一定在「網站」裡）
bool _coveredBy(String k, Iterable<String> others) => others.any((o) => o != k && o.isNotEmpty && k.contains(o));

/// 使用者輸入（可用「,」「、」「；」分隔多個字）→ 主要查詢字 + 建議的相關查詢字。
/// 回傳的 suggestions 已去掉會被主要字包含的（查了也不會多出案件）。
({List<String> primary, List<String> suggestions}) expandKeywords(String input) {
  final primary = <String>[];
  for (final p in input.split(RegExp(r'[,，、;；]'))) {
    final k = p.replaceAll(RegExp(r'\s+'), ''); // 採購網會去掉空白
    if (k.isNotEmpty && !primary.contains(k)) primary.add(k);
  }
  final out = <String>[];
  void add(String k) {
    if (k.isEmpty || primary.contains(k) || out.contains(k)) return;
    if (_coveredBy(k, primary)) return;
    out.add(k);
  }

  for (final k in primary) {
    final t = _taiVariant(k);
    if (t != null) add(t);
    // 輸入裡含有常見字（例如「網站維護」含「網站」）：用常見字的其他寫法替換，例如「網頁維護」
    for (final e in _related.entries) {
      if (!k.contains(e.key)) continue;
      for (final alt in e.value) {
        add(k == e.key ? alt : k.replaceAll(e.key, alt));
      }
    }
  }
  return (primary: primary, suggestions: out.take(8).toList());
}
