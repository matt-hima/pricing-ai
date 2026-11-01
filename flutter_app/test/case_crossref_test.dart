import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:self_quote/case_analysis/pcc.dart';

/// 交叉分析：評選委員、依廠商查的結果與自動挑選要打開的頁面
void main() {
  final committee = File('test/fixtures/pcc_award_committee.html').readAsStringSync(); // 委員資料是虛構的測試資料
  final oneBidder = File('test/fixtures/pcc_award_detail.html').readAsStringSync();
  final list = File('test/fixtures/pcc_awards.html').readAsStringSync();

  test('evaluation committee members are parsed with attendance', () {
    final r = parseReviewers(committee);
    expect(r.map((x) => x.name), ['王小明', '陳美玲', '林志強', '張雅婷', '黃建國']);
    expect(r.first.job, '大學教授');
    expect(r.where((x) => x.attended).length, 3);
    expect(parseAwardDetail(committee).reviewers.length, 5);
    expect(parseAwardDetail(oneBidder).reviewers, isEmpty); // 最低標的案件沒有評選委員
  });

  test('reviewer cross-reference: cases per member and who won them', () {
    const a = AwardDetail(winner: '甲公司', reviewers: [Reviewer('王小明', '教授', true), Reviewer('陳美玲', '副教授', false)]);
    const b = AwardDetail(winner: '甲公司', reviewers: [Reviewer('王小明', '教授', true)]);
    const c = AwardDetail(winner: '乙公司', reviewers: [Reviewer('王小明', '教授', false), Reviewer('林志強', '處長', true)]);
    final recs = reviewerCrossRef({'u1': a, 'u2': b, 'u3': c});
    expect(recs.first.name, '王小明'); // 出現最多件的排前面
    expect(recs.first.caseUrls, ['u1', 'u2', 'u3']);
    expect(recs.first.attended, 2);
    expect(recs.first.winners, {'甲公司': 2, '乙公司': 1});
    expect(recs.map((r) => r.caseUrls.length), [3, 1, 1]);
  });

  test('vendor searches stay out of the keyword statistics', () {
    final col = CaseCollection();
    col.addPage(awardSearchUrl(keyword: '網站', from: DateTime(2026), to: DateTime(2026, 6)).toString(), list);
    col.addPage(awardSearchUrl(from: DateTime(2026), to: DateTime(2026, 6), wonBy: '凌網資訊股份有限公司').toString(), list);
    expect(col.cases.length, 50);
    expect(col.total, 178); // 只算關鍵字查詢
    expect(col.vendorCases['won:凌網資訊股份有限公司']!.length, 50);
    expect(VendorProfile.of('凌網資訊股份有限公司', col).wins, 178);
  });

  test('cross-reference picks evaluated cases first and skips rivals already looked up', () {
    final col = CaseCollection()..addPage(awardSearchUrl(keyword: '網站', from: DateTime(2026), to: DateTime(2026, 6)).toString(), list);
    final picks = pickForCrossRef(col, 10);
    expect(picks.length, 10);
    final evaluated = col.cases.where((c) => c.method.contains('評選')).length;
    expect(picks.take(evaluated.clamp(0, 10)).every((c) => c.method.contains('評選')), isTrue);
    col.details[picks.first.url] = parseAwardDetail(File('test/fixtures/pcc_award_bidders.html').readAsStringSync());
    expect(pickForCrossRef(col, 10).any((c) => c.url == picks.first.url), isFalse); // 讀過的不再打開
    expect(pickRivalsToLookUp(col, 3).map((r) => r.name), hasLength(3));
    col.addPage(awardSearchUrl(from: DateTime(2026), to: DateTime(2026, 6), wonBy: pickRivalsToLookUp(col, 1).single.name).toString(), list);
    expect(pickRivalsToLookUp(col, 3).length, 3); // 查過的那家換成下一家
    expect(pickRivalsToLookUp(col, 10).length, 6); // 7 家投標廠商，1 家已查過
  });
}
