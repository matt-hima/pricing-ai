import 'app_state.dart';
import 'config.dart';
import 'estimator.dart';
import 'i18n/i18n.dart';
import 'ui/quote_paper.dart';

/// 報價單 PDF（pdfmake）。這裡只負責組出文件描述（JSON），排版與字型載入在 web/pdf_bridge.js。
///
/// 版面：Dolibarr 風格的報價單，表格無直線、淡色橫線與斑馬紋、深藍表頭，頁尾有頁碼。

const _navy = '#263C5C';
const _muted = '#5F6B78';
const _line = '#E2E8F0';
const _zebra = '#F7FAFC';
const _head = '#E6E9EE';
const _warn = '#FFF3CD';
const _ink = '#1F2933';
const _contentWidth = 523.0; // A4 寬 595pt − 左右邊界 36pt × 2

final _cjkRe = RegExp(r'[⺀-鿿぀-ヿ가-힯豈-﫿＀-￯]');

/// 可嵌入 PDF 的 Logo：pdfmake 支援 PNG / JPEG
bool hasPdfLogo(String dataUrl) => dataUrl.startsWith('data:image/png') || dataUrl.startsWith('data:image/jpeg');

/* ---------- 文字節點 ---------- */

/// 中日文介面整份用 CJK 字型；其他語言以 Latin 字型為主，使用者輸入的中日文逐段改用 CJK 字型
List<Map<String, dynamic>> _runs(String s, [Map<String, dynamic> style = const {}]) {
  if (I18n.lang.isCjk || !_cjkRe.hasMatch(s)) return [{'text': s, ...style}];
  final out = <Map<String, dynamic>>[];
  final buf = StringBuffer();
  bool? cjk;
  void flush() {
    if (buf.isEmpty) return;
    out.add({'text': buf.toString(), if (cjk == true) 'font': 'CJK', ...style});
    buf.clear();
  }

  for (final r in s.runes) {
    final ch = String.fromCharCode(r);
    final isCjk = _cjkRe.hasMatch(ch);
    if (cjk != null && isCjk != cjk) flush();
    cjk = isCjk;
    buf.write(ch);
  }
  flush();
  return out;
}

/// 單段文字
Map<String, dynamic> _t(
  String s, {
  double? size,
  bool bold = false,
  String? color,
  String? align,
  List<num>? margin,
  double? spacing,
  String? fill,
}) =>
    {
      'text': _runs(s),
      if (size != null) 'fontSize': size,
      if (bold) 'bold': true,
      if (color != null) 'color': color,
      if (align != null) 'alignment': align,
      if (margin != null) 'margin': margin,
      if (spacing != null) 'characterSpacing': spacing,
      if (fill != null) 'fillColor': fill,
    };

/// 一行內混合粗體標籤與內文：parts = [(文字, 是否粗體, 顏色?)]
Map<String, dynamic> _rich(List<(String, bool, String?)> parts, {double? size, String? color, List<num>? margin, String? align}) => {
      'text': [
        for (final (text, bold, c) in parts) ..._runs(text, {if (bold) 'bold': true, if (c != null) 'color': c}),
      ],
      if (size != null) 'fontSize': size,
      if (color != null) 'color': color,
      if (margin != null) 'margin': margin,
      if (align != null) 'alignment': align,
    };

Map<String, dynamic> _rule({double width = _contentWidth, double w = 0.8, String color = _ink}) => {
      'canvas': [
        {'type': 'line', 'x1': 0, 'y1': 0, 'x2': width, 'y2': 0, 'lineWidth': w, 'lineColor': color}
      ],
    };

Map<String, dynamic> _h2(String s) => {
      'stack': [
        _t(s, size: 12, bold: true, margin: [0, 16, 0, 3]),
        _rule(w: 1.2),
        {'text': '', 'margin': [0, 0, 0, 4]},
      ],
      'unbreakable': true,
    };

Map<String, dynamic> _bullets(List<Map<String, dynamic>> items) => {'ul': items, 'fontSize': 9, 'margin': [0, 2, 0, 0]};

/* ---------- 文件 ---------- */

Map<String, dynamic> buildQuotePdf(AppState s) {
  final q = s.q, e = s.estimate, p = s.pricing, ai = s.ai;
  final lang = I18n.lang;
  final m = money;
  final vat = '${fmtNum(q.vatPct)}%';
  final logo = hasPdfLogo(q.logo);
  final initial = q.myName.isEmpty ? '' : String.fromCharCode(q.myName.runes.first);

  // ===== 抬頭 =====
  final company = <dynamic>[
    if (logo)
      {'image': 'logo', 'fit': [150, 46]}
    else
      {
        'table': {
          'widths': [32],
          'heights': [32],
          'body': [
            [_t(initial, size: 16, bold: true, color: '#FFFFFF', align: 'center', fill: _navy, margin: [0, 7, 0, 0])]
          ]
        },
        'layout': 'none',
      },
    _t(q.myName, size: 13, bold: true, margin: [0, 6, 0, 1]),
    if (q.myTaxId.isNotEmpty) _t(tr('q.taxId', {'v': q.myTaxId}), size: 8.5, color: _muted),
    if (q.myAddress.isNotEmpty) _t(q.myAddress, size: 8.5, color: _muted),
    if ([q.myPhone, q.myEmail].any((x) => x.isNotEmpty))
      _t([q.myPhone, q.myEmail].where((x) => x.isNotEmpty).join(' · '), size: 8.5, color: _muted),
  ];

  final title = tr('q.title');
  final head = {
    'columns': [
      {'width': '*', 'stack': company},
      {
        'width': 'auto',
        'stack': [
          _t(lang.isCjk ? title : title.toUpperCase(), size: 24, align: 'right', color: _navy, spacing: lang.isCjk ? 4 : 2),
          _t(q.ref, size: 11, bold: true, align: 'right', margin: [0, 2, 0, 6]),
          {
            'columns': [
              {'width': '*', 'text': ''},
              {
                'width': 'auto',
                'table': {
                  'body': [
                    [_t(tr(ai != null ? 'q.statusAI' : 'q.statusRules'), size: 8.5, color: ai != null ? '#0F766E' : _muted)]
                  ]
                },
                'layout': 'boxes',
              },
            ]
          },
        ],
      },
    ],
  };

  // 每份 PDF 第一頁都看得到的測試用途警語
  final banner = {
    'table': {
      'widths': ['*'],
      'body': [
        [_t(tr('banner.ai'), size: 8.5, bold: true, fill: _warn, margin: [8, 5, 8, 5])]
      ]
    },
    'layout': 'none',
    'margin': [0, 10, 0, 10],
  };

  // ===== 報價對象與條件 =====
  final to = {
    'width': 250,
    'table': {
      'widths': ['*'],
      'body': [
        [
          {
            'stack': [
              _t(tr('q.to'), size: 7.5, color: _muted, margin: [0, 0, 0, 2]),
              _t(q.company.isEmpty ? '—' : q.company, size: 10.5, bold: true),
              if (q.taxId.isNotEmpty) _t(tr('q.taxId', {'v': q.taxId}), size: 9),
              if (q.contact.isNotEmpty) _t(tr('q.contact', {'v': q.contact}), size: 9),
              if (q.email.isNotEmpty) _t(q.email, size: 9),
              if (q.phone.isNotEmpty) _t(q.phone, size: 9),
              if (q.project.isNotEmpty) _t(tr('q.project', {'v': q.project}), size: 9),
            ],
          }
        ]
      ]
    },
    'layout': 'boxes',
  };

  List<dynamic> kv(String k, String v) => [_t(k, size: 9, color: _muted), _t(v, size: 9, align: 'right')];
  final terms = {
    'width': '*',
    'table': {
      'widths': ['auto', '*'],
      'body': [
        kv(tr('q.date'), fmtDate(q.date)),
        kv(tr('q.validUntil'), fmtDate(q.date.add(Duration(days: q.validityDays)))),
        kv(tr('q.refClient'), q.refClient.isEmpty ? '—' : q.refClient),
        kv(tr('q.payTerm'), payTerms[q.payTerm] ?? ''),
        kv(tr('q.payMode'), payModes[q.payMode] ?? q.payMode),
        kv(tr('q.delivery'), e.totalHours > 0 ? tr('unit.months', {'a': '${p.monthsLow}', 'b': '${p.monthsHigh}'}) : '—'),
      ]
    },
    'layout': 'kv',
  };
  final info = {
    'columns': [to, {'width': 24, 'text': ''}, terms],
  };

  // ===== 明細（Dolibarr 報價單列）：深藍表頭、斑馬紋、無直線 =====
  Map<String, dynamic> th(String s, {String align = 'right'}) =>
      _t(s, size: 8, bold: true, color: '#FFFFFF', align: align, fill: _navy);
  final rows = <List<dynamic>>[
    [
      th(tr('th.desc'), align: 'left'),
      th(tr('th.tax')),
      th(tr('th.unit')),
      th(tr('th.qty')),
      th(tr('th.uom'), align: 'center'),
      th(tr('th.disc')),
      th(tr('th.sub')),
    ]
  ];
  var zebra = 0;
  for (final l in p.lines) {
    if (l.group != null) {
      rows.add([
        {...(_t(l.group!, size: 9, bold: true, color: _navy, margin: [0, 6, 0, 0])), 'colSpan': 7},
        for (var i = 0; i < 6; i++) {},
      ]);
      continue;
    }
    final fill = (zebra++).isOdd ? _zebra : null;
    Map<String, dynamic> cell(String s, {String align = 'right'}) => {..._t(s, size: 9, align: align), if (fill != null) 'fillColor': fill};
    rows.add([
      {
        'stack': [
          {
            'text': [
              ..._runs(l.name, {'bold': true}),
              if (l.ai) {'text': '  AI', 'fontSize': 7, 'bold': true, 'color': _navy},
            ],
            'fontSize': 9,
          },
          _t('${l.sub} · ${tr('unit.hoursApprox', {'n': '${l.hours.round()}'})}', size: 7.5, color: _muted),
        ],
        if (fill != null) 'fillColor': fill,
      },
      cell(vat),
      cell(m(p.rate)),
      cell(l.qty.toStringAsFixed(2)),
      cell(tr('unit.pm'), align: 'center'),
      cell('0%'),
      cell(m(l.subtotal)),
    ]);
  }
  final items = {
    'table': {
      'headerRows': 1,
      'dontBreakRows': true,
      'widths': ['*', 30, 62, 32, 58, 30, 66],
      'body': rows,
    },
    'layout': 'quoteLines',
  };

  // ===== 備註與合計 =====
  Map<String, dynamic> noteLine(String k, String v) => _rich([(k, true, null), (v, false, null)], size: 8, color: _muted, margin: [0, 0, 0, 3]);
  final notes = {
    'width': '*',
    'stack': [
      noteLine(tr('n.type'), byId(projectTypes, q.type, 1).name),
      noteLine(tr('n.platform'), s.platformLabel()),
      noteLine(tr('n.design'), byId(designLevels, q.design, 1).name),
      if (q.summary.isNotEmpty) noteLine(tr('n.summary'), q.summary),
      if (q.extra.isNotEmpty) noteLine(tr('n.extra'), q.extra),
      if (q.urgency == 'rush') noteLine(tr('n.rush'), tr('n.rushV')),
      if (q.urgency == 'flex') noteLine(tr('n.flex'), tr('n.flexV')),
    ],
  };
  final totals = {
    'width': 250,
    'table': {
      'widths': ['*', 'auto'],
      'body': [
        [_t(tr('t.net'), size: 9.5), _t(m(p.ht), size: 9.5, align: 'right')],
        [_t(tr('t.vat', {'rate': vat}), size: 9.5), _t(m(p.vat), size: 9.5, align: 'right')],
        [
          _t(tr('t.gross'), size: 10.5, bold: true, fill: _head),
          _t(m(p.ttc), size: 11.5, bold: true, align: 'right', fill: _head),
        ],
        [
          {
            'colSpan': 2,
            'stack': [
              _t(tr('t.range'), size: 8.5, bold: true, color: _navy),
              _t('${m(p.ttc)} – ${m(p.ttcHigh)}', size: 11, bold: true, color: _navy, align: 'right', margin: [0, 2, 0, 0]),
            ],
          },
          {},
        ],
      ]
    },
    'layout': 'totals',
  };
  final summary = {
    'columns': [notes, {'width': 24, 'text': ''}, totals],
    'margin': [0, 12, 0, 0],
  };

  // ===== 1. 總價範圍 =====
  Map<String, dynamic> kpi(String k, String v) => {
        'stack': [_t(k, size: 7.5, color: _muted, margin: [0, 0, 0, 2]), _t(v, size: 10, bold: true)],
      };
  final kpis = {
    'table': {
      'widths': ['*', '*', '*', '*'],
      'body': [
        [
          kpi(tr('kpi.total'), '${m(p.ht)} – ${m(p.htHigh)}'),
          kpi(tr('kpi.complexity'), tr('cx.${p.complexity}')),
          kpi(tr('kpi.hours'), tr('kpi.hoursV', {'mm': '${p.mm}', 'h': '${e.totalHours.round()}'})),
          kpi(tr('kpi.schedule'), tr('kpi.scheduleV', {'a': '${p.monthsLow}', 'b': '${p.monthsHigh}', 'n': '${p.team}'})),
        ]
      ]
    },
    'layout': 'boxes',
  };

  // ===== 2. 人月拆解 =====
  final mm = <dynamic>[];
  for (final g in mmGroups(e).where((g) => g.hours > 0)) {
    final name = g.name.replaceFirst(RegExp(r'^\S+\s'), ''); // 去掉 emoji（字型沒有）
    final ratio = e.totalHours == 0 ? 0.0 : g.hours / e.totalHours;
    mm.add({
      'unbreakable': true,
      'margin': [0, 5, 0, 0],
      'stack': [
        {
          'columns': [
            {'width': '*', ..._t(name, size: 9.5, bold: true)},
            {
              'width': 'auto',
              ..._t(tr('unit.mm', {'mm': (g.hours / q.hoursPerMM).toStringAsFixed(2), 'h': '${g.hours.round()}'}), size: 9, bold: true)
            },
          ]
        },
        {
          'canvas': [
            {'type': 'rect', 'x': 0, 'y': 2, 'w': _contentWidth, 'h': 3.5, 'r': 1.7, 'color': _line},
            {'type': 'rect', 'x': 0, 'y': 2, 'w': _contentWidth * ratio, 'h': 3.5, 'r': 1.7, 'color': _navy},
          ],
          'margin': [0, 0, 0, 4],
        },
        for (final k in g.tasks)
          {
            'columns': [
              {'width': '*', ..._t(k.name, size: 8.5, color: _muted, margin: [14, 0, 0, 1])},
              {'width': 'auto', ..._t(tr('unit.hours', {'n': '${k.hours.round()}'}), size: 8.5, color: _muted)},
            ]
          },
        {'margin': [0, 4, 0, 0], ..._rule(w: 0.5, color: _line)},
      ],
    });
  }

  // ===== 3. 維護 =====
  final maintenance = _bullets([
    _rich([(tr('m.warranty.l'), true, null), (tr('m.warranty.v', {'n': fmtNum(q.warrantyMonths)}), false, null)]),
    _rich([
      (tr('m.sla.l'), true, null),
      (
        tr('m.sla.v', {
          'a': fmtNum(q.maintMinPct),
          'b': fmtNum(q.maintMaxPct),
          'lo': m(p.maintLow),
          'hi': m(p.maintHigh),
          'mlo': m(p.maintLow / 12),
          'mhi': m(p.maintHigh / 12),
        }),
        false,
        null
      ),
    ]),
    _rich([(tr('m.incl.l'), true, null), (tr('m.incl.v'), false, null)]),
    _rich([(tr('m.excl.l'), true, null), (tr('m.excl.v'), false, null)]),
  ]);

  // ===== 免責條款與簽章（綁在同一頁，避免簽章欄孤零零排到下一頁） =====
  final clauses = disclaimerClauses();
  final punct = lang.isCjk ? '：' : '.';
  Map<String, dynamic> sign(String label) => {
        'width': '*',
        'stack': [_rule(width: 220, w: 0.8), _t(label, size: 8.5, color: _muted, margin: [0, 3, 0, 0])]
      };

  final doc = <String, dynamic>{
    'pageSize': 'A4',
    'pageMargins': [36, 36, 36, 46],
    'defaultStyle': {'font': lang.isCjk ? 'CJK' : 'Latin', 'fontSize': 9, 'lineHeight': 1.15, 'color': _ink},
    'info': {'title': q.ref, 'author': q.myName, 'creator': 'Pricing AI'},
    if (logo) 'images': {'logo': q.logo},
    'x_footer': {'left': 'Pricing AI', 'right': '${q.ref}   ·   ${tr('pdf.page', {'n': '{page}'})}'},
    'content': [
      head,
      banner,
      info,
      {'text': '', 'margin': [0, 6, 0, 0]},
      items,
      summary,
      _h2(tr('s.range')),
      kpis,
      _h2(tr('s.mm')),
      ...(mm.isEmpty ? [_t(tr('s.none'), color: _muted)] : mm),
      _h2(tr('s.maint')),
      maintenance,
      if (ai != null) ...[
        _h2(tr('as.title')),
        _bullets([for (final a in ai.assumptions) _t(a)]),
        _h2(tr('risks.title')),
        _bullets([for (final r in ai.risks) _t(r)]),
      ],
      _h2(tr('terms.title')),
      for (var i = 0; i < clauses.length - 1; i++) _clause(i + 1, clauses[i].title, clauses[i].body, punct),
      {
        'unbreakable': true,
        'stack': [
          _clause(clauses.length, clauses.last.title, clauses.last.body, punct),
          _t(tr('terms.buffer', {'b': '${p.buffer}'}), size: 8.5, color: _muted, margin: [0, 4, 0, 0]),
          {
            'columns': [sign(tr('sign.company')), {'width': 40, 'text': ''}, sign(tr('sign.client'))],
            'margin': [0, 34, 0, 0],
          },
        ],
      },
    ],
  };
  return doc;
}

Map<String, dynamic> _clause(int n, String title, String body, String punct) => {
      'text': [..._runs('$n. $title$punct ', {'bold': true}), ..._runs(body)],
      'fontSize': 8.5,
      'margin': [0, 0, 0, 4],
    };

