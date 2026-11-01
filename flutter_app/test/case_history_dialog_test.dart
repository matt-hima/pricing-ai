import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:self_quote/app_state.dart';
import 'package:self_quote/case_analysis/pcc.dart';
import 'package:self_quote/i18n/i18n.dart';
import 'package:self_quote/ui/case_browser_dialog.dart';
import 'package:self_quote/ui/case_history_dialog.dart';

/// 歷史案件彈出視窗：一打開就開啟內嵌的採購網（這裡用假的），帶回案件後交給 AI；
/// 測試環境沒有模型，摘要失敗時仍顯示統計與案件
void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    I18n.lang = Lang.zh;
  });

  testWidgets('opens the procurement browser right away and keeps results when the AI is unavailable', (tester) async {
    final list = File('test/fixtures/pcc_awards.html').readAsStringSync();
    final opened = <(CaseQuery, String?)>[];
    Future<CaseCollection?> fake(BuildContext context, CaseQuery q, {CaseCollection? prior, String? doneLabel, bool auto = false, int details = 0, int rivals = 0}) async {
      opened.add((q, doneLabel));
      return CaseCollection()..addPage(q.url.toString(), list);
    }

    tester.view.physicalSize = const Size(1000, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final s = AppState()..q.type = 'corporate';
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: CaseHistoryDialog(state: s, collect: fake))));
    await tester.pumpAndSettle();

    expect(opened, hasLength(1));
    expect(opened.single.$1.keyword, '網站'); // 由專案類型帶入
    expect(opened.single.$1.cate, ProcCate.services);
    expect(opened.single.$2, tr('hist.useAndSummarize'));
    expect(find.textContaining(tr('case.partial', {'n': '50', 'total': '178'})), findsOneWidget);
    expect(find.text(tr('hist.cases')), findsOneWidget);
    expect(find.textContaining(tr('hist.aiError', {'e': ''}).trim()), findsOneWidget);
    expect(find.text(tr('hist.rerun')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
