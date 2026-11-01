import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../i18n/i18n.dart';
import '../booking_script.dart';
import '../google_form.dart';
import '../google_form_loader.dart';
import '../platform/fetch_form.dart' show canFetchForm;

/// 予約を Google フォームで受け取る：作り方の案内 → 公開リンクを貼る → 質問と必須項目を読み取って確認 → 予約フォームに反映。
/// 結果：[GoogleFormResult]（接続）、null（変更なし）、または [disconnectResult]（接続解除）。
class GoogleFormResult {
  final GForm form;
  final String? calendarId; // 予約カレンダー（スクリプトで作った場合）
  const GoogleFormResult(this.form, this.calendarId);
}

class GoogleFormDialog extends StatefulWidget {
  final String currentUrl;

  /// 作るとよい質問（ページの基本項目 + 追加質問）
  final List<SuggestedQuestion> suggested;
  final String siteName;
  const GoogleFormDialog({super.key, this.currentUrl = '', this.suggested = const [], this.siteName = ''});

  static const disconnectResult = 'disconnect';

  @override
  State<GoogleFormDialog> createState() => _GoogleFormDialogState();
}

class _GoogleFormDialogState extends State<GoogleFormDialog> {
  late final link = TextEditingController(text: widget.currentUrl);
  final source = TextEditingController();
  GForm? form;
  String? calendarId;
  int minutes = 60;
  bool invite = false;
  String? error;
  bool busy = false;

  @override
  void dispose() {
    link.dispose();
    source.dispose();
    super.dispose();
  }

  Future<void> _connect() async {
    setState(() {
      busy = true;
      error = null;
      form = null;
    });
    try {
      // スクリプトの出力行（"PASTE THIS INTO PRICING AI: <リンク> calendar:<ID>"）を丸ごと貼ってもよい
      final f = await loadGoogleForm(extractFormLink(link.text) ?? link.text, pastedSource: source.text);
      final cal = extractCalendarId(link.text);
      if (mounted) {
        setState(() {
          form = f;
          calendarId = cal;
        });
      }
    } catch (e) {
      final k = googleFormErrorKey(e);
      if (mounted) setState(() => error = tr(k, {'d': e is GoogleFormException ? e.detail : ''}));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Widget _step(BuildContext context, int n, String text) => Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(width: 22, child: Text('$n.', style: Theme.of(context).textTheme.bodySmall)),
          Expanded(child: Text(text, style: Theme.of(context).textTheme.bodySmall)),
        ]),
      );

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final f = form;
    return AlertDialog(
      title: Text(tr('gf.title')),
      content: SizedBox(
        width: 620,
        child: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(tr('gf.intro'), style: t.bodyMedium),
            const SizedBox(height: 10),
            _step(context, 1, tr('gf.step1')),
            if (widget.suggested.isNotEmpty) ...[
              Container(
                margin: const EdgeInsets.fromLTRB(22, 4, 0, 8),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: cs.surfaceContainerHighest.withValues(alpha: .6), borderRadius: BorderRadius.circular(8)),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(tr('gf.suggest'), style: t.labelMedium),
                  const SizedBox(height: 4),
                  for (final q in widget.suggested)
                    Text('• ${q.label} — ${tr('gf.kind.${q.kind}')}${q.options.isEmpty ? '' : ' (${q.options.take(5).join(' / ')})'}${q.required ? ' — ${tr('gf.required')}' : ''}', style: t.bodySmall),
                  const SizedBox(height: 6),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(visualDensity: VisualDensity.compact),
                    icon: const Icon(Icons.copy, size: 16),
                    label: Text(tr('gf.copyList')),
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: suggestedAsText(widget.suggested, (k) => tr('gf.kind.$k'), tr('gf.required'))));
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(tr('gf.copied'))));
                    },
                  ),
                ]),
              ),
            ],
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 0, 0, 8),
              child: Wrap(spacing: 8, runSpacing: 6, children: [
                FilledButton.tonalIcon(
                  icon: const Icon(Icons.open_in_new, size: 16),
                  label: Text(tr('gf.create')),
                  onPressed: () => launchUrl(Uri.parse(googleFormCreateUrl), webOnlyWindowName: '_blank'),
                ),
                if (bookingFormTemplateCopyUrl != null)
                  FilledButton.tonalIcon(
                    icon: const Icon(Icons.content_copy, size: 16),
                    label: Text(tr('gf.template')),
                    onPressed: () => launchUrl(Uri.parse(bookingFormTemplateCopyUrl!), webOnlyWindowName: '_blank'),
                  ),
              ]),
            ),
            if (widget.suggested.isNotEmpty)
              Container(
                margin: const EdgeInsets.fromLTRB(22, 0, 0, 8),
                decoration: BoxDecoration(border: Border.all(color: cs.outlineVariant), borderRadius: BorderRadius.circular(8)),
                child: ExpansionTile(
                  tilePadding: const EdgeInsets.symmetric(horizontal: 10),
                  childrenPadding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
                  expandedCrossAxisAlignment: CrossAxisAlignment.start,
                  title: Text(tr('gf.script.title'), style: t.labelLarge),
                  subtitle: Text(tr('gf.script.sub'), style: t.bodySmall),
                  children: [
                    for (var i = 1; i <= 4; i++) _step(context, i, tr('gf.script.s$i')),
                    const SizedBox(height: 6),
                    Wrap(spacing: 12, runSpacing: 6, crossAxisAlignment: WrapCrossAlignment.center, children: [
                      Text(tr('gf.script.length')),
                      DropdownButton<int>(
                        value: minutes,
                        items: [for (final m in const [30, 45, 60, 90, 120]) DropdownMenuItem(value: m, child: Text(tr('set.idleMin', {'n': '$m'})))],
                        onChanged: (v) => setState(() => minutes = v ?? 60),
                      ),
                      FilterChip(label: Text(tr('gf.script.invite')), selected: invite, onSelected: (v) => setState(() => invite = v)),
                    ]),
                    const SizedBox(height: 6),
                    Wrap(spacing: 8, runSpacing: 6, children: [
                      FilledButton.tonalIcon(
                        icon: const Icon(Icons.copy, size: 16),
                        label: Text(tr('gf.script.copy')),
                        onPressed: () {
                          final script = bookingScript(widget.suggested, BookingScriptOptions(siteName: widget.siteName.isEmpty ? 'Bookings' : widget.siteName, confirmation: tr('gf.script.confirm'), durationMinutes: minutes, inviteCustomer: invite));
                          Clipboard.setData(ClipboardData(text: script));
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(tr('gf.script.copied'))));
                        },
                      ),
                      OutlinedButton.icon(
                        icon: const Icon(Icons.copy, size: 16),
                        label: Text(tr('gf.script.copyManifest')),
                        onPressed: () {
                          Clipboard.setData(const ClipboardData(text: bookingManifestSnippet));
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(tr('gf.script.manifestCopied'))));
                        },
                      ),
                      FilledButton.tonalIcon(
                        icon: const Icon(Icons.open_in_new, size: 16),
                        label: Text(tr('gf.script.open')),
                        onPressed: () => launchUrl(Uri.parse('https://script.google.com/create'), webOnlyWindowName: '_blank'),
                      ),
                    ]),
                    const SizedBox(height: 8),
                    Text(tr('gf.script.manifest'), style: t.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
                    const SizedBox(height: 6),
                    Text(tr('gf.script.free'), style: t.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
                    const SizedBox(height: 6),
                    Text(tr('gf.script.warn'), style: t.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
                  ],
                ),
              ),
            for (var i = 2; i <= 5; i++) _step(context, i, tr('gf.step$i')),
            const SizedBox(height: 10),
            TextField(
              controller: link,
              decoration: InputDecoration(labelText: tr('gf.link'), hintText: 'https://forms.gle/…  /  https://docs.google.com/forms/d/e/…/viewform', border: const OutlineInputBorder(), isDense: true),
            ),
            if (!canFetchForm) ...[
              const SizedBox(height: 10),
              Text(tr('gf.pasteHelp'), style: t.bodySmall),
              const SizedBox(height: 6),
              TextField(controller: source, minLines: 2, maxLines: 4, decoration: InputDecoration(labelText: tr('gf.paste'), border: const OutlineInputBorder(), isDense: true)),
            ],
            const SizedBox(height: 10),
            Row(children: [
              FilledButton.icon(onPressed: busy ? null : _connect, icon: busy ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.link, size: 18), label: Text(tr('gf.read'))),
            ]),
            if (error != null) Padding(padding: const EdgeInsets.only(top: 10), child: Text(error!, style: t.bodyMedium?.copyWith(color: cs.error))),
            if (f != null) ...[
              const SizedBox(height: 14),
              Text(tr('gf.found', {'n': '${f.fields.length}', 'r': '${f.requiredCount}'}), style: t.titleSmall),
              if (calendarId != null) Padding(padding: const EdgeInsets.only(top: 4), child: Text(tr('gf.calFound'), style: t.bodySmall)),
              const SizedBox(height: 6),
              for (final x in f.fields)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 1),
                  child: Row(children: [
                    SizedBox(width: 76, child: Text(x.required ? tr('gf.required') : tr('gf.optional'), style: t.labelSmall?.copyWith(color: x.required ? cs.error : cs.onSurfaceVariant))),
                    Expanded(child: Text('${x.label}  ·  ${tr('gf.kind.${x.kind}')}${x.options.isEmpty ? '' : ' (${x.options.take(4).join(' / ')}${x.options.length > 4 ? '…' : ''})'}', style: t.bodySmall, maxLines: 2, overflow: TextOverflow.ellipsis)),
                  ]),
                ),
              if (f.skipped.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 6), child: Text(tr('gf.skipped', {'list': f.skipped.join(', ')}), style: t.bodySmall?.copyWith(color: cs.onSurfaceVariant))),
              const SizedBox(height: 6),
              Text(tr('gf.after'), style: t.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
            ],
          ]),
        ),
      ),
      actions: [
        if (widget.currentUrl.isNotEmpty) TextButton(onPressed: () => Navigator.pop(context, GoogleFormDialog.disconnectResult), child: Text(tr('gf.disconnect'))),
        TextButton(onPressed: () => Navigator.pop(context), child: Text(tr('btn.cancel'))),
        if (f != null) FilledButton(onPressed: () => Navigator.pop(context, GoogleFormResult(f, calendarId)), child: Text(tr('gf.use'))),
      ],
    );
  }
}
