import 'package:flutter/widgets.dart';

import 'en.dart';
import 'es.dart';
import 'ja.dart';
import 'pt.dart';
import 'zh.dart';

/// 支援語言：繁體中文、日文、英文、葡萄牙文、西班牙文
enum Lang {
  zh('zh-TW', '繁體中文', Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant', countryCode: 'TW'), 'tc', 'Traditional Chinese (繁體中文)'),
  ja('ja', '日本語', Locale('ja'), 'jp', 'Japanese (日本語)'),
  en('en', 'English', Locale('en'), 'tc', 'English'),
  pt('pt', 'Português', Locale('pt'), 'tc', 'Brazilian Portuguese (Português do Brasil)'),
  es('es', 'Español', Locale('es'), 'tc', 'Spanish (Español)');

  final String code;
  final String native;
  final Locale locale;

  /// PDF 使用的字型組：tc = Noto Sans TC，jp = Noto Sans JP
  final String fontSet;

  /// 告訴 AI 要用哪種語言輸出
  final String aiName;
  const Lang(this.code, this.native, this.locale, this.fontSet, this.aiName);

  bool get isCjk => this == zh || this == ja;

  /// 清單項目之間的分隔符
  static String get list => I18n.lang.isCjk ? '、' : ', ';

  /// 依瀏覽器語言挑預設語言
  static Lang detect(String? browserLang) {
    final l = (browserLang ?? '').toLowerCase();
    if (l.startsWith('ja')) return ja;
    if (l.startsWith('pt')) return pt;
    if (l.startsWith('es')) return es;
    if (l.startsWith('zh')) return zh;
    return en;
  }

  /// 系統的偏好語言清單（依使用者設定的順序，例如 ["ja-JP", "zh-Hant-TW", "en-US"]）→ 第一個支援的語言；都不支援就用英文
  static Lang detectAny(Iterable<String> tags) {
    for (final t in tags) {
      final l = t.toLowerCase();
      for (final x in values) {
        if (l == x.name || l.startsWith('${x.name}-') || l.startsWith('${x.name}_')) return x;
      }
    }
    return en;
  }

  /// 網址參數 ?lang= 的寬鬆解析（zh、zh-tw、zh-hant、ja、en、pt、es…）；不認得則為 null
  static Lang? fromParam(String? p) {
    final l = (p ?? '').toLowerCase();
    if (l.isEmpty) return null;
    for (final x in values) {
      if (l == x.name || l == x.code.toLowerCase()) return x;
    }
    return l.startsWith('zh') ? zh : null;
  }

  static Lang? fromCode(String? c) {
    for (final l in values) {
      if (l.code == c) return l;
    }
    return null;
  }
}

const _maps = <Lang, Map<String, String>>{
  Lang.zh: zhStrings,
  Lang.ja: jaStrings,
  Lang.en: enStrings,
  Lang.pt: ptStrings,
  Lang.es: esStrings,
};

class I18n {
  static Lang lang = Lang.zh;
}

/// 取得目前語言的字串；`{name}` 會以 args 取代。找不到時退回英文，再退回 key。
String tr(String key, [Map<String, String>? args]) {
  var s = _maps[I18n.lang]![key] ?? enStrings[key] ?? key;
  if (args != null) {
    args.forEach((k, v) => s = s.replaceAll('{$k}', v));
  }
  return s;
}

/// 翻譯來自 JS 的訊息：`@代碼` 或 `@代碼:參數`；一般文字原樣回傳。
/// `@retry:` 的參數本身可以也是 `@代碼`（遞迴翻譯）。
String tx(String s) {
  if (!s.startsWith('@')) return s;
  final i = s.indexOf(':');
  final code = i < 0 ? s.substring(1) : s.substring(1, i);
  final arg = i < 0 ? '' : s.substring(i + 1);
  switch (code) {
    case 'retry':
      return tr('prog.retry') + tx(arg);
    case 'model_not_found':
      return tr('js.model_not_found', {'id': arg});
    case 'limits':
      return tr('gpu.reason.limits', {'detail': arg});
    case 'cpu_downloading':
      return tr('js.cpu_downloading', {'n': arg});
    case 'nowebgpu':
    case 'noadapter':
    case 'nobridge':
      return tr('gpu.reason.$code');
    default:
      return tr('js.$code');
  }
}

/// 從例外取出可顯示的文字（JS 例外可能夾帶 `@代碼`）
String errText(Object e) {
  final m = RegExp(r'@\w+(?::[^\n]*)?').firstMatch('$e');
  return m == null ? '$e' : tx(m.group(0)!);
}

/// 免責條款（首頁、報價單、PDF 共用）
List<({String title, String body})> disclaimerClauses() => [
      for (var i = 1; i <= 6; i++) (title: tr('terms.$i.t'), body: tr('terms.$i.b')),
    ];
