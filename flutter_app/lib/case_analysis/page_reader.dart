/// 通用的採購網頁讀取（原型）：不寫死某個網站的網址與版面，讓本機模型辨認頁面、對應欄位，程式讀值與檢查。
///  1. 程式把頁面縮成摘要：標題、「標籤 → 值」、有表頭的資料表、連結、開頭的文字（模型讀不了十幾萬字的 HTML）
///  2. 模型只做選擇題：這是哪一種頁面（選項固定）、哪個標籤是預算 / 截止日…（只能選頁面上有的標籤）、哪一欄是機關 / 金額…
///  3. 值由程式從頁面讀出來並檢查（金額要讀得出數字、日期要像日期），模型不寫任何值
///  4. 學到的對應存成網站設定檔：同一個網站同一種頁面之後直接套用，不再問模型；套用後缺了必要欄位就重新辨認
/// 驗證頁（要使用者證明自己是人）只辨認出來交給使用者，不會自動處理。
library;

import 'dart:convert';

typedef PageAsk = Future<String> Function(String system, String user, Map<String, dynamic> schema);

enum PageKind {
  tenderList('a list of tenders still open for bids', 'search results: a list of tenders that are still open for bids (has a deadline or closing date column)'),
  awardList('a list of awarded contracts', 'search results: a list of awarded contracts (has an award date or awarded amount column)'),
  tenderNotice('one tender notice, open for bids', 'one tender notice: a single procurement still open for bids, with its details (deadline, budget, requirements)'),
  awardNotice('one award result', 'one award notice: the result of a single procurement (winner, awarded amount, bidders)'),
  verification('a human verification check', 'the site asks the visitor to prove they are human (verification code, captcha, "I am not a robot")'),
  error('an error or no data', 'an error page, "not found", "no data", or a session timeout'),
  other('something else', 'anything else (home page, search form, login, unrelated page)');

  /// 給模型選的短句（小模型選短句比選代號準）
  final String choice;
  final String hint;
  const PageKind(this.choice, this.hint);
}

/// 每種頁面要找的欄位（list 是欄、notice 是標籤）。前面帶 * 的是必要欄位：套用設定檔後讀不到就重新辨認。
const pageFields = <PageKind, List<String>>{
  PageKind.tenderList: ['*title', 'agency', 'caseNo', '*deadline', 'budget'],
  PageKind.awardList: ['*title', 'agency', 'caseNo', 'date', '*amount'],
  PageKind.tenderNotice: ['*title', 'agency', 'caseNo', 'budget', '*deadline', 'awardMethod'],
  PageKind.awardNotice: ['*title', 'agency', 'caseNo', 'budget', '*awardAmount', 'winner', 'bidders', 'awardMethod'],
};

const _fieldHints = {
  'title': 'the name / title of the procurement',
  'agency': 'the buying agency or organization',
  'caseNo': 'the case or reference number',
  'deadline': 'the deadline for submitting bids',
  'budget': 'the budget or estimated value',
  'date': 'the award or publication date',
  'amount': 'the awarded amount',
  'awardAmount': 'the awarded (contract) amount',
  'winner': 'the winning supplier',
  'bidders': 'the number of bidders',
  'awardMethod': 'how the winner is chosen (lowest price, most advantageous / best value…)',
};

class PageTable {
  final List<String> header;
  final List<List<String>> rows; // 每列每格的文字
  final List<List<List<String>>> links; // 每列每格裡的連結網址
  const PageTable(this.header, this.rows, this.links);
}

class PageDigest {
  final String title, text;
  final List<(String, String)> pairs; // 標籤 → 值
  final List<PageTable> tables;
  const PageDigest({required this.title, required this.text, required this.pairs, required this.tables});

  /// 列最多的資料表（清單）
  PageTable? get mainTable => (tables.toList()..sort((a, b) => b.rows.length.compareTo(a.rows.length))).firstOrNull;

  String? value(String label) {
    for (final (k, v) in pairs) {
      if (k == label) return v;
    }
    return null;
  }

  List<String> get labels => [
        for (final (k, _) in pairs) k,
      ].fold(<String>[], (out, k) => out.contains(k) ? out : (out..add(k)));

  /// 給模型看的摘要（短）
  String brief({int labels = 60, int text = 900}) => [
        'Title: $title',
        'Structure: ${tables.isEmpty ? 'no data table' : 'data table with ${tables.map((t) => t.rows.length).reduce((a, b) => a > b ? a : b)} rows'}; ${this.labels.length} label/value pairs',
        for (final (i, t) in tables.indexed) 'Table ${i + 1} columns (${t.rows.length} rows): ${t.header.join(' | ')}',
        if (pairs.isNotEmpty) 'Labels: ${this.labels.take(labels).join(' / ')}',
        'Text: ${this.text.length > text ? this.text.substring(0, text) : this.text}',
      ].join('\n');
}

String _unescape(String s) => s
    .replaceAll('&nbsp;', ' ')
    .replaceAll('&emsp;', ' ')
    .replaceAll('&ensp;', ' ')
    .replaceAll('&amp;', '&')
    .replaceAll('&lt;', '<')
    .replaceAll('&gt;', '>')
    .replaceAll('&quot;', '"')
    .replaceAll('&#39;', "'");

/// 一格的文字：去掉標籤；網頁用程式畫出來的字（寫在 <script> 的字串裡）也算進來
String _cellText(String html, {bool scripts = true}) {
  final scripted = [
    if (scripts)
      for (final s in RegExp(r'<script\b[^>]*>(.*?)</script>', dotAll: true, caseSensitive: false).allMatches(html))
        for (final q in RegExp(r'''["']([^"'<>]{2,300})["']''').allMatches(s[1]!))
          if (!RegExp(r'^[#.\w$-]+$').hasMatch(q[1]!) || RegExp(r'[^\x00-\x7F]').hasMatch(q[1]!)) q[1]!,
  ];
  final plain = _unescape(html
          .replaceAll(RegExp(r'<(script|style)\b[^>]*>.*?</\1>', dotAll: true, caseSensitive: false), ' ')
          .replaceAll(RegExp(r'<!--.*?-->', dotAll: true), ' ')
          .replaceAll(RegExp(r'<(br|/p|/div|/li|/tr)\b[^>]*>', caseSensitive: false), '\n')
          .replaceAll(RegExp(r'<[^>]+>'), ' '))
      .split('\n')
      .map((l) => l.replaceAll(RegExp(r'\s+'), ' ').trim())
      .where((l) => l.isNotEmpty);
  return [...scripted, ...plain].join('\n');
}

List<String> _hrefs(String html, Uri? base) => [
      for (final m in RegExp(r'''href\s*=\s*["']([^"'#][^"']*)["']''', caseSensitive: false).allMatches(html))
        if (!m[1]!.startsWith('javascript:')) base == null ? _unescape(m[1]!) : base.resolve(_unescape(m[1]!)).toString(),
    ];

class _Table {
  final rows = <List<(String html, bool th)>>[];
  List<(String, bool)>? row;
}

/// 頁面 → 摘要
PageDigest digestPage(String html, {Uri? base}) {
  final title = _cellText(RegExp(r'<title[^>]*>(.*?)</title>', dotAll: true, caseSensitive: false).firstMatch(html)?[1] ?? '').replaceAll('\n', ' ');
  final body = html.replaceAll(RegExp(r'<head\b.*?</head>', dotAll: true, caseSensitive: false), '');
  final stack = <_Table>[], done = <_Table>[];
  final cellStart = <int>[];
  final cellTh = <bool>[];
  for (final m in RegExp(r'<(/?)(table|tr|td|th)\b[^>]*>', caseSensitive: false).allMatches(body)) {
    final close = m[1] == '/', name = m[2]!.toLowerCase();
    switch ((name, close)) {
      case ('table', false):
        stack.add(_Table());
      case ('table', true):
        if (stack.isNotEmpty) done.add(stack.removeLast());
      case ('tr', false):
        if (stack.isNotEmpty) stack.last.rows.add(stack.last.row = []);
      case ('td' || 'th', false):
        cellStart.add(m.end);
        cellTh.add(name == 'th');
      case ('td' || 'th', true):
        if (cellStart.isNotEmpty) {
          final start = cellStart.removeLast(), th = cellTh.removeLast();
          // 這一格屬於最內層、還開著的表格
          if (stack.isNotEmpty) (stack.last.row ?? (stack.last.rows..add(stack.last.row = [])).last).add((body.substring(start, m.start), th));
        }
      default:
    }
  }
  done.addAll(stack);

  final pairs = <(String, String)>[];
  final tables = <PageTable>[];
  for (final t in done) {
    for (final r in t.rows) {
      // 「標籤 | 值」：最後兩格，標籤要短；前面可以有區塊名稱那一格
      if (r.length >= 2 && r.length <= 3) {
        final label = _cellText(r[r.length - 2].$1).replaceAll('\n', '');
        final value = _cellText(r.last.$1);
        if (label.isNotEmpty && label.length <= 30 && value.isNotEmpty && !label.contains(RegExp(r'^\d+$'))) pairs.add((label, value));
      }
    }
    // 資料表：有一列全是 th（或第一列）當表頭，之後同樣欄數的列是資料
    final hi = t.rows.indexWhere((r) => r.length >= 4 && r.every((c) => c.$2));
    if (hi < 0) continue;
    final header = [for (final c in t.rows[hi]) _cellText(c.$1).replaceAll('\n', '')];
    final rows = [
      for (final r in t.rows.skip(hi + 1))
        if (r.length == header.length) r,
    ];
    if (rows.isEmpty) continue;
    tables.add(PageTable(header, [for (final r in rows) [for (final c in r) _cellText(c.$1)]], [for (final r in rows) [for (final c in r) _hrefs(c.$1, base)]]));
  }
  final text = _cellText(body, scripts: false).replaceAll('\n', ' ');
  return PageDigest(title: title, text: text, pairs: pairs, tables: tables);
}

// ---------- 讀出來的值與檢查 ----------

double? _amount(String s) {
  final m = RegExp(r'\d[\d,]*(?:\.\d+)?').firstMatch(s.replaceAll(RegExp(r'\s'), ''));
  return m == null ? null : double.tryParse(m[0]!.replaceAll(',', ''));
}

final _date = RegExp(r'(\d{2,4})\s*[/.\-年]\s*(\d{1,2})\s*[/.\-月]\s*(\d{1,2})');

/// 這個欄位的值看起來對嗎：金額要有數字、日期要像日期、家數要是整數
String? checkValue(String field, String raw) {
  final v = raw.split('\n').first.trim();
  if (v.isEmpty) return null;
  switch (field) {
    case 'budget' || 'amount' || 'awardAmount':
      return _amount(v) == null ? null : v;
    case 'deadline' || 'date':
      return _date.hasMatch(v) ? v : null;
    case 'bidders':
      return RegExp(r'^\d+$').hasMatch(v) ? v : null;
    case 'title' || 'agency' || 'winner':
      return v.length < (field == 'title' ? 4 : 2) || RegExp(r'^[\d\s.,/:\-()]+$').hasMatch(v) ? null : v; // 不能只是代碼或數字
    default:
      return v;
  }
}

/// 案號：一串英數代碼（和案名在同一格時用來分開）
bool _looksLikeCaseNo(String s) => RegExp(r'^[A-Za-z0-9][A-Za-z0-9\-_./()]{2,}$').hasMatch(s.trim());

// ---------- 網站設定檔 ----------

/// 一個網站學到的東西：哪個路徑是哪種頁面、每種頁面的欄位在哪個標籤 / 哪一欄
class SiteProfile {
  final String host;
  final Map<String, PageKind> paths;
  final Map<PageKind, Map<String, String>> labels; // 公告：欄位 → 標籤
  final Map<PageKind, Map<String, int>> columns; // 清單：欄位 → 第幾欄
  SiteProfile(this.host, {Map<String, PageKind>? paths, Map<PageKind, Map<String, String>>? labels, Map<PageKind, Map<String, int>>? columns})
      : paths = paths ?? {},
        labels = labels ?? {},
        columns = columns ?? {};

  static String pathKey(Uri u) => u.path;

  /// 這一頁學過沒有（學過就是哪一種）
  PageKind? kindOf(Uri u) => paths[pathKey(u)];

  /// 使用者確認的對應：記下這個路徑是哪一種頁面，以及那種頁面的欄位在哪裡
  void confirm(Uri url, PageMapping m) {
    paths[pathKey(url)] = m.kind;
    if (m.isList) {
      columns[m.kind] = Map.of(m.columns);
    } else {
      labels[m.kind] = Map.of(m.labels);
    }
  }

  /// 學過的頁面種類
  Set<PageKind> get kinds => {...paths.values};

  Map<String, dynamic> toJson() => {
        'host': host,
        'paths': {for (final e in paths.entries) e.key: e.value.name},
        'labels': {for (final e in labels.entries) e.key.name: e.value},
        'columns': {for (final e in columns.entries) e.key.name: e.value},
      };

  factory SiteProfile.fromJson(Map<String, dynamic> j) => SiteProfile(
        j['host'] as String,
        paths: {for (final e in (j['paths'] as Map).entries) e.key as String: PageKind.values.byName(e.value as String)},
        labels: {for (final e in (j['labels'] as Map).entries) PageKind.values.byName(e.key as String): Map<String, String>.from(e.value as Map)},
        columns: {for (final e in (j['columns'] as Map).entries) PageKind.values.byName(e.key as String): Map<String, int>.from(e.value as Map)},
      );
}

class PageRead {
  final PageKind kind;
  final Map<String, String> fields; // 公告的欄位值
  final List<Map<String, String>> rows; // 清單的每一列（含 'link'）
  final int modelCalls;
  final bool fromProfile;
  const PageRead(this.kind, {this.fields = const {}, this.rows = const [], this.modelCalls = 0, this.fromProfile = false});
}

String _required(String f) => f.replaceFirst('*', '');

/// 一種頁面的欄位要怎麼讀：公告用標籤、清單用欄號。使用者可以改，確認後存進網站設定檔。
class PageMapping {
  final PageKind kind;
  final Map<String, String> labels;
  final Map<String, int> columns;
  PageMapping(this.kind, {Map<String, String>? labels, Map<String, int>? columns})
      : labels = labels ?? {},
        columns = columns ?? {};

  bool get isList => kind == PageKind.tenderList || kind == PageKind.awardList;

  /// 這種頁面要找的欄位（必要的在前面帶 *）
  List<String> get fields => [for (final f in pageFields[kind] ?? const <String>[]) _required(f)];
  bool isRequired(String field) => (pageFields[kind] ?? const <String>[]).contains('*$field');

  /// 用這個對應讀出來
  PageRead read(PageDigest d) => isList ? PageRead(kind, rows: _readList(d, columns)) : PageRead(kind, fields: _readNotice(d, labels));

  /// 必要欄位都讀得到
  bool complete(PageDigest d) => _complete(kind, read(d));
}

/// 可以選的標籤（公告）或欄（清單，「欄號:表頭」）
List<String> mappingChoices(PageDigest d, PageKind kind) {
  if (kind == PageKind.tenderList || kind == PageKind.awardList) {
    final t = d.mainTable;
    return t == null ? const [] : [for (final (i, h) in t.header.indexed) '$i:$h'];
  }
  return d.labels;
}

/// 本機模型提出對應（使用者已經說了這是哪一種頁面，不再問模型）
Future<PageMapping> proposeMapping(PageAsk ask, PageDigest d, PageKind kind) async => switch (kind) {
      PageKind.tenderList || PageKind.awardList => PageMapping(kind, columns: await mapListColumns(ask, d, kind)),
      PageKind.tenderNotice || PageKind.awardNotice => PageMapping(kind, labels: await mapNoticeLabels(ask, d, kind)),
      _ => PageMapping(kind),
    };

/// 依對應讀出公告的欄位值（檢查不過的不要）
Map<String, String> _readNotice(PageDigest d, Map<String, String> labels) => {
      for (final e in labels.entries)
        if (d.value(e.value) case final v?) e.key: ?checkValue(e.key, v),
    };

/// 依對應讀出清單的每一列。案號和案名在同一格時，用「像代碼的那一行」分開。
List<Map<String, String>> _readList(PageDigest d, Map<String, int> cols) {
  final t = _tableFor(d, cols);
  if (t == null) return const [];
  final out = <Map<String, String>>[];
  for (final (ri, r) in t.rows.indexed) {
    final row = <String, String>{};
    for (final e in cols.entries) {
      if (e.value < 0 || e.value >= r.length) continue;
      final lines = r[e.value].split('\n');
      final shared = cols.entries.where((x) => x.value == e.value).length > 1;
      final raw = !shared
          ? r[e.value]
          : e.key == 'caseNo'
              ? lines.firstWhere(_looksLikeCaseNo, orElse: () => '')
              : lines.where((l) => !_looksLikeCaseNo(l)).join(' ');
      if (checkValue(e.key, raw) case final ok?) row[e.key] = ok;
    }
    final titleCol = cols['title'];
    final links = titleCol == null ? const <String>[] : t.links[ri][titleCol];
    if (links.isNotEmpty) row['link'] = links.first;
    if (row.containsKey('title')) out.add(row);
  }
  return out;
}

/// 清單在哪個表格：欄位對應的欄數要放得下的第一個（通常是列最多的那個）
PageTable? _tableFor(PageDigest d, Map<String, int> cols) {
  final need = cols.values.fold(0, (a, b) => b > a ? b : a);
  final ok = d.tables.where((t) => t.header.length > need).toList()..sort((a, b) => b.rows.length.compareTo(a.rows.length));
  return ok.isEmpty ? null : ok.first;
}

bool _complete(PageKind k, PageRead r) {
  final req = [for (final f in pageFields[k] ?? const <String>[]) if (f.startsWith('*')) _required(f)];
  if (k == PageKind.tenderList || k == PageKind.awardList) return r.rows.isNotEmpty && req.every(r.rows.first.containsKey);
  return req.every(r.fields.containsKey);
}

// ---------- 模型的選擇題 ----------

Map<String, dynamic> _enumSchema(Map<String, List<String>> choices) => {
      'type': 'object',
      'properties': {for (final e in choices.entries) e.key: {'type': 'string', 'enum': e.value}},
      'required': choices.keys.toList(),
      'additionalProperties': false,
    };

Map<String, dynamic>? _json(String s) {
  final a = s.indexOf('{'), b = s.lastIndexOf('}');
  if (a < 0 || b <= a) return null;
  try {
    return jsonDecode(s.substring(a, b + 1)) as Map<String, dynamic>;
  } catch (_) {
    return null;
  }
}

/// 分兩步問（7B 也常把「招標中」和「已決標」搞混；分開問是一個簡單的二選一）：
///  1. 頁面的樣子：清單、單一公告、驗證、錯誤、其他。選項先由程式依結構縮小：有資料表才可能是清單，有很多「標籤 → 值」才可能是公告
///  2. 清單或公告：還在招標，還是已經決標
const _shapeList = 'a list of procurements (search results)',
    _shapeNotice = 'one procurement notice with its details',
    _shapeCheck = 'a human verification check',
    _shapeError = 'an error or no data',
    _shapeOther = 'something else';
const _stageOpen = 'still open for bids', _stageAwarded = 'already awarded (a result)';

List<String> candidateShapes(PageDigest d) {
  final rows = d.tables.fold(0, (a, t) => t.rows.length > a ? t.rows.length : a);
  return [
    if (rows >= 3) _shapeList,
    if (d.labels.length >= 8) _shapeNotice,
    _shapeCheck,
    _shapeError,
    _shapeOther,
  ];
}

Future<PageKind> identifyPage(PageAsk ask, PageDigest d) async {
  final shapes = candidateShapes(d);
  final shape = _json(await ask(
    '''You look at one page from a public procurement website, in any language. Choose what the page is:
- "$_shapeList": ${PageKind.tenderList.hint.replaceFirst('tenders that are still open for bids (has a deadline or closing date column)', 'tenders or awarded contracts')}
- "$_shapeNotice": a single tender notice or award notice, shown as labels and values
- "$_shapeCheck": ${PageKind.verification.hint}
- "$_shapeError": ${PageKind.error.hint}
- "$_shapeOther": ${PageKind.other.hint}
Only these choices are possible here: ${shapes.map((s) => '"$s"').join(', ')}. Output JSON only.''',
    d.brief(),
    _enumSchema({'kind': shapes}),
  ))?['kind'];
  switch (shape) {
    case _shapeCheck:
      return PageKind.verification;
    case _shapeError:
      return PageKind.error;
    case _shapeList || _shapeNotice:
      final list = shape == _shapeList;
      final words = list ? 'Columns: ${(d.tables.toList()..sort((a, b) => b.rows.length.compareTo(a.rows.length))).first.header.join(' | ')}' : 'Labels: ${d.labels.take(80).join(' / ')}';
      final stage = _json(await ask(
        '''This page from a public procurement website shows ${list ? 'a list of procurements' : 'one procurement'}.
Is it about procurements "$_stageOpen" or "$_stageAwarded"?
Open tenders show a bid deadline or closing date. Award results show the winner, the awarded amount, the number of bidders or the award date.
Output JSON only.''',
        'Title: ${d.title}\n$words',
        _enumSchema({'stage': [_stageOpen, _stageAwarded]}),
      ))?['stage'];
      final awarded = stage == _stageAwarded;
      return list ? (awarded ? PageKind.awardList : PageKind.tenderList) : (awarded ? PageKind.awardNotice : PageKind.tenderNotice);
    default:
      return PageKind.other;
  }
}

/// 公告：每個欄位是哪個標籤（只能選頁面上有的標籤，或空字串）
/// 一次問一個欄位（小模型一次對應很多欄位時常選第一個標籤）；選到的標籤讀出來的值要通過檢查，不然再選一次（排除剛才那個）
Future<Map<String, String>> mapNoticeLabels(PageAsk ask, PageDigest d, PageKind kind) async {
  final fields = [for (final f in pageFields[kind]!) _required(f)];
  final labels = d.labels.take(120).toList();
  final user = 'Title: ${d.title}\n${[for (final l in labels) '$l: ${(d.value(l) ?? '').split('\n').first.cut(40)}'].join('\n')}';
  final out = <String, String>{};
  for (final f in fields) {
    final left = [...labels.where((l) => !out.containsValue(l))];
    for (var attempt = 0; attempt < 2 && left.isNotEmpty; attempt++) {
      final system = '''The page is ${kind.hint}. Each line is "label: value".
Which label holds ${_fieldHints[f]}? Choose "" when no label fits. Output JSON only.''';
      final l = _json(await ask(system, user, _enumSchema({'label': ['', ...left]})))?['label'];
      if (l is! String || l.isEmpty) break;
      if (checkValue(f, d.value(l) ?? '') != null) {
        out[f] = l;
        break;
      }
      left.remove(l);
    }
  }
  return out;
}

/// 清單：每個欄位在哪一欄（選項是「欄號:表頭」）
Future<Map<String, int>> mapListColumns(PageAsk ask, PageDigest d, PageKind kind) async {
  final t = d.mainTable;
  if (t == null) return const {};
  final fields = [for (final f in pageFields[kind]!) _required(f)];
  final opts = [for (final (i, h) in t.header.indexed) '$i:$h'];
  final sample = [for (final r in t.rows.take(2)) [for (final (i, c) in r.indexed) '$i:${c.replaceAll('\n', ' / ').cut(50)}'].join(' | ')].join('\n');
  final system = '''The page is ${kind.hint}.
For each field, choose the column that holds it, or "" when no column fits. Two fields may share one column (for example case number and title in one cell).
${[for (final f in fields) '- $f: ${_fieldHints[f]}'].join('\n')}
Output JSON only.''';
  final out = _json(await ask(system, 'Columns: ${opts.join(' | ')}\nFirst rows:\n$sample', _enumSchema({for (final f in fields) f: ['', ...opts]})));
  return {
    for (final f in fields)
      if (out?[f] case final String c when c.contains(':')) f: int.parse(c.split(':').first),
  };
}

extension on String {
  String cut(int n) => length > n ? '${substring(0, n)}…' : this;
}

/// 讀一頁：設定檔裡有這個路徑就直接套用（不問模型）；沒有或套用後缺必要欄位，就問模型並學起來。
/// [ask] 是 null 時只用設定檔。
Future<PageRead> readPage(String html, Uri url, SiteProfile profile, {PageAsk? ask}) async {
  final d = digestPage(html, base: url);
  final key = SiteProfile.pathKey(url);
  if (profile.paths[key] case final k?) {
    final r = _apply(d, k, profile);
    if (r != null && _complete(k, r)) return PageRead(k, fields: r.fields, rows: r.rows, fromProfile: true);
  }
  if (ask == null) return const PageRead(PageKind.other);
  var calls = 0;
  final inner = ask;
  ask = (s, u, schema) {
    calls++;
    return inner(s, u, schema);
  };
  final kind = await identifyPage(ask, d);
  switch (kind) {
    case PageKind.tenderNotice || PageKind.awardNotice:
      final r0 = _apply(d, kind, profile);
      if (r0 == null || !_complete(kind, r0)) {
        final before = profile.labels[kind];
        final mapped = await mapNoticeLabels(ask, d, kind);
        profile.labels[kind] = mapped;
        // 讀不全就不要記（不然一頁辨認錯的頁面會蓋掉學好的對應）
        if (!_complete(kind, _apply(d, kind, profile)!)) {
          before == null ? profile.labels.remove(kind) : profile.labels[kind] = before;
          return PageRead(kind, fields: _readNotice(d, mapped), modelCalls: calls);
        }
      }
    case PageKind.tenderList || PageKind.awardList:
      final r0 = _apply(d, kind, profile);
      if (r0 == null || !_complete(kind, r0)) {
        final before = profile.columns[kind];
        final mapped = await mapListColumns(ask, d, kind);
        profile.columns[kind] = mapped;
        if (!_complete(kind, _apply(d, kind, profile)!)) {
          before == null ? profile.columns.remove(kind) : profile.columns[kind] = before;
          return PageRead(kind, rows: _readList(d, mapped), modelCalls: calls);
        }
      }
    default:
      // 驗證頁、錯誤頁、其他：不記路徑（同一個路徑下次可能是正常頁面）
      return PageRead(kind, modelCalls: calls);
  }
  final r = _apply(d, kind, profile)!;
  profile.paths[key] = kind;
  return PageRead(kind, fields: r.fields, rows: r.rows, modelCalls: calls);
}

PageRead? _apply(PageDigest d, PageKind k, SiteProfile p) => switch (k) {
      PageKind.tenderNotice || PageKind.awardNotice => p.labels[k] == null ? null : PageRead(k, fields: _readNotice(d, p.labels[k]!)),
      PageKind.tenderList || PageKind.awardList => p.columns[k] == null ? null : PageRead(k, rows: _readList(d, p.columns[k]!)),
      _ => null,
    };
