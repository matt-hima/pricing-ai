import 'package:flutter_test/flutter_test.dart';
import 'package:self_quote/case_analysis/keywords.dart';
import 'package:self_quote/case_analysis/sources/source.dart';

void main() {
  test('aiKeywords drops duplicates, the keyword itself and terms it contains', () async {
    final r = await aiKeywords((s, u, schema) async => '{"keywords":["網頁"," 官 網 ","網站","網站維護","網頁",""]}', '網站', Country.tw);
    expect(r, ['網頁', '官網']);
  });

  test('aiKeywords returns nothing on broken output', () async {
    expect(await aiKeywords((s, u, schema) async => 'sorry', '網站', Country.tw), isEmpty);
  });
}
