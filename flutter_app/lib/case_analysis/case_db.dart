/// 案件資料庫（Drift / SQLite，只在桌面版開啟），照分析用的星狀結構設計（參考 Metabase 的資料模型與提問方式）：
/// - 事實表（fact）：每列是一個事件，帶可加總的量值與指向維度的外鍵
///     fact_award   一件決標一列（機關 + 案號）：金額、預算、投標家數、日期、類別、招標 / 決標方式、來源
///     fact_bid     一件決標 × 一家投標廠商一列：是否得標 → 得標率、競爭對手紀錄
///     fact_review  一件決標 × 一位評選委員一列：是否出席 → 評選委員交叉分析
/// - 維度表（dim）：用來分組的實體  dim_agency、dim_vendor、dim_reviewer
/// - 匯入紀錄：dataset_file（哪些官方資料檔匯入過）、search_total（即時查詢在網站上的總筆數）
/// 提問方式同 Metabase：篩選（AwardFilter，相當於 segment）→ 量值（Metric）→ 分組（Dimension，時間以月為單位）。
/// 官方資料檔讀進來就丟，不保留 XML；同一件案件只留一筆，新資料只更新既有的那筆。
library;

import 'package:drift/drift.dart';

import 'opendata.dart' show DatasetAward;
import 'pcc.dart';

part 'case_db.g.dart';

// ---------- 維度表 ----------

/// 機關（語意：實體名稱）
class DimAgency extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().unique()();
}

/// 廠商（得標或投標）。統一編號只有決標公告明細才有
class DimVendor extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().unique()();
  TextColumn get taxId => text().nullable()();
}

/// 評選委員（同名同職業視為同一人）
class DimReviewer extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  TextColumn get job => text()();

  @override
  List<Set<Column>> get uniqueKeys => [
        {name, job},
      ];
}

// ---------- 事實表 ----------

/// 決標：一件案件一列（主鍵：機關|案號）
class FactAward extends Table {
  TextColumn get caseKey => text()(); // 實體主鍵
  TextColumn get caseNo => text()();
  TextColumn get name => text()(); // 標案名稱（關鍵字篩選用）
  IntColumn get agencyId => integer().references(DimAgency, #id)(); // 外鍵
  IntColumn get winnerId => integer().nullable().references(DimVendor, #id)(); // 外鍵
  TextColumn get category => text().withDefault(const Constant(''))(); // 類別：工程 / 財物 / 勞務
  TextColumn get tenderMethod => text().withDefault(const Constant(''))(); // 類別：招標方式
  TextColumn get awardWay => text().withDefault(const Constant(''))(); // 類別：決標方式
  RealColumn get amount => real()(); // 量值：決標金額（新台幣）
  RealColumn get budget => real().nullable()(); // 量值：預算
  RealColumn get floorPrice => real().nullable()(); // 量值：底價
  IntColumn get bidderCount => integer().nullable()(); // 量值：投標家數
  DateTimeColumn get noticeDate => dateTime().nullable()(); // 時間：決標公告日
  DateTimeColumn get awardDate => dateTime().nullable()(); // 時間：決標日
  TextColumn get url => text().withDefault(const Constant(''))(); // 採購網上的公告（即時查詢才有）
  TextColumn get source => text()(); // 'dataset'（官方開放資料）/ 'live'（即時查詢）
  BoolColumn get hasDetail => boolean().withDefault(const Constant(false))(); // 開過公告明細（有完整投標廠商與委員）
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {caseKey};
}

/// 投標：一件決標 × 一家廠商
class FactBid extends Table {
  TextColumn get caseKey => text().references(FactAward, #caseKey)();
  IntColumn get vendorId => integer().references(DimVendor, #id)();
  BoolColumn get won => boolean()();

  @override
  Set<Column> get primaryKey => {caseKey, vendorId};
}

/// 評選：一件決標 × 一位評選委員
class FactReview extends Table {
  TextColumn get caseKey => text().references(FactAward, #caseKey)();
  IntColumn get reviewerId => integer().references(DimReviewer, #id)();
  BoolColumn get attended => boolean()();

  @override
  Set<Column> get primaryKey => {caseKey, reviewerId};
}

// ---------- 匯入紀錄 ----------

/// 已匯入的官方資料檔
class DatasetFile extends Table {
  TextColumn get name => text()();
  IntColumn get records => integer()();
  IntColumn get size => integer().nullable()();
  DateTimeColumn get checkedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {name};
}

/// 即時查詢在網站上的總筆數（例如某家廠商近 12 個月的得標 / 投標件數）
class SearchTotal extends Table {
  TextColumn get key => text()();
  IntColumn get total => integer()();
  DateTimeColumn get fetchedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {key};
}

String caseKeyOf(String agency, String caseNo) => '${agency.trim()}|${caseNo.trim()}';

// ---------- 提問：篩選 → 量值 → 分組 ----------

/// 篩選條件（相當於 Metabase 的 segment）：名稱含任一關鍵字（連續文字比對）、類別、期間、來源
class AwardFilter {
  final List<String> keywords;
  final ProcCate cate;
  final DateTime? from, to;
  final String? source;
  const AwardFilter({this.keywords = const [], this.cate = ProcCate.any, this.from, this.to, this.source});
}

/// 分組維度
enum Dimension { agency, winner, category, tenderMethod, awardWay, month }

/// 量值
enum Metric { count, sum, average }

class Breakdown {
  final String label;
  final int count;
  final double value;
  const Breakdown(this.label, this.count, this.value);
}

/// 廠商紀錄：投標件數、得標件數、得標總額（依篩選條件）
class VendorRecord {
  final String name;
  final int bids, wins;
  final double wonTotal;
  const VendorRecord(this.name, this.bids, this.wins, this.wonTotal);
  double? get winRate => bids > 0 ? 100 * wins / bids : null;
}

/// 決標（要列出案件時用）
class AwardRow {
  final String caseKey, caseNo, name, agency, winner, category, tenderMethod, awardWay, url, source;
  final double amount;
  final double? budget;
  final int? bidderCount;
  final DateTime? noticeDate;
  const AwardRow({
    required this.caseKey,
    required this.caseNo,
    required this.name,
    required this.agency,
    required this.winner,
    required this.category,
    required this.tenderMethod,
    required this.awardWay,
    required this.url,
    required this.source,
    required this.amount,
    this.budget,
    this.bidderCount,
    this.noticeDate,
  });
}

@DriftDatabase(tables: [DimAgency, DimVendor, DimReviewer, FactAward, FactBid, FactReview, DatasetFile, SearchTotal])
class CaseDb extends _$CaseDb {
  CaseDb(super.e);

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) async {
          await m.createAll();
          // 常用的篩選與分組欄位加索引
          await customStatement('CREATE INDEX IF NOT EXISTS ix_award_notice ON fact_award (notice_date)');
          await customStatement('CREATE INDEX IF NOT EXISTS ix_award_agency ON fact_award (agency_id)');
          await customStatement('CREATE INDEX IF NOT EXISTS ix_award_winner ON fact_award (winner_id)');
          await customStatement('CREATE INDEX IF NOT EXISTS ix_award_url ON fact_award (url)');
          await customStatement('CREATE INDEX IF NOT EXISTS ix_bid_vendor ON fact_bid (vendor_id)');
          await customStatement('CREATE INDEX IF NOT EXISTS ix_review_reviewer ON fact_review (reviewer_id)');
        },
      );

  // ---------- 維度：取得或建立 ----------

  final _agencyIds = <String, int>{}, _vendorIds = <String, int>{};

  Future<int> _agency(String name) async {
    final n = name.trim();
    if (_agencyIds[n] case final id?) return id;
    final row = await (select(dimAgency)..where((t) => t.name.equals(n))).getSingleOrNull();
    return _agencyIds[n] = row?.id ?? await into(dimAgency).insert(DimAgencyCompanion.insert(name: n));
  }

  Future<int?> _vendor(String name, {String? taxId}) async {
    final n = name.trim();
    if (n.isEmpty) return null;
    if (_vendorIds[n] case final id?) {
      if (taxId != null && taxId.isNotEmpty) await (update(dimVendor)..where((t) => t.id.equals(id) & t.taxId.isNull())).write(DimVendorCompanion(taxId: Value(taxId)));
      return id;
    }
    final row = await (select(dimVendor)..where((t) => t.name.equals(n))).getSingleOrNull();
    if (row != null) {
      if (taxId != null && taxId.isNotEmpty && row.taxId == null) await (update(dimVendor)..where((t) => t.id.equals(row.id))).write(DimVendorCompanion(taxId: Value(taxId)));
      return _vendorIds[n] = row.id;
    }
    return _vendorIds[n] = await into(dimVendor).insert(DimVendorCompanion.insert(name: n, taxId: Value(taxId)));
  }

  Future<int> _reviewer(String name, String job) async {
    final row = await (select(dimReviewer)..where((t) => t.name.equals(name) & t.job.equals(job))).getSingleOrNull();
    return row?.id ?? await into(dimReviewer).insert(DimReviewerCompanion.insert(name: name, job: job));
  }

  // ---------- 寫入 ----------

  /// 寫入一件決標：同一件案件只留一筆；已有較新的公告日期就不覆蓋金額與名稱；網址、明細、來源合併保留。
  /// [bids] 是這件的投標廠商（名稱, 統編, 是否得標）；[complete] 表示是公告明細的完整名單（會取代舊的）。
  Future<bool> _upsert({
    required String agency,
    required String caseNo,
    required String name,
    required double amount,
    required String source,
    String category = '',
    String tenderMethod = '',
    String awardWay = '',
    DateTime? noticeDate,
    DateTime? awardDate,
    String url = '',
    double? budget,
    double? floorPrice,
    int? bidderCount,
    List<(String, String?, bool)> bids = const [],
    bool complete = false,
    List<Reviewer> reviewers = const [],
  }) async {
    final key = caseKeyOf(agency, caseNo);
    final old = await (select(factAward)..where((t) => t.caseKey.equals(key))).getSingleOrNull();
    final newer = old == null || (noticeDate != null && (old.noticeDate == null || noticeDate.isAfter(old.noticeDate!)));
    String? winnerName;
    for (final b in bids) {
      if (b.$3) winnerName = b.$1;
    }
    final winnerId = winnerName == null ? null : await _vendor(winnerName);
    final row = FactAwardCompanion(
      caseKey: Value(key),
      caseNo: Value(caseNo),
      name: Value(newer ? name : old.name),
      agencyId: Value(await _agency(agency)),
      winnerId: Value(newer ? (winnerId ?? old?.winnerId) : (old.winnerId ?? winnerId)),
      category: Value(category.isNotEmpty ? category : old?.category ?? ''),
      tenderMethod: Value(tenderMethod.isNotEmpty ? tenderMethod : old?.tenderMethod ?? ''),
      awardWay: Value(awardWay.isNotEmpty ? awardWay : old?.awardWay ?? ''),
      amount: Value(newer ? amount : old.amount),
      budget: Value(budget ?? old?.budget),
      floorPrice: Value(floorPrice ?? old?.floorPrice),
      bidderCount: Value(bidderCount ?? old?.bidderCount),
      noticeDate: Value(newer ? noticeDate ?? old?.noticeDate : old.noticeDate),
      awardDate: Value(awardDate ?? old?.awardDate),
      url: Value(url.isNotEmpty ? url : old?.url ?? ''),
      source: Value(old?.source == 'dataset' || source == 'dataset' ? 'dataset' : 'live'),
      hasDetail: Value(complete || (old?.hasDetail ?? false)),
      updatedAt: Value(DateTime.now()),
    );
    final unchanged = old != null &&
        !complete &&
        !newer &&
        old.amount == row.amount.value &&
        (url.isEmpty || old.url == url) &&
        old.winnerId == row.winnerId.value &&
        (old.source == row.source.value);
    if (!unchanged) await into(factAward).insertOnConflictUpdate(row);
    if (complete) await (delete(factBid)..where((t) => t.caseKey.equals(key))).go();
    for (final (n, tax, won) in bids) {
      final vid = await _vendor(n, taxId: tax);
      if (vid != null) await into(factBid).insertOnConflictUpdate(FactBidCompanion.insert(caseKey: key, vendorId: vid, won: won));
    }
    if (reviewers.isNotEmpty) {
      await (delete(factReview)..where((t) => t.caseKey.equals(key))).go();
      for (final r in reviewers) {
        await into(factReview).insertOnConflictUpdate(FactReviewCompanion.insert(caseKey: key, reviewerId: await _reviewer(r.name, r.job), attended: r.attended));
      }
    }
    return !unchanged; // 投標紀錄是冪等寫入（同一筆重寫不會多一列）
  }

  /// 官方開放資料：得標廠商與（至多一家）未得標廠商
  Future<int> importDataset(Iterable<DatasetAward> awards) async {
    var changed = 0;
    await transaction(() async {
      for (final a in awards) {
        final ok = await _upsert(
          agency: a.agency,
          caseNo: a.caseNo,
          name: a.name,
          amount: a.amount,
          source: 'dataset',
          category: a.category,
          tenderMethod: a.method,
          awardWay: a.awardWay,
          noticeDate: a.noticeDate,
          awardDate: a.awardDate,
          bids: [if (a.winner.isNotEmpty) (a.winner, null, true), if (a.loser.isNotEmpty) (a.loser, null, false)],
        );
        if (ok) changed++;
      }
    });
    return changed;
  }

  /// 即時查詢的結果：清單上的案件、打開過的公告明細（完整投標廠商與評選委員）、網站上的總筆數
  Future<void> saveCollection(CaseCollection col) async {
    final all = [...col.cases, for (final l in col.vendorCases.values) ...l];
    await transaction(() async {
      for (final c in all) {
        final d = col.details[c.url];
        await _upsert(
          agency: c.agency,
          caseNo: c.caseNo,
          name: c.name,
          amount: c.amount,
          source: 'live',
          category: c.category,
          tenderMethod: c.method,
          awardWay: d?.awardWay ?? '',
          noticeDate: c.date,
          url: c.url,
          budget: d?.budget,
          floorPrice: d?.floor,
          bidderCount: d?.bidders,
          bids: d == null ? const [] : [for (final b in d.bidderList) (b.name, b.id.isEmpty ? null : b.id, b.won)],
          complete: d != null && d.bidderList.isNotEmpty,
          reviewers: d?.reviewers ?? const [],
        );
      }
      final now = DateTime.now();
      for (final e in col.totals.entries) {
        await into(searchTotal).insertOnConflictUpdate(SearchTotalCompanion.insert(key: e.key, total: e.value, fetchedAt: now));
      }
    });
  }

  // ---------- 匯入紀錄 ----------

  Future<DatasetFileData?> datasetFileRow(String name) => (select(datasetFile)..where((t) => t.name.equals(name))).getSingleOrNull();

  Future<void> markDatasetFile(String name, {required int records, int? size, DateTime? checkedAt}) =>
      into(datasetFile).insertOnConflictUpdate(DatasetFileData(name: name, records: records, size: size, checkedAt: checkedAt ?? DateTime.now()));

  // ---------- 提問 ----------

  /// 篩選條件 → SQL 的 WHERE（fact_award 的別名是 a）
  (String, List<Variable>) _where(AwardFilter f) {
    final parts = <String>[], vars = <Variable>[];
    final ks = [for (final k in f.keywords) k.replaceAll(RegExp(r'\s+'), '')]..removeWhere((k) => k.isEmpty);
    if (ks.isNotEmpty) {
      parts.add('(${ks.map((_) => r"a.name LIKE ? ESCAPE '\'").join(' OR ')})');
      vars.addAll(ks.map((k) => Variable<String>('%${k.replaceAll(r'\', r'\\').replaceAll('%', r'\%').replaceAll('_', r'\_')}%')));
    }
    const cateName = {ProcCate.works: '工程類', ProcCate.goods: '財物類', ProcCate.services: '勞務類'};
    if (f.cate != ProcCate.any) {
      parts.add('a.category = ?');
      vars.add(Variable<String>(cateName[f.cate]!));
    }
    if (f.from != null) {
      parts.add('a.notice_date >= ?');
      vars.add(Variable<DateTime>(f.from!));
    }
    if (f.to != null) {
      parts.add('a.notice_date < ?');
      vars.add(Variable<DateTime>(f.to!));
    }
    if (f.source != null) {
      parts.add('a.source = ?');
      vars.add(Variable<String>(f.source!));
    }
    return (parts.isEmpty ? '1 = 1' : parts.join(' AND '), vars);
  }

  /// 符合條件的決標（新到舊）
  Future<List<AwardRow>> awards(AwardFilter f, {int? limit}) async {
    final (w, vars) = _where(f);
    final rows = await customSelect(
      'SELECT a.*, g.name AS agency, v.name AS winner FROM fact_award a '
      'JOIN dim_agency g ON g.id = a.agency_id LEFT JOIN dim_vendor v ON v.id = a.winner_id '
      'WHERE $w ORDER BY a.notice_date DESC${limit == null ? '' : ' LIMIT $limit'}',
      variables: vars,
      readsFrom: {factAward, dimAgency, dimVendor},
    ).get();
    return [
      for (final r in rows)
        AwardRow(
          caseKey: r.read<String>('case_key'),
          caseNo: r.read<String>('case_no'),
          name: r.read<String>('name'),
          agency: r.read<String>('agency'),
          winner: r.readNullable<String>('winner') ?? '',
          category: r.read<String>('category'),
          tenderMethod: r.read<String>('tender_method'),
          awardWay: r.read<String>('award_way'),
          url: r.read<String>('url'),
          source: r.read<String>('source'),
          amount: r.read<double>('amount'),
          budget: r.readNullable<double>('budget'),
          bidderCount: r.readNullable<int>('bidder_count'),
          noticeDate: r.readNullable<DateTime>('notice_date'),
        ),
    ];
  }

  /// 決標金額（算中位數、四分位數、分布用；SQLite 沒有中位數函式）
  Future<List<double>> amounts(AwardFilter f) async {
    final (w, vars) = _where(f);
    final rows = await customSelect('SELECT a.amount FROM fact_award a WHERE $w ORDER BY a.amount', variables: vars, readsFrom: {factAward}).get();
    return [for (final r in rows) r.read<double>('amount')];
  }

  /// 依維度分組的量值（例如：各機關的件數、各得標廠商的得標總額、每月件數）
  Future<List<Breakdown>> breakdown(AwardFilter f, Dimension dim, {Metric metric = Metric.count, int limit = 10}) async {
    final (w, vars) = _where(f);
    final (label, join) = switch (dim) {
      Dimension.agency => ('g.name', 'JOIN dim_agency g ON g.id = a.agency_id'),
      Dimension.winner => ('v.name', 'JOIN dim_vendor v ON v.id = a.winner_id'),
      Dimension.category => ('a.category', ''),
      Dimension.tenderMethod => ('a.tender_method', ''),
      Dimension.awardWay => ('a.award_way', ''),
      Dimension.month => ("strftime('%Y-%m', a.notice_date, 'unixepoch')", ''),
    };
    final value = switch (metric) { Metric.count => 'COUNT(*)', Metric.sum => 'SUM(a.amount)', Metric.average => 'AVG(a.amount)' };
    final order = dim == Dimension.month ? 'label' : 'value DESC, n DESC';
    final rows = await customSelect(
      'SELECT $label AS label, COUNT(*) AS n, $value AS value FROM fact_award a $join '
      "WHERE $w AND $label IS NOT NULL AND $label <> '' GROUP BY label ORDER BY $order LIMIT $limit",
      variables: vars,
      readsFrom: {factAward, dimAgency, dimVendor},
    ).get();
    return [for (final r in rows) Breakdown(r.read<String>('label'), r.read<int>('n'), ((r.data['value'] as num?) ?? 0).toDouble())];
  }

  /// 廠商紀錄（依篩選條件）：投標件數、得標件數、得標總額，依得標件數排序
  Future<List<VendorRecord>> vendorRecords(AwardFilter f, {int limit = 10}) async {
    final (w, vars) = _where(f);
    final rows = await customSelect(
      'SELECT v.name AS name, COUNT(*) AS bids, SUM(b.won) AS wins, SUM(CASE WHEN b.won = 1 THEN a.amount ELSE 0 END) AS won_total '
      'FROM fact_bid b JOIN fact_award a ON a.case_key = b.case_key JOIN dim_vendor v ON v.id = b.vendor_id '
      'WHERE $w GROUP BY v.id ORDER BY wins DESC, bids DESC LIMIT $limit',
      variables: vars,
      readsFrom: {factBid, factAward, dimVendor},
    ).get();
    return [for (final r in rows) VendorRecord(r.read<String>('name'), r.read<int>('bids'), (r.data['wins'] as num? ?? 0).toInt(), ((r.data['won_total'] as num?) ?? 0).toDouble())];
  }

  /// 評選委員紀錄（依篩選條件）：評選件數、出席次數、那些案件的得標廠商
  Future<List<ReviewerRecord>> reviewerRecords(AwardFilter f, {int limit = 20}) async {
    final (w, vars) = _where(f);
    final rows = await customSelect(
      'SELECT r.name AS name, r.job AS job, a.case_key AS case_key, a.url AS url, fr.attended AS attended, v.name AS winner '
      'FROM fact_review fr JOIN fact_award a ON a.case_key = fr.case_key JOIN dim_reviewer r ON r.id = fr.reviewer_id '
      'LEFT JOIN dim_vendor v ON v.id = a.winner_id WHERE $w',
      variables: vars,
      readsFrom: {factReview, factAward, dimReviewer, dimVendor},
    ).get();
    final m = <String, ReviewerRecord>{};
    for (final r in rows) {
      final rec = m['${r.read<String>('name')}|${r.read<String>('job')}'] ??= ReviewerRecord(r.read<String>('name'), r.read<String>('job'));
      rec.caseUrls.add(r.read<String>('url').isNotEmpty ? r.read<String>('url') : r.read<String>('case_key'));
      if (r.read<bool>('attended')) rec.attended++;
      final w = r.readNullable<String>('winner');
      if (w != null) rec.winners[w] = (rec.winners[w] ?? 0) + 1;
    }
    return (m.values.toList()..sort((a, b) => b.caseUrls.length.compareTo(a.caseUrls.length))).take(limit).toList();
  }

  /// 已經開過明細的公告（交叉分析就不必再開）：依網址找回 AwardDetail
  Future<Map<String, AwardDetail>> detailsFor(Iterable<String> urls) async {
    final list = urls.toSet().toList();
    final out = <String, AwardDetail>{};
    for (var i = 0; i < list.length; i += 400) {
      final chunk = list.sublist(i, i + 400 > list.length ? list.length : i + 400);
      final awards = await (select(factAward)..where((t) => t.url.isIn(chunk) & t.hasDetail.equals(true))).get();
      for (final a in awards) {
        final bids = await customSelect(
          'SELECT v.name AS name, v.tax_id AS tax_id, b.won AS won FROM fact_bid b JOIN dim_vendor v ON v.id = b.vendor_id WHERE b.case_key = ?',
          variables: [Variable<String>(a.caseKey)],
          readsFrom: {factBid, dimVendor},
        ).get();
        final revs = await customSelect(
          'SELECT r.name AS name, r.job AS job, fr.attended AS attended FROM fact_review fr JOIN dim_reviewer r ON r.id = fr.reviewer_id WHERE fr.case_key = ?',
          variables: [Variable<String>(a.caseKey)],
          readsFrom: {factReview, dimReviewer},
        ).get();
        final winner = [for (final b in bids) if (b.read<bool>('won')) b.read<String>('name')];
        out[a.url] = AwardDetail(
          budget: a.budget,
          floor: a.floorPrice,
          award: a.amount,
          bidders: a.bidderCount,
          winner: winner.isEmpty ? null : winner.first,
          awardWay: a.awardWay.isEmpty ? null : a.awardWay,
          bidderList: [for (final b in bids) Bidder(b.readNullable<String>('tax_id') ?? '', b.read<String>('name'), b.read<bool>('won'))],
          reviewers: [for (final r in revs) Reviewer(r.read<String>('name'), r.read<String>('job'), r.read<bool>('attended'))],
        );
      }
    }
    return out;
  }

  Future<int> countAwards(AwardFilter f) async {
    final (w, vars) = _where(f);
    final r = await customSelect('SELECT COUNT(*) AS n FROM fact_award a WHERE $w', variables: vars, readsFrom: {factAward}).getSingle();
    return r.read<int>('n');
  }
}
