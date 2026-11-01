import 'app_state.dart';
import 'i18n/i18n.dart';

/// 桌面版 PDF：尚未提供（網頁版用 pdfmake）
Future<String> compileQuotePdf(AppState s, void Function(String status) onStatus) async => tr('js.pdf_nobridge');

Future<String> previewQuotePdf(AppState s, void Function(String status) onStatus) async => tr('js.pdf_nobridge');

bool downloadLastPdf(String filename) => false;

String previewKey(AppState s) => '';
