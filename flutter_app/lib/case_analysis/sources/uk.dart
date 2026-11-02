/// United Kingdom: official OCDS APIs (Open Government Licence v3.0), no key needed.
/// - Contracts Finder: lower-value contracts in England (published award notices)
/// - Find a Tender: higher-value contracts across the UK
/// Each month is one sync unit; the API is paged with a cursor ("links.next").
library;

import 'dart:async';
import 'dart:convert';

import 'source.dart';

enum UkService {
  contractsFinder('uk-cf', 'https://www.contractsfinder.service.gov.uk/Published/Notices/OCDS/Search', 'publishedFrom', 'publishedTo'),
  findATender('uk-fts', 'https://www.find-tender.service.gov.uk/api/1.0/ocdsReleasePackages', 'updatedFrom', 'updatedTo');

  final String prefix, endpoint, fromParam, toParam;
  const UkService(this.prefix, this.endpoint, this.fromParam, this.toParam);
}

class UkSource extends AwardSource {
  final UkService service;
  final Duration pause;
  UkSource(this.service, {this.pause = const Duration(seconds: 2)}); // the APIs rate-limit (HTTP 429, Retry-After: 120)

  @override
  Country get country => Country.uk;

  @override
  List<SyncUnit> units(DateTime now, int months) => [
        for (var i = 0; i <= months; i++)
          () {
            final m = DateTime(now.year, now.month - i, 1);
            return SyncUnit('${service.prefix}:${m.year}-${m.month.toString().padLeft(2, '0')}', DateTime(m.year, m.month + 1, 0));
          }(),
      ];

  @override
  Stream<List<SourceAward>> fetch(SyncUnit unit, SourceHttp http) async* {
    final ym = unit.name.split(':').last.split('-');
    final from = DateTime.utc(int.parse(ym[0]), int.parse(ym[1]), 1);
    final to = DateTime.utc(from.year, from.month + 1, 1);
    String iso(DateTime d) => d.toIso8601String().substring(0, 19);
    Uri? next = Uri.parse(service.endpoint).replace(queryParameters: {
      'stages': 'award',
      'limit': '100',
      service.fromParam: iso(from),
      service.toParam: iso(to),
    });
    final seen = <String>{};
    while (next != null) {
      final text = await http.getText(next);
      if (text == null) throw StateError('UK API unavailable');
      final page = jsonDecode(text) as Map<String, dynamic>;
      final awards = parseUkReleases(page, service);
      yield [for (final a in awards) if (seen.add(a.id)) a];
      final link = (page['links'] as Map?)?['next'] as String?;
      next = link == null || link.isEmpty ? null : Uri.parse(link);
      if (next != null) await Future<void>.delayed(pause);
    }
  }
}

/// OCDS release package → awards (one per release; amount from the awards, or the signed contracts when the award has none)
List<SourceAward> parseUkReleases(Map<String, dynamic> page, UkService service) {
  final out = <SourceAward>[];
  for (final r in (page['releases'] as List? ?? const []).cast<Map<String, dynamic>>()) {
    final tender = (r['tender'] as Map?)?.cast<String, dynamic>() ?? const {};
    final awards = (r['awards'] as List? ?? const []).cast<Map<String, dynamic>>().where((a) => a['status'] != 'cancelled' && a['status'] != 'unsuccessful').toList();
    if (awards.isEmpty) continue;
    double gbp(Object? v) {
      final m = (v as Map?)?.cast<String, dynamic>();
      if (m == null || (m['currency'] != null && m['currency'] != 'GBP')) return 0;
      return (m['amount'] as num?)?.toDouble() ?? 0;
    }

    var amount = awards.fold<double>(0, (s, a) => s + gbp(a['value']));
    if (amount <= 0) amount = (r['contracts'] as List? ?? const []).fold<double>(0, (s, c) => s + gbp((c as Map)['value']));
    if (amount <= 0) continue;
    final winners = <(String, String?)>[];
    for (final a in awards) {
      for (final s in (a['suppliers'] as List? ?? const []).cast<Map<String, dynamic>>()) {
        final n = (s['name'] as String? ?? '').trim();
        if (n.isNotEmpty && !winners.any((w) => w.$1.toLowerCase() == n.toLowerCase())) winners.add((n, s['id'] as String?));
      }
    }
    DateTime? date;
    for (final a in awards) {
      date ??= DateTime.tryParse(a['date'] as String? ?? '');
    }
    for (final c in (r['contracts'] as List? ?? const []).cast<Map<String, dynamic>>()) {
      date ??= DateTime.tryParse(c['dateSigned'] as String? ?? '');
    }
    date ??= DateTime.tryParse(r['date'] as String? ?? '');
    int? bidders;
    for (final s in ((r['bids'] as Map?)?['statistics'] as List? ?? const []).cast<Map<String, dynamic>>()) {
      if (s['measure'] == 'bids' && s['value'] is num) bidders = (bidders ?? 0) + (s['value'] as num).toInt();
    }
    final ocid = r['ocid'] as String? ?? '';
    final id = r['id'] as String? ?? ocid;
    out.add(SourceAward(
      id: '${service.prefix}:$ocid',
      name: (tender['title'] as String? ?? '').trim(),
      agency: ((r['buyer'] as Map?)?['name'] as String? ?? '').trim(),
      winners: winners.take(30).toList(), // framework agreements can list 100+ suppliers
      amount: amount,
      date: date?.toLocal(),
      category: {'goods': 'Goods', 'services': 'Services', 'works': 'Works'}[tender['mainProcurementCategory']] ?? '',
      method: (tender['procurementMethodDetails'] as String? ?? '').trim(),
      bidders: bidders,
      budget: gbp(tender['value']) > 0 ? gbp(tender['value']) : null,
      url: switch (service) {
        UkService.contractsFinder => 'https://www.contractsfinder.service.gov.uk/Notice/${ocid.replaceFirst(RegExp(r'^ocds-[a-z0-9]+-'), '')}',
        UkService.findATender => 'https://www.find-tender.service.gov.uk/Notice/$id',
      },
    ));
  }
  return out;
}
