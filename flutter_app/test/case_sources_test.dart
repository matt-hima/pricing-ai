import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:self_quote/case_analysis/case_db.dart';
import 'package:self_quote/case_analysis/case_store.dart';
import 'package:self_quote/case_analysis/keywords.dart';
import 'package:self_quote/case_analysis/sources/es.dart';
import 'package:self_quote/case_analysis/sources/jp.dart';
import 'package:self_quote/case_analysis/sources/pt.dart';
import 'package:self_quote/case_analysis/sources/source.dart';
import 'package:self_quote/case_analysis/sources/stream_parse.dart';
import 'package:self_quote/case_analysis/sources/uk.dart';

/// 其他國家的官方決標資料（測試資料是照各來源格式寫的虛構案件與廠商）
void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  const jpCsv = '﻿"0000000000000000001","Ｒ８ウェブサイト運用保守業務","2026-05-10","12000000.00","W1","8002040","株式会社テストシステムズ","1234567890123"\r\n'
      '"0000000000000000002","庁舎清掃業務","2026-06-01","3000000.00","S1","8004020","サンプル清掃株式会社",""\r\n'
      '"0000000000000000003","複数落札の物品購入","2026-06-02","100.00","N1","8002050","Ａ商事",""\r\n'
      '"0000000000000000003","複数落札の物品購入","2026-06-02","250.00","N1","8002050","Ｂ商事",""\r\n';

  Map<String, dynamic> ukPage(List<Map<String, dynamic>> releases, {String? next}) => {
        'releases': releases,
        'links': {'next': ?next},
      };
  Map<String, dynamic> ukRelease(String ocid, String title, double amount, {List<String> suppliers = const ['Example Web Ltd'], String date = '2026-09-15T00:00:00Z', bool contractOnly = false, int? bids}) => {
        'ocid': ocid,
        'id': '$ocid-award',
        'date': date,
        'buyer': {'name': 'Example Borough Council'},
        'tender': {'title': title, 'mainProcurementCategory': 'services', 'procurementMethodDetails': 'Open procedure'},
        'awards': [
          {
            'status': 'active',
            'date': contractOnly ? null : date,
            'value': contractOnly ? null : {'amount': amount, 'currency': 'GBP'},
            'suppliers': [for (final s in suppliers) {'name': s}],
          },
        ],
        if (contractOnly)
          'contracts': [
            {'value': {'amount': amount, 'currency': 'GBP'}, 'dateSigned': date},
          ],
        if (bids != null) 'bids': {'statistics': [{'measure': 'bids', 'value': bids}]},
      };

  String esEntry(String id, String status, String name, {double amount = 50000, int bids = 4}) => '''
<entry>
  <id>https://contrataciondelestado.es/sindicacion/licitacionesPerfilContratante/$id</id>
  <link href="https://contrataciondelestado.es/wps/poc?uri=deeplink:detalle_licitacion&amp;idEvl=$id"/>
  <title>$name</title>
  <updated>2026-09-20T10:00:00+02:00</updated>
  <cac-place-ext:ContractFolderStatus>
    <cbc-place-ext:ContractFolderStatusCode languageID="es">$status</cbc-place-ext:ContractFolderStatusCode>
    <cac-place-ext:LocatedContractingParty><cac:Party><cac:PartyName><cbc:Name>Ayuntamiento de Ejemplo</cbc:Name></cac:PartyName></cac:Party></cac-place-ext:LocatedContractingParty>
    <cac:ProcurementProject><cbc:Name>$name</cbc:Name><cbc:TypeCode>2</cbc:TypeCode>
      <cac:BudgetAmount><cbc:TaxExclusiveAmount currencyID="EUR">60000</cbc:TaxExclusiveAmount></cac:BudgetAmount></cac:ProcurementProject>
    <cac:TenderResult><cbc:ResultCode>9</cbc:ResultCode><cbc:AwardDate>2026-09-18</cbc:AwardDate><cbc:ReceivedTenderQuantity>$bids</cbc:ReceivedTenderQuantity>
      <cac:WinningParty><cac:PartyIdentification><cbc:ID schemeName="NIF">B00000000</cbc:ID></cac:PartyIdentification><cac:PartyName><cbc:Name>Ejemplo Digital, S.L.</cbc:Name></cac:PartyName></cac:WinningParty>
      <cac:AwardedTenderedProject><cac:LegalMonetaryTotal><cbc:TaxExclusiveAmount currencyID="EUR">$amount</cbc:TaxExclusiveAmount></cac:LegalMonetaryTotal></cac:AwardedTenderedProject></cac:TenderResult>
    <cac:TenderingProcess><cbc:ProcedureCode>9</cbc:ProcedureCode></cac:TenderingProcess>
  </cac-place-ext:ContractFolderStatus>
</entry>''';

  final ptContracts = [
    {
      'idcontrato': '900001',
      'objectoContrato': 'Manutenção do sítio web municipal',
      'adjudicante': ['500000000 - Município de Exemplo'],
      'adjudicatarios': ['510000000 - Exemplo Web, Lda'],
      'precoContratual': 18000.0,
      'precoBaseProcedimento': 20000.0,
      'dataCelebracaoContrato': '12/03/2026',
      'tipoprocedimento': 'Consulta Prévia',
      'tipoContrato': ['Aquisição de serviços'],
      'concorrentes': ['510000000 - Exemplo Web, Lda', '520000000 - Outra Empresa, S.A.'],
    },
    {'idcontrato': '900002', 'objectoContrato': 'Contrato sem valor', 'adjudicante': ['x'], 'adjudicatarios': [], 'precoContratual': 0},
  ];

  test('searchable text ignores case, accents and full-width letters', () {
    expect(searchText('Manutenção do SÍTIO Web', cjk: false), 'manutencao do sitio web');
    expect(searchText('株式会社ＮＴＴデータ', cjk: true), '株式会社nttデータ');
    expect(searchText('網 站', cjk: true), '網站');
    expect(halfWidth('Ｐｏｌｅ＆Ｌｉｎｅ'), 'Pole&Line');
  });

  test('Chinese keywords suggest local wording per country', () {
    expect(localKeywords('網站維護', Country.uk), containsAll(['website', 'maintenance']));
    expect(localKeywords('網站', Country.es), contains('sitio web'));
    expect(localKeywords('網站', Country.pt), contains('sítio web'));
    expect(localKeywords('APP', Country.jp), contains('アプリ'));
    expect(localKeywords('不認得的字', Country.uk), isEmpty);
  });

  test('Japan: one award per case number, codes named, multiple winners added up', () {
    final a = parseJapanCsv(jpCsv);
    expect(a.length, 3);
    final web = a.firstWhere((x) => x.id == 'jp:0000000000000000001');
    expect((web.name, web.agency, web.method, web.amount, web.winners.single), ('R8ウェブサイト運用保守業務', 'デジタル庁', '一般競争入札・総合評価', 12000000.0, ('株式会社テストシステムズ', '1234567890123')));
    final multi = a.firstWhere((x) => x.id == 'jp:0000000000000000003');
    expect(multi.amount, 350);
    expect(multi.winners.map((w) => w.$1), ['A商事', 'B商事']);
    // 年度は 4 月始まり：2026 年 11 月から 12 か月 → 2026 年度と 2025 年度
    expect(JapanSource().units(DateTime(2026, 11, 1), 12).map((u) => u.name), ['jp:2026', 'jp:2025']);
  });

  test('UK: award value, or the contract value when the award has none; buyers, suppliers and bid counts', () {
    final page = ukPage([
      ukRelease('ocds-b5fd17-aaaa', 'Website redesign', 42000),
      ukRelease('ocds-h6vhtk-0001', 'Cloud hosting', 90000, contractOnly: true, bids: 5),
      {'ocid': 'x', 'tender': {'title': 'No award'}, 'awards': []},
    ]);
    final cf = parseUkReleases(page, UkService.contractsFinder);
    expect(cf.length, 2);
    expect((cf.first.amount, cf.first.agency, cf.first.winners.single.$1, cf.first.url), (42000.0, 'Example Borough Council', 'Example Web Ltd', 'https://www.contractsfinder.service.gov.uk/Notice/aaaa'));
    final fts = parseUkReleases(page, UkService.findATender);
    expect((fts[1].amount, fts[1].bidders, fts[1].url), (90000.0, 5, 'https://www.find-tender.service.gov.uk/Notice/ocds-h6vhtk-0001-award'));
    expect(UkSource(UkService.contractsFinder).units(DateTime(2026, 11, 1), 2).map((u) => u.name), ['uk-cf:2026-11', 'uk-cf:2026-10', 'uk-cf:2026-09']);
  });

  test('Spain: only awarded (ADJ/RES) entries; winners, budget, bids and procedure', () async {
    final xml = '<feed>${esEntry('1', 'RES', 'Mantenimiento del sitio web')}${esEntry('2', 'PUB', 'Aún sin adjudicar')}</feed>';
    final got = await xmlElements(Stream.fromIterable([xml.substring(0, 300), xml.substring(300)]), 'entry').map(parseSpainEntry).where((a) => a != null).toList();
    expect(got.length, 1);
    final a = got.single!;
    expect((a.id, a.agency, a.amount, a.budget, a.bidders, a.category, a.method), ('es:1', 'Ayuntamiento de Ejemplo', 50000.0, 60000.0, 4, 'Servicios', 'Abierto simplificado'));
    expect(a.winners.single, ('Ejemplo Digital, S.L.', 'B00000000'));
    expect(a.url, 'https://contrataciondelestado.es/wps/poc?uri=deeplink:detalle_licitacion&idEvl=1');
    final typo = parseSpainEntry(esEntry('3', 'ADJ', 'Sitio web').replaceFirst('2026-09-18', '0026-09-18'))!;
    expect(typo.date!.year, 2026); // 年份打錯時改用更新日期
    expect(SpainSource().units(DateTime(2026, 11, 1), 2).map((u) => u.name), ['es:202610', 'es:202609']); // 本月的檔月底才公開
  });

  test('Portugal: a zipped JSON array is read object by object, without loading the whole file', () async {
    final dir = await Directory.systemTemp.createTemp('pt_test');
    addTearDown(() => dir.delete(recursive: true));
    final zip = Archive()..addFile(ArchiveFile.string('Contratos2026.json', jsonEncode(ptContracts)));
    final f = File('${dir.path}/c.zip')..writeAsBytesSync(ZipEncoder().encode(zip));
    final entries = await zipEntries(f);
    expect(entries.single.name, 'Contratos2026.json');
    final objs = await jsonArrayObjects(zipEntryText(f, entries.single)).toList();
    expect(objs.length, 2);
    final a = objs.map(parsePortugalContract).whereType<SourceAward>().single;
    expect(parsePortugalContract(jsonEncode({...ptContracts.first, 'adjudicatarios': ['- - Nome Exemplo']}))!.winners.single.$1, 'Nome Exemplo');
    expect((a.id, a.agency, a.amount, a.budget, a.bidders, a.date), ('pt:900001', 'Município de Exemplo', 18000.0, 20000.0, 2, DateTime(2026, 3, 12)));
    expect(a.winners.single, ('Exemplo Web, Lda', '510000000'));
  });

  test('JSON splitter keeps braces inside strings and escaped quotes', () async {
    final got = await jsonArrayObjects(Stream.fromIterable(['[{"a":"x}{\\"y"},', '{"b":1}]'])).toList();
    expect(got, ['{"a":"x}{\\"y"}', '{"b":1}']);
  });

  group('database', () {
    late CaseDb db;
    setUp(() => db = CaseDb(NativeDatabase.memory()));
    tearDown(() => db.close());

    test('countries are kept apart; keywords match without accents; a newer record is not overwritten by an older one', () async {
      final pt = [parsePortugalContract(jsonEncode(ptContracts.first))!];
      await db.importAwards(Country.pt, pt);
      await db.importAwards(Country.jp, parseJapanCsv(jpCsv));
      expect(await db.countAwards(const AwardFilter(country: Country.pt)), 1);
      expect(await db.countAwards(const AwardFilter(country: Country.jp)), 3);
      expect(await db.countAwards(const AwardFilter()), 0); // 台灣沒有資料
      expect(await db.countAwards(const AwardFilter(country: Country.pt, keywords: ['sitio web'])), 1);
      expect(await db.countAwards(const AwardFilter(country: Country.jp, keywords: ['ウェブサイト'])), 1);
      expect((await db.vendorRecords(const AwardFilter(country: Country.pt))).single.name, 'Exemplo Web, Lda');

      SourceAward at(DateTime d, double amount) => SourceAward(id: 'es:7', name: 'Sitio web', agency: 'Ayuntamiento', winners: const [('X, S.L.', null)], amount: amount, date: d);
      await db.importAwards(Country.es, [at(DateTime(2026, 9, 1), 100)]);
      await db.importAwards(Country.es, [at(DateTime(2026, 8, 1), 50)]); // 較舊的月份後匯入
      expect((await db.awards(const AwardFilter(country: Country.es))).single.amount, 100);
      await db.importAwards(Country.es, [at(DateTime(2026, 10, 1), 120)]);
      expect((await db.awards(const AwardFilter(country: Country.es))).single.amount, 120);
    });

    test('search filters every country, OR keywords, dates and literal wildcards', () async {
      final titles = {
        Country.tw: ('網 站維護 100%_完成', '網站'),
        Country.uk: ('WEBSITE maintenance 100%_complete', 'website'),
        Country.es: ('Diseño de PÁGINA WEB 100%_completo', 'pagina web'),
        Country.pt: ('Manutenção do SÍTIO WEB 100%_completo', 'sitio web'),
        Country.jp: ('Ｗｅｂ サイト保守 100%_完了', 'webサイト'),
      };
      for (final entry in titles.entries) {
        await db.importAwards(entry.key, [
          SourceAward(id: '${entry.key.name}:search', name: entry.value.$1,
            agency: 'Agency', winners: const [('Vendor', null)],
            amount: 100, date: DateTime(2026, 9, 15)),
        ]);
      }
      for (final entry in titles.entries) {
        final filter = AwardFilter(country: entry.key,
          keywords: ['no matching title', entry.value.$2],
          source: 'dataset', from: DateTime(2026, 9), to: DateTime(2026, 10));
        expect(await db.countAwards(filter), 1, reason: entry.key.name);
        expect((await db.awards(filter)).single.name, entry.value.$1);
        expect(await db.countAwards(AwardFilter(country: entry.key,
          keywords: ['100%_'])), 1);
        expect(await db.countAwards(AwardFilter(country: entry.key,
          keywords: ['100%X'])), 0);
        expect(await db.countAwards(AwardFilter(country: entry.key,
          from: DateTime(2026, 10))), 0);
      }
    });

    test('sync: settled periods are skipped, recent ones rechecked at most daily, failures retried next time', () async {
      final http = _FakeHttp({'uk-cf': jsonEncode(ukPage([ukRelease('ocds-b5fd17-bbbb', 'Website support', 30000)]))});
      final store = CaseStore(db, _NoFetcher(), sourceHttp: http);
      final now = DateTime(2026, 11, 10);
      final uk = [UkSource(UkService.contractsFinder, pause: Duration.zero)];
      expect(await store.syncSource(uk, 2, now: now), 3); // 11、10、9 月
      expect(http.gets, 3);
      expect(await db.countAwards(const AwardFilter(country: Country.uk, keywords: ['website'])), 1);
      expect(await store.syncSource(uk, 2, now: now), 0); // 同一天：不再取
      expect(await store.syncSource(uk, 2, now: now.add(const Duration(days: 2))), 3); // 兩天後：三個月都還在 45 天內，重新取
      expect(http.gets, 6);
      expect(await store.syncSource(uk, 2, now: DateTime(2027, 3, 1)), 3); // 2027 年 3 月：1–3 月是新的期間

      http.fail = true;
      var received = 0;
      expect(await store.syncSource([JapanSource()], 1, now: now, onBytes: (n) => received = n), 0); // 連不上：不記錄
      expect(received, 4 << 20); // 下載進度有回報到畫面
      expect(await db.datasetFileRow('jp:2026'), isNull);
    });

    test('a rate-limit wait is shown; stopping keeps the units already imported', () async {
      final http = _FakeHttp({'uk-cf': jsonEncode(ukPage([ukRelease('ocds-b5fd17-cccc', 'Website hosting', 20000)]))})..rateLimited = true;
      final store = CaseStore(db, _NoFetcher(), sourceHttp: http);
      final waits = <Duration>[];
      var stop = false;
      final got = await store.syncSource(
        [UkSource(UkService.contractsFinder, pause: Duration.zero)],
        3,
        now: DateTime(2026, 11, 10),
        onWait: waits.add,
        onProgress: (done, total) => stop = done >= 1, // 第一個月做完就按停止
        cancelled: () => stop,
      );
      expect(got, 1);
      expect(waits.first, const Duration(seconds: 120));
      expect(await db.datasetFileRow('uk-cf:2026-11'), isNotNull);
      expect(await db.datasetFileRow('uk-cf:2026-10'), isNull); // 沒做的月份下次再取
      expect(await db.countAwards(const AwardFilter(country: Country.uk)), 1);
    });
  });
}

class _NoFetcher implements DataFetcher {
  @override
  Future<String?> get(Uri url) async => null;
  @override
  Future<int?> size(Uri url) async => null;
}

class _FakeHttp implements SourceHttp {
  final Map<String, String> pages;
  int gets = 0;
  bool fail = false;
  _FakeHttp(this.pages);

  bool rateLimited = false;

  @override
  Future<String?> getText(Uri url, {void Function(Duration wait)? onWait}) async {
    gets++;
    if (rateLimited) onWait?.call(const Duration(seconds: 120)); // 伺服器回 429 + Retry-After，等過之後成功
    if (fail) return null;
    return url.host.contains('contractsfinder') ? pages['uk-cf'] : null;
  }

  @override
  Future<File?> download(Uri url, {void Function(int bytes)? onBytes, void Function(Duration wait)? onWait}) async {
    onBytes?.call(4 << 20); // 收到 4 MB 後連線中斷
    return null;
  }
}
