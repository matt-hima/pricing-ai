import '../i18n/i18n.dart';

/// 文案規則（assets/editor/CHEATSHEET.md）：給模型的簡短提示，加上模型回答之後用程式修正格式。
/// 小模型記不住排版規則，所以「寫什麼」用提示引導，「怎麼排版」由 [polishText] 直接改好。

/// 加進提示詞的文案規則（英文；日文、中文等再補該語言的專用規則）
String writingRules(Lang lang) {
  final extra = switch (lang) {
    Lang.ja => '\n- Japanese: use です・ます調 and full-width punctuation（、。！？）. No spaces next to numbers or Latin letters (3件, JavaScriptを). Prefer everyday kanji; use katakana only for words normally written that way.',
    Lang.zh => '\n- Chinese: use full-width punctuation（，。！？：） and one term per concept.',
    Lang.pt || Lang.es => '\n- Use one neutral, polite form of address (você / usted) consistently.',
    _ => '',
  };
  return '''Writing rules:
- Short, plain sentences, one idea each (about 50 characters in Japanese or Chinese, about 15 words elsewhere).
- Calm, polite, friendly tone. No hype or pressure: no "!!!", no "the best in the world".
- One word per concept; keep the same term everywhere.
- Say things directly and positively. Avoid jargon, double negatives and unexplained abbreviations.
- Button text says what happens ("Book a visit"), never "Submit" or "Click here".
- Prices carry the currency and thousands separators (12,000). Times use 24-hour format (10:00 – 19:00).$extra''';
}

const _cjk = r'\u3040-\u30ff\u3400-\u9fff\uff00-\uffef\u3000-\u303f';
const _halfToFull = {',': '、', '.': '。', '!': '！', '?': '？', ':': '：', ';': '；'};
const _zhHalfToFull = {',': '，', '.': '。', '!': '！', '?': '？', ':': '：', ';': '；'};

String _group(String digits) {
  final b = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) b.write(',');
    b.write(digits[i]);
  }
  return b.toString();
}

/// 模型輸出後的機械式修正：連續驚嘆號、刪節號、日文 / 中文的標點與空白、全形數字、金額千分位。
/// [code] 是網站語言（en / zh / ja / pt / es）。網址、信箱、顏色等不要經過這裡。
String polishText(String code, String input) {
  final cjkLang = code == 'ja' || code == 'zh';
  var s = input.replaceAll(RegExp(r'[ \t]+'), ' ').replaceAll(RegExp(r' ?\n ?'), '\n').trim();

  // 連續的 ! ?（半形或全形）只留一個
  s = s.replaceAllMapped(RegExp(r'[!！]{2,}'), (_) => cjkLang ? '！' : '!');
  s = s.replaceAllMapped(RegExp(r'[?？]{2,}'), (_) => cjkLang ? '？' : '?');
  // 刪節號統一成單一字元 …
  s = s.replaceAll(RegExp(r'\.{3,}|。{3,}|…{2,}'), '…');

  if (cjkLang) {
    // 全形英數字 → 半形（金額、時間常被寫成全形）
    s = s.replaceAllMapped(RegExp(r'[０-９Ａ-Ｚａ-ｚ]'), (m) => String.fromCharCode(m[0]!.codeUnitAt(0) - 0xFEE0));
    // 中日文字後面的半形標點 → 全形（字與字之間才轉，避免動到 10:00、1.5 這類）
    final map = code == 'ja' ? _halfToFull : _zhHalfToFull;
    s = s.replaceAllMapped(RegExp('([$_cjk])([,.!?:;])(?=\\s|\$|[$_cjk])'), (m) => '${m[1]}${map[m[2]]}');
    // 全形標點前後不留空白
    s = s.replaceAll(RegExp(r' +([、。，！？：；）」』])'), r'$1').replaceAll(RegExp(r'([（「『]) +'), r'$1');
    s = s.replaceAllMapped(RegExp('([、。，！？：；]) +(?=[$_cjk])'), (m) => m[1]!); // 全形標點後面接中日文時不留空白
    if (code == 'ja') {
      // 日文：數字、英文字與日文之間不放半形空白（3件、JavaScriptを）
      s = s.replaceAllMapped(RegExp('([$_cjk]) +(?=[0-9A-Za-z])'), (m) => m[1]!);
      s = s.replaceAllMapped(RegExp('([0-9A-Za-z%]) +(?=[$_cjk])'), (m) => m[1]!);
    }
  }

  // 金額加千分位：只處理「有貨幣符號或貨幣單位」的 4 位數以上（避免動到年份、電話、郵遞區號）
  s = s.replaceAllMapped(RegExp(r'((?:NT\$|R\$|[$€¥￥£]) ?)(\d{4,})(?![\d,])'), (m) => '${m[1]}${_group(m[2]!)}');
  s = s.replaceAllMapped(RegExp(r'(?<![\d,.])(\d{4,})( ?(?:円|元|ドル|dólares|euros|reais|dollars?|USD|TWD|NTD|JPY|EUR|BRL))'), (m) => '${_group(m[1]!)}${m[2]}');
  return s;
}
