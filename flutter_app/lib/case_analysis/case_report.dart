import 'dart:convert';
import 'dart:typed_data';

import '../i18n/i18n.dart';
import '../pdf_doc.dart' show pdfRuns;

/// 案件分析報告：同一份內容輸出成兩種格式
/// - 分享用的純文字（複製貼到聊天或電子郵件）
/// - PDF（pdfmake 文件描述；圖表以 PNG 放入）
/// 數字都由程式依統計寫成句子；評選委員只寫人數，不寫姓名。

class ReportChart {
  final Uint8List png;
  final double width, height; // 擷取時的邏輯尺寸，用來維持比例
  const ReportChart(this.png, this.width, this.height);
}

class ReportSection {
  final String title;
  final List<String> lines;
  final List<String> bullets;
  final List<List<String>> table; // 第一列是表頭
  final ReportChart? chart;
  const ReportSection(this.title, {this.lines = const [], this.bullets = const [], this.table = const [], this.chart});

  bool get isEmpty => lines.isEmpty && bullets.isEmpty && table.length < 2 && chart == null;
}

class CaseReport {
  final String title, subtitle, note;
  final List<ReportSection> sections;
  final List<String> sources;
  const CaseReport({required this.title, required this.subtitle, required this.sections, this.note = '', this.sources = const []});

  List<ReportSection> get _shown => [for (final s in sections) if (!s.isEmpty) s];

  /// 分享用的純文字：表格只列前幾列，圖表略過
  String toText({int tableRows = 5}) {
    final b = StringBuffer()
      ..writeln(title)
      ..writeln(subtitle);
    for (final s in _shown) {
      b
        ..writeln()
        ..writeln('【${s.title}】');
      for (final l in s.lines) {
        b.writeln(l);
      }
      for (final l in s.bullets) {
        b.writeln('• $l');
      }
      if (s.table.length > 1) {
        for (final r in s.table.skip(1).take(tableRows)) {
          b.writeln('• ${r.where((c) => c.isNotEmpty).join(' · ')}');
        }
      }
    }
    if (note.isNotEmpty || sources.isNotEmpty) b.writeln();
    if (note.isNotEmpty) b.writeln(note);
    for (final s in sources) {
      b.writeln(s);
    }
    return b.toString().trimRight();
  }

  /// pdfmake 文件描述（字型、頁尾在 web/pdf_bridge.js 補上）
  Map<String, dynamic> toPdfDoc({String footer = 'Pricing AI'}) {
    const ink = '#1F2933', muted = '#5F6B78', navy = '#263C5C';
    const width = 523.0; // A4 寬 595pt − 左右邊界 36pt × 2
    Map<String, dynamic> t(String s, {double? size, bool bold = false, String? color, List<num>? margin}) => {
          'text': pdfRuns(s),
          if (size != null) 'fontSize': size,
          if (bold) 'bold': true,
          if (color != null) 'color': color,
          if (margin != null) 'margin': margin,
        };
    final images = <String, String>{};
    final content = <Map<String, dynamic>>[
      t(title, size: 17, bold: true, color: navy),
      t(subtitle, size: 9, color: muted, margin: [0, 3, 0, 6]),
      {
        'canvas': [
          {'type': 'line', 'x1': 0, 'y1': 0, 'x2': width, 'y2': 0, 'lineWidth': 1.2, 'lineColor': navy}
        ],
      },
    ];
    for (final s in _shown) {
      content.add({
        'stack': [
          t(s.title, size: 12, bold: true, margin: [0, 16, 0, 4]),
          for (final l in s.lines) t(l, margin: [0, 1, 0, 1]),
        ],
        'unbreakable': s.lines.length < 6,
      });
      if (s.bullets.isNotEmpty) {
        content.add({
          'ul': [for (final l in s.bullets) t(l)],
          'margin': [0, 3, 0, 0],
        });
      }
      if (s.chart case final c?) {
        final name = 'chart${images.length}';
        images[name] = 'data:image/png;base64,${base64Encode(c.png)}';
        final w = c.width < width ? c.width : width;
        content.add({'image': name, 'width': w, 'height': w * c.height / c.width, 'margin': [0, 6, 0, 2]});
      }
      if (s.table.length > 1) {
        final cols = s.table.first.length;
        content.add({
          'table': {
            'headerRows': 1,
            'widths': [for (var i = 0; i < cols; i++) i == 0 ? '*' : 'auto'],
            'body': [
              [for (final h in s.table.first) t(h, bold: true, size: 8, color: muted)],
              for (final r in s.table.skip(1)) [for (final c in r) t(c, size: 8)],
            ],
          },
          'layout': 'quoteLines',
          'margin': [0, 6, 0, 0],
        });
      }
    }
    if (note.isNotEmpty) content.add(t(note, size: 8, color: muted, margin: [0, 18, 0, 0]));
    for (final s in sources) {
      content.add(t(s, size: 8, color: muted, margin: [0, 3, 0, 0]));
    }
    return {
      'pageSize': 'A4',
      'pageMargins': [36, 36, 36, 46],
      'defaultStyle': {'font': I18n.lang.isCjk ? 'CJK' : 'Latin', 'fontSize': 9.5, 'lineHeight': 1.2, 'color': ink},
      'info': {'title': title, 'creator': 'Pricing AI'},
      if (images.isNotEmpty) 'images': images,
      'content': content,
      'x_footer': {'left': footer, 'right': tr('pdf.page', {'n': '{page}'})},
    };
  }
}
