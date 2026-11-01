/// Portugal: Portal BASE (IMPIC) — contratos públicos registados pelas entidades adjudicantes.
/// Ficheiro anual no dados.gov.pt (JSON dentro de um zip, ~365 MB por ano descomprimido); o endereço muda a cada
/// atualização, por isso é obtido pela API do dados.gov.pt. Lido em streaming numa isolate.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'source.dart';
import 'stream_parse.dart';

const _dataset = 'https://dados.gov.pt/api/1/datasets/contratos-publicos-portal-base-impic-contratos-de-2012-a-2026/';

class PortugalSource extends AwardSource {
  @override
  Country get country => Country.pt;

  @override
  List<SyncUnit> units(DateTime now, int months) {
    final from = DateTime(now.year, now.month - months, now.day);
    return [for (var y = now.year; y >= from.year; y--) SyncUnit('pt:$y', DateTime(y, 12, 31))];
  }

  /// O ano corrente é atualizado com frequência; anos fechados só mudam com correções
  @override
  Duration get settledAfter => const Duration(days: 60);

  @override
  Stream<List<SourceAward>> fetch(SyncUnit unit, SourceHttp http) async* {
    final year = unit.name.substring(3);
    final meta = await http.getText(Uri.parse(_dataset));
    if (meta == null) throw StateError('dados.gov.pt unavailable');
    final res = ((jsonDecode(meta) as Map)['resources'] as List).cast<Map<String, dynamic>>();
    final zip = res.where((r) => '${r['title']}'.toLowerCase() == 'contratos$year.zip').firstOrNull;
    if (zip == null) return; // ainda não publicado
    final file = await http.download(Uri.parse(zip['url'] as String));
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
    if (!e.name.toLowerCase().endsWith('.json')) continue;
    yield* batches(jsonArrayObjects(zipEntryText(f, e)).map(parsePortugalContract).where((a) => a != null).cast<SourceAward>());
  }
}

/// "NIF - Nome" → (nome, NIF)
(String, String?) _party(Object? s) {
  final t = '$s'.trim();
  final m = RegExp(r'^(\d{6,})\s*-\s*(.+)$').firstMatch(t);
  String clean(String x) => x.replaceFirst(RegExp(r'^[\s-]+'), '').trim(); // NIF em falta deixa "- - Nome"
  return m == null ? (clean(t), null) : (clean(m[2]!), m[1]);
}

DateTime? _date(Object? s) {
  final m = RegExp(r'^(\d{2})/(\d{2})/(\d{4})').firstMatch('${s ?? ''}');
  return m == null ? null : DateTime(int.parse(m[3]!), int.parse(m[2]!), int.parse(m[1]!));
}

/// Um contrato do ficheiro anual
SourceAward? parsePortugalContract(String json) {
  final c = jsonDecode(json) as Map<String, dynamic>;
  final amount = (c['precoContratual'] as num?)?.toDouble() ?? 0;
  final name = '${c['objectoContrato'] ?? ''}'.trim();
  if (amount <= 0 || name.isEmpty) return null;
  final buyers = (c['adjudicante'] as List? ?? const []);
  final winners = [for (final w in (c['adjudicatarios'] as List? ?? const [])) _party(w)]..removeWhere((w) => w.$1.isEmpty);
  final competitors = c['concorrentes'];
  final base = (c['precoBaseProcedimento'] as num?)?.toDouble();
  final id = '${c['idcontrato']}';
  return SourceAward(
    id: 'pt:$id',
    name: name,
    agency: buyers.isEmpty ? '' : _party(buyers.first).$1,
    winners: winners.take(30).toList(),
    amount: amount,
    date: _date(c['dataCelebracaoContrato']) ?? _date(c['dataPublicacao']),
    category: (c['tipoContrato'] as List? ?? const []).join(', '),
    method: '${c['tipoprocedimento'] ?? ''}',
    awardWay: '${c['TipoCriterioAdjudicacao'] ?? ''}',
    budget: base != null && base > 0 ? base : null,
    bidders: competitors is List && competitors.isNotEmpty ? competitors.length : null,
    url: 'https://www.base.gov.pt/Base4/pt/detalhe/?type=contratos&id=$id',
  );
}
