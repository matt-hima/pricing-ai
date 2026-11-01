/// 日本：調達ポータル（政府電子調達 GEPS）の落札実績オープンデータ。
/// 年度ごとの全件ファイル（前月末時点、月 1 回更新）を CSV で取得する。中央省庁の調達のみ（自治体は含まない）。
/// ファイル仕様：https://www.p-portal.go.jp/pps-web-biz/resources/app/pdf/rakusatsuopendata.pdf
library;

import 'dart:async';
import 'dart:convert';

import 'package:archive/archive.dart';

import 'source.dart';

const _download = 'https://api.p-portal.go.jp/pps-web-biz/UAB03/OAB0301';

class JapanSource extends AwardSource {
  @override
  Country get country => Country.jp;

  /// 年度は 4 月始まり：期間に重なる年度のファイル（新しい順）
  @override
  List<SyncUnit> units(DateTime now, int months) {
    int fy(DateTime d) => d.month >= 4 ? d.year : d.year - 1;
    final from = DateTime(now.year, now.month - months, now.day);
    return [
      for (var y = fy(now); y >= fy(from); y--) SyncUnit('jp:$y', DateTime(y + 1, 3, 31)),
    ];
  }

  @override
  Stream<List<SourceAward>> fetch(SyncUnit unit, SourceHttp http) async* {
    final year = unit.name.substring(3);
    final file = await http.download(Uri.parse('$_download?fileversion=v001&filename=successful_bid_record_info_all_$year.zip'));
    if (file == null) return;
    try {
      final zip = ZipDecoder().decodeBytes(await file.readAsBytes());
      for (final f in zip.files) {
        if (!f.isFile || !f.name.endsWith('.csv')) continue;
        yield parseJapanCsv(_utf8(f.content));
      }
    } finally {
      await file.parent.delete(recursive: true).catchError((_) => file.parent);
    }
  }
}

String _utf8(List<int> b) => const Utf8Codec().decode(b, allowMalformed: true);

/// 落札実績 CSV（ヘッダーなし、全項目 "" 囲み）→ 決標。1 案件に複数の落札者がいる場合は業者ごとに 1 行なので、案件番号でまとめる
List<SourceAward> parseJapanCsv(String csv) {
  final byCase = <String, List<List<String>>>{};
  for (final line in csv.replaceFirst('﻿', '').split(RegExp(r'\r?\n'))) {
    final f = _fields(line);
    if (f.length < 7) continue;
    (byCase[f[0]] ??= []).add(f);
  }
  final out = <SourceAward>[];
  for (final e in byCase.entries) {
    final rows = e.value, r = rows.first;
    final amount = rows.fold<double>(0, (s, x) => s + (double.tryParse(x[3]) ?? 0));
    if (amount <= 0) continue;
    out.add(SourceAward(
      id: 'jp:${e.key}',
      name: halfWidth(r[1]),
      agency: jpAgencies[r[4]] ?? r[4],
      winners: [for (final x in rows) (halfWidth(x[6]), x.length > 7 && x[7].isNotEmpty ? x[7] : null)],
      amount: amount,
      date: DateTime.tryParse(r[2]),
      method: jpMethods[r[5]] ?? r[5],
    ));
  }
  return out;
}

/// "a","b","c" の 1 行を分割（"" は値の中の引用符）
List<String> _fields(String line) {
  final out = <String>[];
  final b = StringBuffer();
  var q = false;
  for (var i = 0; i < line.length; i++) {
    final c = line[i];
    if (q) {
      if (c == '"') {
        if (i + 1 < line.length && line[i + 1] == '"') {
          b.write('"');
          i++;
        } else {
          q = false;
        }
      } else {
        b.write(c);
      }
    } else if (c == '"') {
      q = true;
    } else if (c == ',') {
      out.add(b.toString());
      b.clear();
    } else {
      b.write(c);
    }
  }
  if (line.isNotEmpty) out.add(b.toString());
  return out;
}

/// 府省コード（ファイル仕様 3.1）
const jpAgencies = {
  'A1': '衆議院', 'B1': '参議院', 'C1': '国立国会図書館', 'D1': '最高裁判所', 'E1': '会計検査院', 'F1': '人事院', 'F2': '国家公務員倫理審査会',
  'G1': '内閣官房', 'H1': '内閣法制局', 'I1': '安全保障会議', 'J1': '内閣府', 'J2': '宮内庁', 'J3': '公正取引委員会', 'J4': '国家公安委員会',
  'J5': '警察庁', 'J6': '金融庁', 'J7': '消費者庁', 'J8': '個人情報保護委員会', 'J9': 'カジノ管理委員会', 'JA': 'こども家庭庁',
  'JB': 'サイバー通信情報監理委員会', 'K1': '総務省', 'K2': '公害等調整委員会', 'K3': '消防庁', 'L1': '法務省', 'L2': '検察庁',
  'L3': '公安審査委員会', 'L4': '公安調査庁', 'M1': '外務省', 'N1': '財務省', 'N2': '国税庁', 'O1': '文部科学省', 'O2': '文化庁',
  'O3': 'スポーツ庁', 'P1': '厚生労働省', 'P2': '中央労働委員会', 'Q1': '農林水産省', 'Q2': '林野庁', 'Q3': '水産庁', 'R1': '経済産業省',
  'R2': '資源エネルギー庁', 'R3': '特許庁', 'R4': '中小企業庁', 'S1': '国土交通省', 'S2': '運輸安全委員会', 'S3': '観光庁', 'S4': '気象庁',
  'S5': '海上保安庁', 'T1': '環境省', 'T2': '原子力規制庁', 'U1': '防衛省', 'V1': '復興庁', 'W1': 'デジタル庁', 'X1': '防災庁',
};

/// 入札方式コード（ファイル仕様 3.2）
const jpMethods = {
  '8002010': '一般競争入札・最低価格', '8002020': '一般競争入札・最高価格', '8002040': '一般競争入札・総合評価', '8002050': '一般競争入札・複数落札',
  '8003010': '指名競争入札・最低価格', '8003020': '指名競争入札・最高価格', '8003040': '指名競争入札・総合評価', '8003050': '指名競争入札・複数落札',
  '8004025': '随意契約・複数業者', '8001010': '随意契約・オープンカウンタ', '8004020': '随意契約・特定業者', '8004030': '随意契約・公募型プロポーザル',
  '8014025': '随意契約・複数業者・少額', '8011010': '随意契約・オープンカウンタ・少額', '8014020': '随意契約・特定業者・少額', '8014030': '随意契約・公募型プロポーザル・少額',
};
