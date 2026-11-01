import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:self_quote/app_state.dart';
import 'package:self_quote/i18n/i18n.dart';
import 'package:self_quote/case_analysis/pcc.dart';
import 'package:self_quote/ui/case_analysis_page.dart';
import 'package:self_quote/ui/case_browser_dialog.dart';

/// 案件分析頁：用存下來的採購網頁面跑一次「查詢 → 對照報價 → 競爭狀況」，確認版面沒有溢出
void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    I18n.lang = Lang.zh;
  });

  testWidgets('search, compare a quote and sample details', (tester) async {
    final list = File('test/fixtures/pcc_awards.html').readAsStringSync();
    final detail = File('test/fixtures/pcc_award_detail.html').readAsStringSync();
    final queries = <CaseQuery>[];
    final autos = <(bool, int, int)>[];
    // 假的「內嵌瀏覽器」：第一次看了清單頁，之後再點開一件案件
    Future<CaseCollection?> fake(BuildContext context, CaseQuery q, {CaseCollection? prior, String? doneLabel, bool auto = false, int details = 0, int rivals = 0, KnownDetails? known}) async {
      queries.add(q);
      autos.add((auto, details, rivals));
      final col = prior ?? CaseCollection();
      col.addPage(q.url.toString(), list);
      if (prior != null) col.addPage('https://web.pcc.gov.tw/tps/atm/AtmAwardWithoutSso/QueryAtmAwardDetail?pkAtmMain=NzEzMTY5MDg=', detail);
      return col;
    }

    final shot = Platform.environment['CASE_SHOT'];
    if (shot != null) {
      // 截圖用真的中文字型（測試預設字型只畫方塊）
      final bytes = File('web/fonts/NotoSansTC-Regular.otf').readAsBytesSync();
      await tester.runAsync(() => (FontLoader('Roboto')..addFont(Future.value(ByteData.view(bytes.buffer)))).load());
    }
    tester.view.physicalSize = const Size(1100, 2600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final key = GlobalKey();
    await tester.pumpWidget(RepaintBoundary(key: key, child: MaterialApp(theme: ThemeData.dark(), home: CaseAnalysisPage(state: AppState(), collect: fake, openStore: () async => null))));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).first, '網站');
    await tester.tap(find.text(tr('case.search')));
    await tester.pumpAndSettle();
    expect(queries.single.keyword, '網站');
    expect(queries.single.url.queryParameters['tenderName'], '網站');
    // 相關查詢字預設勾選前 3 個，一起查
    expect(queries.single.keywords, ['網站', '網頁', '官網', '入口網']);
    expect(autos.single, (true, 5, 3)); // 「分析」直接執行交叉分析：自動點開 5 件、查 3 家競爭對手
    expect(find.text(tr('case.partial', {'n': '50', 'total': '178'})), findsOneWidget);
    expect(find.text(tr('case.s.median')), findsOneWidget);

    await tester.enterText(find.widgetWithText(TextField, tr('case.myPrice')), '1000000');
    await tester.pump();
    expect(find.textContaining('1,000,000'), findsWidgets);

    await tester.tap(find.text(tr('case.detail.run')));
    await tester.pumpAndSettle();
    expect(queries.length, 2);
    expect(autos.last, (false, 0, 0)); // 「點開更多案件」是手動瀏覽
    expect(find.text(tr('case.detail.more')), findsOneWidget);
    expect(find.text(tr('case.comp')), findsOneWidget); // 點開的公告有投標廠商 → 潛在競爭對手
    expect(find.text(tr('case.d.winners')), findsOneWidget);
    expect(find.textContaining('凌網資訊股份有限公司'), findsWidgets);

    // 分享用摘要：有結果就有文字，可以複製；評選委員不寫姓名
    final share = tester.widget<SelectableText>(find.byKey(const ValueKey('case.share.text'))).data!;
    expect(share, startsWith(tr('report.title', {'k': '網站'})));
    expect(share, contains('【${tr('case.summary')}】'));
    expect(share, contains('【${tr('case.position')}】'));
    expect(share, contains('1,000,000')); // 自己的報價
    expect(share, contains('【${tr('case.detail')}】'));
    expect(share, contains(tr('report.source.pcc')));
    String? copied;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') copied = (call.arguments as Map)['text'] as String;
      return null;
    });
    addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null));
    await tester.tap(find.text(tr('case.share.copy')));
    await tester.pump();
    expect(copied, share);
    expect(find.text(tr('case.pdf')), findsOneWidget);
    // 圖表都有「複製圖片」「下載 PNG」
    for (final f in ['case-amounts', 'case-price-position']) {
      expect(find.byKey(ValueKey('chart.copy:$f')), findsOneWidget);
      expect(find.byKey(ValueKey('chart.save:$f')), findsOneWidget);
    }
    expect(find.byKey(const ValueKey('chart.watermark')), findsNWidgets(2)); // 每張圖都有浮水印
    expect(tester.takeException(), isNull);

    if (shot != null) {
      await tester.runAsync(() async {
        final img = await (key.currentContext!.findRenderObject()! as RenderRepaintBoundary).toImage();
        final png = await img.toByteData(format: ui.ImageByteFormat.png);
        File(shot).writeAsBytesSync(png!.buffer.asUint8List());
      });
    }
  });
}
