import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:self_quote/app_state.dart';
import 'package:self_quote/case_analysis/page_reader.dart';
import 'package:self_quote/case_analysis/pcc.dart';
import 'package:self_quote/case_analysis/tender.dart';
import 'package:self_quote/i18n/i18n.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 真的本機模型讀存好的採購網頁面：辨認頁面、選欄位，和現在寫死的解析結果比對，印出一張表。
///   `LIVE_ENGINE_STORAGE=/path/to/pricing-ai FIXTURES=/path/to/test/fixtures flutter test integration_test/page_reader_model_test.dart -d macos`
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('local model identifies procurement pages and maps their fields', (tester) async {
    SharedPreferences.setMockInitialValues({
      'flutter.selfquote.engine.storage': Platform.environment['LIVE_ENGINE_STORAGE'] ?? '/Volumes/dev_disk/pricing-ai',
      'flutter.selfquote.lang.v1': 'zh-TW',
    });
    I18n.lang = Lang.zh;
    final state = AppState();
    await state.init();
    final dir = Platform.environment['FIXTURES'] ?? '/Users/mattlin/Documents/自動估價網站/flutter_app/test/fixtures';
    String page(String f) => File('$dir/$f').readAsStringSync();

    const check = '<html><head><title>政府電子採購網</title></head><body><h2>驗證碼檢核</h2><p>為確保系統正常運作，請輸入圖片中的文字後送出。</p><form><input name="code"><button>送出</button></form></body></html>';
    const error = '<html><head><title>政府電子採購網</title></head><body><h2>系統訊息</h2><p>查無資料，或連線逾時，請重新查詢。</p><a href="/prkms/index">回首頁</a></body></html>';
    final cases = <(String name, String html, String url, PageKind want)>[
      ('open tender list', page('pcc_open_tenders.html'), 'https://web.pcc.gov.tw/prkms/tender/common/basic/readTenderBasic', PageKind.tenderList),
      ('award list', page('pcc_awards.html'), 'https://web.pcc.gov.tw/prkms/tender/common/agent/readTenderAgent', PageKind.awardList),
      ('tender notice', page('pcc_tender_notice.html'), 'https://web.pcc.gov.tw/tps/QueryTender/query/searchTenderDetail?pkPmsMain=1', PageKind.tenderNotice),
      ('award notice', page('pcc_award_detail.html'), 'https://web.pcc.gov.tw/tps/atm/AtmAwardWithoutSso/QueryAtmAwardDetail?pkAtmMain=1', PageKind.awardNotice),
      ('verification', check, 'https://web.pcc.gov.tw/tps/atm/AtmAwardWithoutSso/QueryAtmAwardDetail?pkAtmMain=2', PageKind.verification),
      ('error', error, 'https://web.pcc.gov.tw/prkms/error', PageKind.error),
      ('booking form', page('gform.html'), 'https://docs.example.com/forms/x', PageKind.other),
    ];

    // 現在寫死的解析結果（當作標準答案）
    final n = parseTenderNotice(page('pcc_tender_notice.html'));
    final ad = parseAwardDetail(page('pcc_award_detail.html'));
    final openRule = parseOpenTenders(page('pcc_open_tenders.html')).tenders;
    final awardRule = parseAwardList(page('pcc_awards.html')).cases;
    double? amt(String? s) => s == null ? null : double.tryParse(RegExp(r'[\d,]+(\.\d+)?').firstMatch(s)?[0]?.replaceAll(',', '') ?? '');
    final want = <String, Map<String, Object?>>{
      'tender notice': {'title': n.name, 'agency': n.agency, 'caseNo': n.caseNo, 'budget': n.budget, 'deadline': n.deadline, 'awardMethod': n.awardWay},
      'award notice': {'budget': ad.budget, 'awardAmount': ad.award, 'bidders': ad.bidders, 'winner': ad.winner, 'awardMethod': ad.awardWay},
    };
    bool same(String f, String? got, Object? w) => switch (w) {
          double d => amt(got) == d,
          int i => int.tryParse(got ?? '') == i,
          DateTime t => rocDate(got ?? '') == t,
          _ => got == w,
        };

    final profile = SiteProfile('web.pcc.gov.tw');
    final report = <String>[];
    var kindsRight = 0, fieldsRight = 0, fieldsAll = 0;
    final watch = Stopwatch()..start();
    await state.withModel((ask) async {
      for (final (name, html, url, wantKind) in cases) {
        final t0 = watch.elapsedMilliseconds;
        final r = await readPage(html, Uri.parse(url), profile, ask: (s, u, schema) => ask(s, u, schema: schema));
        final ms = watch.elapsedMilliseconds - t0;
        if (r.kind == wantKind) kindsRight++;
        report.add('$name: kind ${r.kind.name} ${r.kind == wantKind ? 'OK' : 'WRONG (want ${wantKind.name})'} · ${r.modelCalls} model calls · ${(ms / 1000).toStringAsFixed(1)} s');
        if (want[name] case final w?) {
          for (final e in w.entries) {
            fieldsAll++;
            final ok = same(e.key, r.fields[e.key], e.value);
            if (ok) fieldsRight++;
            report.add('    ${e.key}: ${ok ? 'OK' : 'MISS'} got "${r.fields[e.key] ?? '—'}" want "${e.value}" (label ${profile.labels[r.kind]?[e.key] ?? '—'})');
          }
        }
        if (wantKind == PageKind.tenderList || wantKind == PageKind.awardList) {
          final rule = wantKind == PageKind.tenderList
              ? [for (final t in openRule) {'title': t.name, 'agency': t.agency, 'caseNo': t.caseNo, 'link': t.url}]
              : [for (final c in awardRule) {'title': c.name, 'agency': c.agency, 'caseNo': c.caseNo, 'link': c.url, 'amount': c.amount}];
          report.add('    columns ${profile.columns[r.kind]} · rows ${r.rows.length} (rules ${rule.length})');
          for (final f in rule.first.keys) {
            var ok = 0;
            for (final (i, row) in rule.indexed) {
              if (i < r.rows.length && (f == 'amount' ? amt(r.rows[i][f]) == row[f] : r.rows[i][f] == row[f])) ok++;
            }
            fieldsAll++;
            if (ok == rule.length) fieldsRight++;
            report.add('    $f: $ok / ${rule.length} rows match${r.rows.isEmpty ? '' : ' (first: "${r.rows.first[f] ?? '—'}")'}');
          }
        }
      }
    });
    // 第二輪：同樣的頁面只用設定檔
    var fromProfile = 0;
    for (final (_, html, url, wantKind) in cases.take(4)) {
      final r = await readPage(html, Uri.parse(url), profile);
      if (r.fromProfile && r.kind == wantKind) fromProfile++;
    }
    // ignore: avoid_print
    print('PAGE READER REPORT\n${report.join('\n')}\n'
        'kinds $kindsRight / ${cases.length} · fields $fieldsRight / $fieldsAll · second pass from profile $fromProfile / 4 (no model)\n'
        'profile: ${profile.toJson()}');
  });
}
