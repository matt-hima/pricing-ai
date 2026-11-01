import 'dart:convert';

/// Google フォーム連携：公開されたフォームのページから質問（項目名・種類・選択肢・必須）と送信先を読み取り、
/// 予約フォームをその質問に作り替える。送信は訪問者のブラウザからフォームの formResponse に POST するだけなので、
/// サーバーも API キーも不要。フォームのページ（FB_PUBLIC_LOAD_DATA_）は非公開仕様のため、読み取れない場合は理由を返す。

class GField {
  final String entry; // entry.123456
  final String label, kind; // kind: text | paragraph | radio | dropdown | checkbox | date | time
  final List<String> options;
  final bool required;
  const GField(this.entry, this.label, this.kind, this.options, this.required);

  Map<String, Object?> toJson() => {'entry': entry, 'label': label, 'kind': kind, 'options': options, 'required': required};
}

class GForm {
  final String title, action;
  final List<GField> fields;
  final int pages; // セクション数（複数ページのフォームは pageHistory が必要）
  final List<String> skipped; // 対応していない項目（任意項目のみ）
  const GForm(this.title, this.action, this.fields, this.pages, this.skipped);

  int get requiredCount => fields.where((f) => f.required).length;

  /// 編集アクション set_google_form に渡す設定（JSON 文字列）
  String get config => jsonEncode({'action': action, 'pages': pages, 'fields': [for (final f in fields) f.toJson()]});
}

class GoogleFormException implements Exception {
  /// not_public | not_found | unreadable | unsupported_required | no_fields | bad_url
  final String code;
  final String detail;
  GoogleFormException(this.code, [this.detail = '']);
  @override
  String toString() => 'GoogleFormException($code${detail.isEmpty ? '' : ': $detail'})';
}

final _formUrl = RegExp(r'^https?://docs\.google\.com/forms/d/e/([\w-]+)/(viewform|formResponse)', caseSensitive: false);

/// 入力されたリンクがフォームのリンク（または短縮リンク）か
bool looksLikeGoogleForm(String url) {
  final u = url.trim();
  return _formUrl.hasMatch(u) || RegExp(r'^https?://forms\.gle/[\w-]+', caseSensitive: false).hasMatch(u);
}

bool isShortFormLink(String url) => RegExp(r'^https?://forms\.gle/', caseSensitive: false).hasMatch(url.trim());

/// 公開リンク → 送信先（formResponse）。編集用リンク（/d/<id>/edit）は公開されていないので受け付けない。
String formResponseUrl(String viewUrl) {
  final m = _formUrl.firstMatch(viewUrl.trim());
  if (m == null) throw GoogleFormException('bad_url');
  return 'https://docs.google.com/forms/d/e/${m[1]}/formResponse';
}

String? _s(Object? v) => v is String && v.trim().isNotEmpty ? v.trim() : null;

/// フォームのページ HTML → GForm。[pageUrl] は最終的な（リダイレクト後の）公開リンク。
GForm parseGoogleForm(String html, String pageUrl) {
  if (RegExp(r'accounts\.google\.com/(ServiceLogin|v3/signin)|You need permission|アクセス権が必要', caseSensitive: false).hasMatch(html) && !html.contains('FB_PUBLIC_LOAD_DATA_')) {
    throw GoogleFormException('not_public');
  }
  final start = html.indexOf('FB_PUBLIC_LOAD_DATA_');
  if (start < 0) throw GoogleFormException(html.contains('<title>') && RegExp(r'404|not found', caseSensitive: false).hasMatch(html) ? 'not_found' : 'unreadable');
  final eq = html.indexOf('=', start);
  final end = html.indexOf(';</script>', eq);
  if (eq < 0 || end < 0) throw GoogleFormException('unreadable');
  Object? data;
  try {
    data = jsonDecode(html.substring(eq + 1, end).trim());
  } catch (_) {
    throw GoogleFormException('unreadable');
  }
  final action = formResponseUrl(pageUrl);
  List? items;
  String title = '';
  try {
    items = (data as List)[1][1] as List?;
    title = _s((data)[3]) ?? _s((data)[1][8]) ?? '';
  } catch (_) {
    throw GoogleFormException('unreadable');
  }
  if (items == null) throw GoogleFormException('unreadable');

  final fields = <GField>[];
  final skipped = <String>[];
  var sections = 0;
  for (final it in items) {
    if (it is! List || it.length < 4) continue;
    final type = it[3];
    final label = _s(it[1]) ?? '';
    if (type == 8) {
      sections++; // セクション見出し：次のページ
      continue;
    }
    if (type is! int || it.length < 5 || it[4] is! List || (it[4] as List).isEmpty) continue; // 説明文・画像・動画など
    final q = (it[4] as List).first;
    if (q is! List || q.isEmpty || q[0] is! int) continue;
    final required = q.length > 2 && q[2] == 1;
    final entry = 'entry.${q[0]}';
    final options = <String>[
      if (q.length > 1 && q[1] is List)
        for (final o in q[1] as List)
          if (o is List && o.isNotEmpty && _s(o[0]) != null) _s(o[0])!,
    ];
    final kind = switch (type) {
      0 => 'text',
      1 => 'paragraph',
      2 => 'radio',
      3 => 'dropdown',
      4 => 'checkbox',
      9 => 'date',
      10 => 'time',
      _ => '',
    };
    if (kind.isEmpty || label.isEmpty || ((kind == 'radio' || kind == 'dropdown' || kind == 'checkbox') && options.isEmpty)) {
      // 表・ファイルアップロード・目盛りなどは対応外。必須だと送信できないので、その場合はエラー。
      if (required) throw GoogleFormException('unsupported_required', label.isEmpty ? '#$type' : label);
      skipped.add(label.isEmpty ? '#$type' : label);
      continue;
    }
    fields.add(GField(entry, label, kind, options, required));
  }
  if (fields.isEmpty) throw GoogleFormException('no_fields');
  return GForm(title, action, fields, sections + 1, skipped);
}

/// Google フォームを新しく作るページ
const googleFormCreateUrl = 'https://docs.google.com/forms/create';

/// 予約用テンプレート（作者が作って「リンクを知っている全員が閲覧可」にしたフォームの ID）。
/// 設定すると「テンプレートをコピー」ボタンが出る：--dart-define=BOOKING_FORM_TEMPLATE_ID=…
const bookingFormTemplateId = String.fromEnvironment('BOOKING_FORM_TEMPLATE_ID');

String? get bookingFormTemplateCopyUrl => bookingFormTemplateId.isEmpty ? null : 'https://docs.google.com/forms/d/$bookingFormTemplateId/copy';

/// フォームに作るとよい質問（予約サイトの基本項目 + ページにすでにある追加質問）
class SuggestedQuestion {
  final String label, kind; // kind は GField と同じ
  final bool required;
  final List<String> options;
  const SuggestedQuestion(this.label, this.kind, this.required, [this.options = const []]);
}

/// 貼り付け用のテキスト（1 行 1 質問）。[kindLabel] は種類の表示名、[requiredLabel] は「必須」の表示名。
String suggestedAsText(List<SuggestedQuestion> qs, String Function(String kind) kindLabel, String requiredLabel) => [
      for (final q in qs) '${q.label} — ${kindLabel(q.kind)}${q.options.isEmpty ? '' : ' (${q.options.join(' / ')})'}${q.required ? ' — $requiredLabel' : ''}',
    ].join('\n');
