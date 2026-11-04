/// European Union: TED (Tenders Electronic Daily) search API — contract award notices published by public buyers in the EU/EEA.
/// Anonymous, no key. A month holds ~30,000 award notices (~300 MB), so unlike the other countries this source is
/// searched by keyword: each sync unit is one month and the API only returns the notices whose title matches.
library;

import 'dart:async';
import 'dart:convert';

import 'source.dart';

const _endpoint = 'https://api.ted.europa.eu/v3/notices/search';
const _pageSize = 250;
const _maxPages =
    8; // 2,000 notices per keyword set and month is already far more than a price comparison needs

class TedSource extends AwardSource {
  final Duration pause;
  TedSource({this.pause = const Duration(seconds: 1)});

  @override
  Country get country => Country.eu;

  @override
  List<SyncUnit> units(DateTime now, int months) => const []; // only meaningful with keywords

  @override
  List<SyncUnit> unitsFor(DateTime now, int months, List<String> keywords) {
    final ks = [for (final k in keywords) k.trim()]
      ..removeWhere((k) => k.isEmpty || k.contains('"'));
    if (ks.isEmpty) return const [];
    final tag = (ks.map((k) => k.toLowerCase()).toList()..sort()).join('|');
    return [
      for (var i = 0; i <= months; i++)
        () {
          final m = DateTime(now.year, now.month - i, 1);
          return SyncUnit(
            'ted:${m.year}-${m.month.toString().padLeft(2, '0')}:$tag',
            DateTime(m.year, m.month + 1, 0),
            keywords: ks,
          );
        }(),
    ];
  }

  @override
  Stream<List<SourceAward>> fetch(SyncUnit unit, SourceHttp http) async* {
    final ym = unit.name.split(':')[1].split('-');
    final from = DateTime.utc(int.parse(ym[0]), int.parse(ym[1]), 1);
    final to = DateTime.utc(from.year, from.month + 1, 1);
    String day(DateTime d) =>
        '${d.year}${d.month.toString().padLeft(2, '0')}01';
    final titles = unit.keywords.map((k) => 'notice-title ~ "$k"').join(' OR ');
    final query =
        'notice-type IN (can-standard can-social) AND publication-date >= ${day(from)} AND publication-date < ${day(to)} '
        'AND total-value > 0 AND ($titles)';
    final seen = <String>{};
    for (var page = 1; page <= _maxPages; page++) {
      final text = await http.postJson(
        Uri.parse(_endpoint),
        jsonEncode({
          'query': query,
          'fields': [
            'publication-number',
            'notice-title',
            'buyer-name',
            'winner-name',
            'total-value',
            'total-value-cur',
            'publication-date',
            'contract-nature',
            'procedure-type',
          ],
          'limit': _pageSize,
          'page': page,
        }),
      );
      if (text == null) throw StateError('TED API unavailable');
      final notices =
          ((jsonDecode(text) as Map<String, dynamic>)['notices'] as List? ??
                  const [])
              .cast<Map<String, dynamic>>();
      yield [
        for (final a in parseTedNotices(notices))
          if (seen.add(a.id)) a,
      ];
      if (notices.length < _pageSize) break;
      await Future<void>.delayed(pause);
    }
  }
}

/// A multilingual field ({"eng": "…", "deu": "…"}, values are a string or a list): English first, otherwise the first language
List<String> _text(Object? v) {
  if (v is String) return [v];
  if (v is List) return [for (final e in v) '$e'];
  if (v is! Map || v.isEmpty) return const [];
  return _text(v['eng'] ?? v.values.first);
}

/// TED search results → awards. Notices without a positive EUR total are left out (several lots in other currencies cannot be added up).
List<SourceAward> parseTedNotices(List<Map<String, dynamic>> notices) {
  final out = <SourceAward>[];
  for (final n in notices) {
    final pub = n['publication-number'] as String? ?? '';
    final amount = (n['total-value'] as num?)?.toDouble() ?? 0;
    final cur = _text(n['total-value-cur']);
    final name = _text(n['notice-title']).firstOrNull?.trim() ?? '';
    if (pub.isEmpty || name.isEmpty || amount <= 0 || (cur.isNotEmpty && cur.first != 'EUR')) continue;
    final winners = <(String, String?)>[];
    for (final w in _text(n['winner-name'])) {
      final t = w.trim();
      if (t.isNotEmpty && !winners.any((x) => x.$1.toLowerCase() == t.toLowerCase())) winners.add((t, null));
    }
    final nature = _text(n['contract-nature']).firstOrNull ?? '';
    out.add(
      SourceAward(
        id: 'ted:$pub',
        name: name,
        agency: _text(n['buyer-name']).firstOrNull?.trim() ?? '',
        winners: winners.take(30).toList(),
        amount: amount,
        date: DateTime.tryParse(
          '${n['publication-date'] ?? ''}'.split('+').first,
        ),
        category: nature.isEmpty
            ? ''
            : nature[0].toUpperCase() + nature.substring(1),
        method: '${n['procedure-type'] ?? ''}',
        url: 'https://ted.europa.eu/en/notice/-/detail/$pub',
      ),
    );
  }
  return out;
}
