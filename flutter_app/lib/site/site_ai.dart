import '../i18n/i18n.dart';
import '../json_repair.dart';
import 'site_industry.dart';
import 'site_style.dart';

/// 價格 / 營業時間不明時填的文字（不要讓模型編數字）
const askUs = {
  'en': 'Ask us',
  'ja': 'お問い合わせください',
  'zh': '歡迎洽詢',
  'pt': 'Consulte-nos',
  'es': 'Consúltanos',
};

/// 每個語言各一份完整範例（髮廊）。小模型會照範例的語言與格式寫，所以範例用目標語言寫，
/// 並且本身就符合文案規則（全形標點、數字旁不留空白、千分位）。
const _examples = {
  'en': '''{"industry":"salon","brand":"Willow Hair Studio","brandSub":"HAIR & COLOR","h1":"Hair you love,\\nevery day","h2":"Cuts and colour by friendly stylists","lead":"Book a seat in under a minute.","cta":"Book a visit",
 "services":[{"name":"Haircut","sub":"Cut & Style"},{"name":"Colour","sub":"Hair Colour"},{"name":"Treatment","sub":"Hair Care"},{"name":"Styling","sub":"Special Day"}],
 "prices":[{"item":"Haircut","price":"\$35"},{"item":"Colour","price":"\$90"},{"item":"Treatment","price":"\$60"},{"item":"Styling","price":"Ask us"}],
 "hours":[{"day":"Mon – Fri","time":"10:00 – 19:00"},{"day":"Saturday","time":"10:00 – 17:00"},{"day":"Sunday","time":"Closed"}],
 "address":"12 Park Road"}''',
  'ja': '''{"industry":"salon","brand":"ウィロウ ヘアスタジオ","brandSub":"HAIR & COLOR","h1":"毎日が、\\nもっと楽しくなる髪へ。","h2":"やさしいスタイリストが、カットとカラーを担当します。","lead":"ご予約は1分で完了します。","cta":"予約する",
 "services":[{"name":"カット","sub":"Cut & Style"},{"name":"カラー","sub":"Hair Colour"},{"name":"トリートメント","sub":"Hair Care"},{"name":"ヘアセット","sub":"Styling"}],
 "prices":[{"item":"カット","price":"4,500円"},{"item":"カラー","price":"9,000円"},{"item":"トリートメント","price":"6,000円"},{"item":"ヘアセット","price":"お問い合わせください"}],
 "hours":[{"day":"月〜金","time":"10:00 – 19:00"},{"day":"土曜","time":"10:00 – 17:00"},{"day":"日曜・祝日","time":"休業"}],
 "address":"東京都〇〇区1-2-3"}''',
  'zh': '''{"industry":"salon","brand":"柳樹髮廊","brandSub":"HAIR & COLOR","h1":"每一天，\\n都有好心情的髮型。","h2":"親切的設計師，為您剪燙染護。","lead":"一分鐘就能完成預約。","cta":"立即預約",
 "services":[{"name":"剪髮","sub":"Cut & Style"},{"name":"染髮","sub":"Hair Colour"},{"name":"護髮","sub":"Hair Care"},{"name":"造型","sub":"Styling"}],
 "prices":[{"item":"剪髮","price":"NT\$800"},{"item":"染髮","price":"NT\$2,500"},{"item":"護髮","price":"NT\$1,500"},{"item":"造型","price":"歡迎洽詢"}],
 "hours":[{"day":"週一至週五","time":"10:00 – 19:00"},{"day":"週六","time":"10:00 – 17:00"},{"day":"週日","time":"休息"}],
 "address":"台北市〇〇區〇〇路12號"}''',
  'pt': '''{"industry":"salon","brand":"Estúdio Salgueiro","brandSub":"CABELO E COR","h1":"Cabelo que você ama,\\ntodos os dias","h2":"Cortes e coloração com profissionais atenciosos","lead":"Agende em menos de um minuto.","cta":"Agendar",
 "services":[{"name":"Corte","sub":"Cut & Style"},{"name":"Coloração","sub":"Hair Colour"},{"name":"Tratamento","sub":"Hair Care"},{"name":"Penteado","sub":"Styling"}],
 "prices":[{"item":"Corte","price":"R\$ 90"},{"item":"Coloração","price":"R\$ 220"},{"item":"Tratamento","price":"R\$ 150"},{"item":"Penteado","price":"Consulte-nos"}],
 "hours":[{"day":"Seg – Sex","time":"10:00 – 19:00"},{"day":"Sábado","time":"10:00 – 17:00"},{"day":"Domingo","time":"Fechado"}],
 "address":"Rua das Flores, 12"}''',
  'es': '''{"industry":"salon","brand":"Estudio Sauce","brandSub":"PELO Y COLOR","h1":"El pelo que te gusta,\\ntodos los días","h2":"Cortes y color con profesionales amables","lead":"Reserva en menos de un minuto.","cta":"Reservar",
 "services":[{"name":"Corte","sub":"Cut & Style"},{"name":"Color","sub":"Hair Colour"},{"name":"Tratamiento","sub":"Hair Care"},{"name":"Peinado","sub":"Styling"}],
 "prices":[{"item":"Corte","price":"25 €"},{"item":"Color","price":"60 €"},{"item":"Tratamiento","price":"40 €"},{"item":"Peinado","price":"Consúltanos"}],
 "hours":[{"day":"Lun – Vie","time":"10:00 – 19:00"},{"day":"Sábado","time":"10:00 – 17:00"},{"day":"Domingo","time":"Cerrado"}],
 "address":"Calle del Parque 12"}''',
};

/// 第二份範例（咖啡店）：描述的業種是美容室時改用它，避免範例和實際業種一樣而被整份照抄
const _examplesAlt = {
  'en': '''{"industry":"restaurant","brand":"Pine Street Coffee","brandSub":"COFFEE & BAKERY","h1":"A quiet cup,\\nany time of day","h2":"Coffee, cake and light lunches","lead":"Reserve a table for your next meeting.","cta":"Reserve a table",
 "services":[{"name":"Coffee","sub":"Coffee"},{"name":"Cake set","sub":"Cake Set"},{"name":"Light lunch","sub":"Lunch"},{"name":"Group table","sub":"Group Booking"}],
 "prices":[{"item":"Coffee","price":"\$4"},{"item":"Cake set","price":"\$9"},{"item":"Light lunch","price":"\$14"},{"item":"Group table","price":"Ask us"}],
 "hours":[{"day":"Mon – Fri","time":"08:00 – 18:00"},{"day":"Saturday","time":"09:00 – 18:00"},{"day":"Sunday","time":"Closed"}],
 "address":"8 Pine Street"}''',
  'ja': '''{"industry":"restaurant","brand":"パインストリート コーヒー","brandSub":"COFFEE & BAKERY","h1":"静かな一杯を、\\nいつでも。","h2":"コーヒーとケーキ、軽いランチをご用意しています。","lead":"お席のご予約はネットから承ります。","cta":"席を予約する",
 "services":[{"name":"コーヒー","sub":"Coffee"},{"name":"ケーキセット","sub":"Cake Set"},{"name":"軽めのランチ","sub":"Lunch"},{"name":"団体席","sub":"Group Booking"}],
 "prices":[{"item":"コーヒー","price":"500円"},{"item":"ケーキセット","price":"1,000円"},{"item":"軽めのランチ","price":"1,500円"},{"item":"団体席","price":"お問い合わせください"}],
 "hours":[{"day":"月〜金","time":"8:00 – 18:00"},{"day":"土曜","time":"9:00 – 18:00"},{"day":"日曜","time":"休業"}],
 "address":"東京都〇〇区8-9-10"}''',
  'zh': '''{"industry":"restaurant","brand":"松街咖啡","brandSub":"COFFEE & BAKERY","h1":"安靜的一杯，\\n隨時都有。","h2":"提供咖啡、蛋糕與輕食午餐。","lead":"座位可以線上預約。","cta":"預約座位",
 "services":[{"name":"咖啡","sub":"Coffee"},{"name":"蛋糕套餐","sub":"Cake Set"},{"name":"輕食午餐","sub":"Lunch"},{"name":"團體座位","sub":"Group Booking"}],
 "prices":[{"item":"咖啡","price":"NT\$120"},{"item":"蛋糕套餐","price":"NT\$280"},{"item":"輕食午餐","price":"NT\$380"},{"item":"團體座位","price":"歡迎洽詢"}],
 "hours":[{"day":"週一至週五","time":"08:00 – 18:00"},{"day":"週六","time":"09:00 – 18:00"},{"day":"週日","time":"休息"}],
 "address":"台北市〇〇區松街8號"}''',
  'pt': '''{"industry":"restaurant","brand":"Café Rua do Pinheiro","brandSub":"CAFÉ E PADARIA","h1":"Um café tranquilo,\\na qualquer hora","h2":"Café, bolo e almoços leves","lead":"Reserve uma mesa para o seu próximo encontro.","cta":"Reservar mesa",
 "services":[{"name":"Café","sub":"Coffee"},{"name":"Combo de bolo","sub":"Cake Set"},{"name":"Almoço leve","sub":"Lunch"},{"name":"Mesa para grupos","sub":"Group Booking"}],
 "prices":[{"item":"Café","price":"R\$ 8"},{"item":"Combo de bolo","price":"R\$ 25"},{"item":"Almoço leve","price":"R\$ 40"},{"item":"Mesa para grupos","price":"Consulte-nos"}],
 "hours":[{"day":"Seg – Sex","time":"08:00 – 18:00"},{"day":"Sábado","time":"09:00 – 18:00"},{"day":"Domingo","time":"Fechado"}],
 "address":"Rua do Pinheiro, 8"}''',
  'es': '''{"industry":"restaurant","brand":"Café Calle del Pino","brandSub":"CAFÉ Y PANADERÍA","h1":"Un café tranquilo,\\na cualquier hora","h2":"Café, tarta y almuerzos ligeros","lead":"Reserva una mesa para tu próxima reunión.","cta":"Reservar mesa",
 "services":[{"name":"Café","sub":"Coffee"},{"name":"Menú de tarta","sub":"Cake Set"},{"name":"Almuerzo ligero","sub":"Lunch"},{"name":"Mesa para grupos","sub":"Group Booking"}],
 "prices":[{"item":"Café","price":"2 €"},{"item":"Menú de tarta","price":"6 €"},{"item":"Almuerzo ligero","price":"10 €"},{"item":"Mesa para grupos","price":"Consúltanos"}],
 "hours":[{"day":"Lun – Vie","time":"08:00 – 18:00"},{"day":"Sábado","time":"09:00 – 18:00"},{"day":"Domingo","time":"Cerrado"}],
 "address":"Calle del Pino 8"}''',
};

/// 範例本身（用來偵測模型是不是直接抄了範例）
Map<String, dynamic> siteExample(Lang lang, {bool alt = false}) => parseLooseJson((alt ? _examplesAlt : _examples)[lang.name] ?? (alt ? _examplesAlt : _examples)['en']!) ?? const {};

/// 網站文字生成：系統提示詞固定英文（小模型最穩定），輸出語言另行指定，範例則用目標語言。
String siteSystemPrompt(Lang lang, {bool alt = false}) => """You write the text of a one-page appointment-booking website for a small business (salon, clinic, restaurant, school, rental space, repair shop).
From the owner's description, write short, natural website copy for THAT business.
Rules:
1. Output JSON only, no other text.
2. Write ALL text in ${lang.aiName}, except the "sub" fields, which are short English subtitles.
3. Services are what customers can book or buy (menu items, courses, lessons, rooms, treatments), not opening hours. Exactly 4 services, 3 to 5 prices and 3 opening-hours rows.
4. Use only the prices and opening hours the owner gave, in the currency the owner used. For a price the owner did not give, write "${askUs[lang.name] ?? askUs['en']}" instead of inventing a number.
5. Do not invent phone numbers or email addresses.
6. "industry" is one of: ${industryIds.join(', ')}. Pick the closest kind of business.
7. The example below shows the format and style for another business; never copy its wording.
${writingRules(lang)}
Example output for a ${alt ? 'small café' : 'hair salon'} (the page language is ${lang.aiName}):
${(alt ? _examplesAlt : _examples)[lang.name] ?? (alt ? _examplesAlt : _examples)['en']}""";

final _placeholder = RegExp(r'^[\s.…\-–—_?]*$|english subtitle|^(string|text|value)$', caseSensitive: false);
final _digitRun = RegExp(r'\d{9,}'); // 不可能的金額：模型一直重複寫 0

bool _junk(String v) => v.isEmpty || _placeholder.hasMatch(v) || _digitRun.hasMatch(v);

String _s(Object? v, int max) {
  final t = (v ?? '').toString().trim();
  return t.length > max ? t.substring(0, max) : t;
}

List<List<String>> _pairs(Object? raw, String a, String b, int maxA, int maxB, {int max = 6}) {
  if (raw is! List) return [];
  final out = <List<String>>[];
  for (final e in raw.take(max)) {
    if (e is! Map) continue;
    final x = _s(e[a], maxA), y = _s(e[b], maxB);
    if (_junk(x)) continue; // 小模型常照抄範例裡的「..」或重複垃圾
    out.add([x, _junk(y) ? '' : y]);
  }
  return out;
}

/// 把模型輸出整理成編輯器範本字典的覆寫欄位（鍵名與 assets/editor/blocks.js 的 T 相同）。
/// 解析不出任何有用欄位時回傳 null。
Map<String, Object?>? siteOverrides(String modelText, {String lang = 'en'}) {
  final j = parseLooseJson(modelText);
  if (j == null) return null;
  String pol(String v) => polishText(lang, v); // 文案規則：標點、空白、千分位（assets/editor/CHEATSHEET.md）
  final o = <String, Object?>{};
  final ind = '${j['industry'] ?? ''}'.trim().toLowerCase();
  if (industryIds.contains(ind)) o['industry'] = ind;
  void put(String key, String jsonKey, int max) {
    final v = pol(_s(j[jsonKey], max));
    if (!_junk(v)) o[key] = v;
  }

  put('brand', 'brand', 24);
  put('brandSub', 'brandSub', 28);
  put('h1', 'h1', 60);
  put('h2', 'h2', 80);
  put('lead', 'lead', 120);
  put('cta', 'cta', 24);
  put('addr', 'address', 80);
  List<List<String>> polished(List<List<String>> rows) => [
        for (final r in rows) [for (final c in r) pol(c)]
      ];
  final svc = polished(_pairs(j['services'], 'name', 'sub', 24, 28, max: 4));
  if (svc.length >= 2) {
    o['svc'] = svc;
    o['opts'] = [for (final s in svc) s.first];
  }
  final price = polished(_pairs(j['prices'], 'item', 'price', 40, 20));
  if (price.length >= 2) o['price'] = price;
  final hours = polished(_pairs(j['hours'], 'day', 'time', 24, 24, max: 4));
  if (hours.length >= 2) o['hours'] = hours;
  // 只有業種、沒有任何頁面文字，等於沒有可用內容
  return o.keys.every((k) => k == 'industry') ? null : o;
}

/* ---------- 聊天 ---------- */

class ChatTurn {
  final bool user;
  final String text;
  const ChatTurn(this.user, this.text);
}
