import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:self_quote/case_analysis/page_reader.dart';
import 'package:self_quote/case_analysis/pcc.dart';
import 'package:self_quote/case_analysis/tender.dart';

/// 通用頁面讀取：模型只做選擇題（用寫好答案的假模型），值由程式讀並檢查；學到的對應存成網站設定檔，之後不再問模型
void main() {
  String page(String f) => File('test/fixtures/$f').readAsStringSync();

  /// 假模型：依問題回答正確的選擇，並記下問了幾次
  var calls = 0;
  final asked = <String>[];
  Future<String> ask(String system, String user, Map<String, dynamic> schema) async {
    calls++;
    if (system.contains('Which label holds')) asked.add(system.substring(system.indexOf('holds') + 6, system.indexOf('?')));
    final props = schema['properties'] as Map<String, dynamic>;
    List<String> opts(String f) => [...((props[f] as Map)['enum'] as List).cast<String>()];
    String col(String f, String head) => opts(f).firstWhere((o) => o.contains(head), orElse: () => '');
    if (props.containsKey('kind')) {
      final kind = user.contains('驗證碼檢核')
          ? 'a human verification check'
          : user.contains('Table')
              ? 'a list of procurements (search results)'
              : user.contains('截止投標') || user.contains('投標廠商家數')
                  ? 'one procurement notice with its details'
                  : 'something else';
      return jsonEncode({'kind': kind});
    }
    if (props.containsKey('stage')) {
      return jsonEncode({'stage': user.contains('截止投標') ? 'still open for bids' : 'already awarded (a result)'});
    }
    if (system.contains('choose the column')) {
      return jsonEncode({
        for (final f in props.keys)
          f: switch (f) {
            'title' || 'caseNo' => col(f, '標案名稱'),
            'agency' => col(f, '機關名稱'),
            'deadline' => col(f, '截止投標'),
            'budget' => col(f, '預算金額'),
            'date' => col(f, '公告日期'),
            'amount' => col(f, '決標金額'),
            _ => '',
          },
      });
    }
    // 一次一個欄位：從問題的說明找出是哪個欄位
    const labels = {'name / title': '標案名稱', 'buying agency': '機關名稱', 'case or reference': '標案案號', 'budget': '預算金額', 'deadline': '截止投標', 'awarded (contract)': '決標金額', 'number of bidders': '投標廠商家數', 'how the winner': '決標方式', 'winning supplier': '廠商名稱'};
    final q = system.substring(system.indexOf('Which label holds'));
    final l = labels.entries.firstWhere((e) => q.contains(e.key), orElse: () => const MapEntry('', '')).value;
    return jsonEncode({'label': opts('label').contains(l) ? l : ''});
  }

  test('tender notice: fields read by the program match the rule parser; the profile answers the next page', () async {
    calls = 0;
    final p = SiteProfile('web.pcc.gov.tw');
    final url = Uri.parse('https://web.pcc.gov.tw/tps/QueryTender/query/searchTenderDetail?pkPmsMain=1');
    final r = await readPage(page('pcc_tender_notice.html'), url, p, ask: ask);
    final n = parseTenderNotice(page('pcc_tender_notice.html'));
    expect(r.kind, PageKind.tenderNotice);
    expect((r.fields['title'], r.fields['agency'], r.fields['caseNo'], r.fields['awardMethod']), (n.name, n.agency, n.caseNo, n.awardWay));
    expect(r.fields['budget'], '1,446,930元');
    expect(r.fields['deadline'], '115/11/09 17:00');
    expect(r.modelCalls, 8, reason: '$asked'); // 辨認 2 次 + 6 個欄位各 1 次
    // 同一種頁面（同路徑、別的案件）：直接套用，不問模型；設定檔可以存起來再讀回
    final again = await readPage(page('pcc_tender_notice.html'), url.replace(query: 'pkPmsMain=2'), SiteProfile.fromJson(jsonDecode(jsonEncode(p.toJson())) as Map<String, dynamic>));
    expect((again.fromProfile, again.fields['deadline']), (true, '115/11/09 17:00'));
    expect(calls, 8);
  });

  test('lists: the model picks columns; case number and title sharing a cell are split; links come along', () async {
    calls = 0;
    final p = SiteProfile('web.pcc.gov.tw');
    final open = await readPage(page('pcc_open_tenders.html'), Uri.parse('https://web.pcc.gov.tw/prkms/tender/common/basic/readTenderBasic'), p, ask: ask);
    final rule = parseOpenTenders(page('pcc_open_tenders.html')).tenders;
    expect(open.kind, PageKind.tenderList);
    expect(open.rows.length, rule.length);
    for (final (i, t) in rule.indexed) {
      expect((open.rows[i]['title'], open.rows[i]['agency'], open.rows[i]['caseNo']), (t.name, t.agency, t.caseNo));
      expect(rocDate(open.rows[i]['deadline']!), t.deadline);
      expect(open.rows[i]['link'], t.url);
    }
    final awards = await readPage(page('pcc_awards.html'), Uri.parse('https://web.pcc.gov.tw/prkms/tender/common/agent/readTenderAgent'), p, ask: ask);
    final ruleAwards = parseAwardList(page('pcc_awards.html')).cases;
    expect(awards.kind, PageKind.awardList);
    expect(awards.rows.length, ruleAwards.length);
    expect((awards.rows.first['title'], awards.rows.first['caseNo'], awards.rows.first['link']), (ruleAwards.first.name, ruleAwards.first.caseNo, ruleAwards.first.url));
    expect(calls, 6);
  });

  test('a verification page is recognized and never learned; a page missing required fields is asked again', () async {
    calls = 0;
    final p = SiteProfile('web.pcc.gov.tw');
    final url = Uri.parse('https://web.pcc.gov.tw/tps/QueryTender/query/searchTenderDetail?pkPmsMain=3');
    const check = '<html><head><title>政府電子採購網</title></head><body><h2>驗證碼檢核</h2><p>請輸入圖片中的文字</p><form><input name="code"><button>送出</button></form></body></html>';
    expect((await readPage(check, url, p, ask: ask)).kind, PageKind.verification);
    expect(p.paths, isEmpty);
    await readPage(page('pcc_tender_notice.html'), url, p, ask: ask);
    expect(p.paths.values, [PageKind.tenderNotice]);
    // 學過的路徑出現驗證頁：設定檔讀不到必要欄位 → 重新問模型，認出是驗證頁
    calls = 0;
    expect((await readPage(check, url, p, ask: ask)).kind, PageKind.verification);
    expect(calls, 1);
    // 值檢查：金額讀不到數字、日期不像日期的就不要
    expect(checkValue('budget', '不公開'), isNull);
    expect(checkValue('deadline', '另行通知'), isNull);
    expect(checkValue('bidders', '3'), '3');
  });
}
