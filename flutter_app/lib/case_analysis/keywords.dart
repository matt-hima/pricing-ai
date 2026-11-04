/// 關鍵字擴充：採購網的標案名稱查詢會去掉空白、當成一整串連續文字比對（沒有 AND / OR），
/// 所以「網站」找不到「網頁」「官網」的案子，要分開查再合併。這裡依政府標案常見的寫法列出相關的查詢字。
library;

import '../json_repair.dart';
import 'sources/source.dart';

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

/// 其他國家：中文關鍵字裡的常見概念 → 當地標案名稱的常見寫法（只是預設值，使用者可以自己改）。
/// 每個概念：觸發的中文字、英國、西班牙、葡萄牙、日本的寫法
const _concepts = <(List<String>, List<String>, List<String>, List<String>, List<String>)>[
  (['網站', '網頁', '官網', '入口網'], ['website', 'web site', 'web portal'], ['sitio web', 'portal web', 'página web'], ['website', 'sítio web', 'sítio na internet', 'página web', 'portal web'], ['ウェブサイト', 'ホームページ', 'Webサイト']),
  (['APP', 'App', 'app', '行動應用', '應用程式'], ['app', 'mobile application'], ['aplicación móvil', 'app'], ['aplicação móvel', 'app'], ['アプリ', 'スマートフォン']),
  (['系統', '平臺', '平台', '資訊系統'], ['system', 'platform', 'software'], ['sistema', 'plataforma', 'software'], ['sistema', 'plataforma', 'software'], ['システム', 'プラットフォーム']),
  (['維護', '維運'], ['maintenance', 'support'], ['mantenimiento', 'soporte'], ['manutenção', 'suporte'], ['保守', '運用']),
  (['建置', '開發', '設計'], ['development', 'design', 'build'], ['desarrollo', 'diseño', 'implantación'], ['desenvolvimento', 'conceção', 'implementação'], ['構築', '開発', '設計']),
  (['電子商務', '電商', '購物網'], ['e-commerce', 'online shop'], ['comercio electrónico', 'tienda online'], ['comércio eletrónico', 'loja online'], ['電子商取引', 'ECサイト']),
  (['雲端', 'SaaS'], ['cloud', 'saas'], ['nube', 'cloud', 'saas'], ['cloud', 'nuvem', 'saas'], ['クラウド']),
  (['AI', '人工智慧'], ['artificial intelligence'], ['inteligencia artificial'], ['inteligência artificial'], ['AI', '人工知能']),
  (['資安', '資訊安全'], ['cyber security', 'cybersecurity', 'information security'], ['ciberseguridad', 'seguridad de la información'], ['cibersegurança', 'segurança da informação'], ['セキュリティ', '情報セキュリティ']),
  (['數位', '數位化', '電子化'], ['digital'], ['digital', 'digitalización'], ['digital', 'digitalização'], ['デジタル']),
  (['顧問', '諮詢'], ['consultancy', 'advisory'], ['consultoría', 'asesoramiento'], ['consultoria', 'assessoria'], ['コンサルティング', '支援業務']),
  (['教育訓練', '培訓', '課程'], ['training'], ['formación'], ['formação'], ['研修']),
  (['影片', '影音', '拍攝'], ['video', 'film production'], ['vídeo', 'producción audiovisual'], ['vídeo', 'produção audiovisual'], ['動画', '映像']),
  (['印刷'], ['printing'], ['impresión', 'imprenta'], ['impressão', 'tipografia'], ['印刷']),
  (['活動', '展覽', '行銷'], ['event', 'marketing', 'campaign'], ['evento', 'marketing', 'campaña'], ['evento', 'marketing', 'campanha'], ['イベント', '広報', 'プロモーション']),
  (['清潔', '清潔維護'], ['cleaning'], ['limpieza'], ['limpeza'], ['清掃']),
  (['保全', '保全服務'], ['security services', 'guarding'], ['vigilancia', 'seguridad privada'], ['vigilância', 'segurança'], ['警備']),
  (['翻譯'], ['translation'], ['traducción'], ['tradução'], ['翻訳']),
];

/// 中文關鍵字 → [c] 國家的標案名稱常見寫法（認不出概念時回傳空清單，由使用者自己輸入）
List<String> localKeywords(String zhInput, Country c) {
  if (c == Country.tw) return expandKeywords(zhInput).primary;
  final out = <String>[];
  for (final (zh, uk, es, pt, jp) in _concepts) {
    if (!zh.any(zhInput.contains)) continue;
    for (final k in switch (c) { Country.uk => uk, Country.es => es, Country.pt => pt, Country.jp => jp, Country.eu => uk, Country.tw => const <String>[] }) {
      if (!out.contains(k)) out.add(k);
    }
  }
  return out;
}

/// 本機模型提出的相關查詢字（查表認不出的字也能擴充）。[ask] 送出提示並回傳模型原始文字；
/// 回傳已去掉重複、空白、會被主要字包含的字，最多 8 個。模型輸出壞掉時回傳空清單。
Future<List<String>> aiKeywords(Future<String> Function(String system, String user, Map<String, dynamic> schema) ask, String input, Country country) async {
  final primary = expandKeywords(input).primary;
  if (primary.isEmpty) return const [];
  final language = switch (country) {
    Country.tw => 'Traditional Chinese, the wording used in Taiwan government tender titles',
    Country.uk => 'English, the wording used in UK public tender titles',
    Country.es => 'Spanish, the wording used in Spanish public tender titles',
    Country.pt => 'Portuguese, the wording used in Portuguese public tender titles',
    Country.jp => 'Japanese, the wording used in Japanese public tender titles',
    Country.eu => 'English, the wording used in the English titles of EU public tender notices (TED)',
  };
  final system = 'You help search a public procurement site that matches the search text as one continuous phrase (no AND / OR). '
      'Given a search keyword, list other short words or phrases that tender titles commonly use for the same kind of work, written in $language. '
      'Each must be short (1-4 words), different from the keyword, and not contain the keyword. Give at most 8. Output JSON only.';
  final schema = {
    'type': 'object',
    'properties': {
      'keywords': {'type': 'array', 'items': {'type': 'string'}, 'maxItems': 8},
    },
    'required': ['keywords'],
  };
  final parsed = parseLooseJson(await ask(system, 'Keyword: ${primary.join(', ')}', schema));
  final out = <String>[];
  for (final v in (parsed?['keywords'] as List?) ?? const []) {
    if (v is! String) continue;
    final k = v.replaceAll(RegExp(r'\s+'), country == Country.tw || country == Country.jp ? '' : ' ').trim();
    if (k.isEmpty || k.length > 30 || primary.contains(k) || out.contains(k) || _coveredBy(k, primary)) continue;
    out.add(k);
  }
  return out.take(8).toList();
}
