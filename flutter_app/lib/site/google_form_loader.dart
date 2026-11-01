import 'google_form.dart';
import 'platform/fetch_form.dart';

/// 公開リンク（または貼り付けたページのソース）から GForm を読み込む。失敗は GoogleFormException。
Future<GForm> loadGoogleForm(String link, {String? pastedSource}) async {
  final pasted = pastedSource?.trim() ?? '';
  if (pasted.isNotEmpty) {
    final id = RegExp(r'docs\.google\.com/forms/d/e/([\w-]+)/').firstMatch(pasted)?[1] ?? RegExp(r'docs\.google\.com/forms/d/e/([\w-]+)/').firstMatch(link)?[1];
    if (id == null) throw GoogleFormException('unreadable');
    return parseGoogleForm(pasted, 'https://docs.google.com/forms/d/e/$id/viewform');
  }
  if (!looksLikeGoogleForm(link)) throw GoogleFormException('bad_url');
  if (!canFetchForm) throw UnsupportedError('fetch');
  final r = await fetchFormPage(link.trim());
  if (Uri.tryParse(r.url)?.host == 'accounts.google.com') throw GoogleFormException('not_public');
  return parseGoogleForm(r.html, r.url);
}

/// 例外 → i18n キー
String googleFormErrorKey(Object e) => e is GoogleFormException ? 'gf.err.${e.code}' : (e is UnsupportedError ? 'gf.err.paste' : 'gf.err.network');
