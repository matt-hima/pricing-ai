import '../i18n/i18n.dart';

/// 聊天裡顯示的結果列：編輯器回傳的是英文訊息（技術紀錄），這裡依動作與參數翻成使用者介面語言。
/// 這樣回覆是確定的、不會被模型編造（例如「信已寄出」），也一定是正確的語言。
typedef ChatLine = ({bool ok, String text});

String _list(Object? v) => tr('chat.list.$v');
String _section(Object? v) => tr('chat.section.$v');

/// [action] 是送出的動作（含參數），[ok] / [english] 是編輯器的結果
String localizedResult(Map<String, Object?> action, bool ok, String english) {
  final name = '${action['action']}';
  if (!ok) return tr('chat.r.fail', {'reason': english});
  switch (name) {
    case 'set_text':
      return tr('chat.r.set_text', {'text': '${action['text']}'});
    case 'set_row':
    case 'remove_row':
      return tr('chat.r.$name', {'list': _list(action['list'])});
    case 'add_row':
      return tr('chat.r.add_row', {'first': '${action['first']}', 'list': _list(action['list'])});
    case 'scale_prices':
      final num p = action['percent'] is num ? action['percent'] as num : 0;
      final shown = p == p.roundToDouble() ? '${p.round()}' : '$p';
      return tr('chat.r.scale_prices', {'percent': p > 0 ? '+$shown' : shown});
    case 'set_color':
      // 編輯器可能把太淺的顏色調深，所以以訊息裡的最終色碼為準
      final finalHex = RegExp(r'→ (#[0-9a-fA-F]{6})').firstMatch(english)?[1] ?? '${action['color']}';
      return tr('chat.r.set_color', {'color': finalHex}) + (english.contains('darkened') ? tr('chat.r.darkened') : '');
    case 'set_background':
      return tr('chat.r.set_background', {'color': RegExp(r'→ (#[0-9a-fA-F]{6})').firstMatch(english)?[1] ?? '${action['color']}'});
    case 'set_hero_image':
      return tr('chat.r.set_hero_image');
    case 'set_line_link':
      return tr('chat.r.set_line_link', {'url': '${action['url']}'});
    case 'set_section':
      return tr(action['visible'] == false ? 'chat.r.hide' : 'chat.r.show_section', {'section': _section(action['section'])});
    case 'show':
      return tr('chat.r.show', {'section': _section(action['section'])});
    case 'set_device':
      return tr('chat.r.set_device', {'device': tr('chat.device.${action['device']}')});
    case 'undo':
      return tr('chat.r.undo');
    case 'set_theme':
      return tr('chat.r.set_theme', {'theme': tr('chat.theme.${action['theme']}')});
    case 'set_flow':
      return tr('chat.r.set_flow', {'which': tr('chat.flow.${action['which']}')});
    case 'connect_google_form':
      return tr('chat.r.connect_google_form');
    case 'generate_image':
      return tr('chat.r.generate_image');
    case 'regenerate':
      return tr('chat.r.regenerate', {'part': tr('chat.part.${action['part']}')});
    case 'add_form_field':
    case 'remove_form_field':
      return tr('chat.r.$name', {'label': '${action['label']}'});
    case 'set_site_name':
      return tr('chat.r.set_site_name', {'name': '${action['name']}'});
    case 'set_booking_email':
      return tr('chat.r.set_booking_email', {'email': '${action['email']}'});
    case 'check_quality':
      final n = RegExp(r'(\d+) problem\(s\) found, (\d+) fixed automatically, (\d+) left').firstMatch(english);
      return n == null ? tr('chat.r.check.ok') : tr('chat.r.check.some', {'found': n[1]!, 'fixed': n[2]!, 'left': n[3]!});
  }
  return english;
}

/// 編輯器的結果列（與送出的動作依序一一對應）→ 顯示用的列。檢查細節列（detail）是額外的英文技術訊息，原樣顯示。
List<ChatLine> localizedRows(List<Map<String, Object?>> actions, List rows) {
  final out = <ChatLine>[];
  var i = 0;
  for (final x in rows) {
    final row = x as Map;
    final ok = row['ok'] == true;
    if (row['detail'] == true || i >= actions.length) {
      out.add((ok: ok, text: '${row['message']}'));
    } else {
      out.add((ok: ok, text: localizedResult(actions[i], ok, '${row['message']}')));
      i++;
    }
  }
  return out;
}
