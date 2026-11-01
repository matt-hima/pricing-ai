/// 報價單 PDF：文件描述 + 網頁版用 pdfmake 產生（web/pdf_bridge.js）
export 'pdf_doc.dart';
export 'pdf_web.dart' if (dart.library.io) 'pdf_native.dart';
