import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:self_quote/engine/local_engine.dart';
import 'package:self_quote/engine/catalog.dart';
import 'package:self_quote/engine/downloader.dart';
import 'package:self_quote/engine/engine_info.dart';
import 'package:self_quote/engine/image_catalog.dart';
import 'package:self_quote/engine/image_engine.dart' show toJpeg;
import 'package:self_quote/engine/memory.dart';
import 'package:self_quote/engine/installer.dart';
import 'package:self_quote/engine/llama_client.dart';
import 'package:self_quote/site/site_actions.dart';
import 'package:self_quote/site/site_ai.dart';
import 'package:self_quote/site/chat_results.dart';
import 'package:self_quote/site/site_industry.dart';
import 'package:self_quote/site/site_init.dart';
import 'package:self_quote/site/site_planner.dart';
import 'package:self_quote/site/site_style.dart';
import 'package:self_quote/site/site_regen.dart';
import 'package:self_quote/site/google_form.dart';
import 'package:self_quote/site/booking_script.dart';
import 'package:self_quote/service_pricing/service_plan.dart';
import 'package:self_quote/site/site_model.dart';
import 'package:self_quote/site/platform/zip_export.dart';
import 'package:self_quote/site/market_research.dart';
import 'package:self_quote/i18n/i18n.dart';

void main() {
  regenTests();
  memoryAndImageTests();
  marketTests();
  seoTests();
  googleFormTests();
  bookingScriptTests();
  servicePricingTests();
  TestWidgetsFlutterBinding.ensureInitialized();
  HttpOverrides.global = null; // 測試環境預設擋網路；這裡只連本機的假伺服器

  test('engine asset follows OS and CPU architecture', () {
    expect(engineAssetFor(isMac: true, isWindows: false, version: '3.x on "macos_arm64"')!.name, 'llama-$llamaCppTag-bin-macos-arm64.tar.gz');
    expect(engineAssetFor(isMac: true, isWindows: false, version: '3.x on "macos_x64"')!.name, 'llama-$llamaCppTag-bin-macos-x64.tar.gz');
    final win = engineAssetFor(isMac: false, isWindows: true, version: '3.x on "windows_x64"')!;
    expect(win.name, 'llama-$llamaCppTag-bin-win-vulkan-x64.zip');
    expect(win.kind, ArchiveKind.zip);
    expect(win.url.host, 'github.com');
    expect(engineAssetFor(isMac: false, isWindows: false, version: 'linux_x64'), isNull);
  });

  test('every model option in the app maps to a GGUF download', () {
    for (final base in ['Qwen2.5-0.5B-Instruct', 'Qwen2.5-1.5B-Instruct', 'Qwen2.5-7B-Instruct', 'Llama-3.1-8B-Instruct', 'cpu:qwen2.5-0.5b', 'cpu:qwen2.5-1.5b']) {
      final m = modelSpecFor(base);
      expect(m, isNotNull, reason: base);
      expect(m!.url.host, 'huggingface.co');
      expect(m.file, endsWith('.gguf'));
    }
    expect(modelSpecFor('cpu:qwen2.5-0.5b')!.gpu, isFalse);
    expect(modelSpecFor('Qwen2.5-1.5B-Instruct')!.gpu, isTrue);
  });

  test('SSE lines yield content pieces and the done marker', () {
    expect(parseSseLine('data: {"choices":[{"delta":{"content":"Hel"}}]}'), 'Hel');
    expect(parseSseLine('data: {"choices":[{"delta":{}}]}'), isNull);
    expect(parseSseLine('data: [DONE]'), sseDone);
    expect(parseSseLine(': keep-alive'), isNull);
    expect(parseSseLine('data: not json'), isNull);
  });

  test('chat streams from an OpenAI-compatible server and sends a JSON-mode request', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    Map<String, dynamic>? seen;
    server.listen((req) async {
      if (req.uri.path == '/health') {
        req.response.statusCode = 200;
        await req.response.close();
        return;
      }
      seen = jsonDecode(await utf8.decodeStream(req)) as Map<String, dynamic>;
      req.response.headers.contentType = ContentType('text', 'event-stream');
      for (final piece in ['{"a":', '1}']) {
        req.response.write('data: ${jsonEncode({'choices': [{'delta': {'content': piece}}]})}\n\n');
      }
      req.response.write('data: [DONE]\n\n');
      await req.response.close();
    });
    final client = LlamaClient(Uri.parse('http://127.0.0.1:${server.port}'));
    expect(await client.healthy(), isTrue);
    var tokens = 0;
    final text = await client.chat('sys', 'user', onToken: (n) => tokens = n);
    expect(text, '{"a":1}');
    expect(tokens, 2);
    expect(seen!['stream'], isTrue);
    expect(seen!['response_format'], {'type': 'json_object'});
    expect((seen!['messages'] as List).first['role'], 'system');
    await server.close(force: true);
  });

  test('downloader writes the file, reports progress and resumes with Range', () async {
    final payload = List<int>.generate(100000, (i) => i % 251);
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    String? range;
    server.listen((req) async {
      range = req.headers.value(HttpHeaders.rangeHeader);
      final start = range == null ? 0 : int.parse(range!.split('=').last.replaceAll('-', ''));
      req.response.statusCode = range == null ? 200 : 206;
      req.response.contentLength = payload.length - start;
      req.response.add(payload.sublist(start));
      await req.response.close();
    });
    final dir = await Directory.systemTemp.createTemp('dl_test_');
    final dest = File('${dir.path}/m.gguf');
    // 先放一個「下載到一半」的 .part
    await File('${dest.path}.part').writeAsBytes(payload.sublist(0, 40000));
    var last = 0;
    await downloadFile(Uri.parse('http://127.0.0.1:${server.port}/m'), dest, (got, total) => last = got);
    expect(range, 'bytes=40000-');
    expect(await dest.readAsBytes(), payload);
    expect(last, payload.length);
    expect(await File('${dest.path}.part').exists(), isFalse);
    await server.close(force: true);
    await dir.delete(recursive: true);
  });

  test('extract keeps relative paths and symlinks, finds llama-server, blocks path traversal', () async {
    final tar = Archive()
      ..addFile(ArchiveFile.bytes('llama-x/llama-server', [1, 2, 3]))
      ..addFile(ArchiveFile.bytes('llama-x/libllama.0.dylib', [4]))
      ..addFile(ArchiveFile.symlink('llama-x/libllama.dylib', 'libllama.0.dylib'))
      ..addFile(ArchiveFile.bytes('../evil.txt', [9]));
    final gz = GZipEncoder().encode(TarEncoder().encode(tar));
    final dir = await Directory.systemTemp.createTemp('ex_test_');
    final archive = File('${dir.path}/a.tar.gz')..writeAsBytesSync(gz);
    final dest = Directory('${dir.path}/out');
    await extractEngine(archive, ArchiveKind.tarGz, dest);
    final bin = await findServerBinary(dest);
    expect(bin, isNotNull);
    expect(await bin!.readAsBytes(), [1, 2, 3]);
    expect(await File('${dest.path}/llama-x/libllama.0.dylib').exists(), isTrue);
    if (!Platform.isWindows) {
      expect(await Link('${dest.path}/llama-x/libllama.dylib').target(), 'libllama.0.dylib');
    }
    expect(await File('${dir.path}/evil.txt').exists(), isFalse);
    await dir.delete(recursive: true);
  });

  test('site text from the model is cleaned into template overrides', () {
    final o = siteOverrides('''Sure! {"brand":"Mia Nails","h1":"Beautiful nails\\nevery day","cta":"Book",
      "services":[{"name":"Gel","sub":"Gel Nails"},{"name":"Manicure","sub":"Manicure"}],
      "prices":[{"item":"Gel","price":"NT\$1,200"},{"item":"Manicure","price":"NT\$800"}],
      "hours":[{"day":"Tue–Sun","time":"11:00 – 20:00"},{"day":"Mon","time":"Closed"}],
      "address":"Taipei"}''')!;
    expect(o['brand'], 'Mia Nails');
    expect(o['svc'], [['Gel', 'Gel Nails'], ['Manicure', 'Manicure']]);
    expect(o['opts'], ['Gel', 'Manicure']);
    expect((o['price'] as List).length, 2);
    expect(o['addr'], 'Taipei');
    expect(siteOverrides('no json here'), isNull);
    expect(siteOverrides('{"unrelated":1}'), isNull);
  });

  test('junk from small models (placeholders, runaway digits) is dropped', () {
    final o = siteOverrides('''{"brand":"Mia Nails","brandSub":"..","lead":"english subtitle",
      "services":[{"name":"Gel","sub":"English subtitle"},{"name":"..","sub":".."},{"name":"Manicure","sub":"Manicure"}],
      "prices":[{"item":"Gel","price":"1000000000000000000000"},{"item":"Manicure","price":"NT\$800"}],
      "hours":[{"day":"Mon","time":"Closed"}]}''')!;
    expect(o['brand'], 'Mia Nails');
    expect(o.containsKey('brandSub'), isFalse);
    expect(o.containsKey('lead'), isFalse);
    expect(o['svc'], [['Gel', ''], ['Manicure', 'Manicure']]);
    expect(o['price'], [['Gel', ''], ['Manicure', 'NT\$800']]);
    expect(o.containsKey('hours'), isFalse); // 少於兩列就不覆寫，保留範本
  });

  test('a stale llama-server is killed through the pid file, and other programs are left alone', () async {
    if (Platform.isWindows) return;
    final dir = await Directory.systemTemp.createTemp('stale_test_');
    // 假的 llama-server：把 sleep 複製成這個名字，讓 ps 回報的程序名稱是 llama-server
    final fake = File('${dir.path}/llama-server');
    await File('/bin/sleep').copy(fake.path);
    await Process.run('chmod', ['+x', fake.path]);
    final stale = await Process.start(fake.path, ['60']);
    final other = await Process.start('/bin/sleep', ['60']);
    final e = LocalEngine(root: dir);

    await File('${dir.path}/server.pid').writeAsString('${stale.pid}');
    await e.killStale();
    expect(await stale.exitCode.timeout(const Duration(seconds: 5), onTimeout: () => -999), isNot(-999));
    expect(File('${dir.path}/server.pid').existsSync(), isFalse);

    await File('${dir.path}/server.pid').writeAsString('${other.pid}'); // pid 被別的程式用了
    await e.killStale();
    expect(await other.exitCode.timeout(const Duration(milliseconds: 800), onTimeout: () => -999), -999); // 還活著
    other.kill();
    await dir.delete(recursive: true);
  });

  group('storage location', () {
    test('a custom folder (for example on an external disk) becomes the engine root', () async {
      SharedPreferences.setMockInitialValues({LocalEngine.storageKey: '/Volumes/dev_disk/ai'});
      final e = LocalEngine();
      expect((await e.root()).path, '/Volumes/dev_disk/ai/pricing-ai-engine');
      expect(await e.customStorage(), '/Volumes/dev_disk/ai');
      await e.setCustomStorage(null);
      expect(await e.customStorage(), isNull);
    });

    test('a missing disk gives a clear error instead of creating folders under /Volumes', () async {
      SharedPreferences.setMockInitialValues({LocalEngine.storageKey: '/Volumes/__not_connected__/ai'});
      await expectLater(LocalEngine().prepare('Qwen2.5-0.5B-Instruct', (_, __) {}), throwsA(isA<StateError>()));
      expect(Directory('/Volumes/__not_connected__').existsSync(), isFalse);
    });
  });

  group('chat editing with predefined actions', () {
    final catalog = parseCatalog(jsonDecode(File('test/fixtures/catalog.json').readAsStringSync()) as List);
    final all = {for (final a in [...catalog, ...appActions]) a.name: a};

    test('every action has an example whose parameters match its own definition', () {
      for (final a in all.values) {
        expect(a.exampleSay, isNotEmpty, reason: '${a.name} needs an example');
        expect(a.exampleArgs['action'], a.name);
        final names = a.params.map((p) => p.name).toSet();
        for (final k in a.exampleArgs.keys.where((k) => k != 'action')) {
          expect(names, contains(k), reason: '${a.name}.$k');
        }
        for (final need in a.params.where((p) => p.required)) {
          expect(a.exampleArgs.containsKey(need.name), isTrue, reason: '${a.name} example lacks ${need.name}');
        }
      }
    });

    test('the router prompt lists every action and its examples use real names', () {
      final p = routeSystemPrompt(catalog);
      for (final a in all.values) {
        expect(p, contains('- ${a.name} — '), reason: a.name);
      }
      for (final m in RegExp(r'^\{"actions":\[(.*)\]\}$', multiLine: true).allMatches(p)) {
        for (final n in RegExp(r'"(\w+)"').allMatches(m.group(1)!)) {
          expect(all.containsKey(n.group(1)), isTrue, reason: n.group(1));
        }
      }
      final schema = routeSchema(catalog);
      final enumValues = (((schema['properties'] as Map)['actions'] as Map)['items'] as Map)['enum'] as List;
      expect(enumValues, containsAll(all.keys));
    });

    test('the fill prompt and schema describe exactly one action', () {
      final spec = all['set_row']!;
      final p = fillSystemPrompt(spec, Lang.ja);
      expect(p, contains('set_row(list: services|prices|hours|faq, row: row number or a word in the row, first?: text, second?: text)'));
      expect(p, contains('Japanese'));
      expect(p, contains('"row":"Monday"'));
      final item = (((fillSchema(spec)['properties'] as Map)['calls'] as Map)['items']) as Map;
      expect((item['properties'] as Map)['action'], {'const': 'set_row'});
      expect(((item['properties'] as Map)['list'] as Map)['enum'], ['services', 'prices', 'hours', 'faq']);
      expect(item['required'], ['action', 'list', 'row']);
      expect(item['additionalProperties'], isFalse);
    });

    test('planning: route first, then fill only the chosen actions, tolerate junk', () async {
      final asked = <String>[];
      Future<String> fake(String system, String user, Map<String, dynamic> schema) async {
        if (system.startsWith('You check')) {
          asked.add('check');
          return '{"asked": true}';
        }
        if (system.startsWith('You route')) {
          asked.add('route');
          return '{"actions":["set_row","scale_prices","fly","set_row"]}'; // 未知名稱與重複都要被濾掉
        }
        final name = RegExp(r'Action: (\w+)').firstMatch(system)!.group(1)!;
        asked.add(name);
        return name == 'set_row'
            ? '{"calls":[{"action":"set_row","list":"hours","row":"Monday","second":"Closed","extra":{"x":1}}]}'
            : '{"calls":[{"action":"scale_prices","percent":-10}]}';
      }

      final plan = await planChat(
        ask: fake,
        editorActions: catalog,
        snapshot: {'brand': 'Mia'},
        history: const [ChatTurn(true, 'hi')],
        message: 'closed on Mondays and 10% cheaper',
        siteLang: Lang.en,
      );
      expect(asked, ['route', 'check', 'set_row', 'scale_prices']); // 第一個動作不用確認
      expect(plan.routed, ['set_row', 'scale_prices']);
      expect(plan.actions, [
        {'action': 'set_row', 'list': 'hours', 'row': 'Monday', 'second': 'Closed'},
        {'action': 'scale_prices', 'percent': -10},
      ]);
    });

    test('actions the owner did not explicitly ask for are filtered out after routing', () async {
      final asked = <String>[];
      Future<String> fake(String system, String user, Map<String, dynamic> schema) async {
        if (system.startsWith('You route')) return '{"actions":["set_row","scale_prices","set_text"]}';
        if (system.startsWith('You check')) {
          final name = RegExp(r'Change: (\w+)').firstMatch(user)!.group(1)!;
          asked.add(name);
          return name == 'set_row' ? '{"asked": true}' : '{"asked": false}';
        }
        return '{"calls":[{"action":"set_row","list":"hours","row":"Saturday","second":"Closed"}]}';
      }

      final plan = await planChat(ask: fake, editorActions: catalog, snapshot: const {}, history: const [], message: 'closed on Saturdays', siteLang: Lang.en);
      expect(asked, ['scale_prices', 'set_text']); // set_row 是第一個，直接保留
      expect(plan.routed, ['set_row']);
      expect(plan.actions.single['action'], 'set_row');
    });

    test('a single routed action is trusted without a check', () async {
      var checks = 0;
      final plan = await planChat(
        ask: (s, u, c) async {
          if (s.startsWith('You check')) checks++;
          return s.startsWith('You route') ? '{"actions":["undo"]}' : '{}';
        },
        editorActions: catalog,
        snapshot: const {},
        history: const [],
        message: 'undo',
        siteLang: Lang.en,
      );
      expect(checks, 0);
      expect(plan.actions, [{'action': 'undo'}]);
    });

    test('actions without parameters need no second question, and an empty route changes nothing', () async {
      var calls = 0;
      Future<String> fake(String system, String user, Map<String, dynamic> schema) async {
        calls++;
        return system.startsWith('You route') ? '{"actions":["undo"]}' : '{}';
      }

      final plan = await planChat(ask: fake, editorActions: catalog, snapshot: const {}, history: const [], message: 'undo', siteLang: Lang.en);
      expect(plan.actions, [{'action': 'undo'}]);
      expect(calls, 1);
      final none = await planChat(ask: (s, u, c) async => '{"actions":[]}', editorActions: catalog, snapshot: const {}, history: const [], message: 'hi', siteLang: Lang.en);
      expect(none.actions, isEmpty);
    });

    test('emails and urls the owner did not type are rejected as invented', () async {
      Future<String> fake(String s, String u, Map<String, dynamic> c) async => s.startsWith('You check')
          ? '{"asked": true}'
          : s.startsWith('You route')
          ? '{"actions":["set_booking_email","set_line_link"]}'
          : s.contains('Action: set_booking_email')
              ? '{"calls":[{"action":"set_booking_email","email":"made.up@example.com"}]}'
              : '{"calls":[{"action":"set_line_link","url":"https://line.me/R/ti/p/@mia"}]}';
      final plan = await planChat(
        ask: fake,
        editorActions: catalog,
        snapshot: const {},
        history: const [],
        message: 'send bookings to my inbox and the LINE button to https://line.me/R/ti/p/@mia',
        siteLang: Lang.en,
      );
      expect(plan.actions, [{'action': 'set_line_link', 'url': 'https://line.me/R/ti/p/@mia'}]);
      expect(plan.notes.single, contains('made.up@example.com'));
    });

    test('a failed fill step is reported instead of guessed', () async {
      final plan = await planChat(
        ask: (s, u, c) async => s.startsWith('You route') ? '{"actions":["set_color"]}' : 'garbage',
        editorActions: catalog,
        snapshot: const {},
        history: const [],
        message: 'make it nicer',
        siteLang: Lang.en,
      );
      expect(plan.actions, isEmpty);
      expect(plan.notes.single, contains('set_color'));
    });

    test('the router and the fill step never see earlier conversation turns', () async {
      final seen = <String>[];
      Future<String> fake(String system, String user, Map<String, dynamic> schema) async {
        seen.add(user);
        if (system.startsWith('You route')) return '{"actions":["set_section"]}';
        return '{"calls":[{"action":"set_section","section":"float","visible":false}]}';
      }

      final plan = await planChat(
        ask: fake,
        editorActions: catalog,
        snapshot: {'brand': 'Mia'},
        history: const [ChatTurn(true, 'Use a blue colour'), ChatTurn(false, 'The main color has been changed to #0071eb.')],
        message: 'Hide the floating buttons',
        siteLang: Lang.en,
      );
      expect(plan.actions.single['action'], 'set_section');
      for (final u in seen) {
        expect(u, isNot(contains('blue colour')));
        expect(u, isNot(contains('main color has been changed')));
        expect(u, contains('Hide the floating buttons'));
      }
    });

    test('app-side actions are validated', () {
      expect(validateAppAction({'action': 'set_booking_email', 'email': 'me@example.com'}), isNull);
      expect(validateAppAction({'action': 'set_booking_email', 'email': 'not an email'}), isNotNull);
      expect(validateAppAction({'action': 'set_site_name', 'name': ''}), isNotNull);
      expect(validateAppAction({'action': 'set_site_name', 'name': 'Mia Nails'}), isNull);
      expect(isAppAction('set_color'), isFalse);
      expect(isAppAction('set_site_name'), isTrue);
    });

    test('the user prompt carries the current content and the recent conversation', () {
      final p = siteChatUserPrompt({'brand': 'Mia'}, [const ChatTurn(true, 'hi'), const ChatTurn(false, 'hello')], 'make it cheaper');
      expect(p, contains('"brand":"Mia"'));
      expect(p, contains('Owner: hi'));
      expect(p, contains('You: hello'));
      expect(p, endsWith('Owner: make it cheaper'));
    });
  });

  group('writing rules and text polish', () {
    test('Japanese text follows the cheat sheet: full-width punctuation, no stray spaces, one ellipsis, no stacked exclamations', () {
      expect(polishText('ja', '3 件のご予約を承ります!!! JavaScript を使用します, ありがとうございます.'), '3件のご予約を承ります！JavaScriptを使用します、ありがとうございます。');
      expect(polishText('ja', 'お待ちしています...'), 'お待ちしています…');
      expect(polishText('ja', '料金は１２００円です'), '料金は1,200円です');
      expect(polishText('ja', '営業時間 10:00 – 19:00'), '営業時間10:00 – 19:00'); // 数字の前の空白は取る。時刻の中身は変えない
    });

    test('prices get thousands separators only when a currency is attached', () {
      expect(polishText('en', 'Gel nails \$4500'), 'Gel nails \$4,500');
      expect(polishText('zh', '美甲 NT\$3800'), '美甲 NT\$3,800');
      expect(polishText('ja', '12000円'), '12,000円');
      expect(polishText('en', 'Open since 2005, call 0912345678'), 'Open since 2005, call 0912345678'); // 年份、電話不動
      expect(polishText('en', 'Hours 10:00 – 19:00'), 'Hours 10:00 – 19:00');
    });

    test('Chinese gets full-width punctuation between characters but keeps times and decimals', () {
      expect(polishText('zh', '歡迎預約,我們很期待!!!'), '歡迎預約，我們很期待！');
      expect(polishText('zh', '每天 10:00 開始，約 1.5 小時'), '每天 10:00 開始，約 1.5 小時');
    });

    test('other languages only lose repeated marks and extra spaces', () {
      expect(polishText('en', '  Book   now!!!  '), 'Book now!');
      expect(polishText('es', '¿Listo???'), '¿Listo?');
    });

    test('the prompt rules come from the cheat sheet and add language specific lines', () {
      expect(writingRules(Lang.en), contains('Button text says what happens'));
      expect(writingRules(Lang.en), isNot(contains('Japanese:')));
      expect(writingRules(Lang.ja), contains('です・ます調'));
      expect(writingRules(Lang.zh), contains('full-width punctuation'));
      expect(writingRules(Lang.es), contains('usted'));
    });
  });

  group('business types (reservation case studies)', () {
    final catalog = parseCatalog(jsonDecode(File('test/fixtures/catalog.json').readAsStringSync()) as List);
    final addField = catalog.firstWhere((a) => a.name == 'add_form_field');

    test('the five business types are recognised from Japanese, Chinese and English descriptions', () {
      expect(detectIndustry('渋谷にある小さなイタリアンレストランです。ランチとディナーの予約を受けたい'), 'restaurant');
      expect(detectIndustry('A small neighbourhood café with 12 seats'), 'restaurant');
      expect(detectIndustry('美容室です。スタイリストを指名して予約してほしい'), 'salon');
      expect(detectIndustry('台北的美甲沙龍，可以指定設計師'), 'salon');
      expect(detectIndustry('子ども向けのピアノ教室。体験レッスンと振替をネットで受けたい'), 'school');
      expect(detectIndustry('駅前のレンタルスペース。会議室を1時間単位で貸し出し'), 'space');
      expect(detectIndustry('歯科クリニックです。初診と再診の予約を受けたい'), 'clinic');
      expect(detectIndustry('我們是一間家庭診所'), 'clinic');
      expect(detectIndustry('A bakery that sells bread'), 'other');
    });

    test('every industry has needs for the prompt and form questions that the editor accepts', () {
      for (final id in industryIds.where((i) => i != 'other')) {
        expect(industryNeeds[id], isNotEmpty, reason: id);
        for (final lang in const ['en', 'ja', 'zh', 'pt', 'es']) {
          final fields = industryFieldActions(id, lang);
          expect(fields, isNotEmpty, reason: '$id/$lang');
          for (final f in fields) {
            expect(f['action'], 'add_form_field');
            final label = '${f['label']}';
            expect(label.isNotEmpty && label.length <= 30, isTrue, reason: '$id/$lang label "$label"');
            final kind = addField.params.firstWhere((p) => p.name == 'kind').values;
            expect(kind, contains(f['kind']));
            if (f['kind'] == 'select') {
              final opts = '${f['options']}'.split(RegExp('[,、，]')).map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
              expect(opts.length, inInclusiveRange(2, 6), reason: '$id/$lang options');
              expect('${f['options']}'.length <= 120, isTrue);
            }
            expect(f.keys.toSet().difference({'action', 'label', 'kind', 'options', 'required'}), isEmpty);
          }
        }
      }
      expect(industryFieldActions('other', 'ja'), isEmpty);
    });

    test('the content schema forces an industry and the generator uses the detected needs', () async {
      final schema = siteContentSchema();
      expect(((schema['properties'] as Map)['industry'] as Map)['enum'], industryIds);
      expect(schema['required'], contains('industry'));

      String? seenSystem;
      Future<String> fake(String system, String user, Map<String, dynamic> s) async {
        seenSystem = system;
        return jsonEncode({
          'industry': 'other', // 模型沒把握時用關鍵字偵測的結果
          'brand': 'ひまわり歯科', 'brandSub': 'HIMAWARI DENTAL', 'h1': 'やさしい歯医者です', 'h2': '初めての方も安心', 'lead': '予約はネットから。', 'cta': '予約する',
          'services': [{'name': '虫歯治療', 'sub': 'Cavity'}, {'name': '検診', 'sub': 'Check-up'}, {'name': 'ホワイトニング', 'sub': 'Whitening'}, {'name': '矯正', 'sub': 'Braces'}],
          'prices': [{'item': '初診', 'price': '3000円'}, {'item': '再診', 'price': '1500円'}, {'item': '検診', 'price': '4000円'}],
          'hours': [{'day': '月〜金', 'time': '9:00 – 18:00'}, {'day': '土曜', 'time': '9:00 – 13:00'}, {'day': '日曜・祝日', 'time': '休診'}],
          'address': '東京都〇〇区1-2-3',
        });
      }

      final o = (await generateSiteContent(ask: fake, siteLang: Lang.ja, description: '歯科クリニックです。初診は3000円です。初診と再診の予約を受けたい'))!;
      expect(seenSystem, contains('This business looks like a clinic'));
      expect(seenSystem, contains('です・ます調')); // 文案規則
      expect(o['industry'], 'clinic');
      expect((o['price'] as List).first, ['初診', '3,000円']); // 千分位
      expect((o['price'] as List)[1], ['再診', 'お問い合わせください']); // 屋主が言っていない 1500 は模型の創作なので取り除く
    });
  });

  group('prices only come from the owner', () {
    test('numbers are compared ignoring commas and full-width digits', () {
      expect(numbersIn('コースは4500円から、ランチ１２００円、NT dollars 600 / 1,200'), {4500, 1200, 600});
    });

    test('a price with a number the owner never said is replaced by an ask-us text in the page language', () {
      final c = <String, Object?>{
        'price': [
          ['Course', 'NT\$4,500'], // 屋主說過
          ['Lunch', 'NT\$800'], // 沒說過
          ['Tasting', 'Free'], // 沒有數字，保留
          ['Range', '600 – 4,500'], // 兩個數字都說過
        ],
      };
      final n = groundPrices(c, '4500元的套餐，另外有 600 元的單點', 'zh');
      expect(n, 1);
      expect(c['price'], [
        ['Course', 'NT\$4,500'],
        ['Lunch', '歡迎洽詢'],
        ['Tasting', 'Free'],
        ['Range', '600 – 4,500'],
      ]);
    });

    test('the system prompt has an example in the page language, so the model writes in that language', () {
      expect(siteSystemPrompt(Lang.ja), contains('"brand":"ウィロウ ヘアスタジオ"'));
      expect(siteSystemPrompt(Lang.ja, alt: true), contains('"brand":"パインストリート コーヒー"'));
      expect(siteSystemPrompt(Lang.ja, alt: true), isNot(contains('ウィロウ')));
      expect(siteSystemPrompt(Lang.ja), contains('お問い合わせください'));
      expect(siteSystemPrompt(Lang.zh), contains('"brand":"柳樹髮廊"'));
      expect(siteSystemPrompt(Lang.en), contains('"brand":"Willow Hair Studio"'));
      expect(siteSystemPrompt(Lang.pt), contains('Consulte-nos'));
      expect(siteSystemPrompt(Lang.es), contains('Consúltanos'));
    });
  });

  group('hours and examples are not made up or copied', () {
    test('a time the owner never said is replaced, times they did say are kept', () {
      final c = <String, Object?>{
        'hours': [
          ['月〜金', '11:30 – 14:00'], // 11時30分から14時と言った
          ['土曜', '09:00 – 16:00'], // 言っていない
          ['日曜', '休業'], // 時間なし
        ],
      };
      expect(groundHours(c, 'ランチは11時30分から14時まで', 'ja'), 2);
      expect(c['hours'], [
        ['月〜金', '11:30 – 14:00'],
        ['土曜', 'お問い合わせください'],
        ['日曜', 'お問い合わせください'], // 屋主は休みについて何も言っていない
      ]);
      final d = <String, Object?>{'hours': [['日曜', '休業'], ['Sunday', 'Closed']]};
      expect(groundHours(d, '火曜定休です', 'ja'), 0); // 休みに触れていれば保持
    });

    test('copying the format example is detected and retried once', () async {
      final ex = siteExample(Lang.ja);
      var calls = 0;
      Future<String> fake(String system, String user, Map<String, dynamic> s) async {
        calls++;
        final copied = calls == 1;
        return jsonEncode({
          'industry': 'salon',
          'brand': copied ? ex['brand'] : '名古屋ヘアサロン',
          'brandSub': 'NAGOYA HAIR', 'h1': copied ? ex['h1'] : '髪から、毎日を明るく。', 'h2': 'カットとカラー', 'lead': 'ご予約はネットから。', 'cta': '予約する',
          'services': [for (final n in ['カット', 'カラー', 'パーマ', 'トリートメント']) {'name': n, 'sub': 'x'}],
          'prices': [{'item': 'カット', 'price': 'お問い合わせください'}, {'item': 'カラー', 'price': 'お問い合わせください'}, {'item': 'パーマ', 'price': 'お問い合わせください'}],
          'hours': [{'day': '月〜金', 'time': '10:00 – 19:00'}, {'day': '土曜', 'time': '10:00 – 17:00'}, {'day': '火曜', 'time': '休業'}],
          'address': '名古屋市中区1-2-3',
        });
      }

      final o = (await generateSiteContent(ask: fake, siteLang: Lang.ja, description: '名古屋の美容室です。10時から19時、火曜定休'))!;
      expect(calls, 2);
      expect(o['brand'], '名古屋ヘアサロン');

      // 二度とも抄：別家店の名字を置くより、店名と標題は更新しない
      Future<String> stubborn(String system, String user, Map<String, dynamic> s) async => jsonEncode({
            'industry': 'salon', 'brand': ex['brand'], 'brandSub': 'x', 'h1': ex['h1'], 'h2': 'a', 'lead': 'b', 'cta': 'c',
            'services': [for (final n in ['カット', 'カラー', 'パーマ', 'トリートメント']) {'name': n, 'sub': 'x'}],
            'prices': [{'item': 'カット', 'price': 'お問い合わせください'}, {'item': 'カラー', 'price': 'お問い合わせください'}, {'item': 'パーマ', 'price': 'お問い合わせください'}],
            'hours': [{'day': '月〜金', 'time': '10:00 – 19:00'}, {'day': '土曜', 'time': '休業'}, {'day': '日曜', 'time': '休業'}],
            'address': 'x',
          });
      final p = (await generateSiteContent(ask: stubborn, siteLang: Lang.ja, description: '美容室です。10時から19時'))!;
      expect(p.containsKey('brand'), isFalse);
      expect(p.containsKey('h1'), isFalse);
      expect(p['svc'], isNotNull); // 其他內容照常使用
    });
  });

  group('entities and guards in code', () {
    final catalog = parseCatalog(jsonDecode(File('test/fixtures/catalog.json').readAsStringSync()) as List);

    Future<Plan> plan(String msg, List<String> routed, Map<String, Map<String, Object?>> fills) => planChat(
          ask: (system, user, schema) async {
            if (system.startsWith('You route')) return jsonEncode({'actions': routed});
            if (system.startsWith('You check')) return '{"asked": true}';
            final name = RegExp(r'Action: (\w+)').firstMatch(system)!.group(1)!;
            return jsonEncode({'calls': [fills[name]]});
          },
          editorActions: catalog,
          snapshot: const {},
          history: const [],
          message: msg,
          siteLang: Lang.ja,
        );

    test('a fraction becomes the percent the owner wrote', () async {
      final p = await plan('料金をすべて15%安くしてください', ['scale_prices'], {'scale_prices': {'action': 'scale_prices', 'percent': -0.15}});
      expect(p.actions.single['percent'], -15);
      final q = await plan('Make it 20% more expensive', ['scale_prices'], {'scale_prices': {'action': 'scale_prices', 'percent': 0.2}});
      expect(q.actions.single['percent'], 20);
      final r = await plan('cheaper', ['scale_prices'], {'scale_prices': {'action': 'scale_prices', 'percent': -0.1}});
      expect(r.actions.single['percent'], -10);
    });

    test('an email address in the message means the booking email, and a missing URL rules out LINE and picture actions', () async {
      final p = await plan('予約の通知はhello@luna.exampleに送ってください', ['set_line_link'], {'set_booking_email': {'action': 'set_booking_email', 'email': 'hello@luna.example'}});
      expect(p.routed, ['set_booking_email']);
      expect(p.actions.single, {'action': 'set_booking_email', 'email': 'hello@luna.example'});
      final q = await plan('隱藏浮動按鈕', ['set_line_link', 'set_section'], {'set_section': {'action': 'set_section', 'section': 'float', 'visible': false}});
      expect(q.routed, ['set_section']);
    });

    test('view-only actions need a matching word in the message', () async {
      final fills = {'set_section': {'action': 'set_section', 'section': 'float', 'visible': false}, 'set_device': {'action': 'set_device', 'device': 'desktop'}};
      final a = await plan('Oculta los botones flotantes', ['set_device', 'set_section'], fills);
      expect(a.routed, ['set_section']);
      final b = await plan('スマホでの見た目を確認したい', ['set_device'], fills);
      expect(b.routed, ['set_device']);
      final c = await plan('浮かんでいるボタンを非表示にしてください', ['set_device'], fills);
      expect(c.routed, isEmpty);
    });
  });

  group('chat result lines are localized', () {
    final samples = <Map<String, Object?>, String>{
      {'action': 'set_text', 'target': 'h1', 'text': 'Hello'}: 'h1 → "Hello"',
      {'action': 'set_row', 'list': 'hours', 'row': 'Monday', 'second': 'Closed'}: 'hours row 2',
      {'action': 'add_row', 'list': 'prices', 'first': 'Facial', 'second': '\$60'}: 'prices + Facial',
      {'action': 'remove_row', 'list': 'services', 'row': 1}: 'services − X',
      {'action': 'scale_prices', 'percent': -15}: 'prices -15%',
      {'action': 'set_color', 'color': 'blue'}: 'main colour → #2f6fb3',
      {'action': 'set_background', 'target': 'hero', 'color': 'black'}: 'hero background → #2b2b2b',
      {'action': 'set_hero_image', 'url': 'https://a.example/x.jpg'}: 'hero picture set',
      {'action': 'set_line_link', 'url': 'https://line.me/R/ti/p/@mia'}: 'LINE button → x',
      {'action': 'set_section', 'section': 'float', 'visible': false}: 'float hidden',
      {'action': 'set_section', 'section': 'price', 'visible': true}: 'price shown',
      {'action': 'show', 'section': 'hours'}: 'showing hours',
      {'action': 'set_device', 'device': 'mobile'}: 'preview: mobile',
      {'action': 'undo'}: 'undone',
      {'action': 'add_form_field', 'label': 'Allergies', 'kind': 'text'}: 'booking form + Allergies',
      {'action': 'remove_form_field', 'label': 'Allergies'}: 'booking form − Allergies',
      {'action': 'set_site_name', 'name': 'Luna'}: '',
      {'action': 'set_booking_email', 'email': 'a@b.co'}: '',
      {'action': 'check_quality'}: '2 problem(s) found, 1 fixed automatically, 1 left',
    };

    test('every action has a line in every language, with its values filled in and no placeholders left', () {
      final seen = <String, Set<String>>{};
      for (final l in Lang.values) {
        I18n.lang = l;
        samples.forEach((action, english) {
          final text = localizedResult(action, true, english);
          expect(text, isNotEmpty, reason: '${action['action']}/${l.code}');
          expect(text.contains('{') || text.contains('}'), isFalse, reason: '${action['action']}/${l.code}: $text');
          (seen['${action['action']}${action['visible']}'] ??= {}).add(text);
        });
      }
      I18n.lang = Lang.en;
      // 每個動作在 5 種語言裡的文字不會全部一樣（代表真的有翻譯，不是都落回英文）
      seen.forEach((k, v) => expect(v.length, greaterThan(1), reason: k));
    });

    test('values from the action appear in the line, and the colour shown is the one actually applied', () {
      I18n.lang = Lang.ja;
      expect(localizedResult({'action': 'scale_prices', 'percent': -15}, true, 'prices -15%'), 'すべての料金を-15%変更しました');
      expect(localizedResult({'action': 'scale_prices', 'percent': 10}, true, 'prices +10%'), 'すべての料金を+10%変更しました');
      expect(localizedResult({'action': 'set_color', 'color': '#007bff'}, true, 'main colour → #0071eb (#007bff was too light for white button text, so it was darkened to stay readable)'), contains('#0071eb'));
      expect(localizedResult({'action': 'set_color', 'color': '#007bff'}, true, 'main colour → #0071eb (… darkened …)'), contains('濃く'));
      expect(localizedResult({'action': 'set_booking_email', 'email': 'a@b.co'}, true, ''), contains('a@b.co'));
      expect(localizedResult({'action': 'set_section', 'section': 'float', 'visible': false}, true, 'float hidden'), '非表示にしました：浮かぶボタン');
      I18n.lang = Lang.zh;
      expect(localizedResult({'action': 'check_quality'}, true, '2 problem(s) found, 1 fixed automatically, 1 left'), '發現 2 個問題，已自動修正 1 個，剩下 1 個');
      expect(localizedResult({'action': 'check_quality'}, true, 'No problems found'), '沒有發現問題');
      I18n.lang = Lang.en;
      expect(localizedResult({'action': 'set_row', 'list': 'hours'}, false, 'no row matches "Monday" in hours'), 'Could not do that: no row matches "Monday" in hours');
    });

    test('rows pair with the sent actions in order, and check details stay as plain lines', () {
      I18n.lang = Lang.es;
      final lines = localizedRows(
        [
          {'action': 'add_form_field', 'label': 'Alergias', 'kind': 'text'},
          {'action': 'check_quality'},
        ],
        [
          {'action': 'add_form_field', 'ok': true, 'message': 'booking form + Alergias'},
          {'action': 'check_quality', 'ok': true, 'message': '1 problem(s) found, 0 fixed automatically, 1 left'},
          {'action': 'check_quality', 'ok': false, 'message': 'Low contrast 2.2:1', 'detail': true},
        ],
      );
      I18n.lang = Lang.en;
      expect(lines.map((l) => l.text).toList(), ['Pregunta de reserva añadida: Alergias', '1 problema(s) encontrado(s), 0 corregido(s) automáticamente, 1 restante(s)', 'Low contrast 2.2:1']);
      expect(lines.map((l) => l.ok).toList(), [true, true, false]);
    });
  });
}

void regenTests() {
  group('regenerate parts', () {
    test('headline, faq and flow answers become editor actions', () async {
      Future<String> fake(String s, String u, Map<String, dynamic> schema) async {
        final props = (schema['properties'] as Map).keys;
        if (props.contains('h1')) return '{"h1":"新しい見出し","h2":"やさしい二つ目","lead":"1分で予約","cta":"予約する"}';
        if (props.contains('faq')) return '{"faq":[{"q":"駐車場は？","a":"あります。"},{"q":"支払いは？","a":"現金とカードです。"}]}';
        return '{"steps":["選ぶ","日時","入力","確認"]}';
      }

      final snap = {'brand': '桜', 'h1': 'x', 'lead': 'y', 'services': [['カット', '']]};
      final h = await regenerateActions(ask: fake, siteLang: Lang.ja, snapshot: snap, part: 'headline');
      expect(h.map((a) => a['target']), ['h1', 'h2', 'lead', 'cta']);
      final f = await regenerateActions(ask: fake, siteLang: Lang.ja, snapshot: snap, part: 'faq');
      expect(f.single['action'], 'replace_list');
      expect('${f.single['rows']}', contains('駐車場は？|あります。'));
      final s = await regenerateActions(ask: fake, siteLang: Lang.ja, snapshot: snap, part: 'booking_flow');
      expect(s.single, {'action': 'set_flow', 'which': 'booking', 'steps': '選ぶ; 日時; 入力; 確認'});
      expect(await regenerateActions(ask: fake, siteLang: Lang.ja, snapshot: snap, part: 'nope'), isEmpty);
    });
    test('every industry has service steps in every language', () {
      for (final i in industryIds.where((x) => x != 'other')) {
        for (final l in ['en', 'ja', 'zh', 'pt', 'es']) {
          expect(industryServiceSteps(i, l)!.length, greaterThanOrEqualTo(4), reason: '$i/$l');
        }
      }
      expect(industryServiceSteps('other', 'ja'), isNull);
    });
  });
}

void memoryAndImageTests() {
  group('memory budget', () {
    test('vm_stat output becomes available MB', () {
      const out = '''Mach Virtual Memory Statistics: (page size of 16384 bytes)
Pages free:                               10000.
Pages active:                             90000.
Pages inactive:                           20000.
Pages speculative:                         5000.
Pages purgeable:                           1000.''';
      expect(parseVmStatAvailableMB(out), ((10000 + 20000 + 5000 + 1000) * 16384 / 1048576).round());
      expect(parseVmStatAvailableMB('nothing'), isNull);
    });
    test('windows memory numbers are KB', () {
      final m = parseWindowsMem('16777216 4194304\r\n')!;
      expect((m.totalMB, m.availableMB), (16384, 4096));
    });
    test('a model over the budget is refused, one over the free memory only warns', () {
      const mem = MemInfo(8192, 3000);
      expect(memVerdict(needMB: 7000, mem: mem, limitPct: 75), MemVerdict.tooBig); // 預算 6144
      expect(memVerdict(needMB: 4000, mem: mem, limitPct: 75), MemVerdict.tight);
      expect(memVerdict(needMB: 2000, mem: mem, limitPct: 75), MemVerdict.fits);
      expect(memVerdict(needMB: 7000, mem: mem, limitPct: 95), MemVerdict.tight);
    });
    test('SDXL does not fit an 8 GB machine at the default limit, SD 1.5 does', () {
      final xl = imageModelFor('sdxl')!, sd = imageModelFor('sd15')!;
      expect(fitsBudget(imageNeedMB(xl.sizeMB), const MemoryReading(8192, 3000), 75), isTrue); // ≈5.4 GB < 6 GB 預算
      expect(fitsBudget(imageNeedMB(imageModelFor('sdxl-q8')!.sizeMB), const MemoryReading(8192, 3000), 60), isFalse);
      expect(fitsBudget(imageNeedMB(sd.sizeMB), const MemoryReading(8192, 3000), 60), isTrue);
    });
    test('only one heavy job runs at a time', () async {
      final order = <String>[];
      final a = heavyLock.run(() async {
        order.add('a1');
        await Future<void>.delayed(const Duration(milliseconds: 30));
        order.add('a2');
      });
      final b = heavyLock.run(() async => order.add('b'));
      await Future.wait([a, b]);
      expect(order, ['a1', 'a2', 'b']);
    });
  });

  group('picture engine', () {
    test('asset choice per platform', () {
      expect(sdAssetFor(isMac: true, isWindows: false, version: '3.12 (macos_arm64)')!.name, contains('Darwin-macOS'));
      expect(sdAssetFor(isMac: true, isWindows: false, version: '3.12 (macos_x64)'), isNull);
      expect(sdAssetFor(isMac: false, isWindows: true, version: '3.12 (windows_x64)')!.name, contains('win-vulkan-x64'));
      expect(sdAssetFor(isMac: false, isWindows: false, version: ''), isNull);
    });
    test('model files and licenses are the pinned catalog', () {
      expect(imageModels.map((m) => m.id), ['sd15', 'sd21', 'sdxl', 'sdxl-q8']);
      expect(imageModels.every((m) => m.url.host == 'huggingface.co' && m.file.endsWith('.gguf') && m.license.contains('OpenRAIL')), isTrue);
      expect(imageModelFor('nope'), isNull);
    });
    test('png becomes a much smaller jpeg', () {
      final src = img.Image(width: 256, height: 160);
      final rnd = Random(7); // 照片般的雜訊：PNG 很難壓，JPEG 小得多
      for (final p in src) {
        p
          ..r = 100 + rnd.nextInt(60)
          ..g = 90 + rnd.nextInt(60)
          ..b = 80 + rnd.nextInt(60);
      }
      final png = Uint8List.fromList(img.encodePng(src));
      final jpg = toJpeg(png);
      expect(jpg.take(2), [0xFF, 0xD8]);
      expect(jpg.length, lessThan(png.length));
      expect(() => toJpeg(Uint8List.fromList([1, 2, 3])), throwsStateError);
    });
  });

  group('chat guards for the new actions', () {
    test('generate_image and regenerate need matching words, and a web address means use that picture', () async {
      // 模型一律把三個動作都選上；程式依訊息字眼過濾
      Future<String> ask(String s, String u, Map<String, dynamic> schema) async {
        if (schema['properties'] is Map && (schema['properties'] as Map).containsKey('actions')) return '{"actions":["generate_image","regenerate","set_theme","set_background"]}';
        if (u.contains('"generate_image"')) return '{"calls":[{"action":"generate_image","prompt":"a cafe"}]}';
        if (u.contains('"regenerate"')) return '{"calls":[{"action":"regenerate","part":"faq"}]}';
        if (u.contains('"set_background"')) return '{"calls":[{"action":"set_background","target":"hero","color":"pink"}]}';
        if (u.contains('"set_theme"')) return '{"calls":[{"action":"set_theme","theme":"tech"}]}';
        return '{"asked":true}';
      }

      final catalog = parseCatalog(jsonDecode(File('test/fixtures/catalog.json').readAsStringSync()) as List);
      Future<List<String>> routed(String msg) async => (await planChat(ask: ask, editorActions: catalog, snapshot: const {'brand': 'x'}, history: const [], message: msg, siteLang: Lang.en)).routed;
      expect(await routed('Make the whole site dark'), ['set_theme']);
      expect(await routed('Make the background pale pink'), contains('set_background'));
      expect(await routed('Make a picture of a cafe and rewrite the FAQ'), containsAll(['generate_image', 'regenerate']));
      expect(await routed('Use https://example.com/a.jpg as the picture'), isNot(contains('generate_image')));
    });
  });
}

void marketTests() {
  group('market research', () {
    test('Bing result links are decoded and snippets kept', () {
      final real = base64Url.encode(utf8.encode('https://example.com/menu?a=1')).replaceAll('=', '');
      final html = '<ol><li class="b_algo"><h2><a href="https://www.bing.com/ck/a?!&amp;&amp;p=x&amp;u=a1$real&amp;ntb=1">カット &amp; カラー 料金</a></h2><div class="b_caption"><p>カット 4,500円 カラー 7,000円</p></div></li></ol>';
      final hits = parseBing(html);
      expect(hits.single.url, 'https://example.com/menu?a=1');
      expect(hits.single.title, 'カット & カラー 料金');
      expect(hits.single.snippet, contains('4,500円'));
    });
    test('page text keeps only lines with prices', () {
      final text = htmlToText('<style>x{}</style><p>Welcome</p><li>Cut ¥4,500</li><li>About us</li><script>var a=1</script>');
      expect(priceExcerpts(text), 'Cut ¥4,500\n');
    });
    test('prices must appear in the excerpts, others become ask-us', () async {
      Future<String> fake(String s, String u, Map<String, dynamic> schema) async =>
          '{"rows":[{"name":"カット","sub":"Cut","price":"4,500円"},{"name":"カラー","sub":"Colour","price":"9,999円"},{"name":"パーマ","sub":"Perm","price":""}]}';
      final rows = await buildPriceTable(ask: fake, lang: Lang.ja, business: '美容室', area: '渋谷', evidence: 'カット 4,500円 カラー 7,000円');
      expect(rows.map((r) => r.price), ['4,500円', askUs['ja'], askUs['ja']]);
    });
    test('the table becomes replace_list actions for services and prices', () {
      final a = siteActionsFor([PriceRow('カット', 'Cut', '4,500円'), PriceRow('カラー', 'Colour', '7,000円')]);
      expect(a.map((x) => x['list']), ['services', 'prices']);
      expect(a[0]['rows'], 'カット|Cut; カラー|Colour');
      expect(a[1]['rows'], 'カット|4,500円; カラー|7,000円');
      expect(siteActionsFor([PriceRow('カット', '', '1')]).map((x) => x['list']), ['prices']); // 服務至少要 2 列
    });
    test('queries are localized', () {
      expect(marketQueries('美容室', '渋谷', 'ja').first, contains('料金'));
      expect(marketQueries('salon', '', 'en').first, 'salon prices cost');
    });
  });
}

void seoTests() {
  group('SEO files', () {
    test('robots.txt always, sitemap.xml only with a public address', () {
      expect(seoFiles('').keys, ['public/robots.txt']);
      expect(seoFiles('')['public/robots.txt'], isNot(contains('Sitemap')));
      final f = seoFiles('https://example.com');
      expect(f['public/robots.txt'], contains('Sitemap: https://example.com/sitemap.xml'));
      expect(f['public/sitemap.xml'], contains('<loc>https://example.com/</loc>'));
    });
    test('the ZIP carries them, and the public address falls back to the Firebase site', () {
      final names = ZipDecoder().decodeBytes(buildZip('<html></html>', url: 'https://example.com/')).files.map((f) => f.name).toSet();
      expect(names, containsAll(['public/index.html', 'public/robots.txt', 'public/sitemap.xml', 'firebase.json']));
      expect(Site(name: 'a', slug: 'abc', lang: 'en', deploySite: 'my-shop').effectiveUrl, 'https://my-shop.web.app/');
      expect(Site(name: 'a', slug: 'abc', lang: 'en', siteUrl: 'https://x.com').effectiveUrl, 'https://x.com/');
      expect(Site(name: 'a', slug: 'abc', lang: 'en').effectiveUrl, '');
    });
  });
}

void googleFormTests() {
  group('Google Form', () {
    final html = File('test/fixtures/gform.html').readAsStringSync();
    const page = 'https://docs.google.com/forms/d/e/1FAIpQLSdemo/viewform?usp=sf_link';

    test('questions, types, options and required flags are read from the page', () {
      final f = parseGoogleForm(html, page);
      expect(f.action, 'https://docs.google.com/forms/d/e/1FAIpQLSdemo/formResponse');
      expect(f.title, 'Salon booking');
      expect(f.fields.map((x) => x.entry), ['entry.1000001', 'entry.1000002', 'entry.1000003', 'entry.1000004', 'entry.1000005', 'entry.1000006', 'entry.1000007']);
      expect(f.fields.map((x) => x.kind), ['text', 'text', 'radio', 'checkbox', 'paragraph', 'date', 'time']);
      expect(f.fields.map((x) => x.required), [true, false, true, false, false, true, true]);
      expect(f.fields[2].options, ['Cut', 'Colour', 'Perm']);
      expect(f.requiredCount, 4);
      expect(f.pages, 2); // 一個「セクション」→ 2 頁
      expect(f.skipped, ['Photo']); // 任意の「ファイルアップロード」は対応外として除く
    });
    test('a required unsupported question cannot work, a private or odd page gives a clear reason', () {
      final bad = html.replaceFirst('[1000008, null, 0]', '[1000008, null, 1]');
      expect(() => parseGoogleForm(bad, page), throwsA(isA<GoogleFormException>().having((e) => e.code, 'code', 'unsupported_required')));
      expect(() => parseGoogleForm('<html>accounts.google.com/ServiceLogin</html>', page), throwsA(isA<GoogleFormException>().having((e) => e.code, 'code', 'not_public')));
      expect(() => parseGoogleForm('<html>nothing</html>', page), throwsA(isA<GoogleFormException>().having((e) => e.code, 'code', 'unreadable')));
    });
    test('only public links are accepted; edit links are not', () {
      expect(looksLikeGoogleForm('https://forms.gle/abcDEF123'), isTrue);
      expect(looksLikeGoogleForm('https://docs.google.com/forms/d/e/1FAIpQLSx/viewform'), isTrue);
      expect(looksLikeGoogleForm('https://docs.google.com/forms/d/1AbC/edit'), isFalse);
      expect(formResponseUrl('https://docs.google.com/forms/d/e/1FAIpQLSx/viewform?usp=pp_url'), 'https://docs.google.com/forms/d/e/1FAIpQLSx/formResponse');
      expect(() => formResponseUrl('https://example.com'), throwsA(isA<GoogleFormException>()));
    });
    test('the checklist text lists each question with its type and required flag; no template link unless configured', () {
      final text = suggestedAsText(
        const [SuggestedQuestion('Name', 'text', true), SuggestedQuestion('Menu', 'radio', true, ['Cut', 'Colour']), SuggestedQuestion('Notes', 'paragraph', false)],
        (k) => k.toUpperCase(),
        'REQ',
      );
      expect(text, 'Name — TEXT — REQ\nMenu — RADIO (Cut / Colour) — REQ\nNotes — PARAGRAPH');
      expect(googleFormCreateUrl, startsWith('https://docs.google.com/forms/'));
      expect(bookingFormTemplateCopyUrl, isNull);
    });
    test('a Google Form link in the chat goes straight to connect_google_form, untouched', () async {
      Future<String> ask(String s, String u, Map<String, dynamic> schema) async => '{"actions":["set_line_link"]}';
      final catalog = parseCatalog(jsonDecode(File('test/fixtures/catalog.json').readAsStringSync()) as List);
      final p = await planChat(ask: ask, editorActions: catalog, snapshot: const {'brand': 'x'}, history: const [], message: 'Bookings go here https://forms.gle/abcDEF123 please', siteLang: Lang.en);
      expect(p.actions, [
        {'action': 'connect_google_form', 'url': 'https://forms.gle/abcDEF123'}
      ]);
    });
  });
}

void bookingScriptTests() {
  group('Apps Script generator', () {
    final qs = const [
      SuggestedQuestion('Name "x"', 'text', true),
      SuggestedQuestion('Email', 'text', true),
      SuggestedQuestion('Menu', 'radio', true, ['Cut', 'Colour']),
      SuggestedQuestion('Date', 'date', true),
      SuggestedQuestion('Time', 'time', true),
    ];
    test('embeds the questions as JSON, makes only free/busy public, and creates one event per answer', () {
      final s = bookingScript(qs, const BookingScriptOptions(siteName: 'Luna Spa', confirmation: 'Thanks', durationMinutes: 45, inviteCustomer: true));
      final json = RegExp(r'const CONFIG = (\{.*?\n\});', dotAll: true).firstMatch(s)![1]!;
      final cfg = jsonDecode(json) as Map;
      expect(cfg['durationMinutes'], 45);
      expect(cfg['inviteCustomer'], isTrue);
      expect((cfg['fields'] as List).map((f) => (f as Map)['label']), ['Name "x"', 'Email', 'Menu', 'Date', 'Time']);
      expect(s, contains("role: 'freeBusyReader'"));
      expect(s, isNot(contains('UrlFetchApp'))); // 直接 REST を呼ぶと Calendar API の有効化が必要になる
      expect(s, contains('Calendar.Acl.insert'));
      expect(s, contains('CalendarApp.createCalendar')); // 専用カレンダーを新規作成（個人のカレンダーは使わない）
      expect(s, contains('createEvent'));
      expect(s, contains('PASTE THIS INTO PRICING AI'));
      expect(s, isNot(contains('getDefaultCalendar')));
    });
    test('a site name with comment characters cannot break out of the header comment', () {
      final s = bookingScript(qs, const BookingScriptOptions(siteName: 'A */ evil() /* B', confirmation: 'x'));
      expect(s.split('\n').first, isNot(contains('*/')));
    });
    test('the manifest block, pasted after the first { of a manifest, is valid JSON and enables the Calendar service', () {
      final merged = jsonDecode('{\n$bookingManifestSnippet\n  "timeZone": "Asia/Taipei",\n  "runtimeVersion": "V8"\n}') as Map;
      expect((merged['dependencies'] as Map)['enabledAdvancedServices'], [
        {'userSymbol': 'Calendar', 'serviceId': 'calendar', 'version': 'v3'}
      ]);
      expect(merged['timeZone'], 'Asia/Taipei'); // 既存の設定は消えない
    });
    test('the pasted log line gives back the form link and the calendar id', () {
      const line = 'PASTE THIS INTO PRICING AI: https://docs.google.com/forms/d/e/1FAIpQLSabc/viewform calendar:abc123@group.calendar.google.com';
      expect(extractFormLink(line), 'https://docs.google.com/forms/d/e/1FAIpQLSabc/viewform');
      expect(extractCalendarId(line), 'abc123@group.calendar.google.com');
      expect(extractCalendarId('https://forms.gle/x'), isNull);
    });
  });
}

void servicePricingTests() {
  group('service pricing', () {
    final plan = ServicePlan(
      laborPerHour: 400,
      fixedPerMonth: 30000,
      billableHoursPerMonth: 80,
      marginPct: 30,
      taxPct: 5,
      taxIncluded: true,
      roundTo: 10,
      rows: [ServiceRow('Haircut', 60, materials: 100), ServiceRow('Colour', 120, materials: 600)],
    );
    test('cost = labor + overhead share + materials, price reaches the target margin, rounded up and tax-included', () {
      final s = computeServices(plan);
      expect(s.overheadPerHour, 375);
      final cut = s.rows[0];
      expect((cut.labor, cut.overhead, cut.materials, cut.cost), (400, 375, 100, 875));
      expect(cut.shownPrice, 1320); // 875 / 0.7 = 1250 → ×1.05 = 1312.5 → 切り上げ 1320
      expect(cut.priceExTax, closeTo(1257.14, 0.01));
      expect(cut.marginPct, greaterThanOrEqualTo(30)); // 丸めは切り上げなので目標を下回らない
    });
    test('a price you set yourself is kept and its real margin is shown', () {
      final p = ServicePlan(rows: [ServiceRow('Cut', 60, materials: 100, priceOverride: 800)], taxIncluded: false, taxPct: 0);
      final r = computeServices(p).rows.single;
      expect((r.shownPrice, r.overridden), (800, true));
      expect(r.profit, lessThan(0)); // 原価 875 より安い → 赤字が見える
    });
    test('break-even hours cover the fixed costs; prices below cost never break even', () {
      final s = computeServices(plan);
      expect(s.breakEvenHours, isNotNull);
      expect(s.breakEvenHours!, lessThan(plan.billableHoursPerMonth)); // 目標利益率があるので、見込み時間より少なくても固定費を回収できる
      expect(s.monthlyProfitAtPlan, greaterThan(0));
      final cheap = ServicePlan(rows: [ServiceRow('Cut', 60, priceOverride: 100)], taxIncluded: false, taxPct: 0);
      expect(computeServices(cheap).breakEvenHours, isNull);
    });
    test('money formatting and currency defaults', () {
      expect(formatMoney(1234567, 'TWD'), 'NT\$1,234,567');
      expect(formatMoney(9.5, 'USD'), '\$9.50');
      expect(formatMoney(4500, 'JPY'), '¥4,500');
      expect(formatMoney(1110.86, 'TWD'), 'NT\$1,111'); // 台幣・円は小数を出さない
      expect(currencyDefaults['JPY']!.roundTo, 100);
    });
    test('all offered currencies have symbols and defaults; minutes are written in the site language; presets switch language only when untouched', () {
      for (final c in ['TWD', 'JPY', 'USD', 'EUR', 'GBP', 'CNY', 'HKD', 'KRW', 'SGD', 'AUD', 'CAD', 'MXN', 'BRL', 'THB']) {
        expect(currencyDefaults.containsKey(c), isTrue, reason: c);
        expect(formatMoney(1234, c), isNot(startsWith('1')), reason: '$c needs a symbol'); // 記号が付く
      }
      expect(formatMoney(1234.5, 'KRW'), '₩1,235');
      expect(minutesText(60, 'ja'), '60分');
      expect(minutesText(45, 'zh'), '45 分鐘');
      expect(minutesText(30, 'xx'), '30 min');
      expect(rowsAreUntouchedPresets(presetRows('salon', 'ja')), isTrue);
      final edited = presetRows('salon', 'ja')..first.materials = 50;
      expect(rowsAreUntouchedPresets(edited), isFalse);
      expect(rowsAreUntouchedPresets([ServiceRow('My own service', 30)]), isFalse);
    });
    test('every industry has presets in every language, and the plan survives a save and load', () {
      for (final i in ['salon', 'restaurant', 'school', 'space', 'clinic', 'other']) {
        for (final l in ['en', 'ja', 'zh', 'pt', 'es']) {
          expect(presetRows(i, l), isNotEmpty, reason: '$i/$l');
        }
      }
      final back = ServicePlan.decode(plan.encode())!;
      expect(back.rows.map((r) => (r.name, r.minutes, r.materials)), [('Haircut', 60, 100.0), ('Colour', 120, 600.0)]);
      expect(ServicePlan.decode('not json'), isNull);
    });
  });
}
