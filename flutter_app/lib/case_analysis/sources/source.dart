/// 各國政府的官方決標開放資料。每個來源把自己的格式轉成 [SourceAward]，匯入同一個案件資料庫（多一個國家欄位）。
/// 只用官方公開的資料集或 API（一般檔案下載 / 公開 API），不爬查詢網頁。
library;

import 'dart:async';
import 'dart:io';

/// 國家：決定幣別、關鍵字比對方式、出處說明
enum Country {
  tw('TWD'),
  uk('GBP'),
  es('EUR'),
  pt('EUR'),
  jp('JPY'),
  eu('EUR');

  final String currency;
  const Country(this.currency);

  /// 中日文：比對時去掉空白（和台灣採購網一樣連續文字比對）；拉丁文字保留單字間的空白
  bool get cjk => this == tw || this == jp;

  static Country byName(String? s) => Country.values.firstWhere((c) => c.name == s, orElse: () => Country.tw);
}

/// 一筆決標（各國資料統一後的樣子）
class SourceAward {
  final String id; // 來源內的唯一編號（UK：通知編號、JP：調達案件番号+業者、PT：idcontrato、ES：ContractFolderID+機關）
  final String name, agency;
  final List<(String name, String? id)> winners;
  final double amount;
  final DateTime? date;
  final String category, method, awardWay, url;
  final double? budget;
  final int? bidders;
  const SourceAward({
    required this.id,
    required this.name,
    required this.agency,
    required this.winners,
    required this.amount,
    required this.date,
    this.category = '',
    this.method = '',
    this.awardWay = '',
    this.url = '',
    this.budget,
    this.bidders,
  });
}

/// 一次同步的單位：一個檔或一段期間（API 依月份分頁）
class SyncUnit {
  final String name; // 記在 dataset_file 的名稱，例如 'jp:2026'、'uk-cf:2026-10'
  final DateTime periodEnd; // 期間結束日；結束超過 [settledAfter] 就不再更新
  final List<String> keywords; // 依關鍵字查詢的來源（歐盟 TED）：這個單位只取標題符合的案件
  const SyncUnit(this.name, this.periodEnd, {this.keywords = const []});
}

/// 一個資料來源
abstract class AwardSource {
  Country get country;

  /// 這段期間要同步的單位（新到舊）
  List<SyncUnit> units(DateTime now, int months);

  /// 依關鍵字查詢的來源（資料量太大，不能整批下載）：這段期間、這組關鍵字要同步的單位；其他來源忽略關鍵字
  List<SyncUnit> unitsFor(DateTime now, int months, List<String> keywords) => units(now, months);

  /// 期間結束多久之後資料就不再變動
  Duration get settledAfter => const Duration(days: 45);

  /// 取得一個單位的資料。分批回傳（大檔在背景 isolate 串流解析）；取不到（還沒公開、連不上）丟出例外或不回傳任何批次
  Stream<List<SourceAward>> fetch(SyncUnit unit, SourceHttp http);

  /// 資料集的出處與授權（顯示在畫面與報告）
  String get sourceKey => 'case.src.${country.name}';
}

/// 來源用的 HTTP：一般請求與下載到暫存檔（大檔不放進記憶體）。
/// 伺服器回 429 / 503 時照它的 Retry-After 等待後再試，等待時呼叫 [onWait]。
abstract class SourceHttp {
  Future<String?> getText(Uri url, {void Function(Duration wait)? onWait});
  Future<String?> postJson(Uri url, String body, {void Function(Duration wait)? onWait});
  Future<File?> download(Uri url, {void Function(int bytes)? onBytes, void Function(Duration wait)? onWait});
}

/// 使用者按了「停止」
class SyncCancelled implements Exception {
  const SyncCancelled();
}

/// 全形英數轉半形（日本的資料常用全形，例如「株式会社ＮＴＴデータ」）
String halfWidth(String s) => String.fromCharCodes([
      for (final r in s.runes) r >= 0xFF01 && r <= 0xFF5E ? r - 0xFEE0 : (r == 0x3000 ? 0x20 : r),
    ]);

/// 比對用的文字：小寫、去掉重音符號、全形英數轉半形、空白統一（中日文去掉空白）
String searchText(String s, {required bool cjk}) {
  final b = StringBuffer();
  for (final r in s.toLowerCase().runes) {
    var c = r;
    if (c >= 0xFF01 && c <= 0xFF5E) c -= 0xFEE0; // 全形 ASCII
    if (c == 0x3000) c = 0x20;
    b.write(_plain[c] ?? String.fromCharCode(c));
  }
  final t = b.toString().toLowerCase();
  return cjk ? t.replaceAll(RegExp(r'\s+'), '') : t.replaceAll(RegExp(r'\s+'), ' ').trim();
}

const _accents = {
  'a': 'àáâãäåā',
  'c': 'ç',
  'e': 'èéêëē',
  'i': 'ìíîïī',
  'n': 'ñ',
  'o': 'òóôõöøō',
  'u': 'ùúûüū',
  'y': 'ýÿ',
};
final _plain = {
  for (final e in _accents.entries)
    for (final r in e.value.runes) r: e.key,
};
