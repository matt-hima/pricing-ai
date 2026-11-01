import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:self_quote/app_state.dart';
import 'package:self_quote/i18n/i18n.dart';

/// 介面語言：依系統的偏好語言清單自動選擇；使用者選了語言就記住；可改回跟隨系統
void main() {
  test('the first supported language in the preferred list wins', () {
    expect(Lang.detectAny(['fr-FR', 'ja-JP', 'en-US']), Lang.ja);
    expect(Lang.detectAny(['zh-Hant-TW']), Lang.zh);
    expect(Lang.detectAny(['zh_CN']), Lang.zh);
    expect(Lang.detectAny(['pt-BR', 'en']), Lang.pt);
    expect(Lang.detectAny(['es-419']), Lang.es);
    expect(Lang.detectAny(['fr', 'de-DE']), Lang.en); // 都不支援 → 英文
    expect(Lang.detectAny(['english']), Lang.en); // 不是 en 開頭的語言代碼也不會誤判
  });

  testWidgets('follows the system language until the user picks one', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final dispatcher = tester.binding.platformDispatcher;
    addTearDown(dispatcher.clearLocalesTestValue);
    dispatcher.localesTestValue = const [Locale('fr', 'FR'), Locale.fromSubtags(languageCode: 'ja', countryCode: 'JP')];

    final s = AppState();
    await tester.runAsync(s.init);
    expect(I18n.lang, Lang.ja); // 法文不支援，第二順位的日文
    expect(s.followSystem, isTrue);

    // 系統語言改了：跟著改
    dispatcher.localesTestValue = const [Locale('es')];
    await tester.pump();
    expect(I18n.lang, Lang.es);

    // 使用者選了繁體中文：記住，不再跟著系統
    s.setLang(Lang.zh);
    expect(s.followSystem, isFalse);
    expect((await SharedPreferences.getInstance()).getString('selfquote.lang.v1'), Lang.zh.code);
    dispatcher.localesTestValue = const [Locale('pt', 'BR')];
    await tester.pump();
    expect(I18n.lang, Lang.zh);

    // 改回跟隨系統：忘掉選擇，馬上換成系統語言
    s.useSystemLang();
    expect(s.followSystem, isTrue);
    expect(I18n.lang, Lang.pt);
    expect((await SharedPreferences.getInstance()).getString('selfquote.lang.v1'), isNull);

    // 下次啟動：沒有記住的選擇 → 依系統語言
    final again = AppState();
    await tester.runAsync(again.init);
    expect(I18n.lang, Lang.pt);
    s.dispose();
    again.dispose();
  });
}
