import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:self_quote/case_analysis/sources/source.dart';
import 'package:self_quote/case_analysis/sources/ted.dart';

/// 歐盟 TED：依關鍵字、按月查詢決標公告
void main() {
  Map<String, dynamic> notice(
    String pub, {
    Object? total = 12000,
    String cur = 'EUR',
    Object? title,
  }) => {
    'publication-number': pub,
    'notice-title':
        title ??
        {
          'deu': 'Deutschland – Webdesign',
          'eng': 'Germany – Web design services – Neue Webseite',
        },
    'buyer-name': {
      'deu': ['Stadt Köln'],
    },
    'winner-name': {
      'deu': ['Pixel GmbH', 'pixel gmbh'],
    },
    'total-value': total,
    'total-value-cur': [cur],
    'publication-date': '2026-10-01+02:00',
    'contract-nature': ['services'],
    'procedure-type': 'open',
  };

  test(
    'notices become awards: English title, EUR total, de-duplicated winners; unknown or foreign-currency totals left out',
    () {
      final out = parseTedNotices([
        notice('1-2026'),
        notice('2-2026', total: -1),
        notice('3-2026', cur: 'PLN'),
      ]);
      expect(out, hasLength(1));
      final a = out.single;
      expect(
        (a.id, a.name, a.agency, a.amount),
        (
          'ted:1-2026',
          'Germany – Web design services – Neue Webseite',
          'Stadt Köln',
          12000,
        ),
      );
      expect(a.winners.map((w) => w.$1), ['Pixel GmbH']);
      expect(
        (a.date, a.category, a.method),
        (DateTime(2026, 10, 1), 'Services', 'open'),
      );
      expect(a.url, 'https://ted.europa.eu/en/notice/-/detail/1-2026');
    },
  );

  test(
    'sync units are per month and per keyword set; no keywords means nothing to fetch',
    () {
      final src = TedSource(pause: Duration.zero);
      final now = DateTime(2026, 11, 3);
      expect(src.unitsFor(now, 3, const []), isEmpty);
      final units = src.unitsFor(now, 1, ['Web design', ' website ']);
      expect(units.map((u) => u.name), [
        'ted:2026-11:web design|website',
        'ted:2026-10:web design|website',
      ]);
      expect(units.first.keywords, ['Web design', 'website']);
      expect(src.country, Country.eu);
      expect(Country.eu.currency, 'EUR');
    },
  );

  test(
    'fetch posts one query per month with the title keywords and pages until a short page',
    () async {
      final http = _Http([
        jsonEncode({
          'notices': [for (var i = 0; i < 250; i++) notice('$i-2026')],
        }),
        jsonEncode({
          'notices': [notice('250-2026'), notice('0-2026')],
        }), // 0-2026 repeats: counted once
      ]);
      final unit = TedSource(
        pause: Duration.zero,
      ).unitsFor(DateTime(2026, 10, 20), 0, ['website']).single;
      final batches = await TedSource(
        pause: Duration.zero,
      ).fetch(unit, http).toList();
      expect(batches.map((b) => b.length), [250, 1]);
      final q = jsonDecode(http.bodies.first) as Map;
      expect(
        q['query'],
        allOf(
          contains('notice-title ~ "website"'),
          contains('publication-date >= 20261001'),
          contains('publication-date < 20261101'),
        ),
      );
      expect(jsonDecode(http.bodies.last)['page'], 2);
    },
  );
}

class _Http implements SourceHttp {
  final List<String> pages;
  final bodies = <String>[];
  _Http(this.pages);

  @override
  Future<String?> postJson(
    Uri url,
    String body, {
    void Function(Duration wait)? onWait,
  }) async {
    bodies.add(body);
    return pages[bodies.length - 1];
  }

  @override
  Future<String?> getText(
    Uri url, {
    void Function(Duration wait)? onWait,
  }) async => null;

  @override
  Future<File?> download(
    Uri url, {
    void Function(int bytes)? onBytes,
    void Function(Duration wait)? onWait,
  }) async => null;
}
