import 'dart:convert';

import '../i18n/i18n.dart';
import '../json_repair.dart';
import 'site_actions.dart';
import 'site_ai.dart' show ChatTurn;
import 'site_style.dart';

/// 向本機模型提問：回傳模型文字。[schema] 讓 llama.cpp 限制輸出格式。
typedef Ask = Future<String> Function(String system, String user, Map<String, dynamic> schema);

/// 聊天編輯分三小步，每一步模型只做一件很小的事：
///  1. 選動作：從目錄挑出要用的動作名稱（輸出被限制成目錄裡的名稱）；選了兩個以上時，再對每個動作問一次
///     「屋主有明確要求這個嗎？」（是 / 否），濾掉小模型愛多加的動作（第一個動作直接保留：它幾乎都是對的，
///     全部都問反而會把對的也濾掉）
///  2. 填實體：對每個被選中的動作，只看那個動作的說明與一個範例，把參數填進去（輸出被限制成該動作的格式）
///  3. 回覆：不讓模型寫。結果列與回覆句由程式依動作與結果產生（chat_results.dart），
///     所以不會把沒做的事說成做了，也一定是使用者介面的語言
/// 修改頁面的程式碼都在編輯器端預先寫好（assets/editor/actions.js），模型不碰 HTML / CSS。

String _catalogLines(List<ActionSpec> all) => all.map((a) => '- ${a.name} — ${a.description}').join('\n');

String routeSystemPrompt(List<ActionSpec> editorActions) => """You route a website owner's request to editing actions for a one-page booking website.
Output JSON only: {"actions":["<name>", ...]}
List the name of every action the owner explicitly asked for, each name at most once, in the order to run them. Do not add actions the owner did not ask for. Use [] when the owner asks a question or nothing needs to change.
Actions:
${_catalogLines([...editorActions, ...appActions])}
The owner may write in any language (English, Japanese, Chinese, Portuguese, Spanish). Action names are always the English names above.
Examples:
Owner: We are closed on Mondays and make everything 10% cheaper
{"actions":["set_row","scale_prices"]}
Owner: 浮かんでいるボタンを隠して、色を青にしてください
{"actions":["set_section","set_color"]}
Owner: 隱藏營業時間，價格調低 10%
{"actions":["set_section","scale_prices"]}
Owner: Envie as reservas para ana@mia.example
{"actions":["set_booking_email"]}
Owner: Oculta los botones flotantes
{"actions":["set_section"]}
Owner: Use pink and hide the opening hours
{"actions":["set_color","set_section"]}
Owner: Rename the business to Luna Spa
{"actions":["set_text","set_site_name"]}
Owner: What can you do?
{"actions":[]}""";

Map<String, dynamic> routeSchema(List<ActionSpec> editorActions) => {
      'type': 'object',
      'properties': {
        'actions': {
          'type': 'array',
          'maxItems': 4,
          'items': {'enum': [for (final a in [...editorActions, ...appActions]) a.name]},
        },
      },
      'required': ['actions'],
      'additionalProperties': false,
    };

String fillSystemPrompt(ActionSpec a, Lang siteLang) {
  final notes = [for (final p in a.params) if (p.hint.isNotEmpty) '${p.name}: ${p.hint}'];
  return """You fill in the parameters of ONE website editing action.
Action: ${a.signature}
What it does: ${a.description}
${notes.isEmpty ? '' : 'Parameter notes: ${notes.join('; ')}\n'}Output JSON only: {"calls":[{"action":"${a.name}", <parameters>}]}
Add exactly one call. If the owner asked for several things with this action, fill in only the first one. Use the parameter names exactly as listed.
Write website text in ${siteLang.aiName}. Keep prices in the currency format already on the page. Never invent phone numbers, email addresses or URLs; copy them from what the owner wrote.
${_writesText(a) ? '${writingRules(siteLang)}\n' : ''}Example:
Owner: ${a.exampleSay}
${jsonEncode({'calls': [a.exampleArgs]})}""";
}

const confirmSystemPrompt = """You check whether a website owner explicitly asked for one specific change.
Output JSON only: {"asked": true} or {"asked": false}
Answer true only if the owner's message directly asks for this change. Answer false if the message is about something else.
Examples:
Owner: We are closed on Saturdays
Change: scale_prices — Raise or lower every price in the price list by a percentage.
{"asked": false}
Owner: We are closed on Saturdays
Change: set_row — Change cells of an existing row in a list.
{"asked": true}
Owner: Make everything 10% cheaper
Change: set_text — Change one piece of text on the page.
{"asked": false}
Owner: Make everything 10% cheaper
Change: scale_prices — Raise or lower every price in the price list by a percentage.
{"asked": true}""";

const confirmSchema = {
  'type': 'object',
  'properties': {
    'asked': {'type': 'boolean'},
  },
  'required': ['asked'],
  'additionalProperties': false,
};

/// 會寫進頁面文字的動作：給它們文案規則
bool _writesText(ActionSpec a) => const {'set_text', 'set_row', 'add_row', 'set_site_name'}.contains(a.name);

/// 不是「文字」的參數：不做排版修正
const _plainKeys = {'action', 'list', 'target', 'section', 'device', 'row', 'url', 'email', 'color', 'visible', 'percent'};

Map<String, dynamic> fillSchema(ActionSpec a) => {
      'type': 'object',
      'properties': {
        'calls': {'type': 'array', 'minItems': 1, 'maxItems': 1, 'items': actionSchema(a)},
      },
      'required': ['calls'],
      'additionalProperties': false,
    };

/// [snapshot] 是編輯器目前的內容（actions.js 的 snapshot）
String siteChatUserPrompt(Map<String, dynamic> snapshot, List<ChatTurn> history, String message) {
  final recent = history.length > 6 ? history.sublist(history.length - 6) : history;
  final convo = recent.isEmpty ? '' : '\nConversation so far:\n${recent.map((t) => '${t.user ? 'Owner' : 'You'}: ${t.text}').join('\n')}\n';
  return 'Current website content (JSON; list rows are [first, second]):\n${jsonEncode(snapshot)}\n$convo\nOwner: $message';
}

/// 動作 + 它修改的目標：同樣的目標只允許出現一次
String _targetKey(Map<String, Object?> m) {
  final a = '${m['action']}';
  final target = switch (a) {
    'set_row' || 'remove_row' => '${m['list']}/${m['row']}',
    'add_row' => '${m['list']}/${m['first']}',
    'set_text' || 'set_background' => '${m['target']}',
    'set_section' || 'show' => '${m['section']}',
    'regenerate' => '${m['part']}',
    'generate_image' => 'hero',
    'connect_google_form' => 'gform',
    'set_theme' => 'theme',
    _ => '',
  };
  return '$a|$target';
}

final _viewWords = <String, RegExp>{
  'set_device': RegExp(r'phone|mobile|tablet|desktop|laptop|smartphone|スマホ|携帯|モバイル|タブレット|パソコン|デスクトップ|手機|手机|平板|電腦|电脑|桌機|celular|computador|telem[oó]vel|m[oó]vil|ordenador|escritorio|computadora', caseSensitive: false),
  'show': RegExp(r'show me|look at|scroll|take me|見せて|見たい|表示して|移動|看看|看一下|顯示給我|帶我|mostre|mostrar-me|mu[eé]strame|ver la|quero ver', caseSensitive: false),
  'regenerate': RegExp(r'regenerate|rewrite|redo|write (it |them )?again|new version|redraw|再生成|書き直|作り直|考え直|もう一度|重新生成|重寫|重新寫|再寫|重畫|重新畫|gerar novamente|reescrever|escrever de novo|refazer|regenerar|reescribir|volver a escribir|rehacer', caseSensitive: false),
  'generate_image': RegExp(r'image|picture|photo|banner|illustration|画像|写真|イラスト|バナー|圖片|图片|照片|主圖|插圖|imagem|foto|imagen|fotografia|ilustra', caseSensitive: false),
  'set_background': RegExp(r'background|backdrop|\bbg\b|背景|バック|fundo|fondo', caseSensitive: false),
  'undo': RegExp(r'undo|revert|go back|元に戻|取り消|やり直|復原|還原|撤銷|撤销|desfaz|desfazer|volte|deshac|deshacer|revierte', caseSensitive: false),
};

/// 百分比：小模型常把 15% 寫成 0.15 或 -0.15。屋主訊息裡有「N%」就以 N 為準（正負號沿用模型的判斷）。
void _fixPercent(Map<String, Object?> m, String message) {
  final p = m['percent'];
  if (p is! num) return;
  final n = RegExp(r'(\d+(?:\.\d+)?)\s*[%％]').firstMatch(message);
  if (n != null) {
    final v = double.parse(n[1]!);
    m['percent'] = p < 0 ? -v : v;
  } else if (p != 0 && p.abs() < 1) {
    m['percent'] = p * 100; // 沒寫 % 但給了小數：視為比例
  }
}

/// 動作裡的 email / url 參數若不是屋主訊息裡出現過的字，回傳該值（表示是模型捏造的）
String? _ungrounded(Map<String, Object?> m, List<String> said) {
  final hay = said.join('\n').toLowerCase();
  for (final k in const ['email', 'url']) {
    final v = m[k];
    if (v is String && v.isNotEmpty && !hay.contains(v.toLowerCase())) return v;
  }
  return null;
}

typedef Plan = ({List<Map<String, Object?>> actions, List<String> routed, List<String> notes});

/// 步驟 1 + 2：把屋主的話變成要執行的動作清單。名稱與參數是否合法由編輯器端再驗證一次。
Future<Plan> planChat({
  required Ask ask,
  required List<ActionSpec> editorActions,
  required Map<String, dynamic> snapshot,
  required List<ChatTurn> history,
  required String message,
  required Lang siteLang,
}) async {
  final all = {for (final a in [...editorActions, ...appActions]) a.name: a};
  final notes = <String>[];

  // 1) 選動作。只給目前這一句：把前幾輪對話（尤其是助理上一輪的回覆）放進去，
  //    小模型會重複上一輪的動作（實測：先改顏色，再說「隱藏浮動按鈕」又被選成改顏色）。
  final recent = history.length > 4 ? history.sublist(history.length - 4) : history;
  final routeUser = 'Owner: $message';
  final routed = <String>[];
  final rj = parseLooseJson(await ask(routeSystemPrompt(editorActions), routeUser, routeSchema(editorActions)));
  final names = rj?['actions'];
  if (names is List) {
    for (final n in names) {
      if (all.containsKey('$n') && !routed.contains('$n')) routed.add('$n');
    }
  }

  // 只看畫面、不改內容的動作：屋主訊息裡沒有相關字眼就不可能是這個意思（小模型會亂加）
  routed.removeWhere((n) => _viewWords[n] != null && !_viewWords[n]!.hasMatch(message));

  // 實體由程式處理：屋主寫了信箱就是設定預約通知信箱；沒有網址就不可能是 LINE 連結 / 圖片
  final hasEmail = RegExp(r'[^\s@]+@[^\s@]+\.[^\s@]+').hasMatch(message);
  final hasUrl = RegExp(r'https?://', caseSensitive: false).hasMatch(message);
  if (!hasUrl) routed.removeWhere((n) => n == 'set_line_link' || n == 'set_hero_image');
  if (hasUrl) routed.remove('generate_image');
  // Google フォームのリンクは動作も引数も決まっている：モデルに任せず、リンクをそのまま使う
  final formLink = RegExp(r'https?://(docs\.google\.com/forms/[^\s<>"\u3000]+|forms\.gle/[^\s<>"\u3000]+)', caseSensitive: false).firstMatch(message)?[0];
  if (formLink != null) {
    routed.removeWhere((n) => n == 'set_line_link' || n == 'set_hero_image' || n == 'connect_google_form');
    routed.insert(0, 'connect_google_form');
  } else {
    routed.remove('connect_google_form');
  } // 給了網址就是用那張圖，不是產生
  if (hasEmail) {
    routed.remove('set_booking_email');
    routed.insert(0, 'set_booking_email');
  }

  // 1b) 選了兩個以上：第一個（模型最有把握的）直接保留，其餘逐一確認屋主真的有要求
  if (routed.length > 1) {
    final kept = <String>[routed.first];
    for (final name in routed.skip(1)) {
      final spec = all[name]!;
      final out = await ask(confirmSystemPrompt, 'Owner: $message\nChange: $name — ${spec.description}\nDid the owner explicitly ask for this change?', confirmSchema);
      if (parseLooseJson(out)?['asked'] == true) kept.add(name);
    }
    routed
      ..clear()
      ..addAll(kept);
  }

  // 2) 填實體：每個動作一次小問答
  final actions = <Map<String, Object?>>[];
  final seen = <String>{};
  for (final name in routed.take(4)) {
    final spec = all[name]!;
    if (name == 'connect_google_form' && formLink != null) {
      actions.add({'action': name, 'url': formLink});
      continue;
    }
    if (spec.params.isEmpty) {
      actions.add({'action': name});
      continue;
    }
    final out = await ask(fillSystemPrompt(spec, siteLang), '${siteChatUserPrompt(snapshot, const [], message)}\nFill in the "$name" action.', fillSchema(spec));
    final j = parseLooseJson(out);
    final calls = j?['calls'];
    var got = 0;
    if (calls is List) {
      for (final c in calls.take(1)) {
        if (c is! Map) continue;
        final m = <String, Object?>{'action': name};
        c.forEach((k, v) {
          if (k is String && k != 'action' && (v is String || v is num || v is bool)) {
            m[k] = v is String && !_plainKeys.contains(k) ? polishText(siteLang.name, v) : v;
          }
        });
        if (name == 'scale_prices') _fixPercent(m, message);
        // 防止模型捏造：電子郵件與網址必須是屋主自己打出來的
        final fake = _ungrounded(m, [message, ...history.where((t) => t.user).map((t) => t.text)]);
        if (fake != null) {
          notes.add('$name: "$fake" is not in what you wrote, so I did not use it. Please type it in your message.');
          got++; // 已經說明原因，不再補「沒有可用參數」
          continue;
        }
        // 同一個目標被重複 / 互相矛盾地修改時只留第一個（小模型常把同一件事寫好幾次）
        final key = _targetKey(m);
        if (!seen.add(key)) continue;
        actions.add(m);
        got++;
      }
    }
    if (got == 0) notes.add('$name: the model gave no usable parameters');
  }
  return (actions: actions, routed: routed, notes: notes);
}
