import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:pasteboard/pasteboard.dart';

import '../case_analysis/case_report.dart';
import '../i18n/i18n.dart';
import 'brand_logo.dart';
import 'save_file.dart';

/// 圖表外框：標題、圖表與 Pricing AI 浮水印一起擷取成圖片（底色用卡片的顏色，貼到別處不會變透明），
/// 右上角可以「複製圖片」或「下載 PNG」。報告匯出 PDF 時也用 [captureChart] 取得同一張圖。
class ChartFrame extends StatelessWidget {
  final GlobalKey boundary;
  final String title, filename;
  /// 圖表內容：用這裡給的 context 取顏色與字型（淺色主題）
  final WidgetBuilder builder;
  const ChartFrame({super.key, required this.boundary, required this.title, required this.filename, required this.builder});

  @override
  Widget build(BuildContext context) {
    // 圖表一律用淺色：複製、下載或放進 PDF 時，不論介面是深色或淺色，看起來都一樣（白紙上不會出現深色色塊）
    final app = Theme.of(context);
    final light = app.brightness == Brightness.light
        ? app
        : ThemeData(colorScheme: ColorScheme.fromSeed(seedColor: app.colorScheme.primary), fontFamily: app.textTheme.bodyMedium?.fontFamily);
    final t = light.textTheme;
    final cs = light.colorScheme;
    return Stack(children: [
      RepaintBoundary(
        key: boundary,
        child: Container(
          decoration: BoxDecoration(color: cs.surface, border: Border.all(color: cs.outlineVariant), borderRadius: BorderRadius.circular(8)),
          padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Padding(padding: const EdgeInsets.only(right: 76), child: Text(title, style: t.titleSmall)),
            const SizedBox(height: 8),
            Theme(data: light, child: Builder(builder: builder)),
            // 浮水印：在擷取範圍內，複製、下載與 PDF 裡的圖都會帶著（裝飾用，不進無障礙樹）
            const Align(
              alignment: Alignment.centerRight,
              child: Padding(padding: EdgeInsets.only(top: 6), child: ExcludeSemantics(child: Opacity(opacity: .55, child: BrandLogo(key: ValueKey('chart.watermark'), height: 18)))),
            ),
          ]),
        ),
      ),
      Positioned(
        top: 0,
        right: 0,
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          IconButton(
            key: ValueKey('chart.copy:$filename'),
            tooltip: tr('chart.copy'),
            visualDensity: VisualDensity.compact,
            iconSize: 18,
            icon: const Icon(Icons.copy_all_outlined),
            onPressed: () => _copy(context),
          ),
          IconButton(
            key: ValueKey('chart.save:$filename'),
            tooltip: tr('chart.save'),
            visualDensity: VisualDensity.compact,
            iconSize: 18,
            icon: const Icon(Icons.image_outlined),
            onPressed: () => _save(context),
          ),
        ]),
      ),
    ]);
  }

  Future<void> _copy(BuildContext context) async {
    final m = ScaffoldMessenger.of(context);
    final c = await captureChart(boundary);
    if (c == null) return;
    try {
      await Pasteboard.writeImage(c.png);
      m.showSnackBar(SnackBar(content: Text(tr('chart.copied'))));
    } catch (e) {
      m.showSnackBar(SnackBar(content: Text(tr('chart.failed', {'e': '$e'}))));
    }
  }

  Future<void> _save(BuildContext context) async {
    final m = ScaffoldMessenger.of(context);
    final c = await captureChart(boundary);
    if (c == null) return;
    try {
      final at = await saveBytes(c.png, '$filename-${fileDate()}.png', 'image/png');
      if (at != null) m.showSnackBar(SnackBar(content: Text(tr('chart.saved', {'p': at}))));
    } catch (e) {
      m.showSnackBar(SnackBar(content: Text(tr('chart.failed', {'e': '$e'}))));
    }
  }
}

/// 擷取圖表（2 倍解析度的 PNG）；還沒畫出來就回傳 null
Future<ReportChart?> captureChart(GlobalKey boundary, {double pixelRatio = 2}) async {
  final r = boundary.currentContext?.findRenderObject();
  if (r is! RenderRepaintBoundary || !r.hasSize) return null;
  final image = await r.toImage(pixelRatio: pixelRatio);
  try {
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    if (data == null) return null;
    return ReportChart(data.buffer.asUint8List(), r.size.width, r.size.height);
  } finally {
    image.dispose();
  }
}
