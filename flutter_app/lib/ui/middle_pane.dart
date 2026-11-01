import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app_state.dart';
import '../i18n/i18n.dart';
import '../llm.dart' show aiAvailable;
import '../market.dart' show marketSearchAvailable;
import 'case_browser_dialog.dart' show caseBrowserAvailable;
import 'case_history_dialog.dart';
import 'market_dialog.dart';
import '../pdf_export.dart';
import 'pdf_surface.dart';
import 'quote_paper.dart';

/// 中欄：報價單（Dolibarr 樣式）與 XeLaTeX PDF 即時預覽的切換
class MiddlePane extends StatelessWidget {
  final AppState state;
  final void Function(String) onToast;
  const MiddlePane({super.key, required this.state, required this.onToast});

  @override
  Widget build(BuildContext context) {
    final s = state;
    final bounded = MediaQuery.sizeOf(context).width >= 860;

    final header = _Header(state: s, onToast: onToast);
    final body = s.previewOn ? _PdfBody(state: s) : SingleChildScrollView(child: QuotePaper(state: s));

    return LayoutBuilder(builder: (context, c) {
      if (c.hasBoundedHeight && bounded) {
        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          header,
          const SizedBox(height: 12),
          Expanded(child: body),
        ]);
      }
      // 無界高度（手機 / 中等寬度）：PDF 給固定高度，報價單自然展開
      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        header,
        const SizedBox(height: 12),
        if (s.previewOn)
          SizedBox(height: MediaQuery.sizeOf(context).height * .72, child: _PdfBody(state: s))
        else
          QuotePaper(state: s),
      ]);
    });
  }
}

class _Header extends StatelessWidget {
  final AppState state;
  final void Function(String) onToast;
  const _Header({required this.state, required this.onToast});

  @override
  Widget build(BuildContext context) {
    final s = state;
    final cs = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;

    String status;
    Color color = cs.onSurfaceVariant;
    IconData icon;
    if (s.previewBusy) {
      status = s.previewStatus.isEmpty ? tr('st.compiling') : s.previewStatus;
      icon = Icons.sync;
    } else if (s.previewError.isNotEmpty) {
      status = tr('st.failed');
      color = cs.error;
      icon = Icons.error_outline;
    } else if (s.previewStale) {
      status = tr('st.stale');
      icon = Icons.edit_note;
    } else if (s.previewEverRendered) {
      status = tr('st.synced');
      color = Colors.teal;
      icon = Icons.check_circle_outline;
    } else {
      status = tr('st.none');
      icon = Icons.hourglass_empty;
    }

    return Wrap(spacing: 12, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
      SegmentedButton<bool>(
        showSelectedIcon: false,
        segments: [
          ButtonSegment(value: false, icon: const Icon(Icons.receipt_long, size: 18), label: Text(tr('view.paper'))),
          ButtonSegment(value: true, icon: const Icon(Icons.picture_as_pdf_outlined, size: 18), label: Text(tr('view.pdf'))),
        ],
        selected: {s.previewOn},
        onSelectionChanged: (v) => s.setPreviewOn(v.first),
      ),
      if (aiAvailable && marketSearchAvailable)
        OutlinedButton.icon(
          icon: const Icon(Icons.travel_explore, size: 18),
          label: Text(tr('mkt.button')),
          onPressed: () => showDialog<void>(context: context, builder: (_) => MarketDialog(state: s)),
        ),
      if (aiAvailable && caseBrowserAvailable)
        OutlinedButton.icon(
          icon: const Icon(Icons.history_edu, size: 18),
          label: Text(tr('hist.button')),
          onPressed: () => showDialog<void>(context: context, builder: (_) => CaseHistoryDialog(state: s)),
        ),
      if (s.applyToSite != null)
        FilledButton.icon(
          icon: const Icon(Icons.send_outlined, size: 18),
          label: Text(tr('btn.applyToSite')),
          onPressed: s.pricing.lines.any((l) => l.subtotal > 0) ? () => s.applyToSite!(s.sitePayload) : null,
        ),
      if (s.previewOn) ...[
        Row(mainAxisSize: MainAxisSize.min, children: [
          if (s.previewBusy)
            const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
          else
            Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Text(status, style: t.bodySmall?.copyWith(color: color)),
        ]),
        IconButton(
          tooltip: tr('tip.recompile'),
          visualDensity: VisualDensity.compact,
          onPressed: s.previewBusy ? null : s.refreshPreview,
          icon: const Icon(Icons.refresh),
        ),
        IconButton(
          tooltip: tr('tip.download'),
          visualDensity: VisualDensity.compact,
          onPressed: s.previewEverRendered
              ? () => onToast(downloadLastPdf('${s.q.ref}.pdf') ? tr('msg.pdfDone', {'ref': s.q.ref}) : tr('msg.noPdf'))
              : null,
          icon: const Icon(Icons.download),
        ),
      ],
    ]);
  }
}

class _PdfBody extends StatelessWidget {
  final AppState state;
  const _PdfBody({required this.state});

  @override
  Widget build(BuildContext context) {
    final s = state;
    final cs = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;

    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Stack(children: [
        const Positioned.fill(child: PdfSurface()),

        // 首次編譯：說明需要下載引擎
        if (!s.previewEverRendered && s.previewError.isEmpty)
          Positioned.fill(
            child: ColoredBox(
              color: cs.surface.withValues(alpha: .94),
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 420),
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      const CircularProgressIndicator(),
                      const SizedBox(height: 16),
                      Text(s.previewStatus.isEmpty ? tr('pdf.firstTitle') : s.previewStatus, style: t.titleSmall, textAlign: TextAlign.center),
                      const SizedBox(height: 8),
                      Text(tr('pdf.firstBody'),
                          style: t.bodySmall?.copyWith(color: cs.onSurfaceVariant), textAlign: TextAlign.center),
                    ]),
                  ),
                ),
              ),
            ),
          ),

        // 編譯失敗：保留上一版預覽，並顯示錯誤摘要
        if (s.previewError.isNotEmpty)
          Positioned(
            left: 12,
            right: 12,
            top: 12,
            child: Material(
              color: cs.errorContainer,
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Icon(Icons.error_outline, color: cs.onErrorContainer, size: 18),
                    const SizedBox(width: 8),
                    Expanded(child: Text(tr('pdf.errTitle'), style: t.titleSmall?.copyWith(color: cs.onErrorContainer))),
                    TextButton(
                      onPressed: () => Clipboard.setData(ClipboardData(text: s.previewError)),
                      child: Text(tr('btn.copyErr')),
                    ),
                    TextButton(onPressed: s.refreshPreview, child: Text(tr('btn.retry'))),
                  ]),
                  Text(
                    s.previewError.length > 360 ? '${s.previewError.substring(0, 360)}…' : s.previewError,
                    style: t.bodySmall?.copyWith(color: cs.onErrorContainer, fontFamily: 'monospace'),
                  ),
                ]),
              ),
            ),
          ),
      ]),
    );
  }
}
