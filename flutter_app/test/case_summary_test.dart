import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:self_quote/case_analysis/case_summary.dart';
import 'package:self_quote/case_analysis/pcc.dart';
import 'package:self_quote/case_analysis/zh_hant.dart';
import 'package:self_quote/i18n/i18n.dart';

void main() {
  final cases = parseAwardList(File('test/fixtures/pcc_awards.html').readAsStringSync()).cases;
  final detail = parseAwardDetail(File('test/fixtures/pcc_award_detail.html').readAsStringSync());

  test('the AI only gets words: names, agencies and the quote position, no amounts', () {
    final n = caseNotes(keyword: '網站', cases: cases, details: {cases.first.url: detail}, myPrice: 100000);
    expect(n, contains("Vendor's quote compared with similar cases: low"));
    expect(n, contains('Price competition: weak'));
    expect(n, isNot(contains('NT\$')));
    // 有明細的案件排在代表案件最前面
    expect(n.split('Example project names:\n')[1].split('\n').first, contains(cases.first.name));
  });

  test('price and competition facts are written by the app with exact numbers', () {
    I18n.lang = Lang.zh;
    expect(priceFacts(cases, 178), contains('共 178 件'));
    expect(priceFacts(cases, 178), contains('NT\$954,444'));
    expect(competitionFacts({}), tr('hist.f.noDetail'));
    final c = competitionFacts({cases.first.url: detail});
    expect(c, contains('平均 1.0 家投標'));
    expect(c, contains('凌網資訊股份有限公司'));
    expect(c, contains(tr('hist.f.few')));
  });

  test('sentences with numbers not in the data are dropped', () {
    final allowed = allowedNumbers('Median NT\$954,444 (95.4萬); single-bidder 100%; Average bidders: 1.0');
    expect(groundSentences('中位數約 95.4萬。平均有 3 家投標。多數只有 1.0 家。', allowed), '中位數約 95.4萬。多數只有 1.0 家。');
    expect(groundSentences('The median is NT\$954,444. Expect 12 bidders. Most were single-bidder (100%).', allowed), 'The median is NT\$954,444. Most were single-bidder (100%).');
  });

  test('Simplified output becomes Traditional (common characters)', () {
    expect(toTraditional('这些项目由台湾地区政府机构采购，售后服务，公里，干扰。'), '這些項目由台灣地區政府機構採購，售後服務，公里，干擾。');
  });

  test('rounded 萬 / 億 amounts close to a real figure are kept; far-off ones are dropped', () {
    final allowed = allowedNumbers('Median NT\$1,199,000 (119.9萬); highest NT\$15,200,000 (1520萬)');
    expect(groundSentences('中位數約 120萬。最高約 0.15億。也有 300萬 的案子。', allowed), '中位數約 120萬。最高約 0.15億。');
  });

  test('summarizeCases: AI writes overview and advice; copied fields and invented numbers are dropped', () async {
    I18n.lang = Lang.zh;
    final sum = await summarizeCases(
      lang: Lang.zh,
      keyword: '網站',
      cases: cases,
      total: 178,
      details: const {},
      ask: (system, user, schema) async {
        expect(system, contains('Traditional Chinese'));
        expect(user, contains('Example project names'));
        return jsonEncode({
          'overview': '这些多是大学与政府机关的网站维运案。',
          'advice': ['报价贴近一般行情较安全。', '可以降价 37% 抢标。', 'Search keyword: 網站'],
        });
      },
    );
    expect(sum.overview, '這些多是大學與政府機關的網站維運案。');
    expect(sum.price, priceFacts(cases, 178));
    expect(sum.competition, tr('hist.f.noDetail'));
    expect(sum.advice, ['報價貼近一般行情較安全。']);
  });
}
