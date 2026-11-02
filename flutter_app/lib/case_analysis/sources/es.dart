/// España: Plataforma de Contratación del Sector Público (PLACSP), datos abiertos de licitaciones publicadas en los
/// perfiles del contratante (sin contratos menores). Un zip mensual de ficheros ATOM (CODICE); solo se guardan las
/// licitaciones adjudicadas (ADJ) o resueltas (RES). Se lee en streaming en una isolate.
library;

import 'dart:async';
import 'dart:io';

import 'source.dart';
import 'stream_parse.dart';

const esHost = 'contrataciondelsectorpublico.gob.es';
const _monthly = 'https://$esHost/sindicacion/sindicacion_643/licitacionesPerfilesContratanteCompleto3_';

class SpainSource extends AwardSource {
  @override
  Country get country => Country.es;

  /// El mes en curso aún no tiene zip (se publica al terminar el mes)
  @override
  List<SyncUnit> units(DateTime now, int months) => [
        for (var i = 1; i <= months; i++)
          () {
            final m = DateTime(now.year, now.month - i, 1);
            return SyncUnit('es:${m.year}${m.month.toString().padLeft(2, '0')}', DateTime(m.year, m.month + 1, 0));
          }(),
      ];

  @override
  Stream<List<SourceAward>> fetch(SyncUnit unit, SourceHttp http) async* {
    final file = await http.download(Uri.parse('$_monthly${unit.name.substring(3)}.zip'));
    if (file == null) return;
    try {
      yield* inIsolate(_parseZip, file.path);
    } finally {
      await file.parent.delete(recursive: true).catchError((_) => file.parent);
    }
  }
}

Stream<List<SourceAward>> _parseZip(String path) async* {
  final f = File(path);
  for (final e in await zipEntries(f)) {
    if (!e.name.toLowerCase().endsWith('.atom')) continue;
    yield* batches(xmlElements(zipEntryText(f, e), 'entry').map(parseSpainEntry).where((a) => a != null).cast<SourceAward>());
  }
}

String _text(String s) => s
    .replaceAllMapped(RegExp(r'&#(\d+);'), (m) => String.fromCharCode(int.parse(m[1]!)))
    .replaceAllMapped(RegExp(r'&#x([0-9a-fA-F]+);'), (m) => String.fromCharCode(int.parse(m[1]!, radix: 16)))
    .replaceAll('&lt;', '<')
    .replaceAll('&gt;', '>')
    .replaceAll('&quot;', '"')
    .replaceAll('&apos;', "'")
    .replaceAll('&amp;', '&')
    .trim();

String? _first(String xml, String tag) {
  final m = RegExp('<$tag(?:\\s[^>]*)?>([^<]*)</$tag>').firstMatch(xml);
  return m == null ? null : _text(m[1]!);
}

/// Una entrada ATOM → adjudicación (null si no está adjudicada o no tiene importe)
SourceAward? parseSpainEntry(String entry) {
  final status = _first(entry, 'cbc-place-ext:ContractFolderStatusCode');
  if (status != 'ADJ' && status != 'RES') return null;
  final results = RegExp(r'<cac:TenderResult>(.*?)</cac:TenderResult>', dotAll: true).allMatches(entry).map((m) => m[1]!).toList();
  var amount = 0.0;
  int? bidders;
  DateTime? date;
  final winners = <(String, String?)>[];
  for (final r in results) {
    final code = _first(r, 'cbc:ResultCode');
    if (code != null && code != '8' && code != '9') continue; // 8 adjudicado provisionalmente, 9 adjudicado / formalizado
    final total = RegExp(r'<cac:LegalMonetaryTotal>(.*?)</cac:LegalMonetaryTotal>', dotAll: true).firstMatch(r)?[1] ?? '';
    amount += double.tryParse(_first(total, 'cbc:TaxExclusiveAmount') ?? _first(total, 'cbc:PayableAmount') ?? '') ?? 0;
    final q = int.tryParse(_first(r, 'cbc:ReceivedTenderQuantity') ?? '');
    if (q != null && (bidders == null || q > bidders)) bidders = q;
    date ??= DateTime.tryParse(_first(r, 'cbc:AwardDate') ?? '');
    for (final w in RegExp(r'<cac:WinningParty>(.*?)</cac:WinningParty>', dotAll: true).allMatches(r)) {
      final name = _first(w[1]!, 'cbc:Name') ?? '';
      if (name.isNotEmpty && !winners.any((x) => x.$1.toLowerCase() == name.toLowerCase())) winners.add((name, _first(w[1]!, 'cbc:ID')));
    }
  }
  if (amount <= 0) return null;
  final party = RegExp(r'<cac-place-ext:LocatedContractingParty>.*?<cac:Party>(.*?)</cac:Party>', dotAll: true).firstMatch(entry)?[1] ?? '';
  final project = RegExp(r'<cac:ProcurementProject>(.*?)</cac:ProcurementProject>', dotAll: true).firstMatch(entry)?[1] ?? '';
  final budget = double.tryParse(_first(RegExp(r'<cac:BudgetAmount>(.*?)</cac:BudgetAmount>', dotAll: true).firstMatch(project)?[1] ?? '', 'cbc:TaxExclusiveAmount') ?? '');
  final link = RegExp(r'<link href="([^"]+)"').firstMatch(entry)?[1];
  final id = _first(entry, 'id') ?? '';
  final agency = _first(RegExp(r'<cac:PartyName>(.*?)</cac:PartyName>', dotAll: true).firstMatch(party)?[1] ?? '', 'cbc:Name') ?? '';
  return SourceAward(
    id: 'es:${id.split('/').last}',
    name: _first(project, 'cbc:Name') ?? _first(entry, 'title') ?? '',
    agency: agency,
    winners: winners.take(30).toList(),
    amount: amount,
    // algunas fechas de adjudicación vienen mal escritas (p. ej. año 0026): se usa la fecha de actualización
    date: date != null && date.year >= 2000 ? date : DateTime.tryParse(_first(entry, 'updated') ?? ''),
    category: esContractTypes[_first(project, 'cbc:TypeCode')] ?? '',
    method: esProcedures[_first(entry, 'cbc:ProcedureCode')] ?? '',
    budget: budget != null && budget > 0 ? budget : null,
    bidders: bidders,
    url: link == null ? '' : _text(link),
  );
}

/// Tipo de contrato (ContractCode 2.08)
const esContractTypes = {
  '1': 'Suministros', '2': 'Servicios', '3': 'Obras', '21': 'Gestión de Servicios Públicos', '22': 'Concesión de Servicios',
  '31': 'Concesión de Obras Públicas', '32': 'Concesión de Obras', '40': 'Colaboración público-privada', '7': 'Administrativo especial',
  '8': 'Privado', '50': 'Patrimonial',
};

/// Procedimiento (SyndicationTenderingProcessCode 2.07)
const esProcedures = {
  '1': 'Abierto', '2': 'Restringido', '3': 'Negociado sin publicidad', '4': 'Negociado con publicidad', '5': 'Diálogo competitivo',
  '6': 'Contrato menor', '7': 'Derivado de acuerdo marco', '8': 'Concurso de proyectos', '9': 'Abierto simplificado',
  '10': 'Asociación para la innovación', '11': 'Derivado de asociación para la innovación', '12': 'Sistema dinámico de adquisición',
  '13': 'Licitación con negociación', '100': 'Normas internas', '999': 'Otros',
};
