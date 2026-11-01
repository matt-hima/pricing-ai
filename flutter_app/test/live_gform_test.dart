import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:self_quote/site/google_form_loader.dart';

/// 實際的公開 Google 表單（作者建立的預約範本）：真的連上去讀取。預設略過。
/// 執行：GFORM_URL=https://docs.google.com/forms/d/e/…/viewform flutter test test/live_gform_test.dart
void main() {
  final url = Platform.environment['GFORM_URL'];
  test('read a real public Google Form', () async {
    HttpOverrides.global = null;
    final f = await loadGoogleForm(url!);
    // ignore: avoid_print
    print('GFORM ${f.title} pages=${f.pages} action=${f.action}\n${f.fields.map((x) => '${x.entry} ${x.kind} ${x.required ? 'REQ' : 'opt'} ${x.label} ${x.options}').join('\n')}');
    expect(f.fields, isNotEmpty);
  }, skip: url == null ? 'set GFORM_URL' : null);
}
