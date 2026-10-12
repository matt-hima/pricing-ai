import 'package:web/web.dart' as web;

String browserLanguage() => web.window.navigator.language;

/// 網址上的 ?lang=（SEO 語言落地頁的按鈕會帶上），沒有則為 null
String? queryLanguage() => Uri.base.queryParameters['lang'];

void applyPageLanguage(String code, String title) {
  web.document.documentElement?.setAttribute('lang', code);
  web.document.title = title;
}
