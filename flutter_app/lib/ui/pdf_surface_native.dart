import 'package:flutter/material.dart';

import '../i18n/i18n.dart';

void registerPdfPreview() {}

/// 桌面版的 PDF 預覽（尚未提供）
class PdfSurface extends StatelessWidget {
  const PdfSurface({super.key});

  @override
  Widget build(BuildContext context) => Center(child: Text(tr('js.pdf_nobridge')));
}
