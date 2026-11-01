import '../i18n/i18n.dart';
import 'google_form.dart' show looksLikeGoogleForm;

/// 網站編輯動作：目錄由編輯器（assets/editor/actions.js）提供，這裡只負責
///  1. 把目錄組成給模型的提示詞（模型只需要挑動作、填參數）
///  2. 解析模型回覆成動作清單
///  3. 定義兩個只有應用程式能做的動作（網站名稱、預約通知信箱）

class ParamSpec {
  final String name, type, hint;
  final bool required;
  final List<String> values;
  final int? max;
  const ParamSpec(this.name, this.type, {this.required = true, this.values = const [], this.hint = '', this.max});

  static ParamSpec fromJson(Map j) => ParamSpec(
        '${j['name']}',
        '${j['type']}',
        required: j['required'] != false,
        values: [for (final v in (j['values'] as List? ?? const [])) '$v'],
        hint: '${j['hint'] ?? ''}',
        max: j['max'] is num && j['type'] == 'string' ? (j['max'] as num).toInt() : null,
      );

  String get typeText => switch (type) {
        'enum' => values.join('|'),
        'row' => 'row number or a word in the row',
        'number' => 'number',
        'bool' => 'true|false',
        'color' => 'colour name or #rrggbb',
        'url' => 'url',
        _ => 'text',
      };
}

class ActionSpec {
  final String name, description;
  final List<ParamSpec> params;
  final bool app; // true = 由 Flutter 執行，不是編輯器
  final String exampleSay; // 一句屋主說的話
  final Map<String, Object?> exampleArgs; // 對應的動作與參數（給模型當單次示範）
  const ActionSpec(this.name, this.description, this.params, {this.app = false, this.exampleSay = '', this.exampleArgs = const {}});

  static ActionSpec fromJson(Map j) => ActionSpec(
        '${j['name']}',
        '${j['description']}',
        [for (final p in (j['params'] as List? ?? const [])) ParamSpec.fromJson(p as Map)],
        exampleSay: '${(j['example'] as Map?)?['say'] ?? ''}',
        exampleArgs: Map<String, Object?>.from(((j['example'] as Map?)?['args'] as Map?) ?? const {}),
      );

  String get signature => '$name(${params.map((p) => '${p.name}${p.required ? '' : '?'}: ${p.typeText}').join(', ')})';
}

/// 可以重新產生的部分（由應用程式叫本機模型重寫；見 site_regen.dart）
const regenParts = ['headline', 'services', 'faq', 'booking_flow', 'service_flow'];

/// 只有應用程式能做的動作（改的是網站設定，不是頁面內容）
const appActions = [
  ActionSpec('set_site_name', 'Rename the site (the page title and the name in the site list).', [ParamSpec('name', 'string')],
      app: true, exampleSay: 'Call the site Luna Spa', exampleArgs: {'action': 'set_site_name', 'name': 'Luna Spa'}),
  ActionSpec('set_booking_email', 'Set the email address that receives booking requests (予約の通知先 / 預約通知信箱 / e-mail das reservas / correo de las reservas). Use it whenever the owner gives an email address.', [ParamSpec('email', 'string')],
      app: true, exampleSay: 'Send the bookings to hello@luna.example', exampleArgs: {'action': 'set_booking_email', 'email': 'hello@luna.example'}),
  ActionSpec(
      'regenerate',
      'Write a new version of one part of the page with the AI, instead of editing single words (もう一度書いて・作り直して / 重新生成・重寫 / gerar novamente / reescrever / volver a escribir / regenerar). Use it when the owner wants the AI to rewrite the headline, the services, the FAQ, or to redraw a flow chart. hint = the owner\'s wish for the new version, if any.',
      [
        ParamSpec('part', 'enum', values: regenParts, hint: 'headline=the top headlines, services=the service cards, faq=the questions and answers, booking_flow=the booking steps chart, service_flow=the visit steps chart'),
        ParamSpec('hint', 'string', required: false, max: 80),
      ],
      app: true,
      exampleSay: 'Rewrite the FAQ in a friendlier tone',
      exampleArgs: {'action': 'regenerate', 'part': 'faq', 'hint': 'friendlier tone'}),
  ActionSpec(
      'connect_google_form',
      'Make the booking form send bookings to a public Google Form (Googleフォーム / Google 表單 / Google Forms). Use it when the owner gives a Google Form link (docs.google.com/forms or forms.gle). The booking form is rebuilt from the questions of that form.',
      [ParamSpec('url', 'url', hint: 'the Google Form link exactly as the owner wrote it')],
      app: true,
      exampleSay: 'Use this Google Form for bookings: https://forms.gle/abc123',
      exampleArgs: {'action': 'connect_google_form', 'url': 'https://forms.gle/abc123'}),
  ActionSpec(
      'generate_image',
      'Create a new picture for the top banner with the local image AI (画像を生成・バナー画像を作って / 生成圖片・做一張主圖 / gerar uma imagem / generar una imagen). Use it when the owner asks to make or generate a picture, not when they give a web address. prompt = a short English description of the picture, no text or letters in it.',
      [ParamSpec('prompt', 'string', max: 120, hint: 'English, e.g. "a cozy cafe interior with wooden tables"')],
      app: true,
      exampleSay: 'Make a banner picture of a calm hair salon',
      exampleArgs: {'action': 'generate_image', 'prompt': 'a calm modern hair salon interior, warm light'}),
];

/// 單一動作的 JSON schema：動作名稱固定、參數名稱固定、列舉值固定、必填欄位一定出現。
/// 給 llama.cpp 當文法，模型只能「填實體」，寫不出不存在的動作或參數。
Map<String, dynamic> actionSchema(ActionSpec a) {
  Map<String, dynamic> typeOf(ParamSpec p) => switch (p.type) {
        'enum' => {'enum': p.values},
        'bool' => {'type': 'boolean'},
        'number' => {'type': 'number'},
        'row' => {
            'anyOf': [
              {'type': 'integer'},
              {'type': 'string', 'maxLength': 30},
            ],
          },
        'color' => {'type': 'string', 'maxLength': 20},
        'url' => {'type': 'string', 'maxLength': 300},
        _ => {'type': 'string', 'maxLength': p.max ?? 120},
      };
  return {
    'type': 'object',
    'properties': {
      'action': {'const': a.name},
      for (final p in a.params) p.name: typeOf(p),
    },
    'required': ['action', for (final p in a.params) if (p.required) p.name],
    'additionalProperties': false,
  };
}

List<ActionSpec> parseCatalog(List raw) => [for (final j in raw) ActionSpec.fromJson(j as Map)];

bool isAppAction(String name) => appActions.any((a) => a.name == name);

String _describe(ActionSpec a) {
  final hints = [for (final p in a.params) if (p.hint.isNotEmpty) '${p.name}: ${p.hint}'];
  return '- ${a.signature} — ${a.description}${hints.isEmpty ? '' : ' (${hints.join('; ')})'}';
}

final _email = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');

/// 驗證應用程式端的動作；回傳錯誤訊息，沒問題回傳 null
String? validateAppAction(Map<String, Object?> a) {
  switch (a['action']) {
    case 'set_site_name':
      final n = '${a['name'] ?? ''}'.trim();
      return n.isEmpty || n.length > 60 ? '"name" must be 1–60 characters' : null;
    case 'connect_google_form':
      return looksLikeGoogleForm('${a['url'] ?? ''}') ? null : '"url" is not a Google Form link';
    case 'generate_image':
      final t = '${a['prompt'] ?? ''}'.trim();
      return t.isEmpty || t.length > 200 ? '"prompt" must be 1–200 characters' : null;
    case 'regenerate':
      return regenParts.contains('${a['part']}') ? null : '"part" must be one of ${regenParts.join(', ')}';
    case 'set_booking_email':
      return _email.hasMatch('${a['email'] ?? ''}'.trim()) ? null : '"email" is not a valid email address';
  }
  return 'unknown action';
}
