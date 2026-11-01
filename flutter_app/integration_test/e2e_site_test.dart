import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:archive/archive.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';
import 'package:self_quote/app_state.dart';
import 'package:self_quote/i18n/i18n.dart';
import 'package:self_quote/main.dart';
import 'package:self_quote/site/site_model.dart';
import 'package:self_quote/site/site_store.dart';
import 'package:self_quote/site/ui/site_chat.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 端到端（真正的 Mac App）：從「新增網站」開始，全程用聊天（描述店家 → 修改），最後按「Export ZIP」，再解開 ZIP 檢查。
/// 業種與語言隨機挑選（顯示用的亂數種子會印出來，方便重現）：
///   E2E_INDUSTRY=restaurant|salon|school|space|clinic   指定業種
///   E2E_LANG=en|ja|zh|pt|es                              指定語言
///   E2E_SEED=123                                         指定亂數種子
/// 螢幕要亮著、視窗在前景：  caffeinate -d -i flutter test integration_test/e2e_site_test.dart -d macos

/// 業種 × 語言的店家描述（取材自「予約システム比較」業種別案例的需求）
const descriptions = <String, Map<String, String>>{
  'restaurant': {
    'en': 'A small Italian restaurant near Shibuya station with 20 seats. Lunch is 11:30 to 14:00 and dinner 17:30 to 22:00. Courses start at 4500 yen. We take bookings online 24 hours a day because phone calls are hard to answer during service, and no-shows are a problem for us.',
    'ja': '渋谷駅近くの小さなイタリアンレストランです。席数は20席。ランチは11時30分から14時、ディナーは17時30分から22時です。コースは4500円からです。接客中は電話に出られないので、ネットで24時間予約を受けたいです。無断キャンセルにも困っています。',
    'zh': '我們是澀谷車站附近的小型義大利餐廳，共 20 個座位。午餐 11:30 到 14:00，晚餐 17:30 到 22:00，套餐 4500 日圓起。用餐時間很難接電話，希望可以 24 小時線上訂位，也希望減少臨時不到的客人。',
    'pt': 'Somos um pequeno restaurante italiano perto da estação de Shibuya, com 20 lugares. O almoço é das 11:30 às 14:00 e o jantar das 17:30 às 22:00. Os menus começam em 4500 ienes. Queremos receber reservas online 24 horas, porque é difícil atender o telefone durante o serviço.',
    'es': 'Somos un pequeño restaurante italiano cerca de la estación de Shibuya, con 20 asientos. El almuerzo es de 11:30 a 14:00 y la cena de 17:30 a 22:00. Los menús empiezan en 4500 yenes. Queremos recibir reservas en línea las 24 horas, porque es difícil contestar el teléfono durante el servicio.',
  },
  'salon': {
    'en': 'A hair salon in Nagoya. We do cuts, colour, perms and treatments. Customers like to choose their stylist. We are open 10:00 to 19:00 and closed on Tuesdays. Many people book after work, so we want online booking in the evening too.',
    'ja': '名古屋の美容室です。カット、カラー、パーマ、トリートメントがあります。スタイリストを指名して予約してもらいたいです。営業時間は10時から19時、火曜定休です。仕事帰りの夜にもネットで予約を受けたいです。',
    'zh': '我們是名古屋的美髮沙龍，有剪髮、染髮、燙髮和護髮。客人喜歡指定設計師。營業時間 10:00 到 19:00，週二公休。很多人下班後才預約，所以希望晚上也能線上預約。',
    'pt': 'Somos um salão de beleza em Nagoia. Fazemos corte, coloração, permanente e tratamento. Os clientes gostam de escolher o profissional. Abrimos das 10:00 às 19:00 e fechamos às terças. Muitas pessoas agendam depois do trabalho, então queremos agendamento online à noite também.',
    'es': 'Somos un salón de belleza en Nagoya. Hacemos corte, color, permanente y tratamientos. A los clientes les gusta elegir a su profesional. Abrimos de 10:00 a 19:00 y cerramos los martes. Mucha gente reserva después del trabajo, así que queremos reservas en línea también por la noche.',
  },
  'school': {
    'en': 'A piano school in Osaka for children and adults. New students start with a trial lesson. The monthly fee is 8000 yen. Students should be able to report an absence and book a make-up lesson online.',
    'ja': '大阪のピアノ教室です。子ども向けと大人向けのレッスンがあり、まずは体験レッスンを申し込んでもらいたいです。月謝は8000円からで、お休みしたときの振替レッスンもネットで受け付けたいです。',
    'zh': '我們是大阪的鋼琴教室，有兒童與成人課程。新學生先從體驗課開始，月費 8000 日圓起。希望學生可以線上請假並預約補課。',
    'pt': 'Somos uma escola de piano em Osaka, para crianças e adultos. Os novos alunos começam com uma aula experimental. A mensalidade é de 8000 ienes. Queremos que os alunos avisem faltas e agendem aulas de reposição online.',
    'es': 'Somos una escuela de piano en Osaka, para niños y adultos. Los alumnos nuevos empiezan con una clase de prueba. La cuota mensual es de 8000 yenes. Queremos que los alumnos avisen de ausencias y reserven clases de recuperación en línea.',
  },
  'space': {
    'en': 'A small meeting room and co-working space near Taipei station, rented by the hour for 600 NT dollars. People book a time slot online and get the door code after booking. Open 24 hours with no staff on site.',
    'ja': '台北駅の近くにある小さな会議室とコワーキングスペースです。1時間600台湾ドルで貸し出しています。オンラインで時間枠を予約すると、予約後にドアの暗証番号が届きます。無人で24時間利用できます。',
    'zh': '我們是台北車站附近的小型會議室與共享辦公空間，每小時 600 元新台幣。客人線上預約時段，預約後會收到門鎖密碼。無人管理，24 小時開放。',
    'pt': 'Uma pequena sala de reuniões e espaço de coworking perto da estação de Taipei, alugada por hora por 600 dólares taiwaneses. As pessoas reservam um horário online e recebem o código da porta depois. Aberto 24 horas, sem funcionários no local.',
    'es': 'Una pequeña sala de reuniones y espacio de coworking cerca de la estación de Taipéi, alquilada por horas a 600 dólares taiwaneses. La gente reserva un horario en línea y recibe el código de la puerta después. Abierto las 24 horas, sin personal en el lugar.',
  },
  'clinic': {
    'en': 'A family clinic in Taichung with internal medicine and pediatrics. We see patients in the morning and evening and are closed on Sundays. We want patients to book online, choose first visit or return visit, get a reminder, and avoid crowding in the waiting room.',
    'ja': '台中の家庭医クリニックで、内科と小児科を診ています。午前と夕方に診察し、日曜は休診です。オンラインで予約でき、初診と再診を選べて、リマインドが届き、待合室の混雑を減らしたいです。',
    'zh': '我們是台中的家庭診所，內科與小兒科。早上與晚上看診，週日休診。希望病人可以線上預約，區分初診和複診，並且提醒就診時間，減少候診室太擁擠。',
    'pt': 'Uma clínica familiar em Taichung com clínica geral e pediatria. Atendemos de manhã e à noite e fechamos aos domingos. Queremos que os pacientes agendem online, escolham primeira consulta ou retorno, recebam um lembrete e evitem aglomeração na sala de espera.',
    'es': 'Una clínica familiar en Taichung con medicina interna y pediatría. Atendemos por la mañana y por la noche y cerramos los domingos. Queremos que los pacientes reserven en línea, elijan primera visita o revisión, reciban un recordatorio y se evite la aglomeración en la sala de espera.',
  },
};

/// 聊天修改（用網站語言說）：主色、隱藏浮動按鈕、預約通知信箱、價格調降、加一題預約問題
const edits = <String, List<String>>{
  'en': ['Use a blue colour', 'Hide the floating buttons', 'Send bookings to hello@luna.example', 'Make all the prices 15% cheaper', 'Add a question about allergies to the booking form'],
  'ja': ['メインカラーを青にしてください', '浮かんでいるボタンを非表示にしてください', '予約の通知はhello@luna.exampleに送ってください', '料金をすべて15%安くしてください', 'アレルギーについての質問を予約フォームに追加してください'],
  'zh': ['主色改成藍色', '隱藏浮動按鈕', '預約通知寄到 hello@luna.example', '所有價格調低 15%', '預約表單新增一題詢問過敏史'],
  'pt': ['Use a cor azul', 'Oculte os botões flutuantes', 'Envie as reservas para hello@luna.example', 'Deixe todos os preços 15% mais baratos', 'Adicione ao formulário uma pergunta sobre alergias'],
  'es': ['Usa el color azul', 'Oculta los botones flotantes', 'Envía las reservas a hello@luna.example', 'Haz todos los precios un 15% más baratos', 'Añade al formulario una pregunta sobre alergias'],
};

/// 外觀（科技感深色）與重新寫常見問題
const techSay = <String, String>{
  'en': 'Make the whole site high-tech and dark',
  'ja': 'サイト全体をハイテクなダークにしてください',
  'zh': '整個網站改成科技感深色',
  'pt': 'Deixe o site todo tecnológico e escuro',
  'es': 'Dale a todo el sitio un aspecto tecnológico oscuro',
};
const faqSay = <String, String>{
  'en': 'Write the FAQ again',
  'ja': 'よくある質問をもう一度書いてください',
  'zh': '重新寫常見問題',
  'pt': 'Escreva o FAQ de novo',
  'es': 'Vuelve a escribir las preguntas frecuentes',
};

const sampleBrands = ['Sakura Clinic', '桜エステクリニック', '櫻花美學診所', 'Clínica Sakura'];

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('random industry: new site → chat builds it → chat edits it → Export ZIP → the ZIP is a correct site', (tester) async {
    final seed = int.tryParse(Platform.environment['E2E_SEED'] ?? '') ?? DateTime.now().millisecondsSinceEpoch % 100000;
    // ignore: avoid_print
    print('E2E env: INDUSTRY=${Platform.environment['E2E_INDUSTRY']} LANG=${Platform.environment['E2E_LANG']} SEED=${Platform.environment['E2E_SEED']}');
    final rnd = Random(seed);
    final industry = Platform.environment['E2E_INDUSTRY'] ?? descriptions.keys.elementAt(rnd.nextInt(descriptions.length));
    final lang = Platform.environment['E2E_LANG'] ?? langs.keys.elementAt(rnd.nextInt(langs.length));
    final description = descriptions[industry]![lang]!;
    final uiLang = Lang.fromCode(lang == 'zh' ? 'zh-TW' : lang)!;
    // ignore: avoid_print
    print('E2E scenario: industry=$industry lang=$lang seed=$seed');

    SharedPreferences.setMockInitialValues({
      'flutter.selfquote.engine.storage': Platform.environment['LIVE_ENGINE_STORAGE'] ?? '/Volumes/dev_disk/pricing-ai',
      'flutter.selfquote.lang.v1': uiLang.code,
    });
    I18n.lang = uiLang; // 聊天介面跟著使用者介面語言
    final state = AppState();
    final siteStore = Store(aiAvailable: true);
    await siteStore.init();
    await tester.pumpWidget(SelfQuoteApp(state: state, siteStore: siteStore));
    await state.init();
    I18n.lang = uiLang;
    state.startQuoting(); // 略過介紹頁（只寫進假的偏好設定）
    await tester.pump(const Duration(milliseconds: 500));

    Future<void> waitFor(bool Function() ok, String what, {int seconds = 120}) async {
      final end = DateTime.now().add(Duration(seconds: seconds));
      while (!ok()) {
        if (DateTime.now().isAfter(end)) {
          final chat = [for (final e in find.byType(SelectableText).evaluate()) (e.widget as SelectableText).data ?? ''];
          // ignore: avoid_print
          print('TIMEOUT DUMP: busy=${state.busy} progress="${state.progressText}" last bubbles=${chat.reversed.take(3).map((t) => t.replaceAll('\n', ' / ')).toList()} texts=${[for (final x in find.byType(Text).evaluate()) (x.widget as Text).data ?? ''].where((t) => t.contains('ZIP') || t.contains('xport')).toList()}');
          fail('timed out waiting for $what');
        }
        await tester.pump(const Duration(milliseconds: 400));
      }
    }

    // 1) 進到「網站建置」，用「新增網站」選語言（介面上的操作）
    await tester.tap(find.byIcon(Icons.web_outlined));
    await tester.pump(const Duration(milliseconds: 300));
    await waitFor(() => find.byType(CircularProgressIndicator).evaluate().isEmpty, 'the editor to load', seconds: 60);
    await tester.tap(find.byWidgetPredicate((w) => w is IconButton && w.tooltip == 'New site'));
    await tester.pump(const Duration(milliseconds: 600));
    await tester.tap(find.text(langs[lang]!).last);
    await tester.pump(const Duration(milliseconds: 600));
    await waitFor(() => !siteStore.current.initialized && siteStore.current.lang == lang, 'the new site to exist', seconds: 20);
    await waitFor(() => find.byType(CircularProgressIndicator).evaluate().isEmpty, 'the editor to reload', seconds: 60);
    expect(find.textContaining(tr('chat.hello.init').substring(0, 8)), findsOneWidget, reason: 'the chat opens by itself with the greeting in $lang');

    // 2) 送出一則訊息並等聊天處理完（送出鈕先變灰、再亮起）；回傳最後一組結果列
    Future<List<String>> say(String message) async {
      final box = find.byWidgetPredicate((w) => w is TextField && (w.decoration?.hintText == tr('chat.hint.edit') || w.decoration?.hintText == tr('chat.hint.init')));
      expect(box, findsOneWidget);
      final tf = tester.widget<TextField>(box);
      expect(tf.enabled, isTrue);
      tf.controller!.text = message; // 直接寫進輸入框的 controller（模擬鍵盤輸入不一定接得上）
      final sendBtn = find.ancestor(of: find.byIcon(Icons.send), matching: find.byType(IconButton));
      final sentAt = SiteChatPanel.messageCount.value;
      tester.widget<IconButton>(sendBtn).onPressed!.call();
      // 訊息送出 → 使用者訊息 + 助理回覆（共 +2）；回覆之後送出鈕要恢復可按
      await waitFor(() => SiteChatPanel.messageCount.value >= sentAt + 2, 'the chat to answer "$message"', seconds: 300);
      await waitFor(() => tester.widget<IconButton>(sendBtn).onPressed != null, 'the chat to be ready again after "$message"', seconds: 30);
      await tester.pump(const Duration(milliseconds: 800));
      final bubbles = [for (final e in find.byType(SelectableText).evaluate()) (e.widget as SelectableText).data ?? ''];
      final lines = [for (final e in find.byType(Text).evaluate()) (e.widget as Text).data ?? ''].where((t) => t.length > 3 && !t.contains('Pricing') && !t.contains('Site builder')).toList();
      // ignore: avoid_print
      print('CHAT [$lang] "$message"\n  assistant: ${bubbles.isEmpty ? '' : bubbles.last.replaceAll('\n', ' / ')}\n  results: $lines');
      return lines;
    }

    // 3) 第一則：描述店家 → 整頁、依業種的預約問題、品質檢查
    await say(description);
    expect(siteStore.current.initialized, isTrue);
    await waitFor(() => !sampleBrands.any(siteStore.current.project.contains), 'the sample clinic text to be replaced', seconds: 30);
    final afterInit = siteStore.current.project;
    expect(afterInit.contains('data-extra'), industry == 'other' ? isFalse : isTrue, reason: 'the $industry booking questions should be added');
    expect(find.textContaining(tr('chat.r.check.ok')), findsWidgets, reason: 'the cheat-sheet quality check should pass (shown in $lang)');
    expect(find.byWidgetPredicate((w) => w is TextField && w.decoration?.hintText == tr('chat.hint.edit')), findsOneWidget, reason: 'after setup the chat is in edit mode');

    // 4) 之後全部用聊天修改
    final m = edits[lang]!;
    await say(m[0]);
    String? primary() => RegExp(r'data-pal[^#]*(#[0-9a-fA-F]{6})').firstMatch(siteStore.current.project)?[1];
    await waitFor(() => primary() != null && primary() != '#7a6657', 'the main colour to change', seconds: 30);
    final rgb = int.parse(primary()!.substring(1), radix: 16);
    expect((rgb & 0xFF) > ((rgb >> 16) & 0xFF), isTrue, reason: 'the main colour ${primary()} should be blue');

    await say(m[1]);
    await waitFor(() => siteStore.current.project.contains('"display":"none"'), 'the floating buttons to be hidden', seconds: 30);

    await say(m[2]);
    expect(siteStore.current.mailto, 'hello@luna.example');

    final before = siteStore.current.project;
    await say(m[3]); // 價格調降：描述裡有價格的業種會看到數字變小
    final priceChanged = siteStore.current.project != before;
    await say(m[4]); // 加一題預約問題
    final questions = RegExp('data-extra').allMatches(siteStore.current.project).length;
    await say(techSay[lang]!);
    await waitFor(() => siteStore.current.project.contains('bk-tech'), 'the high-tech theme to be applied', seconds: 30);
    final faqBefore = RegExp(r'bk-qa').allMatches(siteStore.current.project).length;
    await say(faqSay[lang]!); // 本機模型重寫常見問題（regenerate）
    // ignore: avoid_print
    print('SOFT: faq blocks before=$faqBefore after=${RegExp(r'bk-qa').allMatches(siteStore.current.project).length}');
    // ignore: avoid_print
    print('SOFT: prices changed=$priceChanged, booking questions now=$questions (before edits: ${RegExp('data-extra').allMatches(afterInit).length})');

    // 5) 匯出 ZIP（介面上的按鈕）→ 到「下載」資料夾找檔案
    final slug = siteStore.current.slug;
    final downloads = await getDownloadsDirectory();
    final zipFile = File('${downloads!.path}/$slug.zip');
    if (zipFile.existsSync()) zipFile.deleteSync();
    // 視窗夠寬時是文字按鈕，窄時是圖示按鈕（提示文字都是 Export ZIP）
    final exportText = find.text('Export ZIP');
    await tester.tap(exportText.evaluate().isNotEmpty ? exportText.first : find.byWidgetPredicate((w) => w is IconButton && w.tooltip == 'Export ZIP'));
    await waitFor(() => zipFile.existsSync(), 'the ZIP to be written to Downloads', seconds: 30);
    await tester.pump(const Duration(seconds: 1));

    // 6) 解開 ZIP，檢查這是一個正確的網站
    final archive = ZipDecoder().decodeBytes(zipFile.readAsBytesSync());
    final names = archive.files.map((f) => f.name).toSet();
    expect(names, containsAll(['public/index.html', 'public/robots.txt', 'firebase.json', 'README.txt']));
    final html = utf8.decode(archive.findFile('public/index.html')!.content as List<int>);
    final firebase = jsonDecode(utf8.decode(archive.findFile('firebase.json')!.content as List<int>)) as Map;
    expect((firebase['hosting'] as Map)['public'], 'public');
    expect(html, startsWith('<!DOCTYPE html>'));
    expect(html, contains('<html lang="$lang">'));
    expect(html, contains('<title>'));
    expect(html, contains('property="og:title"'));
    expect(html, contains('<noscript>'));
    expect(html, contains('type="application/ld+json"'), reason: 'structured data for search engines');
    expect(html, contains('name="twitter:card"'));
    expect(html, contains('class="bk-skip"'));
    expect(html, contains('<main id="main">'));
    expect(html, contains('data-booking'));
    expect(html, contains('data-mailto="hello@luna.example"'));
    expect(html, contains('mailto:hello@luna.example'), reason: 'the noscript fallback should offer the booking email');
    expect(html, contains('display:none'), reason: 'the hidden floating buttons');
    expect(sampleBrands.any(html.contains), isFalse, reason: 'no sample clinic text should be left in the exported page');
    expect(html.contains('data-extra'), isTrue, reason: 'the industry booking questions should be in the exported form');
    expect(html, contains('/site-runtime.js'));
    expect(html, contains('<body class="bk-tech">'), reason: 'the high-tech theme should be exported');
    expect('data:image/svg+xml;base64,'.allMatches(html).length, greaterThanOrEqualTo(2), reason: 'both Mermaid flow charts should be in the page as images');
    expect(html, contains('class="bk-qa"'), reason: 'the FAQ should be exported');
    // 主色：匯出的 CSS 要含有新的主色（hex 或 rgb 寫法）
    final r = (rgb >> 16) & 0xFF, g = (rgb >> 8) & 0xFF, b = rgb & 0xFF;
    expect(html.contains(primary()!.toLowerCase()) || html.contains('rgb($r, $g, $b)') || html.contains('rgb($r,$g,$b)'), isTrue, reason: 'the exported CSS should use the new main colour ${primary()}');
    // ignore: avoid_print
    print('E2E OK: industry=$industry lang=$lang zip=${zipFile.lengthSync()} bytes, html=${html.length} chars, files=$names');
    zipFile.deleteSync();
  });
}
