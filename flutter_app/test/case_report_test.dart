import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:self_quote/case_analysis/case_report.dart';
import 'package:self_quote/i18n/i18n.dart';

/// 案件分析報告：同一份內容輸出成分享文字與 PDF（pdfmake 文件描述）
void main() {
  final png = Uint8List.fromList([137, 80, 78, 71]);
  CaseReport report() => CaseReport(
        title: '採購案件分析：網站',
        subtitle: '2026-11-01 · 關鍵字：網站',
        sections: [
          ReportSection('決標金額概況', lines: ['同類決標案件共 50 件。'], bullets: ['常見機關：A、B'], chart: ReportChart(png, 800, 200)),
          const ReportSection('空的段落'),
          ReportSection('決標案件', table: [
            ['名稱', '金額'],
            for (var i = 1; i <= 8; i++) ['案件 $i', 'NT\$$i'],
          ]),
        ],
        note: '各案範圍不同。',
        sources: ['資料來源：採購網'],
      );

  test('share text: headings, bullets, the first table rows; empty sections and charts left out', () {
    I18n.lang = Lang.zh;
    final text = report().toText();
    expect(text.split('\n').take(2), ['採購案件分析：網站', '2026-11-01 · 關鍵字：網站']);
    expect(text, contains('【決標金額概況】\n同類決標案件共 50 件。\n• 常見機關：A、B'));
    expect(text, isNot(contains('空的段落')));
    expect(text, contains('• 案件 5 · NT\$5'));
    expect(text, isNot(contains('案件 6')));
    expect(text, endsWith('各案範圍不同。\n資料來源：採購網'));
  });

  test('PDF document: A4 with the chart image scaled to the page and a table with a header row', () {
    I18n.lang = Lang.zh;
    final doc = report().toPdfDoc();
    expect(doc['pageSize'], 'A4');
    expect((doc['defaultStyle'] as Map)['font'], 'CJK');
    expect((doc['images'] as Map)['chart0'], startsWith('data:image/png;base64,'));
    final content = (doc['content'] as List).cast<Map>();
    final image = content.firstWhere((c) => c['image'] == 'chart0');
    expect((image['width'], image['height']), (523.0, 523.0 * 200 / 800)); // 比頁面寬：縮到內容寬度，維持比例
    final table = content.firstWhere((c) => c.containsKey('table'))['table'] as Map;
    expect(table['headerRows'], 1);
    expect((table['body'] as List).length, 9); // 表頭 + 全部 8 列（PDF 不截斷）
    expect(content.any((c) => '$c'.contains('空的段落')), isFalse);
  });

  test('Latin interface: CJK names switch to the CJK font run by run', () {
    I18n.lang = Lang.en;
    final doc = report().toPdfDoc();
    expect((doc['defaultStyle'] as Map)['font'], 'Latin');
    final title = (doc['content'] as List).first as Map;
    expect((title['text'] as List).first['font'], 'CJK');
    I18n.lang = Lang.zh;
  });
}
