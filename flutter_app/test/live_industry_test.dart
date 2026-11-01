@Timeout(Duration(minutes: 20))
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:self_quote/engine/local_engine.dart';
import 'package:self_quote/i18n/i18n.dart';
import 'package:self_quote/site/site_industry.dart';
import 'package:self_quote/site/site_init.dart';

/// 「預約系統比較」業種別案例（餐飲店 / 美容室 / 教室 / 租借空間 / 診所）的真實測試：
/// 把屋主會說的話交給真正的本機模型（GPU），產生整頁文字，連同該業種要加的預約欄位寫成 JSON，
/// 第二半（套用到編輯器、檢查頁面）由瀏覽器端執行。預設略過。
/// 執行：LIVE_ENGINE_ROOT=… INDUSTRY_OUT=out.json flutter test test/live_industry_test.dart
const scenarios = [
  (id: 'restaurant', lang: 'ja', say: '渋谷駅近くの小さなイタリアンレストランです。ランチは11時30分から14時、ディナーは17時30分から22時。席数は20席で、予約はネットで24時間受けたいです。ドタキャンが多くて困っているので、予約の注意書きもほしいです。コースは4500円からです。'),
  (id: 'salon', lang: 'ja', say: '名古屋の美容室です。カット、カラー、パーマ、トリートメントがあります。スタイリストを指名して予約してもらいたいです。営業時間は10時から19時、火曜定休です。電話は営業中に出られないので、夜でもネットで予約を受けたいです。'),
  (id: 'school', lang: 'ja', say: '大阪のピアノ教室です。子ども向けと大人向けのレッスンがあり、まずは体験レッスンを申し込んでもらいたいです。月謝は8000円からで、お休みしたときの振替レッスンもネットで受け付けたいです。'),
  (id: 'space', lang: 'en', say: 'A small meeting room and co-working space near Taipei station, rented by the hour for 600 NT dollars. People book a time slot online and get the door code after booking. Open 24 hours, no staff on site.'),
  (id: 'clinic', lang: 'zh', say: '我們是台中的家庭診所，內科與小兒科。早上與晚上看診，週日休診。希望病人可以線上預約，區分初診和複診，並且提醒就診時間，減少候診室太擁擠。'),
];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({});
  final root = Platform.environment['LIVE_ENGINE_ROOT'];
  final out = Platform.environment['INDUSTRY_OUT'];
  final skip = root == null || out == null ? 'set LIVE_ENGINE_ROOT and INDUSTRY_OUT' : null;

  test('generate a site from each business type description', () async {
    HttpOverrides.global = null;
    final engine = LocalEngine(root: Directory(root!));
    await engine.prepare(Platform.environment['LIVE_ENGINE_MODEL'] ?? 'Qwen2.5-1.5B-Instruct', (p, t) {});
    Future<String> ask(String system, String user, Map<String, dynamic> schema) => engine.chat(system, user, schema: schema, maxTokens: 900);

    final results = <Map<String, Object?>>[];
    for (final s in scenarios) {
      final lang = Lang.fromCode(s.lang == 'zh' ? 'zh-TW' : s.lang)!;
      final sw = Stopwatch()..start();
      final content = await generateSiteContent(ask: ask, siteLang: lang, description: s.say);
      final industry = '${content?['industry'] ?? 'other'}';
      results.add({
        'id': s.id,
        'lang': s.lang,
        'say': s.say,
        'seconds': sw.elapsed.inSeconds,
        'content': content,
        'expectedIndustry': s.id,
        'industry': industry,
        'fields': industryFieldActions(industry, s.lang),
      });
    }
    File(out!).writeAsStringSync(jsonEncode(results));
    await engine.stop();
  }, skip: skip);
}
